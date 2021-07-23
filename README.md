# argo-kaniko-example
This repository builds a simple image using kaniko into a Argo Workflow

## Prerequisities
- A Kubernetes Cluster. For this example we use Minikube (kubernetes locally)
- A dockerhub account in order to push the image  

## Configuration files 

There are four files that have to initialize to run the example:
- volume.yaml (It creates a persistent volume used as kaniko build context)
- volume-claim.yaml (The persistent volume used as kaniko build context)
- templates.yaml (This file contains the frequently-used templates such as `build-image template` )
- build_wf.yaml  (is for starting the workflow that contains the example image)
## Create a dockerfile into the local mounted directory
The first step is to SSH into the cluster, where it will mounted in kaniko container as build context. Then, you should create a dockerfile there. 

```shell
mkdir -p kaniko/work && cd kaniko/work
echo 'FROM alpine:3.12.4' >> dockerfile
echo 'ENTRYPOINT ["echo"]' >> dockerfile
echo 'CMD ["hello world"]' >> dockerfile

cat dockerfile
FROM alpine:3.12.4
ENTRYPOINT ["echo"]
CMD ["hello world"]
pwd
/home/<user-name>/kaniko/work # copy this path in volume.yaml file
```

## Secret authorization that holds the authentication token

Create the Secret, naming it regcred:

```shell
kubectl create secret docker-registry regcred --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
```

## Create resources

```shell
kubectl -n argo create -f volume.yaml
kubectl -n argo create -f volume-claim.
argo -n argo template create templates.yaml
argo -n argo submit --watch build_wf.yaml
```

> Note: It is important to notice that `-n <namespace>` should be defined 
