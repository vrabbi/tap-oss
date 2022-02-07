# Example workload YAML
In this folder you will find a sub-folder per Out Of The Box Supply Chain.  
Depending on the supply chain you want to utilize, go into the relevant folder and select the language of your choice to see an example app which is ready to be created.  

# Deploying a workload
1. Clone this git repo  
```bash
git clone https://github.com/vrabbi/tap-oss.git
```  
2. Go to the relevant folder  
```bash
cd tap-oss/example-workloads/<SUPPLY CHAIN NAME>/<LANGUAGE>
```  
3. Deploy the workload YAML
```bash
kubectl apply -f workload.yaml
```  
4. Monitor the resource creation along the supply chains path using the following commands  
```bash
## Get all workloads in the current namespace
kubectl get workload
```  
```bash
## get the tekton pipeline runs (Relevant in testing,kaniko and gitops Supply Chains)
kubectl get pipelineruns,taskruns
```  
```bash
## Get the Kpack resources utilized for building our image (relevant for all Supply chains except the Kaniko Supply Chain)
kubectl get cnbimage,build
```  
```bash
## Get all resources that have been generated as part of the supply chain - requires the kubectl-lineage plugin
kubectl lineage workload/<WORKLOAD NAME> -o split wide
```  
