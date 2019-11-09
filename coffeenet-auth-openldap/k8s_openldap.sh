#!/bin/bash

PORT=389
CONTAINER_VERSION=1.2.2
NAME=coffeenet-auth-openldap
NAMESPACE=coffeenet

## default configuration options
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-admin}


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
  name: $NAME
type: Opaque
data:
  ldapAdminPassword: $(encode_secret $LDAP_ADMIN_PASSWORD)
YAML
)

just_do_k8s "$SECRETS"


DEPLOYMENT=$(cat<<YAML
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: $NAME
  name: $NAME
spec:
  ports:
  - port: $PORT
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
    spec:
      containers:
      - name: $NAME
        image: osixia/openldap:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        env:
        - name: LDAP_TLS
          value: "false"
        - name: LDAP_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAME
              key: ldapAdminPassword
        livenessProbe:
          tcpSocket:
            port: $PORT
          initialDelaySeconds: 20
          periodSeconds: 10
          failureThreshold: 10
        readinessProbe:
          tcpSocket:
            port: $PORT
          initialDelaySeconds: 20
          periodSeconds: 10
          failureThreshold: 10

YAML
)

just_do_k8s "$DEPLOYMENT"

kubectl rollout status deployment "$NAME" -n "$NAMESPACE"
