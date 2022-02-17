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
tanzu package repository add tap-oss -n tap-oss --create-namespace --url ghcr.io/vrabbi/tap-oss-repo:0.2.4
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
      server: "gitea-ssh.gitea.svc.cluster.local"
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
tanzu package install tap -p tap-install.tap.oss -v 0.2.4 -n tap-oss -f tap-oss-values.yaml
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
echo "Configuring Contour TLS Delegation for the wildcard certificate"
cat << EOF > tls-certificate-delegation.yaml
apiVersion: projectcontour.io/v1
kind: TLSCertificateDelegation
metadata:
  name: default-delegation
  namespace: kube-system
spec:
  delegations:
    - secretName: wildcard
      targetNamespaces:
      - "*"
EOF
cat << EOF > wildcard-secret.yaml
apiVersion: v1
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZVakNDQXpxZ0F3SUJBZ0lVYU45QnRQbnJzUXNBcmladFJZbnpTcDNqT2J3d0RRWUpLb1pJaHZjTkFRRUwKQlFBd0hURWJNQmtHQTFVRUF3d1NLaTR4TWpjdU1DNHdMakV1Ym1sd0xtbHZNQjRYRFRJeU1ESXhOakU0TVRNegpNMW9YRFRJek1ESXhOakU0TVRNek0xb3dIVEViTUJrR0ExVUVBd3dTS2k0eE1qY3VNQzR3TGpFdWJtbHdMbWx2Ck1JSUNJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBZzhBTUlJQ0NnS0NBZ0VBc1htV3VIZFplY3VkYjJ5T0ZibVEKZ1puRm5YVWlGVWpIVDdNWndPWVNPckxlSHg1alVzZHI2RzJFU3NUUW9JY3A5ejJLY2o0dXJyejg1UGlRWW4zawovTCs2ZTlhcDBRSytRMXZaV1oweG1KR1NiaFlCVGhQYzd4MXBsVFVyajFNVnY3UE1jTHhYdHluVDkxMHhPY1RHCmpXdmYyeDZsQ29ac0lTRVFPakNBUmg2d3hqbGJDZUhIMHg2eVVQemQxVVhnSEN6RzM0bXpVdVIxQzZkQXZ4K0YKZTNsSmpsU2VOMUpITEhaWCt1TFZqcWNtemFDNFdrMGowNzUvaUxOd3c4T0RpQkt6UFp6RlZzNkdSZkhLQjdJeQpWRHNpV0hJd3A5TlpsRUtvQld2d2J0R2RFOHpwcGRiWU9vbi9ERWpZTmNwMkJyZTcweUx6VjN6bUxQbHBwOU4yCmN3L2tId0hxb1BPcVI3d05KNllnSDIwZS9QQUJqcHBaaFpPaEJqN1VYMm5sSFJMKzNZMWVaWEFXK1htREg4V0cKOUd5VS9iKy9Wdi9ReGwzNk5EY3Q4Qk9naEsrRzV5Nm5JZ0Y3a1dFYk1jRVZTOHg2YSsxR2xxcFVldzJjK0tjQwp4U05lVE9TaVV3bGM5SzNnV0syS3UyT3Rvc2p2cDd3ZGIxWHVRa1dlZTVQdkNTS2NWMTdQUHVCeS9TYnU4dnoxCm1ma1FGbmpZdEFlaFFHM0xGMDZiS2RyUkNTTC92K1ZzcTFiU1NnbUFabkF4M1JzVTRVZWFSMXloWTF6T0VHVVUKT0RTblo1QkJZQ1gvcSt4dVJMc0lDZUNIbkpRR3lHS1NzclpkanVHTmxCQSt6VmZpdXB1aWhBN0QzQmlTdWthbgpidjhUbTMrNTllVkNJMVNpbUpqYmFHOENBd0VBQWFPQmlUQ0JoakFkQmdOVkhRNEVGZ1FVUzhiMldnU0dFTUdoCmhpNytnbFhWV3Q0Q2JUa3dId1lEVlIwakJCZ3dGb0FVUzhiMldnU0dFTUdoaGk3K2dsWFZXdDRDYlRrd0R3WUQKVlIwVEFRSC9CQVV3QXdFQi96QXpCZ05WSFJFRUxEQXFnaElxTGpFeU55MHdMVEF0TVM1dWFYQXVhVytIQkg4QQpBQUdDRG5KbFoybHpkSEo1TG14dlkyRnNNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUNBUUFySWI3eS9JSjh6ckNaCmFzOGJYYXRwVEdnZlQvUGZrSzBpRDl0OHB0WE5zcmRVbXJaVnlObGVlQStVYXlKTi9qMDZmdDZhS2FDNS9LM2oKbk5MQnFvZTNRZ1JzY0FkcWlxTU5NdWY4V0tDcFNzaHRLMGVKS1R6T2dTN3hFQ2pXclhnMWVHRVBBbFh5WmFLdQpXNGViT3ozYy9XVGpJYlpacVNNV2U1R3NIenFXcUVSekVYcFU3UmdDTWtIMWg3VDlrV3dKQ2k4REF6UHZwTEJCCjFYMUFKRVc1WnRsSmZ0MEJFSld6RmExTWsyYVRZK3U0blVlaHpScnJHU1FYY3Jvd2NRNE5QRkt2TzA3M3k0d0UKck9JK080Nk0yTDlhVWZDWnpHWGRBaFVrcjkvYWRhMjVOZ0dHTmdkRmpBaEpyYVBaL0lLelhHb1htMGRXRFY4eQpjMWNKaUgzalBPSDMxeFJJSVFjWktOVHhRaGxFQkxNMGZibjZ1ZXZoM3N0Qms5eFl5SGxFdjJvc1RZTWp4N2NRClUvQkQvb2VnWTlCcUgzaUxSeVRWc2VPYkZtTUtHamVWRzV3RVI0OVNjMjAwZHBOV28vaUs3WDZsdkhnYUZySFQKZ05zejF1TENEdndlUTlneXBFaHVUMmhWUTNQSmJIZG5UWnI1Y0RlT3pXb2NtaDNKN1MybVZFNGNHbW82Zjh4UwpXUFVPZmNHY25yZERJRWUzWnUrQXdzMHlpMTMvSERvNmlEKzJpVktkUkVZNXBZWUczMDNaMmQzaEhmc2VPanc1CkIxQWVFNXVkbFZHZHh3YUtnVEMwSW5SbGhHWXFaaVFabVM4TjRNM1ZUdVdUUG1aNlQ1SHQ4aWNSVzhUUW93MzIKaHBvZ2QxOWRPS3VLb3R1QTRyKzZucVA2YUYrdFVBPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUpRZ0lCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQ1N3d2dna29BZ0VBQW9JQ0FRQ3hlWmE0ZDFsNXk1MXYKYkk0VnVaQ0JtY1dkZFNJVlNNZFBzeG5BNWhJNnN0NGZIbU5TeDJ2b2JZUkt4TkNnaHluM1BZcHlQaTZ1dlB6aworSkJpZmVUOHY3cDcxcW5SQXI1RFc5bFpuVEdZa1pKdUZnRk9FOXp2SFdtVk5TdVBVeFcvczh4d3ZGZTNLZFAzClhURTV4TWFOYTkvYkhxVUtobXdoSVJBNk1JQkdIckRHT1ZzSjRjZlRIckpRL04zVlJlQWNMTWJmaWJOUzVIVUwKcDBDL0g0VjdlVW1PVko0M1VrY3NkbGY2NHRXT3B5Yk5vTGhhVFNQVHZuK0lzM0REdzRPSUVyTTluTVZXem9aRgo4Y29Ic2pKVU95SlljakNuMDFtVVFxZ0ZhL0J1MFowVHpPbWwxdGc2aWY4TVNOZzF5bllHdDd2VEl2TlhmT1lzCitXbW4wM1p6RCtRZkFlcWc4NnBIdkEwbnBpQWZiUjc4OEFHT21sbUZrNkVHUHRSZmFlVWRFdjdkalY1bGNCYjUKZVlNZnhZYjBiSlQ5djc5Vy85REdYZm8wTnkzd0U2Q0VyNGJuTHFjaUFYdVJZUnN4d1JWTHpIcHI3VWFXcWxSNwpEWno0cHdMRkkxNU01S0pUQ1Z6MHJlQllyWXE3WTYyaXlPK252QjF2VmU1Q1JaNTdrKzhKSXB4WFhzOCs0SEw5Ckp1N3kvUFdaK1JBV2VOaTBCNkZBYmNzWFRwc3AydEVKSXYrLzVXeXJWdEpLQ1lCbWNESGRHeFRoUjVwSFhLRmoKWE00UVpSUTROS2Rua0VGZ0pmK3I3RzVFdXdnSjRJZWNsQWJJWXBLeXRsMk80WTJVRUQ3TlYrSzZtNktFRHNQYwpHSks2UnFkdS94T2JmN24xNVVJalZLS1ltTnRvYndJREFRQUJBb0lDQURlTldiSlFHWC9ZVG1Wc1UyVlZlbmcyCnkvYW5qWTJnQkZOY09ubDVDc2U0NlhKUUxzTGdqVlJwdzNrcjlpbnBaU2R3NmY4c202d3lsKzZNSjVYTTFucVAKQVM1MldSMkZnRXpSV1UyRnVOcUs1b3p5OG1HZ01nM2U1UWZCWnVzc0ZLaTIvUTFreHdnY1hhOFdTcXhNZmVJUwpuRFdZZUF5OVd1ZGIxQnFDeUFRcTR5YUpHWWdVVmxvdFI1KzJKekgwOTF1YVlIM2tPbTk5OTIwNFl6bndBZlpPClZzbm9qc1crU1cwUGRpYWdEanppOFhCNEdIeWJuTlZRMGRiV1pEdkMzVThnbTE1enpnbUlCOXVvL1pZL0h5WGkKaExPdXVyQXRwZUtVb3NkZnJCamtJQWpzb1U0NTIrRW5CT0N4aEl3QjNjUG9pekJoeGszaVdLSkhSOTB5Z2VhbwphNU41TGhCWUk2Nk1DYjFEYUNUS2t6MUZOUzZQTnJtYnkydjIxSCtSTjZqSTlDSmp1RXJjeHg4cmJHTEhFWjBsCnVXWWVqL1lwc0FyelozazdHZkZTSVlEMmw5aEp3VS9IMThVM2lQZENtaUkzSVIxeDlyekJiK01DRGFMRVVrYWUKRGtJcFZNaG0rRUhzT2lKaFl3ckVTTkNmSmlLUGhnelkzVUZCRGUxc1dZemNGZGNjY1pudS9yU1ZmQUh2WWwxcApvUDNtNXdrcEZMclVBdzBRcVd3eWVTU01uU1M2TXJHai9UQ2dhSmkveFUwbTBaTjlqUzlqRWk3b25Wb1BVQmxtClZMQU1xMGppSUxkWmZCNlB6UVBtMFVHSHZFb0FDNDBwVGRTZnhzSlFhMFhpNC9FUDNqUjg1NldnYUdjanNCenQKTWUrUTVsREtHRFlqbWRFQlVFZmhBb0lCQVFEb0lISlpLL1R5RTNtTktHeU1kMUJVU1pheUhuL0pZL3lWS0R0VQpvRm5Bc1k5Z2JEdnNnb3kwOFhXVWF1TGpNNUJtN21pdGxLb0Q5Rit3eWVxejFVTmJmV0x6VkdRd1BBbTVBQXEwCit0WFRYbzV4aElpeS9oQ3FLcWxWM1lvT05uN0tuN1B3VWdXUmVPa003T1VZMForL3JVMTF5dTI3U215L1hsZG8KM1d4dFRiU3lqcnNTbDJlbkdjVlc2YlozOFRJSllRNEdiUWFXbW0vWTFHODJIMmQ0dWYvb2I0ektISThYYWRZbwpqMndacDk5SHpBTkFWRktKK2g5YzExRmoxYXd1S3A4RGM0a1E0alJQNXM0Z3E0UlU4MzNMQlhPT1cvMnpyaUdMCkhnZmkxdmJuQnltWWVwQU9BVjZIUnRaOTNxandKNlpTb3NGMDNaZW5vRjlLNEkwWEFvSUJBUUREdWozUENYcUoKS2VjU0Ewbnk0WlpWRHVmbFduQUdZUjhKMXhCcjIzQnY3bDVMS0hEY2M0bVpXbFFFZjRPTWNEMTRKMTdXSSsySAo4MmVvSkVZdnVIWGNCSEd0SEx5Z3pjTUpCTHdxMEZUKzE4eXdadXJ6akdiWnBPOHJiRFc5NWZoc0FHa1d4UW1DClhYdVAxQ1ZYZ2NYZHo0REhNUHdmYW5RODcwaGFia1FDZW1FZkIyZm4rY09aWVk4M0VTWWRTU0hISHZwZkpCSVMKcjBMaUF4ajJPL1JaL0plWWI2L1ZOaWZMZzlsM0RVUTE5NnhDWGJxU3U3bGVUVXBON21CblVxZVpaSGdSRVZ2Ugp5Q3BXVTh4cFdSc21JZTQwRkdjcldZSmIzL0tMNFRVdW05ajFxaEwvdUk4QnV6N3lJcU9RbGovMjdQOFpabG95Ck84S3BjSzdTQlFacEFvSUJBUUNYQzQzODBtcVlIdTRJV1ZhUTdJNmIyaXF5Q3NDU05uckVRQ0tqUlpoQm1BaTQKOEpUcHFHV1ExRkh6V3IzNm83SUNHSDZLL09MSW9mcW1XaTFjQ1pqRDdzbzFsaU4vYzRITUhPZmFyaUgzWVY4RgpKUDJpbzBvS3dLbmhrci9qMGJnZGQyQXFMK1Vwck9qUkhWRlNIZzE2TjNYaEFVUkNqQUpKWUVVMm1tYVVsV3pRCmg2blpSaVlQaU9odFRyVUtSU3VQQ05XTWZ1TTdtcERQSWlTZnJqMnhSQzd1ZTYrOFVHc1lEQ2xyeVMvSlhnQWYKZ3ZSV3BzZnl1b3d2Nkhnd28zaGZyaUk4cDdCNENRbUxPSi9HaUhVYXBqcWpvZzk0Z2dtTEl2TDJ5SHJQTTV3RAo1eGc4L1B2QjhVZ21kSVRiOE1nelJVbW9HZm9TWnFMcFU2VE9YMkhQQW9JQkFGb0kyeFBZOVdBUlFYVDh4RkNRCnl2bVhvTDdWU2tEMC9qVWxsQzA1UlZDSDR5SkptUmtmb01WRlV1NjZ4WVdkdi9qOGkxaVFNRnpnYitkZHdGZUYKVDlvRXhWSHZyU2wvWFY5UnFVazhpa3lzY2tFWEpxOGYvOVBRVmlDd1oweFNkR01pRVRWak1BdWkrd3JmZU1uMwpMVkRxZWYrbkhlTkpzZXl4MmFPWG8zdE1WazdTdGs1MGl6Q01PemdHa0hUYVJrcDFpcENuWkJUcVFDYjlhOGNoCkx6Y1J4WjVlaWhEWEY1azdycFpnS09kMlpld2xkNFMyREFCQUo1VVB1Wkx0NTZEZElZb2daUTlzTjJWOHFNUXgKTkJibmRzN0lMK2syQkl4RXlTcmxUdlNBeGwzRGZYZmFxeFlOejFmTTdWYStkdkFjZHdCMUg3cUoyUExlbmR5SQphVGtDZ2dFQVp3RnNNanRqSDdIQ2RMaUNmT2JPTkorRkJJUm94QXNyMXdWNitGa2x5WVJsSmE3SkkxOWxiUDZHCmtXdGtiVHRBSFVHTHorVEExZ2sxLzZ3ZGRYNE9yUXZBVU51T2xnaWV2THEvMXVyNWJHM3l2c09HL2EzNk1vOHMKbmw3MjlRL0wyRkFYbW9tOWsxQSt1RTA4M09RdEkxQmlmZUlXSmJXUzBvN1Y4bHFiK1hOMUJnN1dxb1l6cmxrNApINU9FZEU0NHFaNnpWdUpBZ1pYbGJmLzFMbk1ZMW1sL0N5UHNXc0UzOFBKc0dSQmhBOHlLZlN4NG5yaXBxSkFHClpMenBDS3F0NS8vR1hjbytpaVA2djI3RmVrOGZvNEhXa3o5dEhuV1FuVlEwS2pXelk5WXYwcE0ya3JNRWFBaTIKblN3cTExYWlHNlgrWUVnK1ljWTlFTTg1RkQ2NGxRPT0KLS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLQo=
kind: Secret
metadata:
  name: wildcard
  namespace: kube-system
type: kubernetes.io/tls
EOF
kubectl apply -f wildcard-secret.yaml
kubectl apply -f tls-certificate-delegation.yaml
echo "Configuring Default TLS certificate for all knative services"
kubectl patch cm config-contour -n knative-serving -p '{"data":{"default-tls-secret":"kube-system/wildcard"}}'
echo "Waiting for Cluster Builder to be ready"
kubectl wait --for=condition=Ready=true clusterbuilder/builder --timeout=10m
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

