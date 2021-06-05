#!/usr/bin/env bash

set -eo pipefail
set -u

KNATIVE_VERSION=${KNATIVE_VERSION:-0.23.0}
KNATIVE_NET=${KNATIVE_NET:-kourier}
KNATIVE_NET_KOURIER_VERSION=${KNATIVE_NET_KOURIER_VERSION:-0.23.0}

STARTTIME=$(date +%s)

## INSTALL SERVING
echo -e "\033[0;92m 🍿 Installing Knative Serving... \033[0m"

n=0
set +e
until [ $n -ge 2 ]; do
  kubectl apply -f https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-crds.yaml > /dev/null && break
  n=$[$n+1]
  sleep 5
done
set -e
kubectl wait --for=condition=Established --all crd > /dev/null

n=0
set +e
until [ $n -ge 2 ]; do
  kubectl apply -f https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-core.yaml > /dev/null && break
  n=$[$n+1]
  sleep 5
done
set -e
kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n knative-serving > /dev/null


## INSTALL KOURIER
echo -e "\033[0;92m 🔌 Installing Knative Serving Networking Layer ${KNATIVE_NET}... \033[0m"

n=0
until [ $n -ge 2 ]; do
  kubectl apply -f https://github.com/knative-sandbox/net-kourier/releases/download/v$KNATIVE_NET_KOURIER_VERSION/kourier.yaml > /dev/null && break
  n=$[$n+1]
  sleep 5
done
kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n kourier-system > /dev/null
kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n knative-serving > /dev/null

# Configure Knative to use this ingress
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'



INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [  -z $INGRESS_HOST ]; do
  sleep 5
  INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
done

echo "The INGRESS_HOST is $INGRESS_HOST"

KNATIVE_DOMAIN=$INGRESS_HOST.nip.io
echo "The KNATIVE_DOMAIN $KNATIVE_DOMAIN"
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"

echo -e "🕹 Installing Knative Samples Apps... \033[0m"
curl -sL https://raw.githubusercontent.com/csantanapr/knative-kind/master/03-serving-samples.sh | bash


DURATION=$(($(date +%s) - $STARTTIME))

echo -e "\033[0;92m 🚀 Knative installed with samples took: $(($DURATION / 60))m$(($DURATION % 60))s \033[0m"
echo -e "\033[0;92m 🎉 Now have some fun with Serverless Apps \033[0m"
