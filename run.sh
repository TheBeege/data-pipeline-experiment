#!/usr/bin/env bash

# Install kind separately
kind create cluster --name data-pipeline --config kubernetes/config.kind.yaml

kubectl create namespace data-pipeline
kubectl create namespace metallb-system
kubectl apply -n data-pipeline -f kubernetes/notebook.pvc.yaml

#######################################
########## HELM REPOSITORIES ##########
#######################################
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add nginx-stable https://helm.nginx.com/stable

#######################################
# LOAD BALANCER AND INGRESS CONTROLLER #
#######################################
helm upgrade --namespace metallb-system --install metallb bitnami/metallb
kubectl apply -n metallb-system -f kubernetes/config.metallb.yaml
helm install nginx-controller nginx-stable/nginx-ingress

#######################################
############## DATABASE ###############
#######################################
helm upgrade \
  --install database bitnami/mariadb \
  --namespace data-pipeline \
  --values kubernetes/values.mariadb.yaml

#######################################
########## JUPYTER NOTEBOOK ###########
#######################################
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm upgrade --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace data-pipeline \
  --values kubernetes/values.jupyterhub.yaml
