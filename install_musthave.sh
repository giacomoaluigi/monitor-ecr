#!/bin/sh

sudo yum install -y git

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

sudo chmod +x ./kubectl

sudo mv kubectl /usr/bin/

kubectl version --short --client

mkdir ~/.kube

aws s3 cp s3://giacomo-k8s-launch-config/.kube/config ~/.kube/