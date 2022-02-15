# TAP OSS Scripts
This folder contains scripts to help with woking with the TAP OSS stack.

## Checking TAP OSS Stack Status
There is a script in this folder called **check-tap-oss-status.sh**.  
This script provides a simple and human readable output on the status of the platform and all its core components.  
  
### Running the script
```bash
./check-tap-oss-status.sh
```  
  
### Example Output
```bash
Package Repository Status: Reconcile succeeded
Package Install Statuses:
  * TAP Installation Package: Reconcile succeeded
  * Cert Manager: Reconcile succeeded
  * Contour: Reconcile succeeded
  * Knative Serving: Reconcile succeeded
  * Flux Source Controller: Reconcile succeeded
  * Developer Namespace Preperation: Reconcile succeeded
  * Kpack: Reconcile succeeded
  * Kpack Configuration: Reconcile succeeded
  * OOTB Supply Chains: Reconcile succeeded
  * Service Bindings: Reconcile succeeded
  * Tekton: Reconcile succeeded
Custom Resource Statuses:
  * Kpack:
    * Cluster Stack: Ready = True
    * Cluster Store: Ready = True
    * Cluster Builder: Ready = True - (registry.local:5000/tap-oss/builder@sha256:138762bd2a4ecc0f6b50980b12961fbdd29ba7b6e767f0f21b02c6dbe2ee6b5b)
Configured Supply Chains:
  ootb-basic-supply-chain Selectors:
    apps.tanzu.vmware.com/workload-type: "web"

  ootb-basic-supply-chain-with-kaniko Selectors:
    apps.tanzu.vmware.com/image-builder: "kaniko"
    apps.tanzu.vmware.com/workload-type: "web"

  ootb-gitops-supply-chain Selectors:
    apps.tanzu.vmware.com/gitops: "true"
    apps.tanzu.vmware.com/workload-type: "web"

  ootb-gitops-supply-chain-with-svc-bindings Selectors:
    apps.tanzu.vmware.com/gitops: "true"
    apps.tanzu.vmware.com/has-bindings: "true"
    apps.tanzu.vmware.com/workload-type: "web"

  ootb-svc-binding-native-k8s-deployment Selectors:
    apps.tanzu.vmware.com/has-db-binding: "true"
    apps.tanzu.vmware.com/native-k8s-deployment: "true"
    apps.tanzu.vmware.com/workload-type: "web"

  ootb-testing-supply-chain Selectors:
    apps.tanzu.vmware.com/has-tests: "true"
    apps.tanzu.vmware.com/workload-type: "web"

Deployed Workloads:
  go-demo-app [default] Status:
    Ready = True
    Applied Supply Chain: ootb-basic-supply-chain
```

## Self Contained Local Environment
This script will bring up a tanzu unmanaged cluster (TCE 0.10.0) and install the entire TAP OSS stask on it.  
This script requires no variable and everything is preconfigured to work OOTB.  
The script installs and configures:  
1. A TCE Unmanaged Cluster with exposed ports of 443 and 80 to support ingress
2. A local registry in docker to be used for all images and artifacts needed for the platform
3. Gitea - A simple git server implementation run on kubernetes to support testing the GitOps flow in TAP OSS
4. Creates a Wildcard Cert for \*.127.0.0.1.nip.io and uses that for all knative services being deployed.
5. Creates an SSH Key for git authentication and configures it in Gitea
6. Configures the TCE cluster to trust the insucre docker registry
7. Deploys and configures TAP OSS full stack deployment
8. Validates and waits for all components to be up and running
  
### Pre Reqs
1. You need the following CLIs installed:
* kubectl
* Tanzu CLI for TCE - version 0.10.0+
* docker (tested on ubuntu and WSL2)
* jq
* helm
2. You cannot have an application bound to ports 80 or 443 on the node you run this on or the platform wont work
  
### Running the script
```bash
./local-env/deploy-tap-oss-contained-env.sh
```  

### Credentials and URLs:
1. Gitea
* URL: https://gitea.127.0.0.1.nip.io
* User: gitea\_admin
* Password: VMware1!
2. Registry:
* FQDN in kubernetes: registry.local:5000
* User: user
* Password: password
* FQDN from host machine: localhost:5000

### Cleanup
To delete the environment brought up as part of the loal env you can run the cleanup script:
```bash
./local-env/clean-up-tap-oss-contained-env.sh
```
