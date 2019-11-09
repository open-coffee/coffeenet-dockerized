#!/bin/bash

PORT=80
CONTAINER_VERSION=0.7.2
NAME=coffeenet-auth-phpldapadmin
NAMESPACE=coffeenet

HOST="$NAME.192.168.99.100.nip.io"

LDAP_HOSTS=${LDAP_HOSTS:-coffeenet-auth-openldap.$NAMESPACE.svc.cluster.local}

function just_do_k8s {
    echo -n "$1" | kubectl apply -n $NAMESPACE -f -
}

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
    spec:
      containers:
      - name: $NAME
        image: osixia/phpldapadmin:$CONTAINER_VERSION
        ports:
        - containerPort: $PORT
        env:
        - name: PHPLDAPADMIN_HTTPS
          value: "false"
        - name: PHPLDAPADMIN_LDAP_HOSTS
          value: "$LDAP_HOSTS"
        - name: PHPLDAPADMIN_LDAP_CLIENT_TLS
          value: "false"
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
