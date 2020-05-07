# Setup Knative with Minikube

>Updated and verified on May 6th, 2020 with:
>- Knative version 0.14
>- Minikube version 1.9.2
>- Kubernetes version 1.18.2

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
minikube config set kubernetes-version v1.18.2
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

You can check out other addons and settings using `minikube addon list`


### Install Knative


Select the version of Knative Serving to install
```bash
export KNATIVE_VERSION="0.14.0"
```

Install crds
```bash
kubectl apply --filename https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-crds.yaml
```

Install the controller
```bash
kubectl apply --filename https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-core.yaml
```

Verify that app pods for Knative serving are Running
```
kubectl get pods --namespace knative-serving -w
```

Output should be:
```
NAME                         READY   STATUS    RESTARTS   AGE
activator-6f5d97f57b-pctgb   1/1     Running   0          49s
autoscaler-c6f75f5f4-9grc2   1/1     Running   0          49s
controller-5dd9c9f5-g8brp    1/1     Running   0          49s
webhook-7b688c478f-zjp8b     1/1     Running   0          48s
```

## Install Kourier
Startig with Knative version `0.13` you can choose from multiple networing layers like Istio, Contour, Kourier, and Ambasador.
More info [#installing-the-serving-component](https://knative.dev/docs/install/any-kubernetes-cluster/#installing-the-serving-component)

```bash
kubectl apply --filename https://github.com/knative/net-kourier/releases/download/v$KNATIVE_VERSION/kourier.yaml
```

Verify Kourier is Running
```bash
kubectl get pods --namespace kourier-system -w
```

Output should be:
```
NAME                                      READY   STATUS    RESTARTS   AGE
3scale-kourier-control-f6cc554c-kpqth     1/1     Running   0          20s
3scale-kourier-gateway-7ff5b9f7db-sztvr   1/1     Running   0          21s
```

Get the `EXTERNAL-IP` for the kourier svc
```bash
kubectl get svc kourier -n kourier-system
```

Output should be:
```
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
kourier   LoadBalancer   10.107.1.152   10.107.1.152   80:30225/TCP,443:31215/TCP   2m25s
```

Save the `EXTERNAL-IP` address value in an environment variable `INGRESS_HOST`
```bash
export INGRESS_HOST=$(kubectl -n kourier-system get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $INGRESS_HOST
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
Setup domain name to use the External IP Address of the kourier service above
```bash
export KNATIVE_DOMAIN="$INGRESS_HOST.nip.io"
```
```bash
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"
```



## Deploy Knative Application

Deploy a Knative Service using the following yaml manifest:

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



Verify status of Knative Service until is Ready
```bash
kubectl get ksvc -w
```

Wait util column `READY` is `True` it might take a minute or two:
```
NAME    URL                                        LATESTCREATED   LATESTREADY   READY     REASON
hello   http://hello.default.10.107.1.152.nip.io   hello-r4vz7                   Unknown   RevisionMissing
hello   http://hello.default.10.107.1.152.nip.io   hello-r4vz7     hello-r4vz7   Unknown   RevisionMissing
hello   http://hello.default.10.107.1.152.nip.io   hello-r4vz7     hello-r4vz7   Unknown   IngressNotConfigured
hello   http://hello.default.10.107.1.152.nip.io   hello-r4vz7     hello-r4vz7   True  
```


Test the App
```bash
curl $(kubectl get ksvc hello -o jsonpath='{.status.url}')
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

Try the service `url` on your browser
```
open $(kubectl get ksvc hello -o jsonpath='{.status.url}')
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

Try to access the url again, and you will see the new pods running again.
```
NAME                                     READY   STATUS
hello-r4vz7-deployment-c5d4b88f7-rr8cd   0/2     Pending
hello-r4vz7-deployment-c5d4b88f7-rr8cd   0/2     ContainerCreating
hello-r4vz7-deployment-c5d4b88f7-rr8cd   1/2     Running
hello-r4vz7-deployment-c5d4b88f7-rr8cd   2/2     Running
```

Some people call this **Serverless** 🎉 🌮 🔥

If you have any issues with this instructions [open an new issue](https://github.com/csantanapr/knative-minikube/issues/new) please 🙏🏻
