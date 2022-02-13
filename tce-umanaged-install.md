# Install instructions for TAP OSS on a TCE unmanaged cluster
1. Create a cluster and expose the relevant ports
```bash
tanzu um create tap-oss-cls-01 -c calico -p 80:80/tcp -p 443:443/tcp
```  
2. Add the package repository for TAP OSS to the cluster
```bash
tanzu package repository add tap-oss -n tap-oss --create-namespace --url ghcr.io/vrabbi/tap-oss-repo:0.2.3
```  
3. Create a values file replacing the marked fields as needed:
```bash
export KP_DEFAULT_REPO=harbor.example.com/tap-oss
export KP_DEFAULT_REPO_PASSWORD=Harbor12345
export KP_DEFAULT_REPO_USERNAME=admin
export KP_BUILDER_TAG=harbor.vrabbi.cloud/tap-oss/builder
export IMAGE_REGISTRY_USERNAME=admin
export IMAGE_REGISTRY_PASSWORD=Harbor12345
export IMAGE_REGISTRY_FQDN=harbor.example.com
export GITHUB_SSH_PRIVATE_KEY=""
export IMAGE_PREFIX=harbor.vrabbi.cloud/workloads/oss-
export GITOPS_DEST_REPO=example/tap-gitops-demo.git
export GITHUB_USERNAME=example
cat << EOF > tap-oss-values.yaml
contour:
  envoy:
    hostPorts:
      enable: true
    service:
      type: ClusterIP
kpack:
  kp_default_repository: "$KP_DEFAULT_REPO"
  kp_default_repository_password: "$KP_DEFAULT_REPO_PASSWORD"
  kp_default_repository_username: "$KP_DEFAULT_REPO_USERNAME"
kpack_config:
  builder:
    tag: "$KP_BUILDER_TAG"
knative:
  domain:
    type: real
    name: 127.0.0.1.nip.io
dev_ns_preperation:
  registry:
    username: "$IMAGE_REGISTRY_USERNAME"
    password: "$IMAGE_REGISTRY_PASSWORD"
    server: "$IMAGE_REGISTRY_FQDN"
  namespaces:
  - name: "default"
    exists: true
    createPipeline: true
    language: go
    gitops:
      enabled: true
      base64_encoded_ssh_key: "$GITHUB_SSH_PRIVATE_KEY"
      base64_encoded_known_hosts: ""
  - name: "team-a"
    exists: false
    createPipeline: true
    language: java
    gitops:
      enabled: true
      base64_encoded_ssh_key: "$GITHUB_SSH_PRIVATE_KEY"
      base64_encoded_known_hosts: ""
ootb_supply_chains:
  image_prefix: "$IMAGE_PREFIX"
  gitops:
    configure: true
    git_writer:
      message: "TAP OSS Based Update of app configuration"
      ssh_user: "git"
      server: "github.com"
      repository: "$GITOPS_DEST_REPO"
      base64_encoded_ssh_key: "$GITHUB_SSH_PRIVATE_KEY"
      base64_encoded_known_hosts: ""
      branch: "oss"
      username: "$GITHUB_USERNAME"
      user_email: "gitops@tap.oss"
      port: ""
  testing:
    configure: true
cert_injection_webhook:
  ca_cert_data: ""
EOF
```  
4. Install the platform
```bash
tanzu package install tap -p tap-install.tap.oss -v 0.2.3 -n tap-oss -f tap-oss-values.yaml
```
