#!/usr/bin/env bash

set -e

# Set up docker daemon file to support the registry we'll set up
echo 'You MUST set {"insecure-registries": ["registry-docker-registry:5000"]} in your Docker Desktop engine configuration'
echo 'You must also add 127.0.0.1 registry-docker-registry to your /etc/hosts file on the host OS'
read -p "Press enter to continue"

#if [[ ! -f "/etc/docker/daemon.json" ]]
#then
#  echo '{"insecure-registries": ["registry-docker-registry:5000"]}' | jq -M | sudo tee /etc/docker/daemon.json > /dev/null
#elif [ "$(jq '.["insecure-registries"] | index ("registry-docker-registry:5000")' /etc/docker/daemon.json)" != 0 ]
#then
#  cat /etc/docker/daemon.json | jq -M '.["insecure-registries"] += ["registry-docker-registry:5000"]' | sudo tee /etc/docker/daemon.json > /dev/null
#fi

# Install kind separately
kind create cluster --name data-pipeline --config kubernetes/config.kind.yaml

kubectl create namespace data-pipeline
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
kubectl annotate ingressclass nginx ingressclass.kubernetes.io/is-default-class=true
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

#######################################
############## DATABASE ###############
#######################################
helm upgrade --cleanup-on-fail \
  --install database bitnami/mariadb \
  --namespace data-pipeline \
  --values kubernetes/values.mariadb.yaml

#######################################
############## PREFECT ################
#######################################
helm repo add prefecthq https://prefecthq.github.io/server/
helm upgrade --cleanup-on-fail \
 --install pipeline prefecthq/prefect-server \
 --namespace data-pipeline \
 --values kubernetes/values.prefect.yaml
# http://localhost:8000/

#######################################
########## JUPYTER NOTEBOOK ###########
#######################################
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm upgrade --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace data-pipeline \
  --values kubernetes/values.jupyterhub.yaml
# http://localhost:8000/jupyterhub
# default login -- admin / admin

#######################################
########### DOCKER REGISTRY ###########
#######################################
helm repo add twuni https://helm.twun.io
helm upgrade --cleanup-on-fail \
  --install registry twuni/docker-registry \
  --namespace data-pipeline \
  --set service.type=NodePort \
  --set service.nodePort=30500

#######################################
############ PREFECT FLOWS ############
#######################################
# should have a hosts file entry where registry-docker-registry is localhost
prefect backend server
PREFECT__SERVER__ENDPOINT=http://localhost:8000/apollo prefect create project twitter-pipeline
docker build -t 127.0.0.1:30500/twitter-data-science:latest flows/
kubectl port-forward -n data-pipeline service/registry-docker-registry 30500:5000 > /dev/null 2>&1 &
docker push 127.0.0.1:30500/twitter-data-science:latest
kill $(jobs -l | grep "kubectl port-forward" | awk '{print $2}')
PREFECT__SERVER__ENDPOINT=http://localhost:8000/apollo python flows/register_flow.py
