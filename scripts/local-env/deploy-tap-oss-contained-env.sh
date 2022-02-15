mkdir -p tap-oss-contained-env-files
cd tap-oss-contained-env-files
tanzu um create tap-oss-cls-01 -c calico -p 80:80/tcp -p 443:443/tcp
docker run -d --restart=always -p "5000:5000" --name "registry.local" registry:2
docker network connect kind registry.local
docker cp tap-oss-cls-01-control-plane:/etc/containerd/config.toml ./config.toml
cat << EOF >> config.toml
[plugins."io.containerd.grpc.v1.cri".registry]                                                                                
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]                                                                      
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.local:5000"]                                              
      endpoint = ["http://registry.local:5000"]                                                                               
  [plugins."io.containerd.grpc.v1.cri".registry.configs]                                                                      
    [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.local:5000".tls]                                          
      insecure_skip_verify = true
EOF
docker cp config.toml tap-oss-cls-01-control-plane:/etc/containerd/config.toml
docker exec tap-oss-cls-01-control-plane service containerd restart
ssh-keygen -b 2048 -t rsa -f ./git-ssh-key -q -N ""
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes -keyout example.key -out example.crt -subj "/CN=*.127.0.0.1.nip.io" -addext "subjectAltName=DNS:*.127-0-0-1.nip.io,IP:127.0.0.1,DNS:registry.local"
tanzu package repository add tap-oss -n tap-oss --create-namespace --url ghcr.io/vrabbi/tap-oss-repo:0.2.3
export KP_DEFAULT_REPO=registry.local:5000/tap-oss
export KP_DEFAULT_REPO_PASSWORD=password
export KP_DEFAULT_REPO_USERNAME=user
export KP_BUILDER_TAG=registry.local:5000/tap-oss/builder
export IMAGE_REGISTRY_USERNAME=user
export IMAGE_REGISTRY_PASSWORD=password
export IMAGE_REGISTRY_FQDN=registry.local:5000
export GITHUB_SSH_PRIVATE_KEY="`cat ./git-ssh-key | base64 -w 0`"
export IMAGE_PREFIX=registry.local:5000/workloads/oss-
export GITOPS_DEST_REPO=gitea_admin/tap-gitops-demo.git
export GITHUB_USERNAME=gitea_admin
export CERT_B64_DATA=`cat example.crt | base64 -w 0`
cat << EOF > contour-values.yaml
envoy:
  hostPorts:
    enable: true
  service:
    type: ClusterIP
EOF
tanzu package install cert-manager -n tap-oss -p cert-manager.tap.oss -v 1.6.1
tanzu package install contour -n tap-oss -p contour.tap.oss -v 1.19.1 -f contour-values.yaml
kubectl create ns gitea
cat << EOF > gitea-values.yaml
ingress:
  enabled: true
  hosts:
  - host: gitea.127.0.0.1.nip.io
    paths:
      - path: /
        pathType: Prefix
  tls:
  - secretName: nip-io-tls
    hosts:
    - gitea.127.0.0.1.nip.io
gitea:
  admin:
    password: "VMware1!"
  config:
    repository:
      DEFAULT_PUSH_CREATE_PRIVATE: false
      ENABLE_PUSH_CREATE_USER: true
      DEFAULT_PRIVATE: public
      DEFAULT_BRANCH: main
EOF
kubectl create secret tls nip-io-tls -n gitea --cert=./example.crt --key=./example.key
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
helm install gitea-charts/gitea --name-template gitea -n gitea -f gitea-values.yaml
cat << EOF > tap-oss-values.yaml
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
      server: "gitea.127.0.0.1.nip.io"
      repository: "$GITOPS_DEST_REPO"
      base64_encoded_ssh_key: "$GITHUB_SSH_PRIVATE_KEY"
      base64_encoded_known_hosts: ""
      branch: "main"
      username: "$GITHUB_USERNAME"
      user_email: "gitops@tap.oss"
      port: ""
  testing:
    configure: true
cert_injection_webhook:
  ca_cert_data: "$CERT_B64_DATA"
disabled_packages:
  - "cert-manager.tap.oss"
  - "contour.tap.oss"
EOF
tanzu package install tap -p tap-install.tap.oss -v 0.2.3 -n tap-oss -f tap-oss-values.yaml
echo "Setting up Access to the local registry from your docker daemon..."
ipAddr=`docker inspect -f '{{.NetworkSettings.IPAddress}}' registry.local | tr '\n' ' '`
hostName="registry.local"
matchesInHosts=`grep -n registry.local /etc/hosts | cut -f1 -d:`
hostEntry="$ipAddr $hostName"
if [ ! -z "$matchesInHosts" ]
then
    echo "Updating existing hosts entry."
    # iterate over the line numbers on which matches were found
    while read -r line_number; do
        # replace the text of each line with the desired host entry
        sudo sed -i "${line_number}s/.*/${hostEntry} /" /etc/hosts
    done <<< "$matchesInHosts"
else
    echo "Adding new hosts entry."
    echo "$hostEntry" | sudo tee -a /etc/hosts > /dev/null
fi
echo "Waiting for all Packages to fully reconcile"
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/cartographer --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/cert-injection-webhook --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/cert-manager --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/contour --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/dev-ns-preperation --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/flux-source-controller --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/knative --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/kpack --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/kpack-config --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/ootb-supply-chains --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/service-bindings --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/tap --timeout=10m
kubectl wait -n tap-oss --for=condition=ReconcileSucceeded pkgi/tekton-pipelines --timeout=10m
echo "Configuring SSH Key in Gitea"
export KEY_DATA="`cat git-ssh-key.pub`"
curl -X POST https://gitea.127.0.0.1.nip.io/api/v1/user/keys -u 'gitea_admin:VMware1!' -k -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"read_only": false,"title":"tap-oss","key":"'"$KEY_DATA"'"}'
echo "Getting the status of the TAP Platform"
bold=$(tput bold)
normal=$(tput sgr0)
echo "${bold}Package Repository Status:${normal} `kubectl get pkgr -n tap-oss tap-oss --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "${bold}Package Install Statuses:${normal}"
echo "  ${bold}* TAP Installation Package:${normal} `kubectl get pkgi -n tap-oss tap --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Cert Manager:${normal} `kubectl get pkgi -n tap-oss cert-manager --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Contour:${normal} `kubectl get pkgi -n tap-oss contour --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Knative Serving:${normal} `kubectl get pkgi -n tap-oss knative --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Flux Source Controller:${normal} `kubectl get pkgi -n tap-oss flux-source-controller --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Developer Namespace Preperation:${normal} `kubectl get pkgi -n tap-oss dev-ns-preperation --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Kpack:${normal} `kubectl get pkgi -n tap-oss kpack --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Kpack Configuration:${normal} `kubectl get pkgi -n tap-oss kpack-config --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* OOTB Supply Chains:${normal} `kubectl get pkgi -n tap-oss ootb-supply-chains --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Service Bindings:${normal} `kubectl get pkgi -n tap-oss service-bindings --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "  ${bold}* Tekton:${normal} `kubectl get pkgi -n tap-oss tekton-pipelines --no-headers -o custom-columns=STATE:.status.friendlyDescription`"
echo "${bold}Custom Resource Statuses:${normal}"
echo "  ${bold}* Kpack:${normal}"
echo "    ${bold}* Cluster Stack:${normal} $(kubectl get clusterstack base --no-headers -o custom-columns=STATE:.status.conditions[0].type) = $(kubectl get clusterstack base --no-headers -o custom-columns=STATE:.status.conditions[0].status)"
echo "    ${bold}* Cluster Store:${normal} $(kubectl get clusterstores.kpack.io default --no-headers -o custom-columns=STATE:.status.conditions[0].type) = $(kubectl get clusterstores.kpack.io default --no-headers -o custom-columns=STATE:.status.conditions[0].status)"
echo "    ${bold}* Cluster Builder:${normal} $(kubectl get clusterbuilder builder --no-headers -o custom-columns=STATE:.status.conditions[0].type) = $(kubectl get clusterbuilder builder --no-headers -o custom-columns=STATE:.status.conditions[0].status) - ($(kubectl get clusterbuilder builder --no-headers -o custom-columns=IMG:.status.latestImage))"
echo "${bold}Configured Supply Chains:${normal}"
arrCSC=`kubectl get clustersupplychain -o custom-columns=NAME:.metadata.name --no-headers`
for csc in $arrCSC
do
  echo "  ${bold}$csc Selectors:${normal} `kubectl get clustersupplychains.carto.run $csc -o json | jq .spec.selector -r | sed 's/{//g' - | sed 's/}//g' - | sed 's/,//g' - | sed 's/"apps/apps/g' - | sed 's/": /: /g' - | sed 's/^/  /g' -`"
done
echo "Your environment is ready!"
echo "${bold}Connection Details:${normal}"
echo "  ${bold}Git Server:${normal}"
echo "    ${bold}URL:${normal} https://gitea.127.0.0.1.nip.io"
echo "    ${bold}User:${normal} gitea_admin"
echo "    ${bold}Password:${normal} VMware1!"
echo "    ${bold}SSH Private Key Path:${normal} `pwd`/git-ssh-key"
echo "    ${bold}SSH Private Key Path:${normal} `pwd`/git-ssh-key.pub"
echo "  ${bold}OCI Registry:${normal}"
echo "    ${bold}FQDN:${normal} registry.local:5000"
echo "    ${bold}User:${normal} user"
echo "    ${bold}Password:${normal} password"
echo "  ${bold}Wildcard Certificate:${normal}"
echo "    ${bold}Cert Path:${normal} `pwd`/example.crt"
echo "    ${bold}Key Path:${normal} `pwd`/example.key"

