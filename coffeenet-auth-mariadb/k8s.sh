#!/bin/bash

PORT=3306
CONTAINER_VERSION=10.3.9
NAME=coffeenet-auth-mariadb
NAMESPACE=coffeenet


## default configuration options
MYSQL_USER=${MYSQL_USER:-auth}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-auth}

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
  mysqlUser: $(encode_secret $MYSQL_USER)
  mysqlPassword: $(encode_secret $MYSQL_PASSWORD)
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
  create-auth-database.sql: |
    CREATE DATABASE IF NOT EXISTS \`auth\` CHARACTER SET UTF8 COLLATE utf8_unicode_ci;
    GRANT ALL ON \`auth\`.* TO 'auth'@'%';
    -- Make privileges active
    FLUSH PRIVILEGES;
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
        config-hash: $(hashsum "$CONFIG")
    spec:
      containers:
      - name: $NAME
        image: mariadb:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        livenessProbe:
          exec:
            command: ["sh", "-c", "/usr/bin/mysql --user=\$MYSQL_USER --password=\$MYSQL_PASSWORD --execute \"SHOW DATABASES;\""]
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 5
        readinessProbe:
          exec:
            command: ["sh", "-c", "/usr/bin/mysql --user=\$MYSQL_USER --password=\$MYSQL_PASSWORD --execute \"SHOW DATABASES;\""]
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 5
        env:
        - name: MYSQL_RANDOM_ROOT_PASSWORD
          value: "yes"
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: $NAME
              key: mysqlUser
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAME
              key: mysqlPassword
        volumeMounts:
        - name: entrypoint-initdb
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: entrypoint-initdb
        configMap:
          name: $NAME
YAML
)

just_do_k8s "$DEPLOYMENT"

kubectl rollout status deployment "$NAME" -n "$NAMESPACE"
