# Build an image through an Argo workflow
This repository consists of two examples of Argo Workflow
1. upload and run images using public image repository (i.e. DockerHub)
2. upload and run images using a private image repository and private object storage (MinIO) 

## Prerequisities
- A Kubernetes Cluster. For this example we use Minikube (kubernetes locally)
- A dockerhub account in order to push the image (for public repo)
- Integration of private registry
- Deployment of private ocject storage (we use minio in our example) 

## Installation steps
To install the whole environment you could execut the `install.sh`, otherwise you could follow the steps that are listed below:
1. Argo installation ()
```shell
kubectl create ns argo
kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-workflows/stable/manifests/namespace-install.yaml 
```
2. Setup a private registry
```shell
# We'll start with creating a directory in which we'll store our configs and certificates (TLS configuration, htpasswd config)
mkdir -p registry/certs 
mkdir -p registry/auth
cd registry/certs/
openssl genrsa 1024 > domain.key
chmod 400 domain.key
# Generate certificate 
openssl req -new -x509 -nodes -sha1 -days 365 -key domain.key -out domain.crt
# Access auth/ directory
cd ../auth/
# Use the registry container to generate a htpasswd file
# You can change the username and password fields
docker run --rm --entrypoint htpasswd registry:2 -Bbn username testuser password testpassword > htpasswd

# Move to the registry/ folder
cd ..
docker run -d \
    -p 5000:5000 \
    --restart=always \
    --name registry \
    -v "$(pwd)"/auth:/auth \
    -e "REGISTRY_AUTH=htpasswd" \
    -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
    -v "$(pwd)"/certs:/certs \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    registry:2
```
To push/pull any image from your local registry you could see the examples below:
```shell
# Sign-in to the private registry
docker login 0.0.0.0:5000
# Pull busybox image
docker pull busybox
# Tag the image
docker tag busybox 0.0.0.0:5000/busybox
# Try to push the image
docker push 0.0.0.0:5000/busybox
```

Secret authorization that holds the authentication token:
```shell
kubectl create secret docker-registry regcred --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
```

3. Configuring your artifact repository
Argo project supports any S3 artifact repository (AWS,GCS,Minio,etc.)
```shell
brew install helm # mac, helm 3.x
helm repo add minio https://helm.min.io/ # official minio Helm charts
helm repo update
helm install argo-artifacts minio/minio --set service.type=LoadBalancer --set fullnameOverride=argo-artifacts --namespace argo
```
> Note: Minio is installed via Helm, it generated credentials. You will use these credentials to login to the UI. The commands below give you the `ACCESKEY` and the `SECRETKEY`
```shell
ACCESS_KEY=$(kubectl get secret argo-artifacts --namespace argo -o jsonpath="{.data.accesskey}" | base64 --decode)
SECRET_KEY=$(kubectl get secret argo-artifacts --namespace argo -o jsonpath="{.data.secretkey}" | base64 --decode)
```

kubectl -n argo port-forward --address 0.0.0.0 argo-artifacts-646df795d7-v2k5l 9000:9000  &>/dev/null &
## Configuration files 

<!-- There are four files that have to initialize to run the example:
- volume.yaml (It creates a persistent volume used as kaniko build context)
- volume-claim.yaml (The persistent volume used as kaniko build context) -->
- templates.yaml (This file contains the frequently-used templates such as `build-image template` )
- build_wf.yaml  (is for starting the workflow that contains the example image)


## Create a dockerfile into the project's directory
Firstly, we should navigate into the project's directory and create the following commands. The dockerfiles below will be saved into the context folder

```shell
cat >> context/dockerfile << EOF
FROM alpine:latest
ENTRYPOINT ["echo"]
CMD ["hello"]
EOF
cat >> context/dockerfile << EOF
FROM alpine:latest
ENTRYPOINT ["echo"]
EOF
```

## Upload the files into the private object storage
Then, using the script `upload_to_minio.sh`, we set the bucket name and the file that contains the dockerfiles
```shell
bash upload_to_minio.sh -b my-bucket -d context
```
The command above will compress the dockerfiles into a `context.tar.gz` file and it will uploaded into the specifies object storage 

## Argo templates and workflow 
When the upload will be finished, you should run the templates to define that they will live into the cluster. By doing such a method, you create a library that allows you to use the most frequent-used templates and reuse them into different workflows. The command below is used to save the template into the Argo.

```shell
argo -n argo template create templates.yaml
```
After that you are ready to run your workflow.
```shell
argo -n argo submit build_wf.yaml
```
> Note: You could use the `--watch` argument to monitor the progress of the workflow
> Note: It is important to notice that `-n <namespace>` should be defined. If you have deploy the Argo Project into the default namespace of kubernetes then you should prevent this definition 


## Secret authorization that holds the authentication token

Create the Secret, naming it regcred:

```shell
kubectl create secret docker-registry regcred --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
```