# helm-lim

A Helm chart for Fortify License and Infrastructure Manager

![Version: 24.2.0](https://img.shields.io/badge/Version-24.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 24.2.0](https://img.shields.io/badge/AppVersion-24.2.0-informational?style=flat-square)

## Tested On

- ![Kubernetes: v1.28](https://img.shields.io/badge/kubernetes-v1.28-green?style=flat-square)

## Table of Contents

- [Tool Prerequisites](#tool-prerequisites)
- [Installation](#installation)
  - [Installation Prerequisites](#installation-prerequisites)
  - [Installation Steps](#installation-steps)
- [Upgrade](#upgrade-lim-helm-chart-from-previous-releases-to-v2420)
  - [Upgrade Prerequisites](#upgrade-prerequisites)
  - [Upgrade Steps](#upgrade-steps)
- [Values](#values)
  - [Required](#required)
  - [Optional, but Recommended](#optional-but-recommended)
  - [Other Values](#other-values)

## Tool Prerequisites

- [kubectl v1.28.7](https://kubernetes.io/docs/reference/kubectl/)
- [helm v3.12.2](https://helm.sh/)
- [yq v4.35.1](https://github.com/mikefarah/yq)

## Installation

> NOTE: The following instructions are for example purposes and are based on a Minikube environment and Linux system.
> Windows systems may require different syntax for certain commands and other Kubernetes Cluster providers may require additional/different configurations.

### Installation Prerequisites

- A working Kubernetes Cluster
- A [PersistentVolumeClaim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) to use for LIM persistence

### Installation Steps

- [Prepare for installation](#prepare-for-installation)
- [Prepare default Admin credentials Secret and values](#prepare-default-admin-credentials-secret-and-values)
- [Prepare JWT Secret and value(s)](#prepare-jwt-secret-and-values)
- [Prepare Server Certificate Secret(s) and value(s)](#prepare-server-certificate-secrets-and-values)
- [Prepare Signing Certificate Secrets and values](#prepare-signing-certificate-secrets-and-values)
- [Install Release](#install-release)
- [Set up port forwarding](#set-up-port-forwarding-through-kubectl)
- [Verify LIM is available](#verify-lim-is-available)
- [Test admin login](#test-admin-login)

### Prepare for installation

1. Copy the below yaml template and save it to a file in your machine named `values.yaml`:

    ```yaml
    defaultAdministrator:
      # -- (kubernetes.io/basic-auth) Name of the secret hosting admin credentials.
      credentialsSecretName: lim-admin-credentials
      # -- Admin name.
      fullName: update-with-your-name
      # -- Admin email.
      email: update-with-your-email@your-domain.com

    jwt:
      # -- (Opaque) Name of the secret hosting the JWT securityKey to use.
      securityKeySecretName: lim-jwt-security-key

    serverCertificate:
      # -- (Opaque | TLS) The name of the Secret hosting the server certificate
      # value.
      certificateSecretName: lim-server-certificate

    signingCertificate:
      # -- (Opaque | TLS) The name of the Secret hosting the signing certificate
      # value.
      certificateSecretName: lim-signing-certificate
      # -- (Opaque) The name of the Secret hosting the signing certificate `pfx`
      # password.
      certificatePasswordSecretName: lim-signing-certificate-password

    dataPersistence:
      # -- (PersistentVolumeClaim) A managed Persistent Volume Claim name.
      # PVC must be created before volume binding.
      existingClaim: your-persistent-volume-claim-name
    ```

1. Update the following placeholder values in values.yaml:

- defaultAdministrator.email
- defaultAdministrator.fullName
- dataPersistence.existingClaim

### Prepare default Admin credentials Secret and values

> NOTE: Secret will be named `lim-admin-credentials`

1. Run the following command to create the proper Secret in Kubernetes:

    ```shell
    kubectl create secret generic lim-admin-credentials \
    --type=basic-auth \
    --from-literal=username=lim_admin \
    --from-literal=password=$(openssl rand -base64 32)
    ```

### Prepare JWT Secret and value(s)

> NOTE: Secret will be named `lim-jwt-security-key`

1. Run the following command to create the proper Secret in Kubernetes:

    ```shell
    kubectl create secret generic lim-jwt-security-key \
    --type=Opaque \
    --from-literal=key=$(openssl rand -base64 64)
    ```

### Prepare Server Certificate Secret(s) and value(s)

If you wish to use a `PEM` (`.crt`) Server Certificate:

  1. Run the following command to create the server certificate:

      ```shell
      openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout /tmp/lim-server-key.pem -out /tmp/lim-server-cert.pem -subj "/C=CA/ST=Ontario/L=Waterloo/O=OpenText/OU=IT"
      ```

  1. Run the following command to create the proper Secret in Kubernetes:

      ```shell
      kubectl create secret generic lim-server-certificate \
      --type=TLS \
      --from-file=tls.crt=/tmp/lim-server-cert.pem \
      --from-file=tls.key=/tmp/lim-server-key.pem
      ```

  1. Run the following command to delete the certificate file(s):

      ```shell
      rm /tmp/lim-server-key.pem
      rm /tmp/lim-server-cert.pem
      ```

### Prepare Signing Certificate Secrets and values

1. Run the following command to create the server certificate:

    ```shell
    openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout /tmp/lim-signing-key.pem -out /tmp/lim-signing-cert.pem -subj "/C=CA/ST=Ontario/L=Waterloo/O=OpenText/OU=IT"
    ```

1. Run the following command to create a pfx file from the cert files:

    ```shell
    openssl pkcs12 -export -out /tmp/lim-signing-cert.pfx -inkey /tmp/lim-signing-key.pem -in /tmp/lim-signing-cert.pem
    ```

1. Save the password you used to secure your pfx certificate

    ```shell
    LIM_SIGNING_CERT_PWD="your-password-here"
    ```

1. Run the following command to create the proper Secrets in Kubernetes:

    ```shell
    kubectl create secret generic lim-signing-certificate \
    --type=Opaque \
    --from-file=tls.pfx=/tmp/lim-signing-cert.pfx
    kubectl create secret generic lim-signing-certificate-password \
    --type=Opaque \
    --from-literal=pfx.password=$LIM_SIGNING_CERT_PWD
    ```

1. Run the following command to delete the certificate file(s):

      ```shell
      rm /tmp/lim-signing-key.pem
      rm /tmp/lim-signing-cert.pem
      rm /tmp/lim-signing-cert.pfx
      ```

### Install release

1. Install LIM with Helm:

    > NOTE: To find available versions, go to the `tags` section of the helm chart page in DockerHub

    ```shell
    helm install lim oci://registry-1.docker.io/fortifydocker/helm-lim --version 24.2.0
    ```

### Set up port forwarding through `kubectl`

1. Verify that your LIM Pod is running successfuly:

    ```shell
    kubectl get pods
    ```

    > NOTE: It may take a few minutes before your pod gets to a proper `1/1 Running` configuration. You can run the command above multiple times or use the flag `-w` to watch for any changes.

1. Open a new terminal shell

1. Set up port forwarding through kubectl to access your LIM endpoint:

    For example, to forward the `localhost` port `8080`:

    ```shell
    kubectl port-forward svc/lim 8080:37562
    ```

### Verify LIM is available

1. Follow the steps at [Set up port forwarding through kubectl](#set-up-port-forwarding-through-kubectl).

1. You should now be able to access the LIM web endpoint through your favorite browser:

    ```txt
    https://localhost:8080
    ```

### Test admin login

1. Follow the steps at [Set up port forwarding through kubectl](#set-up-port-forwarding-through-kubectl).

1. Access the login endpoint from your favorite browser:

    ```txt
    https://localhost:8080/login
    ```

1. Log in with your default admin credentials

## Upgrade LIM Helm Chart from previous releases to v24.2.0

### Upgrade Prerequisites

- A running LIM environment
- `kubectl` access to LIM environment
- `helm` access to LIM environment
- Access to the LIM web client
- LIM admin credentials

### Upgrade Steps

- [Retrieve Licenses](#retrieve-licenses)
- [Retrieve Licenses](#removerelease-licenses)
- [Destroy previous LIM Deployment](#destroy-previous-lim-deployment)
- [Update values.yaml](#update-your-valuesyaml)
- [Deploy LIM v24.2.0 Deployment](#deploy-lim-v2420-deployment)
- [Register Licenses](#register-licenses)

### Retrieve licenses

1. Access your LIM web client on your favorite web browser

1. Go to the Admin tab

1. Note down your Fortify License & Infrastructure Manager Activation Token, License Server Description and Fortify License Server URL values

1. Go to the Licenses tab

1. Go to the Details page for each of your registered licenses and note down their respective Activation Tokens

1. Go to the License Pools subtab

1. Go to the Details page for each of your license pools and note down their respective configuration

### Remove/Release licenses

> ⚠️ WARNING ⚠️ - Make sure to follow the steps on [Retrieve Licenses](#retrieve-licenses) before proceeding. The actions in this section can lock your licenses to a deactivated cluster if not.

1. Access your LIM web client on your favorite web browser

1. Go to the License Pools subtab

1. Click Delete on each of your registered license pools

1. Go to the Licenses tab

1. Click Remove on each of your registered licenses

1. Go to the Admin tab

1. Click Release on your Server License

### Destroy previous LIM Deployment

> ⚠️ WARNING ⚠️ - Make sure your kubectl and helm contexts are set to the correct cluster before running the following commands!

1. Use helm to delete your LIM release

    ```shell
    helm delete YOUR_RELEASE_NAME --namespace YOUR_NAMESPACE
    ```

### Update your values.yaml

1. Merge your previous values.yaml with the provided values.yaml by the v24.2.0 release using your favorite text editor

### Deploy LIM v24.2.0 Deployment

1. Use helm to deploy your v24.2.0 LIM release

    ```shell
    helm install YOUR_RELEASE_NAME --namespace YOUR_NAMESPACE
    ```

### Register licenses

1. Access your LIM web client on your favorite web browser

1. Go to the Admin tab

1. Enter the Fortify License & Infrastructure Manager Activation Token, License Server Description and Fortify License Server URL values from your previous deployment

1. Go to the Licenses tab

1. Click Add License and add each of your licenses from the previous deployment

1. Go to the License Pools subtab

1. Click Add License Pool and add each of your license pools from the previous deployment

## Values

The following values are exposed by the Helm Chart. Unless specified as `Required`, values should only be overridden as made necessary by your specific environment.

### Required

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| dataPersistence.existingClaim | PersistentVolumeClaim | `""` | A managed Persistent Volume Claim name. PVC must be created before volume binding. Required if dataPersistence is enabled. |
| defaultAdministrator.credentialsSecretName | kubernetes.io/basic-auth | `""` | Name of the secret hosting admin credentials. |
| defaultAdministrator.email | string | `"invalid_email@somecompany.org"` | Admin email.  |
| jwt.securityKeySecretName | Opaque | `""` | Name of the secret hosting the JWT securityKey to use. |
| serverCertificate.certificatePasswordSecretName | Opaque | `""` | The name of the Secret hosting the server certificate `pfx` password. |
| serverCertificate.certificateSecretName | Opaque, TLS | `""` | The name of the Secret hosting the server certificate value. |
| signingCertificate.certificatePasswordSecretName | Opaque | `""` | The name of the Secret hosting the server certificate `pfx` password. |
| signingCertificate.certificateSecretName | Opaque | `""` | The name of the Secret hosting the signing certificate value. |

### Optional, but recommended

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| defaultAdministrator.fullName | string | `"LIM Default Admin"` | Admin full name. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| allowNonTrustedServerCertificate | bool | `false` | Determines whether to allow non-trusted server certificate. |
| containerPort.name | string | `"https"` | Name of the container port. |
| containerPort.port | int | `1443` | Port to expose in the container. |
| containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting LIM container. |
| customResources | object | `{"enabled":false,"resources":{}}` | Custom map that lets you define Kubernetes resources you want installed and configured as part of this chart. If you provide any resources, be sure to provide them as quoted, and set `customResources.enabled` to `true`. |
| customResources.enabled | bool | `false` | Whether to enable custom resource creation. |
| customResources.resources | Kubernetes YAML | `{}` | Custom resources to generate. |
| dataPersistence.disabled | bool | `false` | Whether to disable data persistence. It is Optional, but recommended to leave data persistence on. |
| dataPersistence.storeLogs | bool | `false` | Whether to store logs. |
| fortifyLicensingUrl | url | `"https://licenseservice.fortify.microfocus.com/"` | Defines the Foritfy License Service URL. |
| fullnameOverride | string | `.Release.name` | Overrides the fully qualified app name of the release. |
| image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| image.repository | string | `"fortifydocker/lim"` | Repository where to pull LIM docker image from. |
| image.tag | string | `"24.2.ubi.8"` | Version of the LIM docker image to pull. |
| imagePullSecrets | list | `[]` | list of references to secrets in the same namespace to use for pulling any of the images used by this release. |
| ingress.annotations | object | `{}` | Annotations to add to resulting resource. |
| ingress.className | string | `""` | Ingress resource class name. |
| ingress.enabled | bool | `false` | Whether to enable Ingress. |
| ingress.hosts[0] | object | `{"host":"lim.local","paths":[{"path":"/","pathType":"Prefix"}]}` | Hostname to accept requests through. |
| ingress.hosts[0].paths[0] | object | `{"path":"/","pathType":"Prefix"}` | Path to accept requests through. |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` | PathType. |
| ingress.tls | list | `[{"hosts":["some-host"],"secretName":"some-name"}]` | Defines TLS configurations. The default shows example configuration values, actual default is `[]`. |
| jwt.expirationMinutes | int | `5` | How long (in minutes) the token expires. |
| jwt.refreshTokenExpirationMinutes | int | `60` | How long (in minutes) the refresh token expires. |
| jwt.securityKeySecretKey | Opaque | `"token"` | Name of the key in secret hosting the JWT securityKey to use. |
| jwt.validAudience | string | `"FortifyLimAuthAudience"` | The intended recipients for the JWT, typically identified by their application ID or URL. |
| jwt.validIssuer | string | `"FortifyLimAuthIssuer"` | The entity that issued the JWT, usually identified by a URL. |
| nameOverride | string | `.Chart.name` | Overrides the name of this chart. |
| nodeSelector | pod.nodeSelector | `{"kubernetes.io/os":"linux"}` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| podSecurityContext | pod.securityContext | forces `UID`, `GID` to `1000`, disallow privilege escalation | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| proxy.address | string | `""` | Proxy server address. |
| proxy.credentialsSecretName | kubernetes.io/basic-auth | `""` | Name of the secret hosting proxy credentials. |
| proxy.enabled | bool | `false` | Whether to enable Proxy. |
| proxy.mode | int | `0` | Values can be: None=0, AutoDetect=1, Manual=2. |
| proxy.port | int | `0` | Proxy server port. |
| readinessInitialDelay | int | `10` | Defines an initial delay in seconds for readiness probe. |
| resources.limits.cpu | string | `".5"` | Defines the limits of cpu resources granted to this pod. |
| resources.limits.memory | string | `"1Gi"` | Defines the limits of memory resources granted to this pod. |
| resources.requests.cpu | string | `".5"` | Defines the initial request of cpu resources granted to this pod. |
| resources.requests.memory | string | `"1Gi"` | Defines the initial request of memory resources granted to this pod. |
| serverCertificate.certificateType | string | `"PEM"` | `PFX`, `PEM` (.crt). |
| serverCertificate.enabled | bool | `true` | Whether to enable TLS server certificate. |
| serverCertificate.pemCertPrivateKeySecretKey | string | `"tls.key"` | Name of the key that holds the private key (.key) of the PEM file in the provided Secret. |
| serverCertificate.pemCertPublicKeySecretKey | string | `"tls.crt"` | Name of the key that holds the public key (.crt) of the PEM file in the provided Secret. |
| serverCertificate.pfxCertSecretKey | string | `"tls.pfx"` | Name of the key that holds the `.pfx` file with both public and private keys. |
| serverCertificate.pfxPasswordSecretKey | string | `"pfx.password"` | Name of the key that holds the `pfx` password for unlocking the `.pfx` certificate file. |
| service.port | int | `37562` | Port to expose for HTTPS calls. |
| service.type | string | `"ClusterIP"` | Service type to use. |
| signingCertificate.pfxCertSecretKey | string | `"tls.pfx"` | Name of the key that holds the `.pfx` file with both public and private keys. |
| signingCertificate.pfxPasswordSecretKey | string | `"pfx.password"` | Name of the key that holds the `pfx` password for unlocking the `.pfx` certificate file. |
| tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
