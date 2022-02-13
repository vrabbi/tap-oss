# CHANGE LOG FOR THIS REPO
## 0.2.3
* Added Jenkins Package  
* Added Argo Workflows Package  
* Added Argo CD Package  
* Added RabbitMQ Operator Package  
  
## 0.2.2
* Added instructions for running on TCE Unmanaged Clusters (TCE 0.10.0+)  
* Added example values files  
* Added overlay to change the default knative service template  
* Added support for contour to use Host Ports (useful in Kind based clusters like TCE unmanaged clusters)  
  
## 0.2.1
* Added Gitops supply chain with service bindings using the service claims struct of the workload yaml  
* Added workload example for binding to a rabbitMQ cluster  
* Fixed issue in gitops git-writer task where it failed if the folder already existed in git  
* Fixed Service bindings RBAC to allow work with RabbitMQ (OSS and Tanzu) and Tanzu PostgreSQL operator based objects  
* Added Cert Injection Webhook Package  
* Validated support for running on EKS, kind and minikube  
  
## 0.2.0
* Add Service Bindings Package  
* Add Service Bindings for MySQL example workload  
* Add Service Bindings Supply Chain example  
* Make all package optional (opt out mechanism added)  
* Make OOTB Supply chains optional (opt out mechanism added)  
* Added Kaniko based example workload  
* Standardized the labels for workloads and supply chains  
* Added additional docs for getting started  
* Enhanced experience for deployment on a Local Docker based environment  
* Added script to get the status of the platform  
  
## 0.1.5
* Add kaniko base supply chain for building images  
* add workload examples for building images with Kaniko instead of Kpack  
  
## 0.1.4
* Fix issue with knative to local docker TCE clusters  
  
## 0.1.3
* Tech Debt cleanup  
  
## 0.1.2
* Add support for setting Contour to use a ClusterIP for local clusters  
  
## 0.1.1
* Fix issue with openapiv3 schema for meta package  
* Add example workloads for utilization with the supply chains  
  
## 0.1.0
Initial Release  
