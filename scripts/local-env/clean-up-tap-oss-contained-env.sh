tanzu um rm tap-oss-cls-01
docker kill registry.local
docker rm registry.local
sudo sed -i '/.*registry.local$/d' /etc/hosts
