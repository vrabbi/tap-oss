# TAP OSS Stack

## Overview
This repo contains the source configuration built for a TAP OSS stack installation.  
This Package repository has been tested on TCE 0.9.1 and TKGm 1.4 and works with the installed versions of Kapp Controller and doesnt require upgrading of Kapp Controller nor does it require secretgen inorder to work.  
## Why
Tanzu Application Platform is an amazing platform and is vastly built on open source projects. This repo brings together the Open source tools that are part of TAP into an easy installation method similar to TAP for the OSS community.  
As not everyone has licensing for the TAP, this is meant as a way to play with the underlying technologies and understand at least in part what TAP "feels like".  
  
## Whats included:
This package repository includes the following packages:  
1. **tap-install.tap.oss** - A single package that can install all other packages to allow for a simple installation like found in TAP  
2. **cartographer.tap.oss** - A package based on the official package from the cartographer repo  
3. **dev-ns-preperation.tap.oss** - A package for creating all the needed objects in a namespace (including the namespace itself if wanted) to run TAP OSS workloads  
4. **flux-source-controller.tap.oss** - A package for installing Flux Source Controller  
5. **kpack-config.tap.oss** - A package with configuration to setup kpack with Paketo buildpacks  
6. **ootb-supply-chains.tap.oss** - A package that includes Supply chains for use in the cluster  
7. **tekton.tap.oss** - A package to install Tekton to run pipelines within our supply chains  
8. **kpack.tap.oss** - This is the TCE Kpack package simply in the same repo to not have a requirement to install the TCE repo as well  
9. **knative-serving.tap.oss** - This is the TCE Knative Serving package simply in the same repo to not have a requirement to install the TCE repo as well  
10. **cert-manager.tap.oss** - This is the TCE Cert Manager package simply in the same repo to not have a requirement to install the TCE repo as well  
11. **contour.tap.oss** - This is the TCE Contour package simply in the same repo to not have a requirement to install the TCE repo as well  
  
## Installation instructions on TCE and TKGm
1. Create the TAP OSS namespace  
```bash
kubectl create namespace tap-oss
```  
2. Install the Package repository  
```bash
tanzu package repository add tap-oss -n tap-oss --url ghcr.io/vrabbi/tap-oss-repo:0.1.5
```  
3. Create a values file for installing the platform
```bash
cat <<EOF > tap-oss-values.yaml
contour:
  envoy:
    service:
      type: <FILL ME IN>
kpack:
  kp_default_repository: <FILL ME IN>
  kp_default_repository_password: <FILL ME IN>
  kp_default_repository_username: <FILL ME IN>
kpack_config:
  builder:
    tag: <FILL ME IN>
knative:
  domain:
    name: <FILL ME IN>
    type: real
dev_ns_preperation:
  registry:
    username: <FILL ME IN>
    password: <FILL ME IN>
    server: <FILL ME IN>
  namespaces:
  - name: "default"
    exists: true
    createPipeline: true
    language: go
    gitops:
      enabled: true
      base64_encoded_ssh_key: <FILL ME IN>
      base64_encoded_known_hosts: ""
  - name: "example-ns-01"
    exists: false
    createPipeline: true
    language: go
    gitops:
      enabled: true
      base64_encoded_ssh_key: <FILL ME IN>
      base64_encoded_known_hosts: ""
ootb_supply_chains:
  image_prefix: <FILL ME IN>
  gitops:
    configure: true
    git_writer:
      message: "TAP OSS Based Update of app configuration"
      ssh_user: "git"
      server: "github.com"
      repository: <FILL ME IN>
      base64_encoded_ssh_key: <FILL ME IN>
      base64_encoded_known_hosts: ""
      branch: <FILL ME IN>
      username: <FILL ME IN>
      user_email: <FILL ME IN>
      port: ""
  testing:
    configure: true
EOF
```  
4. Update values file with your configuration values  
&nbsp;&nbsp;&nbsp;&nbsp;Check out the [INSTALL_VALUES_EXPLANATION.md](INSTALL_VALUES_EXPLANATION.md) file for more info on the configuration parameters
5. Install the Platform  
```bash
tanzu package install tap -n tap-oss -p tap-install.tap.oss -v 0.1.3 -f tap-oss-values.yaml
```  
5. Wait for all package installs to reconcile
```bash
kubectl get pkgi -n tap-oss
```  
6. Enjoy!
