# Function & knative

## Table of Contents

  * [Pre-requisites](#pre-requisites)
  * [Run project locally](#run-project-locally)
  * [Build and deploy on k8s](#build-and-deploy-on-k8s)
  * [Knative way](#knative-way)
  * [Create a kind cluster for knative](#create-a-kind-cluster-for-knative)

## Pre-requisites

* [Docker for Mac or Windows](https://www.docker.com/products/docker-desktop)
* [kind](https://kind.sigs.k8s.io/) - to run your local Kubernetes cluster
* Java 11
* Maven 3.6.3+
* [Httpie](http://httpie.org/)

## Run project locally

- Build and run the project locally
```bash
cd hello
./mvnw clean package
mvn spring-boot:run
```
- Access it using `httpie tool`
```bash
cat | http -s solarized POST :8080/hello Content-Type:text/plain
charles
^D
HTTP/1.1 200 
Content-Type: application/json
Date: Wed, 08 Jul 2020 16:11:30 GMT
Keep-Alive: timeout=60
Transfer-Encoding: chunked
accept-encoding: gzip, deflate
connection: keep-alive, keep-alive
user-agent: HTTPie/2.2.0

{
    "message": "Welcome, charles\n"
}
```
## Build and deploy on k8s

- Build the docker image using JIB maven plugin
```bash
export USER=xxxx
export PASSWORD=yyyyyy
export IMAGE=cmoulliard/sb-function:latest

mvn compile jib:dockerBuild \
    -Djib.to.image=$IMAGE \
    -Djib.to.auth.username=$USER \
    -Djib.to.auth.password=$PASSWORD
```
- Push it to docker hub
```bash
docker push $IMAGE
```
- Launch a k8s cluster locally
```bash
kind create cluster --name k8s
```
- Create a pod/service using the Spring Boot JIB image built. Next, forward the port in order to access the application
```bash
kubectl create ns demo
kubectl run spring-boot-function --image=$IMAGE --port=8080 --restart=Never -n demo

# Wait until pod is running
kubectl port-forward spring-boot-function 8080 -n demo
```
- Access the service
```bash
cat | http -s solarized POST :8080/hello Content-Type:text/plain
Sylvie
^D
...
{
    "message": "Welcome, sylvie"
}
```
- Delete the kind cluster
```bash
kind delete clusters k8s
```
## Knative way

- To play with the `Function` on a Knative k8 cluster, it is needed that knative is [installed](#create-a-kind-cluster-for-knative). Next, you can deploy the Knative service using the following yaml resource.
```bash
kubectl create ns demo-knative
kubectl apply -f resources/sb-kn-serving.yml -n demo-knative
```
- Access the service using the Service URL
```bash
SVC_URL=$(kubectl get ksvc greeter -n demo-knative -ojsonpath="{.status.url}")
http -s solarized POST $SVC_URL/hello name=sylvie 
...
{
    "message": "Welcome, sylvie"
}
```

## Create a kind cluster for knative

Info: https://github.com/knative/docs/blob/b639fa2ea3af7c6fff0ca60a02f0ff4d2215366c/blog/articles/set-up-a-local-knative-environment-with-kind.md

- Create a kubernetes cluster using kind
```bash
kind create cluster --name knative --config bin/kind-knative-cfg.yml
```
- Add Knative components using the Knative CRDs
```bash
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.0/serving-crds.yaml
```
- After the CRDs, the core components are the next to be installed on your cluster. 
```bash
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.0/serving-core.yaml
```
- Next, choose a networking layer such as `Kourier` which is the option with the lowest resource requirements, and connects to `Envoy` & `Knative Ingress` CRDs directly.
```bash
curl -Lo kourier.yaml https://github.com/knative/net-kourier/releases/download/v0.15.0/kourier.yaml
```
- By default, the Kourier service is set to be of type LoadBalancer. On local machines, this type doesn’t work, so you’ll have to change the type to NodePort and add nodePort elements to the two listed ports.  
  The complete Service portion (which runs from line 75 to line 94 in the document), should be replaced with:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: kourier
  namespace: kourier-system
  labels:
    networking.knative.dev/ingress-provider: kourier
spec:
  ports:
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: 31080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8443
    nodePort: 31443
  selector:
    app: 3scale-kourier-gateway
  type: NodePort
```
- Install kourier
```bash
kubectl apply -f resources/kourier.yaml
```
- Now you will need to set Kourier as the default networking layer for Knative Serving. You can do this by entering the command:
```bash
kubectl patch configmap/config-network \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
```
- If you want to validate that the patch command was successful, run the command:
```bash
kubectl describe configmap/config-network --namespace knative-serving
```
- To get the same experience that you would when using a cluster that has DNS names set up, you can add a “magic” DNS provider.
  `nip.io` provides a wildcard DNS setup that will automatically resolve to the IP address you put in front of `nip.io`.
  To patch the domain configuration for Knative Serving using nip.io, enter the command:
```bash
kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"127.0.0.1.nip.io":""}}'
  ```
- If you want to validate that the patch command was successful, run the command:
```bash
kubectl describe configmap/config-domain --namespace knative-serving
```
- By now, all pods in the knative-serving and kourier-system namespaces should be running. You can check this by entering the commands:
```bash
kubectl get pods --namespace knative-serving
kubectl get pods --namespace kourier-system
```
- To validate your cluster gateway is in the right state and using the right ports, enter the command:
```bash
kubectl --namespace kourier-system get service kourier
NAME      TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
kourier   NodePort   10.107.188.214   <none>        80:31080/TCP,443:31443/TCP   41s
```
- Now that the cluster, Knative, and the networking components are ready, you can deploy an app.
  The straightforward Go app that already exists, is an excellent example app to deploy.
  The first step is to create a yaml file with the hello world service definition:

```bash
cat > service.yaml <<EOF
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go # The name of the app
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go # The URL to the image of the app
          env:
            - name: TARGET # The environment variable printed out by the sample app
              value: "Hello Knative Serving is up and running with Kourier!!"
EOF
```
- Deploy the Knative service
```bash
kubectl create ns demo
kubectl apply -f resources/service.yaml -n demo
```
- To validate your deployment, you can use kubectl get ksvc. NOTE: While your cluster is configuring the components that make up the service, the output of the kubectl get ksvc command will show that the revision is missing. The status ready eventually changes to true.
```bash
kubectl get ksvc -n demo
```
- Test the service
```bash
http http://helloworld-go.demo.127.0.0.1.nip.io/                      
HTTP/1.1 200 OK
content-length: 62
content-type: text/plain; charset=utf-8
date: Wed, 08 Jul 2020 14:37:00 GMT
server: envoy
x-envoy-upstream-service-time: 1159

Hello Hello Knative Serving is up and running with Kourier!!!
```
- You can stop your cluster and remove all the resources you’ve created by entering the command:
```bash
kind delete cluster --name knative
```