#!/bin/bash

PORT=9999
HOST=coffeenet-auth.192.168.99.100.nip.io
CONTAINER_VERSION=1.16.1
NAME=coffeenet-auth
NAMESPACE=coffeenet


## default configuration options
MYSQL_USER=${MYSQL_USER:-auth}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-auth}
MYSQL_SERVER_URI=jdbc:mariadb://coffeenet-auth-mariadb.$NAMESPACE.svc.cluster.local:3306/auth
LDAP_SERVER_URI=ldap://coffeenet-auth-openldap.$NAMESPACE.svc.cluster.local:389
LDAP_BIND_DN=${LDAP_BIND_DN:-cn=admin,dc=example,dc=org}
LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-admin}
DISCOVERY_SERVER_URI=http://coffeenet-discovery.$NAMESPACE.svc.cluster.local/eureka/


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
  name: $NAME-mysql
type: Opaque
data:
  mysqlUser: $(encode_secret $MYSQL_USER)
  mysqlPassword: $(encode_secret $MYSQL_PASSWORD)
---
apiVersion: v1
kind: Secret
metadata:
  labels:
    app: $NAME
  name: $NAME-ldap
type: Opaque
data:
  ldapBindDn: $(encode_secret $LDAP_BIND_DN)
  ldapBindPassword: $(encode_secret $LDAP_BIND_PASSWORD)
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
      application-name: CoffeeNet Auth
      allowed-authorities: ROLE_COFFEENET-ADMIN
      security:
        enabled: false
      discovery:
        instance:
          home-page-url: http://$HOST/clients
          hostname: $HOST
        client:
          service-url:
            defaultZone: $DISCOVERY_SERVER_URI
      logging:
        console:
          enabled: true
    auth:
      development: true
      default-redirect-url: http://$HOST/clients
      ldap:
        url: $LDAP_SERVER_URI
        base: dc=example,dc=org
        userSearchBase: ou=People
        userSearchFilter: (uid={0})
        groupSearchBase: ou=Groups
        groupSearchFilter: member={0}
        connection-with-tls: false
    server:
      port: $PORT
      session:
        cookie:
          name: coffee-cookie
    endpoints.health.sensitive: false
    spring:
      datasource:
        url: $MYSQL_SERVER_URI
        driver-class-name: org.mariadb.jdbc.Driver
        tomcat:
          test-on-borrow: true
          validation-query: SELECT 1
      jpa:
        hibernate:
          ddl-auto: validate
      messages:
        fallback-to-system-locale: false

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
        image: coffeenet/coffeenet-auth:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        livenessProbe:
          httpGet:
            path: /health
            port: $PORT
          initialDelaySeconds: 60
          periodSeconds: 10
          failureThreshold: 10
        readinessProbe:
          httpGet:
            path: /health
            port: $PORT
          initialDelaySeconds: 60
          periodSeconds: 10
          failureThreshold: 10
        env:
        - name: JAVA_OPTIONS
          value: ""
        - name: JVM_OPTIONS
          value: "-XX:+PrintFlagsFinal -XX:+PrintGCDetails"
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: $NAME-mysql
              key: mysqlUser
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAME-mysql
              key: mysqlPassword
        - name: AUTH_LDAP_BIND_DN
          valueFrom:
            secretKeyRef:
              name: $NAME-ldap
              key: ldapBindDn
        - name: AUTH_LDAP_BIND_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAME-ldap
              key: ldapBindPassword
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
