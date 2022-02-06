# Suggested CLIs
TAP OSS is built on top of many OSS Projects. while all of these tools can be managed via kubectl, many of the tools have dedicated CLI tools which can be very usefull and add additional capabilities.  
  
## KPACK
KPACK is used in 3 of the 4 OOTB supply chains and is in charge of building our images for us utilizing cloud native buildpacks.  
To interact with KPACK it can be very useful to have the [KP CLI](https://github.com/vmware-tanzu/kpack-cli/releases/tag/v0.4.2)
  
## KNATIVE
kNative is used to deploy our workloads in the OOTB supply chains. while not needed, the kNative CLI [KN](https://github.com/knative/client/releases/tag/knative-v1.2.0) can be very helpful especially for debugging.
  
## KUBECTL LINEAGE
When trying to understand the generated objects that have been produced by the supply chain as a result of our workload, the [kubectl-lineage](https://github.com/tohjustin/kube-lineage) plugin can be very helpful.
  
## KUBECTX and KUBENS
When working with kubernetes these CLI tools are some of the most handy CLIs for easing the movement between contexts on our terminal. [KUBECTX and KUBENS](https://github.com/ahmetb/kubectx) are kubectl plugins developed by the maintainer of krew - the plugin manager for kubectl.
  
## TEKTON
Tekton is used in 3 of the 4 OOTB supply chains (GitOps, testing and Kaniko). while everything can be done from kubectl, the Tekton CLI [TKN](https://github.com/tektoncd/cli/releases/tag/v0.22.0) can be very helpful in debugging issues.
  
## TANZU
the installation instructions for this package repository is currently based on the Tanzu CLI. while it is possible to do via kubectl, the experience with [TANZU CLI](https://github.com/vmware-tanzu/community-edition/releases/tag/v0.9.1) is much better.  
The Carvel team are working on a specific CLI for Kapp Controll - kctrl, which this repo will document the usage of once it is GA.
