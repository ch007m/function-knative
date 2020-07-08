# function-knative

## Pre-requisites

* [Docker for Mac or Windows](https://www.docker.com/products/docker-desktop)
* [kind](https://kind.sigs.k8s.io/) - to run your local Kubernetes cluster
* Java 11
* Maven 3.6.3+

## Run project locally

- Build and run the project locally
```bash
cd hello
./mvnw clean package
mvn spring-boot:run
```
- Access it using `httpie tool`
```
http -s solarized POST :8080 name=charles
HTTP/1.1 200 
Content-Type: application/json
Date: Wed, 08 Jul 2020 09:24:28 GMT
Keep-Alive: timeout=60
Transfer-Encoding: chunked
accept-encoding: gzip, deflate
connection: keep-alive, keep-alive
user-agent: HTTPie/2.2.0

{
    "message": "Welcome, charles"
}
```

## Launch K8s cluster using kind tool

**IMPORTANT**: Currently the application is tested only with local clusters.

```bash
$PROJECT_HOME/bin/start-kind.sh
```