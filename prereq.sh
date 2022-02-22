set -a
. ./env.txt

echo "Set gcloud project"
gcloud config set project $GCP_PROJECT

echo "Create routers"
gcloud compute routers create "${CLUSTER_NAME}-myrouter" --project=$GCP_PROJECT --region=$GCP_REGION --network=$GCP_NETWORK_NAME

echo "Create NAT"
gcloud compute routers nats create "${CLUSTER_NAME}-mynat" --project=$GCP_PROJECT --router-region=$GCP_REGION --router="${CLUSTER_NAME}-myrouter" \
    --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips

echo "Create service account"
gcloud iam service-accounts create capg-sa \
    --description="service account used by capg" \
    --display-name="capg-sa"

echo "Bind Editor role to service account"
gcloud projects add-iam-policy-binding cx-tom \
    --member="serviceAccount:capg-sa@cx-tom.iam.gserviceaccount.com" \
    --role="roles/editor"

echo "Generate service account key"
gcloud iam service-accounts keys create $GOOGLE_APPLICATION_CREDENTIALS \
    --iam-account=capg-sa@cx-tom.iam.gserviceaccount.com

echo "Clone the image builder repository"
rm -rf /tmp/image-builder && git clone https://github.com/kubernetes-sigs/image-builder.git /tmp/image-builder

export GCP_PROJECT_ID=$GCP_PROJECT

echo "Run the Make target to generate GCE images"
cd /tmp/image-builder/images/capi && make build-gce-ubuntu-1804

echo "Check that you can access the published images"
gcloud compute images list --project ${GCP_PROJECT} --no-standard-images --filter="family:capi-ubuntu-1804-k8s"