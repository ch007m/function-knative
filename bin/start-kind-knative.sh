#!/bin/bash

set -eu
set -o errexit

export CLUSTER_NAME=${CLUSTER_NAME:-knative}
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# create registry container unless it already exists
export CONTAINER_REGISTRY_NAME='kind-registry'
export CONTAINER_REGISTRY_PORT='5000'

running="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_REGISTRY_NAME}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "${CONTAINER_REGISTRY_PORT}:5000" --name "${CONTAINER_REGISTRY_NAME}" \
    registry:2
fi

# Create a cluster with the local registry enabled in containerd
if [ -f ${CURRENT_DIR}/kind-knative-cfg.yml ];
then
 echo "Loading config from ${CURRENT_DIR}/kind-cluster-config.yaml"
 envsubst < ${CURRENT_DIR}/kind-knative-cfg.yml | kind create cluster \
    --name="${CLUSTER_NAME}" --config=-
else
  kind create cluster --name="${CLUSTER_NAME}"
fi

# connect the registry to the cluster network only for new
if [ "${running}" != 'true' ]; then
  docker network connect "kind" "${CONTAINER_REGISTRY_NAME}"
fi

## Label nodes for using registry
# tell https://tilt.dev to use the registry
# https://docs.tilt.dev/choosing_clusters.html#discovering-the-registry
for node in $(kind get nodes --name="$CLUSTER_NAME"); do
  kubectl annotate node "${node}" \
    "tilt.dev/registry=localhost:${CONTAINER_REGISTRY_PORT}" \
    "tilt.dev/registry-from-cluster=${CONTAINER_REGISTRY_NAME}:${CONTAINER_REGISTRY_PORT}";
done

## Label worker nodes
kubectl  get nodes --no-headers -l '!node-role.kubernetes.io/master' -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | xargs -I{} kubectl label node {} node-role.kubernetes.io/worker=''

######################################
## Knative Serving
######################################`
kubectl apply -f https://github.com/knative/serving/releases/download/v0.15.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/v0.15.0/serving-core.yaml

kubectl apply -f resources/kourier.yaml

kubectl patch configmap/config-network \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'

kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"127.0.0.1.nip.io":""}}'

# skip registriesSkippingTagResolving for few local and development registry prefixes
kubectl patch configmap/config-deployment \
    -n knative-serving \
    --type merge \
    -p '{"data":{"registriesSkippingTagResolving": "ko.local,dev.local,localhost:5000"}}'

