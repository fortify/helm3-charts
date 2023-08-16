# Fortify Software Security Center and Fortify ScanCentral SAST/DAST Deployment

This is a deployment example for Fortify Software Security Center (SSC) and Fortify ScanCentral SAST/DAST using minikube. Minikube is a tool that allows you to run a single-node Kubernetes cluster locally. It is useful for developing and testing applications that are designed to run on Kubernetes.

This example is intended to teach you how to do a deployment, but not in a production environment. Emphasis has not been placed on security in this example. Keep in mind that if you are deploying to a production environment, you will need to take additional measures to ensure the security of your system.

## Prerequisites

### Minikube

Install **minikube**: https://minikube.sigs.k8s.io/docs/start/

### Helm

Install **helm**: https://helm.sh/docs/intro/quickstart/

### OpenSSL

You will use OpenSSL (https://www.openssl.org/) to create a self-signed wildcard certificate. You can install OpenSSL using the OS package manager.

### fortify.license file

A working **fortify.license** file for SSC and ScanCentral SAST.

### Docker hub fortifydocker credentials

You need Docker Hub credentials to access private docker images. If you have the images in another registry you will need to configure it manually.

### License and Infrastructure Manager and ScanCentral DAST and WebInspect licenses

ScanCentral DAST requires a working LIM instance with a license pool for WebInspect scanners. Unfortunately, LIM does not currently support Linux, so you cannot install it as part of this deployment.
Follow standard procedures to install and configure LIM on a Windows machine or using Windows containers. **LIM must be accessed in API mode. Using the URL for LIM service will not work.**

### ScanCentral DAST Configuration tool with SecureBase container image

ScanCentral DAST uses a configuration tool to initialize the database. The configuration tool image that is hosted at Docker Hub does not include the SecureBase and does not work to initialize/migrate the database.
You must obtain the image, including the SecureBase, from other channels.

## Environment preparation

### Minikube start

```commandline
minikube start
```

### Enable minikube ingress

You will use an ingress to make our applications accessible. Minikube offers a simple method to deploy an NGINX ingress to the system.

```commandline
minikube addons enable ingress
```

Make note of the IP address for minikube. All ingresses will be reachable there.

```commandline
minikube ip
```

In this document the IP is going to be **192.168.49.2** .

### Certificates

You will create a wildcard self-signed certificate for demo purposes and derive a Java Keystore for SSC.

You will use a technique to resolve domain names in local deployments: **nip.io** allows you to use domain names that resolve to any IP address. You can retrieve the ingress' IP with `minikube ip`. If, for example, the IP is **192.168.49.2**, then **ssc.192-168-49-2.nip.io** and **scsast.192-168-49-2.nip.io** will both resolve to **192.168.49.2**. Using nip.io domain names the browser can reach the right ingress IP.

The certificate will work for all **192-168-49-2.nip.io** subdomains.

First create a directory named **certificates**. From that directory, run:

```commandline
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem -subj "/CN=*.192-168-49-2.nip.io"
```

This command generates two files: **certificate.pem** and **key.pem**. Next, create a kubernetes TLS secret to be used by the ingresses:

```commandline
kubectl create secret tls wildcard-certificate --cert=certificate.pem --key=key.pem
```

You will also generate a Java Key Store for SSC. First, generate a PKCS12 keystore with openssl:

```commandline
openssl pkcs12 -export -name ssc -in certificate.pem -inkey key.pem -out keystore.p12 -password pass:changeme
```

And create the keystore (**ssc-service.jks**) for SSC:

```commandline
keytool -importkeystore -destkeystore ssc-service.jks -srckeystore keystore.p12 -srcstoretype pkcs12 -alias ssc -srcstorepass changeme -deststorepass changeme
```

You will also need a truststore for SSC since it will be accessing ScanCentral Controller at the ingress:

```commandline
keytool -import -trustcacerts -file certificate.pem -alias "wildcard-cert" -keystore truststore -storepass changeme -noprompt
```

### Install MySQL Helm Chart (SSC Database)

SSC supports MySQL, Oracle and MSSQL databases. You will next install MySQL using the official bitnami helm chart:

Install bitnami repo:

```commandline
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Return to the directory that contains the values files and use the mysql-values.yaml file provided to install mysql:

```commandline
helm install mysql bitnami/mysql -f mysql-values.yaml --version 9.3.1
```

If you check the mysql-values.yaml file, notice that you are creating the SSC database automatically during installation using the recommended settings in SSC. For demo purposes, the credentials specified are:

- User: **root**
- Password: **password**

### Install PostgreSQL Helm Chart (ScanCentral DAST Database)

ScanCentral DAST supports PostgreSQL and MSSQL. You'll now install PostgreSQL using the official bitnami chart:

Install bitnami repo (skip if already installed on previous step):

```commandline
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Use this command to install PostgreSQL:

```commandline
helm install postgresql bitnami/postgresql --version 11.9.0 \
  --set auth.postgresPassword=password \
  --set auth.database=scdast_db
```

This installs PostgreSQL and creates a database named **scdast_db** with `postgres/password` credentials.

### Create a Docker Registry Secret
Most of the Fortify docker images can be found in the private Docker Hub repository **fortifydocker**. To pull these images, you need to create a secret with your Docker Hub credentials and name it **fortifydocker**.

```commandline
kubectl create secret docker-registry fortifydocker --docker-username <USERNAME> --docker-password <PASSWORD>
```

### Create SSC secret

SSC requires that you create a secret manually before you install it. You must prepare several files in advance. Create a directory named ssc-secret and copy the following files into it:

- **ssc.autoconfig**

SSC will run in autoconfig mode. The ssc.autoconfig file provides the configuration for that step. Its contents are as follows:

```yaml
appProperties:
  host.validation: false

datasourceProperties:
  db.username: root
  db.password: password

  jdbc.url: 'jdbc:mysql://mysql:3306/ssc_db?sessionVariables=collation_connection=latin1_general_cs&rewriteBatchedStatements=true'

dbMigrationProperties:

  migration.enabled: true
  migration.username: root
  migration.password: password
```

In this case, you provide the JDBC connection string to authenticate to the MySQL database. Autoconfiguration also enables automatic database migration.

- **fortify.license**
- **ssc-service.jks**
- **truststore**

#### Generate the secret

Change from current directory to **ssc-secret** and run:

```commandline
kubectl create secret generic ssc \
  --from-file=. \
  --from-literal=ssc-service.jks.password=changeme \
  --from-literal=ssc-service.jks.key.password=changeme \
  --from-literal=truststore.password=changeme
```

Go back to the previous directory.

## Install Fortify charts

Next, you parameterize the charts using the helm command (you can use the provided values files too).

### Add Fortify Helm repository

```commandline
helm repo add fortify https://fortify.github.io/helm3-charts
```

### Install SSC chart

```commandline
helm install ssc fortify/ssc \
  --set urlHost=ssc.192-168-49-2.nip.io \
  --set imagePullSecrets[0].name=fortifydocker \
  --set secretRef.name=ssc \
  --set secretRef.keys.sscLicenseEntry=fortify.license \
  --set secretRef.keys.sscAutoconfigEntry=ssc.autoconfig \
  --set secretRef.keys.httpCertificateKeystoreFileEntry=ssc-service.jks \
  --set secretRef.keys.httpCertificateKeystorePasswordEntry=ssc-service.jks.password \
  --set secretRef.keys.httpCertificateKeyPasswordEntry=ssc-service.jks.key.password \
  --set secretRef.keys.jvmTruststoreFileEntry=truststore \
  --set secretRef.keys.jvmTruststorePasswordEntry=truststore.password \
  --set resources=null
```

On the first run, SSC initializes the database. This can take several minutes.

We must create an ingress for SSC too:

```commandline
kubectl create ingress ssc-ingress \
  --rule='ssc.192-168-49-2.nip.io/*=ssc-service:443,tls=wildcard-certificate' \
  --annotation nginx.ingress.kubernetes.io/backend-protocol=HTTPS
```

The ingress annotation: `nginx.ingress.kubernetes.io/backend-protocol=HTTPS` indicates that the SSC internal endpoint is using HTTPS. By default, NGINX "expects" the backend endpoints to serve HTTP and cannot communicate if the protocol is HTTPS, unless that annotation is added.

### Install ScanCentral SAST chart

```commandline
helm install scancentral-sast fortify/scancentral-sast  \
  --set imagePullSecrets[0].name=fortifydocker \
  --set-file fortifyLicense=fortify.license \
  --set-file trustedCertificates[0]=certificates/certificate.pem \
  --set controller.thisUrl='https://scsast.192-168-49-2.nip.io/scancentral-ctrl' \
  --set controller.sscUrl='https://ssc.192-168-49-2.nip.io' \
  --set controller.persistence.enabled=false \
  --set controller.ingress.enabled=true \
  --set controller.ingress.hosts[0].host=scsast.192-168-49-2.nip.io \
  --set controller.ingress.hosts[0].paths[0].path=/ \
  --set controller.ingress.hosts[0].paths[0].pathType=Prefix \
  --set controller.ingress.tls[0].secretName=wildcard-certificate \
  --set controller.ingress.tls[0].hosts[0]=scsast.192-168-49-2.nip.io
```

This will output notes to retrieve auto-generated secrets such as the key shared between SSC and the SAST Controller.
Use the following command to retrieve the **SSC and ScanCentral Controller shared secret**:

```commandline
kubectl get secret scancentral-sast -o jsonpath="{.data.scancentral-ssc-scancentral-ctrl-secret}" | base64 -d
```

### SSC and ScanCentral SAST Configuration

Log into https://ssc.192-168-49-2.nip.io with `admin/admin` credentials. Change the default admin password when prompted. In this example, use `Toughpass1!`

At `Administration > Configuration > ScanCentral SAST`, enable ScanCentral SAST, enter **https://scsast.192-168-49-2.nip.io/scancentral-ctrl/** at **Scancentral controller URL** box and **SSC and Scancentral controller shared secret**.

Select `Administration > Configuration > ScanCentral SAST`, and then select Enable ScanCentral SAST. In the ScanCentral Controller URL box, enter **https://scsast.192-168-49-2.nip.io/scancentral-ctrl/**. In the **SSC and ScanCentral controller shared secret** box, enter the shared secret.
After you save the configuration, run the following to restart the SSC pod:

```commandline
kubectl delete pod ssc-webapp-0
```
This deletes the pod and initiates a new one immediately. You should now see the ScanCentral SAST section in SSC.

### Install ScanCentral DAST chart

In order to install ScanCentral DAST, SSC must be running. Before you start the installation, collect the following information:

- SSC URL and credentials.
- LIM API URL and credentials **(The LIM Service URL does not work on with Linux sensors. You must use the LIM API URL)**.
- WebInspect license pool name and password.
- The docker image repository and tag for the config tool with SecureBase. In this example, it is placed in **fortify-docker.svsartifactory.swinfra.net/fortify/dast-config-sb/22.2.0/22.2.0.271-ubi8.6.0:latest** .

```commandline
helm install scancentral-dast fortify/scancentral-dast --timeout 40m \
  --set imagePullSecrets[0].name=fortifydocker \
  --set images.upgradeJob.repository=myregistry/fortify/dast-config-sb/23.1.0/23.1.0.181-ubi8.6.0 \
  --set images.upgradeJob.tag=latest \
  --set configuration.databaseSettings.databaseProvider=PostgreSQL \
  --set configuration.databaseSettings.server=postgresql \
  --set configuration.databaseSettings.database=scdast_db \
  --set configuration.databaseSettings.dboLevelDatabaseAccount.username=postgres \
  --set configuration.databaseSettings.dboLevelDatabaseAccount.password=password \
  --set configuration.databaseSettings.standardDatabaseAccount.username=postgres \
  --set configuration.databaseSettings.standardDatabaseAccount.password=password \
  --set configuration.serviceToken=thisisaservicetoken \
  --set configuration.sSCSettings.sSCRootUrl=https://ssc.192-168-49-2.nip.io \
  --set configuration.sSCSettings.serviceAccountUserName=admin \
  --set configuration.sSCSettings.serviceAccountPassword=<SSC_ADMIN_PASSWORD> \
  --set configuration.dASTApiSettings.corsOrigins[0]=https://ssc.192-168-49-2.nip.io \
  --set configuration.dASTApiSettings.corsOrigins[1]=https://scdastapi.192-168-49-2.nip.io \
  --set configuration.lIMSettings.limUrl=<LIM_API_URL> \
  --set configuration.lIMSettings.serviceAccountUserName=<LIM_ADMIN_USER> \
  --set configuration.lIMSettings.serviceAccountPassword=<LIM_ADMIN_PASSWORD> \
  --set configuration.lIMSettings.defaultLimPoolName=<LIM_POOL_NAME> \
  --set configuration.lIMSettings.defaultLimPoolPassword=<LIM_POOL_PASSWORD> \
  --set configuration.lIMSettings.useLimRestApi=true \
  --set ingress.api.enabled=true \
  --set ingress.api.hosts[0].host=scdastapi.192-168-49-2.nip.io \
  --set ingress.api.hosts[0].paths[0].path=/ \
  --set ingress.api.hosts[0].paths[0].pathType=Prefix \
  --set ingress.api.tls[0].secretName=wildcard-certificate \
  --set ingress.api.tls[0].hosts[0]=scdastapi.192-168-49-2.nip.io
```

Notice the `--timeout 40m` argument. The ScanCentral DAST Helm chart uses Helm hooks to run the configuration tool to initialize, migrate and apply the configuration to the database. This happens before anything is deployed. Helm has a 10-minute timeout for hooks to complete, but DAST database initialization takes around 30 minutes. That is why you use the `--timeout` argument.

### ScanCentral DAST Configuration at SSC

In SSC, select `Administration > Configuration > ScanCentral DAST`. In the ScanCentral Controller URL box, enter **https://scdastapi.192-168-49-2.nip.io** . This enables the DAST section in SSC.
