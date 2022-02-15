#!/bin/bash

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
echo "${bold}Deployed Workloads:${normal}"
arrWld=`kubectl get workload -A -o json | jq '.items[] | "\(.metadata.name) \(.metadata.namespace)"' -r`
IFS=$'\n'
for wld in $arrWld
do
  wldName=`echo $wld | awk '{print $1}'`
  wldNS=`echo $wld | awk '{print $2}'`
  echo "  ${bold}$wldName [$wldNS] Status:${normal}"
  echo "`kubectl get workload $wldName -n $wldNS -o json | jq '. | "    \(.status.conditions[2].type) = \(.status.conditions[2].status) \n    Applied Supply Chain: \(.status.supplyChainRef.name)"' -r`"
done
