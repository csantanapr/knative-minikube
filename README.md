# Setup Knative with Minikube

>Updated and verified on 2020/11/02 with:
>- Knative version 0.18.1
>- Minikube version 1.14.2
>- Kubernetes version 1.19.3

## Install Minikube

On MacOS
```bash
brew install minikube
```

For more information installing or using minikube checkout the docs https://minikube.sigs.k8s.io/docs/start/


## Setup Minikube

Make sure you have a recent version of minikube:
```
minikube update-check
```

Make sure you have a recent version of kubernetes, you can configure the version to avoid needing the start flag:
```
minikube config set kubernetes-version v1.19.3
```

>I recommend using the hyperkit vm driver is available in your platform.

>The configuration for memory of `2GB` and `2 cpus`, should work fine, if you want to change the values you can do it with `minikube config`
```
minikube config set memory 2048
minikube config set cpus 2
```

## Sart Minikube


If you think you have some configuration and want to start with a clean environment you can delete the VM:
```
minikube delete
```

Now star the minikube vm
```
minikube start
```

>If your VM doesn't start and gets stuck, check that your are not connected using a VPN such as Cisco VPN AnyConnect, this vpn client affects networking and avoids many kubernetes environmentes (ie minikube, minishift) from starting.

In a new terminal run
```
minikube tunnel
```

You can check out other addons and settings using `minikube addons list`


### Install Knative

TLDR; `./demo.sh`

1. Select the version of Knative Serving to install
    ```bash
    export KNATIVE_VERSION="0.18.1"
    ```

1. Install Knative Serving in namespace `knative-serving`
    ```bash
    kubectl apply -f https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-crds.yaml

    kubectl apply -f https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-core.yaml

    kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-serving
    ```


## Install Kourier
In Knative you need to choose from multiple networing layers like Istio, Contour, Kourier, and Ambasador.
More info [#installing-the-serving-component](https://knative.dev/docs/install/any-kubernetes-cluster/#installing-the-serving-component)

1. Select the version of Knative Net Kurier to install
    ```bash
    export KNATIVE_NET_KOURIER_VERSION="0.18.0"
    ```

1. Install Knative Layer kourier in namespace `kourier-system`
    ```bash
    kubectl apply -f https://github.com/knative/net-kourier/releases/download/v$KNATIVE_NET_KOURIER_VERSION/kourier.yaml

    kubectl wait deployment --all --timeout=-1s --for=condition=Available -n kourier-system

    # deployment for net-kourier gets deployed to namespace knative-serving
    kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-serving
    ```

1. Save the external address value in an environment variable `EXTERNAL-IP`
    ```bash
    export EXTERNAL_IP=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo EXTERNAL_IP=$EXTERNAL_IP
    ```


## Configure Knative for Kourier


To configure Knative Serving to use Kourier by default:
```bash
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
```

## Configure DNS local access

Optional: You can manually configure the config map domain names.

1. Setup domain name to use the External IP Address of the kourier service above
    ```bash
    export KNATIVE_DOMAIN="$EXTERNAL_IP.nip.io"

    kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"
    ```



## Deploy Knative Application

Deploy using [kn](https://github.com/knative/client)
```bash
kn service create hello \
--image gcr.io/knative-samples/helloworld-go \
--port 8080 \
--env TARGET=Knative
```

**Optional:** Deploy a Knative Service using the equivalent yaml manifest:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go
          ports:
            - containerPort: 8080
          env:
            - name: TARGET
              value: "Knative"
EOF
```

Wait for Knative Service to be Ready
```bash
kubectl wait ksvc hello --all --timeout=-1s --for=condition=Ready
```

Get the URL of the new Service
```bash
SERVICE_URL=$(kubectl get ksvc hello -o jsonpath='{.status.url}')
echo $SERVICE_URL
```

Test the App
```bash
curl $SERVICE_URL
```

Output should be:
```
Hello Knative!
```

Check the knative pods that scaled from zero
```
kubectl get pod -l serving.knative.dev/service=hello
```

Output should be:
```
NAME                                     READY   STATUS    RESTARTS   AGE
hello-r4vz7-deployment-c5d4b88f7-ks95l   2/2     Running   0          7s
```

Try the service `url` on your browser (command works on linux and macos)
```bash
open $SERVICE_URL
```

You can watch the pods and see how they scale down to zero after http traffic stops to the url
```
kubectl get pod -l serving.knative.dev/service=hello -w
```

Output should look like this:
```
NAME                                     READY   STATUS
hello-r4vz7-deployment-c5d4b88f7-ks95l   2/2     Running
hello-r4vz7-deployment-c5d4b88f7-ks95l   2/2     Terminating
hello-r4vz7-deployment-c5d4b88f7-ks95l   1/2     Terminating
hello-r4vz7-deployment-c5d4b88f7-ks95l   0/2     Terminating
```

Try to access the url again, and you will see a new pod running again.
```
NAME                                     READY   STATUS
hello-r4vz7-deployment-c5d4b88f7-rr8cd   0/2     Pending
hello-r4vz7-deployment-c5d4b88f7-rr8cd   0/2     ContainerCreating
hello-r4vz7-deployment-c5d4b88f7-rr8cd   1/2     Running
hello-r4vz7-deployment-c5d4b88f7-rr8cd   2/2     Running
```

Some people call this **Serverless** 🎉 🌮 🔥

If you have any issues with this instructions [open an new issue](https://github.com/csantanapr/knative-minikube/issues/new) please 🙏🏻
