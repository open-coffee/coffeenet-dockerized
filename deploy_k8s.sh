#!/bin/bash

echo "==> going to bootstrap coffeenet on your configured k8s cluster"

kubectl cluster-info

echo "==> creating namespace coffeenet"
kubectl create namespace coffeenet


echo "==> deploying coffeenet-auth"

echo "==> deploying coffeenet-auth: mariadb"
./coffeenet-auth-mariadb/k8s.sh


echo "==> deploying coffeenet-auth: openldap"
./coffeenet-auth-openldap/k8s_openldap.sh

echo "==> deploying coffeenet-auth: phpldapadmin"
./coffeenet-auth-openldap/k8s_phpldapadmin.sh

echo "==> deploying coffeenet-auth: auth-server"
./coffeenet-auth/k8s.sh


echo "==> deploying coffeenet-discovery"
./coffeenet-discovery/k8s.sh


echo "==> deploying coffeenet-frontpage"

echo "==> deploying coffeenet-frontpage: mongodb"
./coffeenet-frontpage-mongodb/k8s.sh

echo "==> deploying coffeenet-frontpage: frontpage"
./coffeenet-frontpage/k8s.sh

