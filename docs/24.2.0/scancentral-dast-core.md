# helm-scancentral-dast-core

A Helm chart for ScanCentral DAST core applications and infrastructure.

![Version: 24.2.0](https://img.shields.io/badge/Version-24.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 24.2.0](https://img.shields.io/badge/AppVersion-24.2.0-informational?style=flat-square)

## Tested On

- ![Kubernetes: v1.28](https://img.shields.io/badge/kubernetes-v1.28-green?style=flat-square)

## Table of Contents

- [Tool Prerequisites](#tool-prerequisites)
- [Installation](#installation)
- [Upgrade](#upgrade)
- [Configurable values](#values)

## Tool Prerequisites

These instructions were written and tested using the following tool versions.   It is recommended that the same tool versions be used in order to avoid unpredictable results.

- [kubectl v1.28.7](https://kubernetes.io/docs/reference/kubectl/)
- [helm v3.12.2](https://helm.sh/)

## Installation

> NOTE: The following instructions are for testing purposes and are based on a Minikube environment running on Linux.

- [Prepare for installation](#prepare-for-installation)
  - [Preparing LIM Secrets](#preparing-lim-secrets)
  - [Prepare Database Credentials](#prepare-database-credentials)
  - [Prepare Service Account Token](#prepare-service-account-token)
  - [Prepare SSC Credentials](#prepare-ssc-credentials)
  - [Prepare service SSL certificates](#prepare-service-ssl-certificates)
  - [Prepare image pull secret](#prepare-image-pull-secret)
- [Installing ScanCentral DAST core](#installing-scancentral-dast-core)
- [Special Considerations for testing environments](#special-considerations-for-testing-environments)

### Prepare for installation

#### Preparing LIM Secrets

1. Ensure that LIM is up and running within the cluster, that LIM is activated, and that WebInspect has been licensed.
1. Create a secret in the namespace you intend to install ScanCentral DAST into, using the license pool information you defined in LIM.

    ```bash
    kubectl -n <scancentral namespace> \
    create secret generic lim-pool \
    --type='basic-auth' \
    --from-literal=username=<lim license pool name> \
    --from-literal=password=<lim license pool password>
    ```

1. You will need to ensure that you have the name of the administrative secret used for LIM, this will be required to pass to the helm chart.   LIM names this secret 'lim-admin-credentials' by default.

#### Prepare Database Credentials

1. Create or obtain the credentials to a 'DBO-level Account' as described within the Fortify ScanCentral DAST documentation.
1. Create a secret in the namespace you intend to install ScanCentral DAST into, using the credentials obtained in the previous step.

    ```bash
    kubectl -n <scancentral namespace> \
    create secret generic scdast-db-owner \
    --type='basic-auth' \
    --from-literal=username=<DBO username> \
    --from-literal=password=<DBO password>
    ```

1. Create or obtain the credentials to a 'Standard Account' as described within the Fortify ScanCentral DAST documentation.
1. Create a secret in the namespace you intend to install ScanCentral DAST into, using the credentials obtained in the previous step.

    ```bash
    kubectl -n <scancentral namespace> \
    create secret generic scdast-db-standard \
    --type='basic-auth' \
    --from-literal=username=<DBO username> \
    --from-literal=password=<DBO password>
    ```

#### Prepare Service Account Token

1. Generate a service account token and install into Kubernetes as a secret using the example below.

    ```bash
    kubectl -n <scancentral namespace> \
    create secret generic scdast-service-token \
    --type='opaque' \
    --from-literal=service-token=$(openssl rand -base64 32)
    ```

#### Prepare SSC Credentials

1. Create or obtain the service account credentials for SSC as described within the Fortify ScanCentral DAST documentation.
1. Create a secret in the namespace you intend to install ScanCentral DAST into, using the credentials obtained in the previous step.

    ```bash
    kubectl -n <scancentral namespace> \
    create secret generic scdast-ssc-serviceaccount \
    --type='basic-auth' \
    --from-literal=username=<SSC username> \
    --from-literal=password=<SSC password>
    ```

#### Prepare service SSL certificates

Service SSL certificates ensure that components communcate to one another with SSL.  This certificates do not affect ingress resources.   Certificates MUST be in PKCS#12 (PFX) format.
Generating these certificates off of your internal trusted PKI services can be done by using the kubectl create secret commands with your PKI-generated PFX files and passwords.

1. Prepare API service certificate

    ```bash
    API_SERVER_CERT_PWD="$(openssl rand -base64 32)"
    openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout /tmp/api-server-key.pem -out /tmp/api-server-cert.pem -subj "/C=CA/ST=Ontario/L=Waterloo/O=YourCompany/OU=IT"
    openssl pkcs12 -export -out /tmp/api-server-cert.pfx -inkey /tmp/api-server-key.pem -in /tmp/api-server-cert.pem  -passout "pass:${API_SERVER_CERT_PWD}"
    kubectl create secret generic api-server-certificate --type=Opaque --from-file=tls.pfx=/tmp/api-server-cert.pfx
    kubectl create secret generic api-server-certificate-password --type=Opaque --from-literal=password=$API_SERVER_CERT_PWD
    rm /tmp/api-server-key.pem /tmp/api-server-cert.pem /tmp/api-server-cert.pfx
    unset API_SERVER_CERT_PWD
    ```

1. Prepare UtilityService service certificate

    ```bash
    UTILITYSERVICE_SERVER_CERT_PWD="$(openssl rand -base64 32)"
    openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout /tmp/utilityservice-server-key.pem -out /tmp/utilityservice-server-cert.pem -subj "/C=CA/ST=Ontario/L=Waterloo/O=YourCompany/OU=IT"
    openssl pkcs12 -export -out /tmp/utilityservice-server-cert.pfx -inkey /tmp/utilityservice-server-key.pem -in /tmp/utilityservice-server-cert.pem  -passout "pass:${UTILITYSERVICE_SERVER_CERT_PWD}"
    kubectl create secret generic utilityservice-server-certificate --type=Opaque --from-file=tls.pfx=/tmp/utilityservice-server-cert.pfx
    kubectl create secret generic utilityservice-server-certificate-password --type=Opaque --from-literal=password=$UTILITYSERVICE_SERVER_CERT_PWD
    rm /tmp/utilityservice-server-key.pem /tmp/utilityservice-server-cert.pem /tmp/utilityservice-server-cert.pfx
    unset UTILITYSERVICE_SERVER_CERT_PWD
    ```

#### Prepare image pull secret

The ScanCentral DAST core helm chart by default references its images directly from Docker Hub.  Therefore, to use that default configuration you will need to create an image pull secret and store it in Kubernetes in your installation namespace in order for Kubernetes to properly install your images.

If you are replicating these images to a local repository, you can skip this step and update the relevant image values in the helm chart to reference your local repository.

```bash
kubectl -n <scancentral dast namespace> \
create secret docker-registry docker.io \
--docker-server=registry-1.docker.io \
--docker-username='<docker username>' \ 
--docker-password='<docker password>' \
--docker-email='<docker user email>'
```

### Installing ScanCentral DAST core

The following command installs ScanCentral DAST utilizing recommended defaults for all services.   In some cases, you may find it necessary to customize these values, and may do so either using the 'set' or by creating an values.yaml override file and passing it to the commandline with -f.   For more information about helm overrides, refer to the Helm documentation.

For more information about what values can be overriden, consult the [values](#values) section below.

> Note: These example values presume a database of type 'MS-SQL', with secrets named the same as the examples above. If these values are altered the command line below must be updated accordingly.

```bash
helm upgrade -i oci://registry-1.docker.io/fortifydocker/helm-scancentral-dast-core --version <chart version> --timeout 60m \
-n <scancentral namespace> \
--set imagePullSecrets=docker-registry \
--set appsettings.lIMSettings.limUrl="<https url to LIM service>" \ # Update with your LIM Host/Port
--set appsettings.sSCSettings.sSCRootUrl="<ssc root URL>" \ # Update with your SSC host path
--set database.dboLevelAccountCredentialsSecret=scdast-db-owner \
--set database.standardAccountCredentialsSecret=scdast-db-standard \
--set sscServiceAccountSecretName=scdast-ssc-serviceaccount \
--set serviceTokenSecretName=scdast-service-token \
--set limServiceAccountSecretName=lim-admin-credentials \
--set limDefaultPoolSecretName=lim-pool \
--set api.certificate.certificateSecretName=api-server-certificate \
--set api.certificate.certificateSecretName=api-server-certificate-password \
--set utilityService.certificate.certificateSecretName=api-server-certificate \
--set utilityService.certificate.certificateSecretName=api-server-certificate-password
```

### Special Considerations for testing environments

By default, the helm chart defines the container resource/requests based on recommended
best-practice values intended to prevent performance issues and unexpected Kubernetes evictions of containers and pods.  These values are often too large for a small test environment, that does not require those level of resources. 

To disable these settings, paste the below values into a file called "resource_override.yaml" and add it to the install commandline with the -f flag. (e.g. -f resource_override.yaml")

> WARNING: Using the below settings in production is not supported and will lead to unstable behaviors.

```yaml
# Set all Kubernetes resources except for the datastores to best-effort mode (no resource requirements)
# DO NOT null out the resource configuration for the 'datastore' containers, this will result in unexpected evictions due to how that service allocates memory.
api:
  resources: null

globalService:
  resources: null
 
utilityService:
  resources: 
    requests:
      cpu: null
      memory: null
    limits:
      cpu: null
      memory: null

twofactorauth:
  resources: null

fortifyConnectServer:
  resources: null

upgradeJobs:
  resources: null
  prepJob:
    resources: null
```

## Upgrade

Upgrade helm-scancentral-dast-core chart from previous releases.

- [Preparing for Upgrade](#preparing-for-upgrade)
- [Perform the upgrade](#perform-the-upgrade)

### Preparing for Upgrade

This release of the ScanCentral DAST helm chart has many changes that are not compatible with the previous chart.   However, because all of the state for Scancentral DAST is installed in the database, no data will be lost.

### Perform the upgrade

1. Remove the previous ScanCentral DAST helm deployment.   If you don't remember the release name, you can find it using the following example command.

    ```bash
    helm -n <scancentral namespace> list
    ```

1. Once you have identified the previous ScanCentral DAST installation, uninstall that helm chart.

    ```bash
    helm -n <scancentral namespace> uninstall <release name>
    ```

1. Now perform the steps listed in [Installation](#installation).

## Values

The following values are exposed by the Helm Chart. Unless specified as `Required`, values should only be overridden as made necessary by your specific environment.

### Required

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| api.certificate.certificatePasswordSecretName | Opaque | `""` | The name of the Secret hosting the server certificate password. |
| api.certificate.certificateSecretName | Opaque | `""` | The name of the Secret hosting the server certificate value. |
| appsettings.lIMSettings.limUrl | string | `""` | URL to reach LIM. |
| appsettings.sSCSettings.sSCRootUrl | string | `"http://ssc"` | Root URL for connecting to SSC |
| database.dboLevelAccountCredentialsSecret | kubernetes.io/basic-auth | `""` | Name of the secret hosting Database Owner Level Account credentials. |
| limDefaultPoolSecretName | kubernetes.io/basic-auth | `""` | Name of the secret hosting the LIM Default Pool credentials. |
| limServiceAccountSecretName | kubernetes.io/basic-auth | `""` | Name of the secret hosting the LIM Service Account credentials. |
| serviceTokenSecretName | Opaque | `""` | Name of the secret hosting the Service Token. |
| sscServiceAccountSecretName | kubernetes.io/basic-auth | `""` | Name of the secret hosting the SSC Service Account credentials. |
| utilityService.certificate.certificatePasswordSecretName | Opaque | `""` | The name of the Secret hosting the server certificate password. |
| utilityService.certificate.certificateSecretName | Opaque | `""` | The name of the Secret hosting the server certificate value. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| allowScanScaling | bool | `false` | Enables API and GlobalService Kubernetes roles for Sensor Auto Scaling/Scan Scaling Warning: Setting to 'true' allows arbitrary Kubernetes YAML to be installed via the UI.   Ensure that this function in the UI is appropriately restricted to authorized personnel before enabling. |
| api.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| api.affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| api.certificate.certificatePasswordSecretKey | string | `"password"` | Name of the key that holds the password for unlocking the certificate file. |
| api.certificate.enabled | bool | `true` | Whether to enable TLS server certificate.  When false, http (plain-text) communication will be used. |
| api.certificate.pfxCertSecretKey | string | `"tls.pfx"` | Name of the key that holds the `.pfx` file with both public and private keys. |
| api.containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting API container. |
| api.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| api.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| api.image.repository | string | `"fortifydocker/scancentral-dast-api"` | Repository where to pull docker image from. |
| api.image.tag | string | `"24.2.ubi.8"` | Version of the docker image to pull. |
| api.ingress.annotations | ingress.annotations | `{}` | Annotations to add to resulting resource. |
| api.ingress.className | string | `""` | Ingress resource class name. |
| api.ingress.enabled | bool | `false` | Whether to enable Ingress. |
| api.ingress.hosts[0].host | string | `"dast-api.local"` |  |
| api.ingress.hosts[0].paths[0] | object | `{"path":"/","pathType":"Prefix"}` | Path to accept requests through. |
| api.ingress.hosts[0].paths[0].pathType | string | `"Prefix"` | PathType. |
| api.ingress.tls | list | `[{"hosts":["some-host"],"secretName":"some-name"}]` | Defines TLS configurations. The default shows example configuration values, actual default is `[]`. |
| api.nameOverride | string | `nil` | Custom name to give to the Pod. NOTE: `-api` will be appended by the release. |
| api.nodeSelector | pod.nodeSelector | `kubernetes.io/os: linux` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| api.podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| api.podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| api.podSecurityContext | pod.securityContext | `{}` | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| api.resources | object | `{"limits":{"cpu":"4","memory":"10Gi"},"requests":{"cpu":"4","memory":"5Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| api.service.port | int | `34785` | Port to expose for HTTPS calls. |
| api.service.type | string | `"ClusterIP"` | Service type to use. |
| api.tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
| appsettings.applySecureBase | bool | `true` | Whether to apply SecureBase. |
| appsettings.dASTApiSettings.disableCorsOrigins | bool | `false` | Whether to disable CORS Origins. |
| appsettings.databaseSettings.database | string | `"DAST"` | Name of the database instance |
| appsettings.databaseSettings.databaseProvider | SQLServer | PostgreSQL | AzureSQLServer | AzurePostgreSQL | AmazonRdsPostgreSQL | `"SQLServer"` |  Indicates the type of database that will be used. |
| appsettings.databaseSettings.dboLevelDatabaseAccount.additionalConnectionProperties | []string | `nil` | List of additional connection properties to append to the database connection string. @default "someKey=SomeValue" |
| appsettings.databaseSettings.dboLevelDatabaseAccount.useWindowsAuthentication | bool | `false` | Whether to use Windows Authentication |
| appsettings.databaseSettings.server | string | `"MyServer"` | Name of the database server. |
| appsettings.databaseSettings.standardDatabaseAccount.additionalConnectionProperties | []string | `nil` | List of additional connection properties to append to the database connection string. @default "someKey=SomeValue" |
| appsettings.databaseSettings.standardDatabaseAccount.createLogin | bool | `false` | Whether to create a login for this account. |
| appsettings.disableAdvancedScanPrioritization | bool | `false` | Whether to disable advanced scan prioritization. |
| appsettings.enableRestrictedScanSettings | bool | `false` | Whether to enable restricted scan settings. |
| appsettings.environmentSettings.allowNonTrustedServerCertificate | bool | `false` | Whether to allow non-trusted server certificate. |
| appsettings.environmentSettings.proxySettings.proxyAddress | string | `""` | Proxy server address with `:PORT`. |
| appsettings.environmentSettings.proxySettings.useProxy | bool | `false` | Whether to enable a proxy. |
| appsettings.fortifyConnectServerSettings.disableFortifyConnectServer | bool | `true` | Whether to disable Fortify Connect Server. |
| appsettings.fortifyConnectServerSettings.externalHost | string | `"invalidHost.replaceme.org"` | FortifyConnectServer external host advertised at ScanCentral DAST UI.  Replace with a valid external host name. |
| appsettings.fortifyConnectServerSettings.externalPort | int | `2022` | Port used by Fortify Connect Server externally. |
| appsettings.fortifyConnectServerSettings.internalPort | int | `33467` | Port used by Fortify Connect Server internally. |
| appsettings.retainCompletedScans | bool | `false` | Whether to retain completed scans. |
| appsettings.secureBasePath | string | `nil` | Path to SecureBase definitions. If not blank, you must use a container instance that contains the "DefaultData.zip file" (/app/DefaultData.zip) WARNING: LIM must be up and fully licensed prior to installing this helm chart if the value is blank. |
| appsettings.smartUpdateSettings.licensingUrl | string | `"https://licenseservice.fortify.microfocus.com/"` | URL used for licensing Smart Update. |
| appsettings.smartUpdateSettings.smartUpdateUrl | string | `"https://smartupdate.fortify.microfocus.com/"` | URL used for general Smart Update. |
| appsettings.utilityWorkerServiceSettings | object | `{}` |  |
| commonPodAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). These annotations are added to all Pods deployed in this release. |
| customResources | object | `{"enabled":false,"resources":{}}` | Custom map that lets you define Kubernetes resources you want installed and configured as part of this chart. If you provide any resources, be sure to provide them as quoted using `|`, and set `customResources.enabled` to `true`. |
| customResources.enabled | bool | `false` | Whether to enable custom resource creation. |
| customResources.resources | Kubernetes YAML | `{}` | Custom resources to generate. |
| database.standardAccountCredentialsSecret | kubernetes.io/basic-auth | `""` | Name of the secret hosting Database Owner Level Account credentials. |
| debrickedAccessTokenSecretKey | Opaque | `"access-token"` | Name of the key in the secret hosting the Debricked access token. |
| debrickedAccessTokenSecretName | Opaque | `""` | Name of the secret hosting the Debricked access token. |
| fortifyConnectServer.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| fortifyConnectServer.affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| fortifyConnectServer.containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting API container. |
| fortifyConnectServer.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| fortifyConnectServer.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| fortifyConnectServer.image.repository | string | `"fortifydocker/scancentral-dast-fortifyconnect"` | Repository where to pull docker image from. |
| fortifyConnectServer.image.tag | string | `"24.2.ubi.8"` | Version of the docker image to pull. |
| fortifyConnectServer.nameOverride | string | `nil` | Custom name to give to the Pod. NOTE: `-globalservice` will be appended by the release. |
| fortifyConnectServer.nodeSelector | pod.nodeSelector | `kubernetes.io/os: linux` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| fortifyConnectServer.podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| fortifyConnectServer.podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| fortifyConnectServer.podSecurityContext | pod.securityContext | `{}` | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| fortifyConnectServer.resources | object | `{"limits":{"cpu":"4","memory":"4Gi"},"requests":{"cpu":"4","memory":"4Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| fortifyConnectServer.service.annotations | service.annotations | `{}` | Defines annotations to add to resulting Kubernetes resource. |
| fortifyConnectServer.service.loadBalancerClass | string | `nil` | Required if service type is LoadBalancer. |
| fortifyConnectServer.service.nodePort | string | `nil` | Port to expose on the Node. Required if service type is NodePort. |
| fortifyConnectServer.service.type | ClusterIP | NodePort | LoadBalancer | ExternalName | `"LoadBalancer"` | Service type. |
| fortifyConnectServer.sshKeySecretName | string | `""` | Name of the Secret hosting SSH Key data. |
| fortifyConnectServer.sshPrivateKeySecretKey | string | `"private.key"` | Name of the key in the Secret hosting SSH Private Key data. |
| fortifyConnectServer.sshPublicKeySecretKey | string | `"public.key"` | Name of the key in the Secret hosting SSH Public Key data. |
| fortifyConnectServer.tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
| fullnameOverride | string | `.Release.name` | Overrides the fully qualified app name of the release. |
| globalService.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| globalService.affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| globalService.containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting API container. |
| globalService.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| globalService.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| globalService.image.repository | string | `"fortifydocker/scancentral-dast-globalservice"` | Repository where to pull docker image from. |
| globalService.image.tag | string | `"24.2.ubi.8"` | Version of the docker image to pull. |
| globalService.nameOverride | string | `nil` | Custom name to give to the Pod. NOTE: `-globalservice` will be appended by the release. |
| globalService.nodeSelector | pod.nodeSelector | `kubernetes.io/os: linux` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| globalService.podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| globalService.podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| globalService.podSecurityContext | pod.securityContext | `{}` | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| globalService.resources | object | `{"limits":{"cpu":"4","memory":"4Gi"},"requests":{"cpu":"4","memory":"2Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| globalService.tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
| imagePullSecrets | list | `[]` | list of references to secrets in the same namespace to use for pulling any of the images used by this release. Must be defined if pulling images directly from DockerHub (default) |
| jobmanagementrole.nameOverride | string | `nil` | Enables name override for the job management role |
| nameOverride | string | `.Chart.name` | Overrides the name of this chart. |
| proxyCredentialsSecretName | kubernetes.io/basic-auth | `""` | Name of the secret hosting proxy credentials. |
| serviceTokenSecretKey | Opaque | `"service-token"` | Name of the key in the secret hosting the Service Token. |
| twofactorauth.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| twofactorauth.affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| twofactorauth.containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting API container. |
| twofactorauth.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| twofactorauth.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| twofactorauth.image.repository | string | `"fortifydocker/fortify-2fa"` | Repository where to pull docker image from. |
| twofactorauth.image.tag | string | `"24.2.ubi.8"` | Version of the docker image to pull. |
| twofactorauth.ingress.annotations | ingress.annotations | `{}` | Annotations to add to resulting resource. |
| twofactorauth.ingress.className | string | `""` | Ingress resource class name. |
| twofactorauth.ingress.enabled | bool | `false` | Whether to enable Ingress. |
| twofactorauth.ingress.hosts[0].host | string | `"dast-2fa.local"` |  |
| twofactorauth.ingress.hosts[0].paths[0] | object | `{"path":"/","pathType":"Prefix"}` | Path to accept requests through. |
| twofactorauth.ingress.hosts[0].paths[0].pathType | string | `"Prefix"` | PathType. |
| twofactorauth.ingress.tls | list | `[{"hosts":["some-host"],"secretName":"some-name"}]` | Defines TLS configurations. The default shows example configuration values, actual default is `[]`. |
| twofactorauth.masterTokenSecretKey | string | `"master-token"` | Name of the key in the Secret hosting the Two Factor Authentication master token. |
| twofactorauth.masterTokenSecretName | string | `""` | Name of the Secret hosting the Two Factor Authentication master token. NOTE: Token should be a minimum of 36 characters. |
| twofactorauth.nameOverride | string | `nil` | Custom name to give to the Pod. NOTE: `-2fa` will be added by the release. |
| twofactorauth.nodeSelector | pod.nodeSelector | `kubernetes.io/os: linux` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| twofactorauth.podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| twofactorauth.podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| twofactorauth.podSecurityContext | pod.securityContext | `{}` | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| twofactorauth.resources | object | `{"limits":{"cpu":"16","memory":"64Gi"},"requests":{"cpu":"16","memory":"16Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| twofactorauth.service.port | int | `59752` | Port to expose for HTTPS calls. |
| twofactorauth.service.type | string | `"ClusterIP"` | Service type to use. |
| twofactorauth.tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
| upgradejob.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| upgradejob.affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| upgradejob.containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting API container. |
| upgradejob.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| upgradejob.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| upgradejob.image.repository | string | `"fortifydocker/scancentral-dast-config"` | Repository where to pull docker image from. |
| upgradejob.image.tag | string | `"24.2.ubi.8"` | Version of the docker image to pull. |
| upgradejob.nameOverride | string | `nil` | Custom name to give to the Pod(s). NOTE: `-upgrade-job` will be appended by the release. |
| upgradejob.nodeSelector | pod.nodeSelector | `kubernetes.io/os: linux` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| upgradejob.podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| upgradejob.podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| upgradejob.podSecurityContext | pod.securityContext | `{}` | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| upgradejob.prepJob.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| upgradejob.prepJob.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| upgradejob.prepJob.image.repository | string | `"bitnami/kubectl"` | Repository where to pull docker image from. |
| upgradejob.prepJob.image.tag | string | `"1.28"` | Version of the docker image to pull. |
| upgradejob.prepJob.resources | object | `{"limits":{"cpu":".5","memory":"1Gi"},"requests":{"cpu":".5","memory":"1Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| upgradejob.resources | object | `{"limits":{"cpu":"4","memory":"4Gi"},"requests":{"cpu":"4","memory":"4Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| upgradejob.run | bool | `true` | Whether to run upgrade flow for creation, migration or updates on the backend databases on every helm upgrade. |
| upgradejob.tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
| utilityService.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| utilityService.affinity | pod.affinity | `{}` | Defines Node Affinity configurations to add to resulting Kubernetes Pod(s). |
| utilityService.certificate.certificatePasswordSecretKey | string | `"password"` | Name of the key that holds the password for unlocking the certificate file. |
| utilityService.certificate.enabled | bool | `true` | Whether to enable TLS server certificate.  When false, http (plain-text) communication will be used. |
| utilityService.certificate.pfxCertSecretKey | string | `"tls.pfx"` | Name of the key that holds the `.pfx` file with both public and private keys. |
| utilityService.containerSecurityContext | pod.containers[*].securityContext | `{}` | Defines security context configurations to add to resulting API container. |
| utilityService.datastore.additionalEnvironmentVariables | list | `[]` | Defines any additional environment variables to add to the resulting pod. |
| utilityService.datastore.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| utilityService.datastore.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| utilityService.datastore.image.repository | string | `"mcr.microsoft.com/mssql/server"` | Repository where to pull docker image from. |
| utilityService.datastore.image.tag | string | `"2022-latest"` | Version of the docker image to pull. |
| utilityService.datastore.mssqlStorage.sizeLimit | String | `"1500Mi"` | Sets the maximum size of MSSQL's internal storage.  |
| utilityService.datastore.resources | object | `{"limits":{"cpu":"1","ephemeral-storage":"1500Mi","memory":"4Gi"},"requests":{"cpu":"1","ephemeral-storage":"1500Mi","memory":"4Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| utilityService.image.digest | string | `nil` | Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared. |
| utilityService.image.pullPolicy | string | `"IfNotPresent"` | Image pull behavior. |
| utilityService.image.repository | string | `"fortifydocker/dast-scanner"` | Repository where to pull docker image from. |
| utilityService.image.tag | string | `"24.2.ubi.8"` | Version of the docker image to pull. |
| utilityService.logLevel | string | `""` |  |
| utilityService.nameOverride | string | `nil` | Custom name to give to the Pod. NOTE: `-utilityservice` will be appended by the release. |
| utilityService.nodeSelector | pod.nodeSelector | `kubernetes.io/os: linux` | Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s). |
| utilityService.podAnnotations | pod.annotations | `{}` | Defines annotations to add to resulting Kubernetes Pod(s). |
| utilityService.podLabels | pod.labels | `{}` | Defines labels to add to resulting Kubernetes Pod(s). |
| utilityService.podSecurityContext | pod.securityContext | `{}` | Defines security context configurations to add to resulting Kubernetes Pod(s). |
| utilityService.resources | object | `{"limits":{"cpu":"4","ephemeral-storage":"30Gi","memory":"32Gi"},"requests":{"cpu":"4","ephemeral-storage":"30Gi","memory":"16Gi"}}` | Resource requests (guaranteed resources) and limits for the pod |
| utilityService.scandataStorage.sizeLimit | String | `"15Gi"` | Sets the maximum amount of temporary data that can be stored for a scan.   Must be less than or equal to the amount of ephemeral storage defined.  |
| utilityService.service.port | int | `48756` | Port to expose for HTTPS calls. |
| utilityService.service.type | string | `"ClusterIP"` | Service type to use. |
| utilityService.tolerations | pod.tolerations | `[]` | Defines Toleration configurations to add to resulting Kubernetes Pod(s). |
