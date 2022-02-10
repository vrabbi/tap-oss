# Usage
This example uses the rabbitmq cluster operator and the service binding controller to bind an application to your workload.  
This is implemented in a gitops workflow as this is an optimal way to handle backend service bindings when deploying to multiple clusters.  
While we are doing this in the same cluster in this example the gitops approach is being used to show that this is possible and is a very powerfull approach for workload management.
# Pre Reqs
1. Install the rabbitMQ Cluster Operator:
```bash
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
```  
2. Create a rabbitMQ cluster using the manifest in this repo
```bash
kubectl apply -f rabbitmq.yaml
```  
  
# Installation
1. Deploy the workload
```bash
kubectl apply -f workload.yaml
```  
2. when the workload is complete the generated YAML will be uploaded to your configured git repo
3. Download the file and apply it to your cluster
4. Watch the magic happen!
