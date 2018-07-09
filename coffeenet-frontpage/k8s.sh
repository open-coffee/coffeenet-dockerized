#!/bin/bash

PORT=8080
HOST=coffeenet-frontpage.192.168.99.100.nip.io
CONTAINER_VERSION=0.5.0
NAME=coffeenet-frontpage
NAMESPACE=coffeenet


## default configuration options
DISCOVERY_SERVER_URI=http://coffeenet-discovery.$NAMESPACE.svc.cluster.local/eureka/
AUTH_SERVER_URI=http://coffeenet-auth.192.168.99.100.nip.io
MONGO_USER=${MONGO_USER:-frontpage}
MONGO_PASSWORD=${MONGO_PASSWORD:-frontpage}
MONGO_HOST=coffeenet-frontpage-mongodb.$NAMESPACE.svc.cluster.local
MONGO_PORT=27017
OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID:-coffeeNetClient}
OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET:-coffeeNetClientSecret}



function encode_secret {
  echo -n "$1" | base64 -w 0
}

function hashsum {
    echo "$1" | sha256sum | awk '{print $1}'
}

function just_do_k8s {
    echo -n "$1" | kubectl apply -n $NAMESPACE -f -
}

SECRETS=$(cat<<YAML
---
apiVersion: v1
kind: Secret
metadata:
  labels:
    app: $NAME
  name: $NAME-mongo
type: Opaque
data:
  mongoUser: $(encode_secret $MONGO_USER)
  mongoPassword: $(encode_secret $MONGO_PASSWORD)
---
apiVersion: v1
kind: Secret
metadata:
  labels:
    app: $NAME
  name: $NAME-oauth
type: Opaque
data:
  clientId: $(encode_secret $OAUTH_CLIENT_ID)
  clientSecret: $(encode_secret $OAUTH_CLIENT_SECRET)
YAML
)

just_do_k8s "$SECRETS"


CONFIG=$(cat <<YAML
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $NAME
data:
  application.yaml: |
    coffeenet:
      profile: integration
      application-name: CoffeeNet Frontpage
      allowed-authorities: ROLE_COFFEENET-ADMIN
      discovery:
        instance:
          home-page-url: http://$HOST/
          hostname: $HOST
        client:
          service-url:
            defaultZone: $DISCOVERY_SERVER_URI
      security:
        client:
          accessTokenUri: $AUTH_SERVER_URI/oauth/token
          userAuthorizationUri: $AUTH_SERVER_URI/oauth/authorize
        logoutSuccessUrl: $AUTH_SERVER_URI/logout
        resource:
          user-info-uri: $AUTH_SERVER_URI/user
      logging:
        console:
          enabled: true
    endpoints.health.sensitive: false
    health.config.enabled: false
    server:
      port: $PORT
    spring:
      data:
        mongodb:
          host: $MONGO_HOST
          port: $MONGO_PORT
          authentication-database: admin
          database: frontpage
YAML
)

just_do_k8s "$CONFIG"

DEPLOYMENT=$(cat <<YAML
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: $NAME
  name: $NAME
spec:
  ports:
  - port: 80
    targetPort: $PORT
  selector:
    app: $NAME
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: $NAME
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: $NAME
      annotations:
        secret-hash: $(hashsum "$SECRETS")
        config-hash: $(hashsum "$CONFIG")
    spec:
      containers:
      - name: $NAME
        image: coffeenet/coffeenet-frontpage:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        env:
        - name: JAVA_OPTIONS
          value: ""
        - name: JVM_OPTIONS
          value: "-XX:+PrintFlagsFinal -XX:+PrintGCDetails"
        - name: SPRING_DATA_MONGODB_USERNAME
          valueFrom:
            secretKeyRef:
              name: $NAME-mongo
              key: mongoUser
        - name: SPRING_DATA_MONGODB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAME-mongo
              key: mongoPassword
        - name: COFFEENET_SECURITY_CLIENT_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: $NAME-oauth
              key: clientId
        - name: COFFEENET_SECURITY_CLIENT_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: $NAME-oauth
              key: clientSecret
        volumeMounts:
        - name: config-volume
          mountPath: /config
      volumes:
      - name: config-volume
        configMap:
          name: $NAME
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: $NAME
  annotations:
    ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: $HOST
    http:
      paths:
      - path: /
        backend:
          serviceName: $NAME
          servicePort: 80
YAML
)

just_do_k8s "$DEPLOYMENT"

kubectl rollout status deployment "$NAME" -n "$NAMESPACE"

echo "$NAME is available via http://$HOST"
