#!/bin/bash

PORT=27017
CONTAINER_VERSION=4.0
NAME=coffeenet-frontpage-mongodb
NAMESPACE=coffeenet


## default configuration options
MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME:-frontpage}
MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD:-frontpage}

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
  mongoInitdbRootUsername: $(encode_secret $MONGO_INITDB_ROOT_USERNAME)
  mongoInitdbRootPassword: $(encode_secret $MONGO_INITDB_ROOT_PASSWORD)
YAML
)

just_do_k8s "$SECRETS"


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
        image: mongo:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        livenessProbe:
          exec:
            command: ["sh", "-c", "echo 'db.stats().ok' | mongo localhost:$PORT/admin --quiet"]
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 5
        readinessProbe:
          exec:
            command: ["sh", "-c", "echo 'db.stats().ok' | mongo localhost:$PORT/admin --quiet"]
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 5
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: $NAME
              key: mongoInitdbRootUsername
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAME
              key: mongoInitdbRootPassword
YAML
)

just_do_k8s "$DEPLOYMENT"

kubectl rollout status deployment "$NAME" -n "$NAMESPACE"
