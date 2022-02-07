# Using Service Bindings with workloads

## Preperation
This example uses native k8s deployment, service and ingress objects and as such requires us to add a few additional parameters to our workload yaml that with knative we would not need:
1. containerPort - this is set to 8080 in the example and is configured to work that way. if your app is on a different port change it in the workload.yaml file
2. ingressDomain - we will be creating an ingress and as we dont have the default config settings like in knative, we must supply the suffix of the domain our ingress we point to.

As we are binding to an existing data service, we need to apply the mysql.yaml in the cluster before deploying our workload:
```bash
kubectl apply -f mysql.yaml
```  

## Deployment
Just like any other workload we can install our app via a single command:
```bash
kubectl apply -f workload.yaml
```
