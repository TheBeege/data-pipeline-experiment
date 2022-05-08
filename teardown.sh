#!/usr/bin/env bash

set -e

kind delete cluster --name data-pipeline
docker stop kind-registry && docker rm kind-registry
