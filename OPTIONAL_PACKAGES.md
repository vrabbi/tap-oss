# Additional Packages
Besides the TAP platform packages, additional packages have been added to the repo that you can install and utilize within custom supply chains.  
Currently the packages available here are based on the Bitnami Helm charts for the software they install and have been wrapped into Carvel packages to make the installation seamless.  
All images have been relocated to ghcr as well in order to prevent docker hub pull rate limiting issues.  

## Available Packages
Currently the addtional Packages in this repo include:
1. RabbitMQ Operator - installs both the Cluster operator and topology operator. Useful for testing and using the Service Bindings Supply Chain.
2. Argo CD - useful for GitOps based Supply chains in destination clusters
3. Argo Workflows - can be used to replace Tekton for testing or any other task in a supply chain
4. Jenkins - can be used via a tekton or argo task/pipeline/workflow to run tests or any other step in a supply chain.

## Installation Instructions
For any of the packages you can follow the bellow procedure to get the optional values to configure the installation:  
1. Run the following to get the available packages:
```bash
tanzu package available get -n tap-oss
```  
2. Select the package name and export its name as an enviornment variable
```bash
export PKG_NAME=<FILL ME IN>
```  
3. Retrieve the latest version of the package
```bash
VERSIONS=($(tanzu package available list "$PKG_NAME" -n tap-oss -o json | jq -r ".[].version" | sort -t "." -k1,1n -k2,2n -k3,3n))
PKG_VERSION=${VERSIONS[-1]}
```  
4. Get the list of values you can set for this package
```bash
tanzu package available get $PKG_NAME/$PKG_VERSION --values-schema
```  
5. Create a values file based on the output from above with the values you would like to override
6. Install the package
```bash
# Without any overrides
tanzu package install -n tap-oss $PKG_NAME -p $PKG_NAME -v $PKG_VERSION

# With a values file
tanzu package install -n tap-oss $PKG_NAME -p $PKG_NAME -v $PKG_VERSION -f <CUSTOM VALUES FILE>
```  
7. Enjoy!
