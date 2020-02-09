# Setup Knative with Minikube

>Updated and verified on Feb, 2020 with Knative version 0.12

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
minikube config set kubernetes-version v1.17.2
```

>I recommend using the hyperkit vm driver is available in your platform.

>The default configuration for memory of `2GB` and `4 cpus`, should work fine, if you want to increase it you can do it with `minikube config` command

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

## Install Istio (Lean)

```bash
kubectl apply -f https://raw.githubusercontent.com/knative/serving/master/third_party/istio-1.4.2/istio-crds.yaml
```

```bash
kubectl apply -f https://raw.githubusercontent.com/knative/serving/master/third_party/istio-1.4.2/istio-minimal.yaml
```


Verify Istio is Running
```bash
kubectl get pods --namespace istio-system -w
```

Output should be:
```
NAME                                     READY   STATUS      RESTARTS   AGE
cluster-local-gateway-866d94b5f5-2ht7h   1/1     Running     0          17m
istio-ingressgateway-54589b686-bhcmz     2/2     Running     0          19m
istio-init-crd-10-1.4.2-dr4zb            0/1     Completed   0          20m
istio-init-crd-11-1.4.2-dks6s            0/1     Completed   0          20m
istio-init-crd-14-1.4.2-5p62d            0/1     Completed   0          20m
istio-pilot-7b5967465c-gfhrf             1/1     Running     0          19m
```

Get the `EXTERNAL-IP` for the istio-ingressgateway
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

Output should be:
```
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.96.147.24   10.96.147.24   15020:31149/TCP,80:32309/TCP,443:30119/TCP   11m
```

Save the `EXTERNAL-IP` address value in an environment variable `INGRESS_HOST`
```bash
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

### Install Knative


Select the version of Knative Serving to install
```bash
export KNATIVE_VERSION="0.12.0"
```

Install crds
```bash
kubectl apply --filename https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-crds.yaml
```

Install the controller
```bash
kubectl apply \
--selector networking.knative.dev/certificate-provider!=cert-manager \
--filename https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving.yaml
```

Verify that app pods for Knative serving are Running
```
kubectl get pods --namespace knative-serving -w
```

Output should be:
```
NAME                                READY   STATUS    RESTARTS   AGE
activator-7db6679666-fwtxh          1/1     Running   0          8m15s
autoscaler-ffc9f79b4-qtpgv          1/1     Running   0          8m15s
autoscaler-hpa-5994dfdb67-tfbrr     1/1     Running   0          8m15s
controller-6797f99458-9qxql         1/1     Running   0          8m14s
networking-istio-85484dc749-fnc2p   1/1     Running   0          8m14s
webhook-6f97457cbf-sxxxq            1/1     Running   0          8m14s
```



## Configure Knative

Setup domain name to use the External IP Address of the istio-ingressgateway service above

```bash
export KNATIVE_DOMAIN="$INGRESS_HOST.nip.io"
```

```bash
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"
```

## Deploy Knative Application

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
NAME    URL                                          LATESTCREATED   LATESTREADY   READY     REASON
hello   http://hello.default.10.108.164.193.nip.io   hello-jm665                   Unknown   RevisionMissing
hello   http://hello.default.10.108.164.193.nip.io   hello-jm665     hello-jm665   Unknown   RevisionMissing
hello   http://hello.default.10.108.164.193.nip.io   hello-jm665     hello-jm665   Unknown   IngressNotConfigured
hello   http://hello.default.10.108.164.193.nip.io   hello-jm665     hello-jm665   True
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
NAME                                      READY   STATUS    RESTARTS   AGE
hello-kpkxt-deployment-78c9b8c9cf-zrht8   2/2     Running   0          6s
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
NAME                                      READY   STATUS
hello-jm665-deployment-68d5444d59-5hfsl   2/2     Running
hello-jm665-deployment-68d5444d59-5hfsl   2/2     Terminating
hello-jm665-deployment-68d5444d59-5hfsl   1/2     Terminating
hello-jm665-deployment-68d5444d59-5hfsl   0/2     Terminating
```

You can access the url again, and you will see the new pods running again.
```
NAME                                      READY   STATUS
hello-jm665-deployment-68d5444d59-4rxqt   0/2     Pending
hello-jm665-deployment-68d5444d59-4rxqt   0/2     ContainerCreating
hello-jm665-deployment-68d5444d59-4rxqt   1/2     Running
hello-jm665-deployment-68d5444d59-4rxqt   2/2     Running
```

Some people call this **Serverless** 🎉 🌮 🔥

If you have any issues with this instructions [open an new issue](https://github.com/csantanapr/knative-minikube/issues/new) please 🙏🏻
