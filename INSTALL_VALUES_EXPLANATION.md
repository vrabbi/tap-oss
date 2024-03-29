# Values Explanation
Each package that requires values has a specific high level key with all configuration nested bellow it.  

## CONTOUR
The configurations exposed allows you to set the Envoy service type and to configure the use of host ports for envoy.
By default it will use a service of type LoadBalancer. for local clusters add the following:  
```
contour:
  envoy:
    hostPorts:
      enable: true
      http: 80
      https: 443
    service:
      type: ClusterIP
```  
  
## KPACK
The configuration options are a subset of the TCE Package options.  
The required values are:  
```
kpack:
  kp_default_repository: # Default repo for images and configuration bundles to be saved to
  kp_default_repository_password: # Password used for Kpack to create and upload the builder
  kp_default_repository_username: # Username used for Kpack to create and upload the builder
```  

## KPACK CONFIG
This is needed as the TCE Kpack package does not configure Kpack for us so we have an additional package to do so.  
The required values are:  
```
kpack_config:
  builder:
    tag: # The full path where you want the builder created in your registry
```  
## CERT INJECTION WEBHOOK
This is needed to support self signed registries or source control systems with kpack. This allows us to configure proxy and CA values to be injected into kpack build pods automatically via a mutating webhook
The Supported values are:
```
cert_injection_webhook:
  ca_cert_data: # BASE64 encoded CA cert data to inject into the Pods
  http_proxy: # HTTP Proxy ENV Variable value to inject into the build pods
  https_proxy: # HTTPS Proxy ENV Variable value to inject into the build pods
  no_proxy: # NO Proxy ENV Variable value to inject into the build pods
```  

## KNATIVE
The configuration options are the same as the TCE Package.  
The required values are:  
```
knative:
  domain:
    name: # Domain suffix for all ingress objects created in the system and deployed via Knative. if type is not real leave this field empty
    type: real # can be real, nip.io or sslip.io ##IMPORTANT## if running on a docker based TCE cluster you can only use real here or the pakage will fail to reconcile
```  

## DEV NAMESPACE PREPERATION
This package allows us to configure automatically as many namespaces as we want for TAP OSS Workloads. Many objects are needed for successful deployment of workloads and this mechanism allows for an easy way to achieve this.  
The required values are:  
```
dev_ns_preperation:
  registry:
    username: # The Username for authenticating against your registry for pushing images
    password: # The Password for authenticating against your registry for pushing images
    server: # The FQDN of your registry where you will be pushing images to
  namespaces: # An array of 1 or more namespaces to prepare for TAP OSS workloads
  - name: # Namespace name to prepare
    exists: # boolean value of true or false. If it is set to true the namespace will not be created but all other objects will be created. If set to false the namespace will be created as well
    createPipeline: # boolean value of true or false. if set to true, example tekton resources will be created in the namespace for consumption via the supply chains.
    language: # Must be set is createPipeline is set to true. currently supported values are go and java
    gitops:
      enabled: # boolean value of true or false. The GitOps supply chain requires additional configuration objects. if set to true those objects will be created as well
      base64_encoded_ssh_key: # If gitops.enabled is set to true then you must put the SSH KEY for git authentication in base64 encoding here.
      base64_encoded_known_hosts: # if not empty, must include the base64 encoded value of the known hosts entry for the git server. if set with an empty string, host key verification is disabled
```  

## OUT OF THE BOX SUPPLY CHAINS
This package will install 1 to 3 supply chains to help you getting started with the platform based on your inputs.  
The required values are:  
```
ootb_supply_chains:
  disable_specific_supply_chains: # Array of supply chains to not install. options are: ootb-basic-supply-chain, ootb-gitops-supply-chain, ootb-basic-supply-chain-with-kaniko, ootb-testing-supply-chain and ootb-gitops-supply-chain-with-svc-bindings
  image_prefix: # Prefix for image creation path. the workload name will be added as the suffix. should be in the format of <REGISTRY>/<PROJECT or USERNAME>/ or <REGISTRY>/<PROJECT or USERNAME>/<SOME STRING>
  gitops:
    configure: # boolean value of true or false. if set to true, a gitops supply chain will be created. this requires additional inputs which are found in the gitops.git_writer section bellow.
    git_writer: # if gitops.configure is true all sub fields here must be set otherwise you can ommit the git_writer section.
      message: # Commit message for pushing config up to git. commit message will be in the format \[<WORKLOAD NAME>\] - <COMMIT MESSAGE>
      ssh_user: # SSH user when authenticating with git
      server: # Git server FQDN
      repository: # Git repo path. for github for example it should be <USER or ORG NAME>/<REPO NAME>.git
      base64_encoded_ssh_key: # SSH KEY for git authentication in base64 encoding
      base64_encoded_known_hosts: # if not empty, must include the base64 encoded value of the known hosts entry for the git server. if set with an empty string, host key verification is disabled
      branch: # Branch to push commits to
      username: # Git username
      user_email: # Git email address
      port: # for default port 22 can be left empty, otherwise you must provide the port number for ssh connections to the git server
  testing:
    configure: true # boolean value of true or false. if set to true, a supply chain with a tekton step doing source code scanning is created
```
## DISBALING PACKAGE INSTALLATIONS
While it is strongly suggested to install the full stack of this platform to gain all capabilities you may want to disable specific packages from being installed.  
It is possible to either install every package manually which may be viable in highly automated environments, or you can still use the meta package but simply disable specific packages from being installed:
```
disabled_packages:
  - "" # List the package you want to disable being installed.
```  
The supported values for this array are:
* **cartographer.tap.oss** - This is the core of TAP so should not be removed unless you have cartographer already installed
* **cert-manager.tap.oss** - required for knative and contour to work well so should not be removed unless you have cert manager already installed
* **contour.tap.oss** - Required for Knative. only remove if you have contour already deployed
* **dev-ns-preperation.tap.oss** - If you dont use this you will need to setup RBAC and other objects manually in any namespace you want to enable for TAP OSS
* **flux-source-controller.tap.oss** - Required for all OOTB supply chains in this repo. only remove if you have flux v2 or source controller already deployed
* **knative-serving.tap.oss** - Strongly recommended way to deploy apps. used in all but one OOTB supply chain so should only be disabled if you have knative pre installed.
* **kpack-config.tap.oss** - For easy installation this package gives you a simple UX. for production deployments, you should configure kpack with more care and consideration.
* **kpack.tap.oss** - For all but 1 OOTB Supply chain kpack is used to build our images. should only be disabled if you have kpack or TBS pre installed.
* **ootb-supply-chains.tap.oss** - Gives an easy way to get started by exposing different supply chains to get you started. if disabled, you will need to manually create a supply chain before you can deploy a workload.
* **tekton.tap.oss** - Used in all but 1 OOTB supply chain. should be disabled only if you have pre installed tekton
* **service-bindings.tap.oss** - Used in 1 OOTB supply chain currently. if you disable this package, binding to backend services will be very complex.
* **cert-injection-webhook.tap.oss** - Used in kpack. if you disable this package, you cannot build images with source from a self signed source or push to a registry with self signed certs.
