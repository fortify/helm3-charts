# Helm Deployment

## Requirements

- A Kubernetes cluster with linux nodes.
- kubectl (https://kubernetes.io/docs/tasks/tools/).
- Helm 3 (https://github.com/helm/helm/releases).

## Additional Documentation

For more information about ScanCentral DAST components and how to configure and use a DAST environment, refer to the _Micro Focus Fortify ScanCentral DAST Configuration and Usage Guide_. You can find documentation on the Micro Focus Support and Services Documentation page (https://www.microfocus.com/en-us/support/documentation). 

## Non-public docker images

**DAST Configuration Tool CLI with SecureBase** and **Webinspect** cannot be pulled from **fortifydocker** public registry. **Webinspect** image must be downloaded and pushed to your private registry. Next section describes how to build and push the **DAST Configuration Tool CLI with SecureBase** image.

### Create ScanCentral DAST Configuration Tool Docker Image with SecureBase

ScanCentral DAST can be initialized, upgraded or configured automatically if `autoDeploy:` is `true` at **values.yaml**. By default, the helm chart uses **fortifydocker/scancentral-dast-config** image to run the **autoDeploy** job. This docker image does not include the file **DefaultData.zip** which contains the data to seed a new database or to upgrade from previous versions. As it lacks this file, **autoDeploy** will not be able to initialize or upgrade the database. These two methods describe how to obtain a **scancentral-dast-config** image that includes **DefaultData.zip**:

#### Method 1: Load fortifydocker/scancentral-dast-config-sb from tar

- On a machine with docker support, sign in to Fortify Customer Portal and download **scancentral-dast-config-sb.tar**.
- On a command prompt, run `docker load scancentral-dast-config-sb.tar` . This command will load the **fortifydocker/scancentral-dast-config-sb:22.2** image from the tar file.
- Run `docker tag fortifydocker/scancentral-dast-config-sb:22.2 <DOCKER_REGISTRY>/scancentral-dast-config-sb:22.2`. Replace `<DOCKER_REGISTRY>` with your docker registry. It must be accessible from your Kubernetes cluster.
- Run `docker push <DOCKER_REGISTRY>/scancentral-dast-config-sb:22.2`. This command will push the docker image to `<DOCKER_REGISTRY>`.
- Change the image reference for the `upgradeJob` at `values.yaml`.

```yaml
images:
(...)
  upgradeJob:
    repository: <DOCKER_REGISTRY>/scancentral-dast-config-sb
    tag: "22.2"
    pullPolicy: "IfNotPresent"
(...)
```
- Install the chart.

#### Method 2: Download the SecureBase and build a new docker image

- Sign in to Fortify Customer Portal and download DefaultData.zip.
- On a machine with docker support, create a directory and a file named Dockerfile in it with this content:

```dockerfile
FROM fortifydocker/scancentral-dast-config:22.2

COPY DefaultData.zip /app/
```

- Place DefaultData.zip in that directory.
- Open a command prompt, change to the Dockerfile's directory and run: `docker build -t <DOCKER_REGISTRY>/scancentral-dast-config-sb:22.2 .`. This will build a new image with DefaultData.zip at C:\app directory. Replace `<DOCKER_REGISTRY>` with your docker registry. It must be accessible from your Kubernetes cluster.
- Run `docker push <DOCKER_REGISTRY>/scancentral-dast-config-sb:22.2`. This command will push the docker image to `<DOCKER_REGISTRY>`.
- Change the image reference for the `upgradeJob` at `values.yaml`.

```yaml
images:
(...)
  upgradeJob:
    repository: <DOCKER_REGISTRY>/scancentral-dast-config-sb
    tag: "22.2"
    pullPolicy: "IfNotPresent"
(...)
```
- Install the chart.


## Deploy the Chart

### Install Dependencies

Jump to next section if WebInspect script engine (WISE) is disabled.
WebInspect script engine (WISE) requires that **HAProxy Ingress** and **Kubernetes Metrics Server** are installed in the cluster. See the next links for install instructions:

- https://artifacthub.io/packages/helm/haproxy-ingress/haproxy-ingress/?modal=install
- https://github.com/kubernetes-sigs/metrics-server#installation

### Install ScanCentral DAST Chart

You can copy values.yaml to a new file and make any customizations you need. After that, run the following command in the Chart's directory:

```commandline
$ helm install scancentral-dast . -f <VALUES_YAML_FILE> --timeout 40m
```

This will create a release called `scancentral-dast` based on the variables contained at the values file.
The timeout is increased to 40m in case the database needs a complete initialization, which may take around 30 minutes.

### Upgrade/Update

After making any customizations needed to the values.yaml file, run the following command in the Chart's directory:

```commandline
$ helm upgrade scancentral-dast . -f <VALUES_YAML_FILE> --timeout 40m
```

Helm will apply the new configuration. If you monitor the pods, you will see that an Upgrade job will be triggered. This job turns ScanCentral DAST pods off first, then it applies any necessary changes to the database. After the database upgrade, all ScanCentral DAST components are restarted. 

## Configure ScanCentral DAST API Ingress

In order to expose the ScanCentral DAST API endpoint with an ingress, you must first install an Ingress controller in the cluster. Installing the controller is out of the scope of this guide. For more information, see https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/.

Here is an example on how to configure the ingress using Azure's AKS HTTP application routing solution (https://docs.microsoft.com/en-us/azure/aks/http-application-routing). We assume that the routing addon has already been installed. Take note of the <CLUSTER_SPECIFIC_DNS_ZONE>.

If TLS is required, we must create a secret with the certificate and private key. This secret is used by the ingress to establish the TLS connection.

Assuming that we have the certificate in PEM format at `cert.pem` and the key at `cert.key`, run the following command:

```commandline
$ kubectl create secret tls tls-secret --cert=cert.pem --key=cert.key
secret/tls-secret created
```

Now, we make sure that `api` and `twofactorauth` are enabled at `ingress` section of the values file. We want to expose the API with the FQDN `dast-api.<CLUSTER_SPECIFIC_DNS_ZONE>` and twofactorauth component with `dast-2fa.<CLUSTER_SPECIFIC_DNS_ZONE>` . Run the following command:

```yaml
ingress:
  api:
    enabled: true
    annotations:
      # This annotation is required. It registers the ingress to use Azure's HTTP Application routing addon
      # The addon will check the ingress configuration and prepare the necessary cloud resources so the
      # endpoint can be reached. Other controllers use other Annotations.
      kubernetes.io/ingress.class: addon-http-application-routing
    hosts:
      - host: dast-api.<CLUSTER_SPECIFIC_DNS_ZONE>
        paths:
          - path: /
            pathType: Prefix
    tls:
      - hosts:
          - dastapi.<CLUSTER_SPECIFIC_DNS_ZONE>
        secretName: tls-secret
        
  twofactorauth:
    enabled: false
    annotations:
      # This annotation is required. It registers the ingress to use Azure's HTTP Application routing addon
      # The addon will check the ingress configuration and prepare the necessary cloud resources so the
      # endpoint can be reached. Other controllers use other Annotations.
      kubernetes.io/ingress.class: addon-http-application-routing

      # twofactor auth uses https in the backend
      nginx.ingress.kubernetes.io/backend-protocol: https

      # twofactorauth uses WebSockets. If using nginx, these annotations are necessary
      # in order to keep the WebSockets open enough time to be functional
      # https://kubernetes.github.io/ingress-nginx/user-guide/miscellaneous/#websockets
      nginx.ingress.kubernetes.io/proxy-read-timeout: 3600
      nginx.ingress.kubernetes.io/proxy-send-timeout: 3600
    hosts:
      - host: dast2fa.<CLUSTER_SPECIFIC_DNS_ZONE>
        paths:
          - path: /
            pathType: Prefix
    tls:
      - hosts:
          - dast2fa.<CLUSTER_SPECIFIC_DNS_ZONE>
        secretName: tls-secret
```

Now we upgrade the release with the following command:

```commandline
$ helm upgrade scancentral-dast . -f <VALUES_YAML_FILE>
```

When the upgrade is complete, we should be able to get the ingress with the following command:

```commandline
$ kubectl get ingress
NAME       CLASS    HOSTS                     ADDRESS         PORTS     AGE
scancentral-dast-api   <none>   dastapi.<CLUSTER_SPECIFIC_DNS_ZONE>   <PUBLIC_IP>     80, 443   0h10m
scancentral-dast-twofactorauth   <none>   dast2fa.<CLUSTER_SPECIFIC_DNS_ZONE> <PUBLIC_IP>  80, 443   0h10m
```

We can reach the API through the IP specified at <PUBLIC_IP>. It is out of the scope of this document to configure the DNS routing.
We can test it with curl, for example:

```commandline
$ curl -k https://dastapi.<CLUSTER_SPECIFIC_DNS_ZONE>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
(truncated)
```

We use `-k` to allow insecure connections as we used a self-signed certificate for demo purposes.

## Enable WISE

WISE is disabled in default values. You must set `wise.enabled` to **true** at `values.yaml` to enable it, but before applying that configuration you must install some dependencies in the cluster.
WISE uses Kubernetes Metrics Server to gather WISE Pod resource usage metrics. It also uses HAProxy internally to distribute the processing load between WISE pods. Please follow the instructions on these links to install these dependencies:

- https://artifacthub.io/packages/helm/haproxy-ingress/haproxy-ingress/
- https://github.com/kubernetes-sigs/metrics-server

Please read the comments at `wise` section at `values.yaml` for additional configuration information before installing/upgrading.
