# Cluster API for GCP Demo
This repository contains scripts to set up a CAPG cluster for demonstration purpose.

### Pre-requisites
- kubectl
- kind
- clusterctl
- gcloud

## Usage

1. Create a GCP project and update variable `GCP_PROJECT` in `env.txt`.

2. Set up CAPG pre-requisites
    ```
    ./prereq.sh
    ```

3. Bootstrap a kind cluster and provision a CAPG cluster
    ```
    ./bootstrap.sh
    ```

4. 