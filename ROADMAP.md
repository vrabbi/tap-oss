# This file explains the general roadmap for this repo
## Add more configurability
* Support clusters without Service Type Load Balancer (Local Clusters) via a simple configuration - DONE (version 0.1.2+)
* Support exclusion of specific packages from installation - DONE (version 0.2.0+)
* Enable more customization based on community feedback
## **More OOTB Supply Chains**
* Testing Supply Chain using jenkins pipeline for testing
* Testing Supply Chain using Argo Workflows for testing
* GitOps Supply Chain with Poly Repo Configuration - WIP
* Basic Supply chain using Kaniko instead of kpack to build images - DONE (version 0.1.5+)
## **Extend the core packages to include:**
* [Backstage](https://backstage.io/) - WIP
* [Backstage Software Templates integration (Similar to App Accelerator)](https://backstage.io/docs/features/software-templates/software-templates-index)
* [Service Bindings](https://github.com/vmware-labs/service-bindings) - DONE (version 0.2.0+)
## **Create a set of optional packages**
* [RabbitMQ Operator](https://github.com/rabbitmq/cluster-operator) - WIP
* [PostgreSQL Operator](https://github.com/zalando/postgres-operator)
* [MySQL Operator](https://github.com/mysql/mysql-operator)
* [Gitea](https://gitea.io/en-us/) - WIP
* [Jenkins](https://github.com/bitnami/charts/tree/master/bitnami/jenkins)
## **Add Advanced workload examples**
* Applications that utilize service bindings - DONE (version 0.2.0+)
* Applications with custom build parameters and env vars - DONE (version 0.2.0+)
