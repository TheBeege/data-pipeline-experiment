#!/usr/bin/env bash

set -e

#######################################
############ LOCAL REGISTRY ###########
#######################################
# Thanks to https://kind.sigs.k8s.io/docs/user/local-registry/
# create registry container unless it already exists
# These two vars' values are also set in config.kind.yaml
#   and registry.configmap.yaml
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

#######################################
############ SET UP CLUSTER ###########
#######################################
if [[ "$(kind get clusters)" != *"data-pipeline"* ]]
then
  kind create cluster --name data-pipeline --config kubernetes/config.kind.yaml
fi

# connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

if [[ -z "$(kubectl get namespaces data-pipeline --ignore-not-found | tail -n 1)" ]]
then
  kubectl create namespace data-pipeline
fi

# Just docs, but good idea
if [[ -z "$(kubectl get configmap local-registry-hosting -n data-pipeline --ignore-not-found)" ]]
then
  kubectl apply -f kubernetes/registry.configmap.yaml
fi

if [[ -z "$(kubectl get pvc pvc-notebook --ignore-not-found -n data-pipeline)" ]]
then
  kubectl apply -n data-pipeline -f kubernetes/notebook.pvc.yaml
fi

#######################################
########## HELM REPOSITORIES ##########
#######################################
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add nginx-stable https://helm.nginx.com/stable

#######################################
######### INGRESS CONTROLLER ##########
#######################################
if [[ -z "$(kubectl get deployments ingress-nginx-controller --ignore-not-found -n ingress-nginx)" ]]
then
  # https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx
  # The manifests contains kind specific patches to forward the hostPorts to the ingress controller, set taint tolerations and schedule it to the custom labelled node.
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl annotate ingressclass nginx ingressclass.kubernetes.io/is-default-class=true
  sleep 2
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
fi

#######################################
############## DATABASE ###############
#######################################
if [[ -z "$(kubectl get configmap mariadb-init-scripts -n data-pipeline --ignore-not-found)" ]]
then
  kubectl apply -f kubernetes/initScriptsConfigmap.mariadb.yaml
fi
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
############ PREFECT FLOWS ############
#######################################
# should have a hosts file entry where registry-docker-registry is localhost
prefect backend server
kubectl wait --namespace data-pipeline \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=apollo \
  --timeout=120s
export PREFECT__SERVER__ENDPOINT=http://localhost:8000/apollo
if [[ "$(prefect get projects --name twitter-pipeline | tail -n 1)" != "twitter-pipeline"* ]]
then
  prefect create project twitter-pipeline
fi
source .env && python flows/register_flow.py
