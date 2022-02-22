# Cluster API for GCP Demo
GitOps for applications is cool. Now we want to GitOps infrastucture as well. This repository contains scripts to bootstrap a GitOps-enabled CAPG management cluster.
Once the management cluster is set up, additional workload clusters and other infrastructure resources can be created the GitOps way thanks to CAPI and GCP Config Connector.

### Pre-requisites
- kubectl
- kind
- clusterctl
- gcloud
- flux

## Usage

1. Create a GCP project and update variable `GCP_PROJECT` in `env.txt`.

2. Set up CAPG pre-requisites
    ```
    ./prereq.sh
    ```

3. Create a temporary kind cluster, bootstrap a CAPG management cluster, pivot CAPI resource, and bootstrap flux
    ```
    ./bootstrap.sh
    ```
