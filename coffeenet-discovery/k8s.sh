#!/bin/bash

PORT=8761
HOST=coffeenet-discovery.192.168.99.100.nip.io
CONTAINER_VERSION=1.13.1
NAME=coffeenet-discovery
NAMESPACE=coffeenet

function encode_secret {
  echo -n "$1" | base64 -w 0
}

function hashsum {
    echo "$1" | sha256sum | awk '{print $1}'
}

function just_do_k8s {
    echo -n "$1" | kubectl apply -n $NAMESPACE -f -
}


CONFIG=$(cat <<YAML
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $NAME
data:
  application.yaml: |
    server:
      port: $PORT
    eureka:
      environment: docker
      datacenter: docker
      server:
        waitTimeInMsWhenSyncEmpty: 0
    coffeenet:
      profile: integration
      application-name: CoffeeNet Discovery
      allowed-authorities: ROLE_COFFEENET-ADMIN
      discovery:
        instance:
          home-page-url: http://$HOST/
          hostname: $HOST
        client:
          service-url:
            defaultZone: http://$HOST/eureka/
          register-with-eureka: true
          fetch-registry: false
      logging:
        console:
          enabled: true

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
        config-hash: $(hashsum "$CONFIG")
    spec:
      containers:
      - name: coffeenet-discovery
        image: coffeenet/coffeenet-discovery:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        livenessProbe:
          httpGet:
            path: /health
            port: $PORT
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /health
            port: $PORT
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 5
        env:
        - name: JAVA_OPTIONS
          value: ""
        - name: JVM_OPTIONS
          value: "-XX:+PrintFlagsFinal -XX:+PrintGCDetails"
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
