#!/bin/bash
set -e
set -a
. ./env.txt

BOOTSTRAP_CLUSTER_NAME=capg
export GCP_B64ENCODED_CREDENTIALS=$( cat $GOOGLE_APPLICATION_CREDENTIALS | base64 | tr -d '\n' )

echo "Check pre-requisites"
clusterctl version || (echo "clusterctl is not installed. Please install it first." && exit 1)
kind version || (echo "kind is not installed. Please install it first." && exit 1)
kubectl version || (echo "kubectl is not installed. Please install it first." && exit 1)
if ! docker info > /dev/null 2>&1; then
  echo "This script uses docker, and it isn't running - please start docker and try again!"
  exit 1
fi

echo "Get published GCE image"
export IMAGE_ID="projects/$GCP_PROJECT/global/images/$(gcloud compute images list --project $GCP_PROJECT --no-standard-images --filter="family:capi-ubuntu-1804-k8s" --format="value(name)")"

echo "Create a temporary kind bootstrap cluster"
kind get clusters | grep -q $BOOTSTRAP_CLUSTER_NAME || kind create cluster --name $BOOTSTRAP_CLUSTER_NAME

echo "Initialize CAPG"
kubectl get ns capg-system || clusterctl init --infrastructure gcp

echo "Generate CAPG manifests"
clusterctl generate cluster $CLUSTER_NAME \
  --kubernetes-version v$KUBERNETES_VERSION \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > $CLUSTER_NAME.yaml

# ClusterResourceSet isn't working for CAPG
# echo "Add calico label for ClusterResourceSet"
# yq e '.metadata.labels.cni="calico"' capg-demo.yaml

# echo "Append ClusterResourceSet Calico CNI to manifests"
# cat calico-crs.yaml >> $CLUSTER_NAME.yaml

echo "Apply CAPG manifest to bootstrap cluster"
kubectl apply -f $CLUSTER_NAME.yaml

echo "Sleep 5 minutes for cluster API to set up cluster"
# sleep 5m

echo "Get kubeconfig"
clusterctl get kubeconfig $CLUSTER_NAME > $CLUSTER_NAME.kubeconfig

echo "Install Calico CNI"
kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig apply -f https://docs.projectcalico.org/v3.21/manifests/calico.yaml

echo "Wait for nodes to be ready. You can have another window and run 'watch kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig get nodes' to monitor node status."
kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig wait --for=condition=Ready nodes --all --timeout=15m

echo "Init cluster API on the target management cluster"
clusterctl init --infrastructure gcp --kubeconfig=$CLUSTER_NAME.kubeconfig

echo "Pivot cluster API resources from bootstrap cluster to the target management cluster"
clusterctl move --to-kubeconfig=$CLUSTER_NAME.kubeconfig
kubectl --kubeconfig=./capg-demo.kubeconfig get gcpcluster -A
kubectl --kubeconfig=./capg-demo.kubeconfig get gcpmachine -A

echo "Pivot is done. Temporary bootstrap cluster can be deleted."

echo "Bootstrap flux"
flux bootstrap github \
  --owner=$FLUX_REPO_OWNER \
  --repository=$FLUX_REPO_NAME \
  --path=clusters/capg-demo \
  --personal \
  --kubeconfig=$CLUSTER_NAME.kubeconfig