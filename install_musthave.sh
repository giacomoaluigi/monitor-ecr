#!/bin/sh

sudo su

yum install -y git

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x ./kubectl

mv kubectl /usr/bin/

kubectl version --short --client

mkdir ~/.kube
mkdir ~/.aws

aws s3 cp s3://giacomo-k8s-launch-config/config ~/.kube/config
aws s3 cp s3://giacomo-k8s-launch-config/.aws/* ~/.aws/ -recursive