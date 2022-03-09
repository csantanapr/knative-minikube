#!/usr/bin/env bash

set -eo pipefail
set -u

KONK_MINIKUBE_BRANCH=${KONK_MINIKUBE_BRANCH:-master}

echo -e "🍿 Installing Knative Serving and Eventing ... \033[0m"
STARTTIME=$(date +%s)
curl -sL https://raw.githubusercontent.com/csantanapr/knative-minikube/${KONK_MINIKUBE_BRANCH}/install.sh | bash
echo -e "🕹 Installing Knative Samples Apps... \033[0m"
curl -sL https://raw.githubusercontent.com/csantanapr/knative-kind/master/03-serving-samples.sh | bash


# Setup Knative DOMAIN DNS
INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z $INGRESS_HOST ]; then INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); fi
while [ -z $INGRESS_HOST ]; do
  sleep 5
  INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z $INGRESS_HOST ]; then INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); fi
done

if [ "$INGRESS_HOST" == "localhost" ]; then INGRESS_HOST=127.0.0.1; fi

KNATIVE_DOMAIN=$INGRESS_HOST.sslip.io

curl -sL https://raw.githubusercontent.com/csantanapr/knative-kind/master/05-eventing-samples.sh | KNATIVE_DOMAIN=$INGRESS_HOST.sslip.io bash
DURATION=$(($(date +%s) - $STARTTIME))
echo "kubectl get ksvc,broker,trigger"
kubectl -n default get ksvc,broker,trigger
echo -e "\033[0;92m 🚀 Knative install with samples took: $(($DURATION / 60))m$(($DURATION % 60))s \033[0m"
echo -e "\033[0;92m 🎉 Now have some fun with Serverless and Event Driven Apps \033[0m"
