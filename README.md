# function-knative

## Pre-requisites

* https://www.docker.com/products/docker-desktop[Docker for Mac or Windows]
* https://kind.sigs.k8s.io/[kind] - to run your local Kubernetes cluster
* Java 11
* Maven 3.6.3+

## Start Kubernetes Cluster

**IMPORTANT**: Currently the application is tested only with local clusters.

```bash
$PROJECT_HOME/bin/start-kind.sh
```