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
######### INGRESS CONTROLLER ##########
#######################################
# https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx
# The manifests contains kind specific patches to forward the hostPorts to the ingress controller, set taint tolerations and schedule it to the custom labelled node.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

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
# default login -- admin / admin