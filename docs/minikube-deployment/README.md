# SSC and ScanCentral SAST/DAST deployment

This is a deployment example for SSC and ScanCentral SAST using Minikube. Minikube is a tool that allows you to run a single-node Kubernetes cluster locally. It is useful for developing and testing applications that are designed to run on Kubernetes.

This example is intended to teach you how to do a deployment, but it is not intended to be a production environment. Emphasis has not been placed on security in this example. Keep in mind that if you are deploying to a production environment, you will need to take additional measures to ensure the security of your system.

## Prerequisites

### Minikube

Install **minikube**: https://minikube.sigs.k8s.io/docs/start/

### Helm

Install **helm**: https://helm.sh/docs/intro/quickstart/

### OpenSSL

We will use OpenSSL (https://www.openssl.org/) to create a self-signed wildcard certificate. You can probably install OpenSSL using OS's package manager.

### fortify.license file

A working **fortify.license** file for SSC and ScanCentral SAST.

### Docker hub fortifydocker credentials

We need Docker Hub credentials to access private docker images. If you have the images in another registry you will need to configure it manually.

### License and Infrastructure Manager and ScanCentral DAST and WebInspect licenses

ScanCentral DAST requires a working LIM instance with a license pool for WebInspect scanners. Unfortunately LIM does not support linux at this moment and we cannot install it as part of this deployment.
Follow standard procedures to install and configure LIM on a Windows machine or using Windows containers. **LIM must be accessed in API mode, using LIM service's URL will not work.**

### ScanCentral DAST Configuration tool with SecureBase container image

ScanCentral DAST uses a configuration tool to initialize the database. The configuration tool image that is hosted at Docker Hub does not include the SecureBase and does not work to initialize/migrate the database.
You must obtain the image including the SecureBase from other channels.

## Environment preparation

### Minikube start

```commandline
$ minikube start
```

### Enable minikube ingress

We will use an ingress to make our applications accessible. Minikube offers a simple method to deploy an NGINX ingress to the system.

```commandline
$ minikube addons enable ingress
```

Take note of minikube's IP as all the ingresses will be reachable there.

```commandline
$ minikube ip
```

### Certificates

We will create a wildcard self-signed certificate for demo purposes and derive a Java Keystore for SSC.

We are going to use a technique to be able to resolve domain names in local deployments:
**nip.io** allows us to use domain names that resolve to any IP we want. We have retrieved ingress' IP with
`minikube ip`. For example, if that IP is **192.168.49.2**, **ssc.192-168-49-2.nip.io** and **scsast.192-168-49-2.nip.io** will both resolve to **192.168.49.2**.
Using this kind of domain names both internal components and browser will be able to reach the right ingress IP.

The certificate will work for all **192-168-49-2.nip.io** subdomains.

First create a directory called **certificates**. At that directory, run:

```commandline
$ openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem -subj "/CN=*.192-168-49-2.nip.io"
```

This command will generate two files: **certificate.pem** and **key.pem**. Now we create a kubernetes TLS secret to be used by the ingresses:

```commandline
$ kubectl create secret tls wildcard-certificate --cert=certificate.pem --key=key.pem
```

We will also generate a Java Key Store for SSC. First we generate a PKCS12 keystore with openssl:

```commandline
$ openssl pkcs12 -export -name ssc -in certificate.pem -inkey key.pem -out keystore.p12 -password pass:changeme
```

And create the keystore (**ssc-service.jks**) for SSC:

```commandline
$ keytool -importkeystore -destkeystore ssc-service.jks -srckeystore keystore.p12 -srcstoretype pkcs12 -alias ssc -srcstorepass changeme -deststorepass changeme
```

We will also need a truststore for SSC as it will be accessing Scancentral controller at the ingress:

```commandline
$ keytool -import -trustcacerts -file certificate.pem -alias "wildcard-cert" -keystore truststore -storepass changeme -noprompt
```

### Install MySQL Helm Chart (SSC Database)

SSC supports MySQL, Oracle and MSSQL databases. We are going to install MySQL using the official bitnami helm chart:

Install bitnami repo:

```commandline
$ helm repo add bitnami https://charts.bitnami.com/bitnami
```

Go back to the directory with the values files. Use the provided mysql-values.yaml file to install mysql:

```commandline
$ helm install mysql bitnami/mysql -f mysql-values.yaml --version 9.3.1
```

If you check mysql-values.yaml you will notice that we are creating a SSC DB automatically during the installation with the recommended settings by SSC.
For demo purposes, the credentials specified are:

- User: **root**
- Password: **password**

### Install PostgreSQL Helm Chart (ScanCentral DAST Database)

ScanCentral DAST supports PostgreSQL and MSSQL. We are going to install PostgreSQL using the official bitnami chart:

Install bitnami repo (skip if already installed on previous step):

```commandline
$ helm repo add bitnami https://charts.bitnami.com/bitnami
```

Use this command to install PostgreSQL:

```commandline
$ helm install postgresql bitnami/postgresql --version 11.9.0 \
  --set auth.postgresPassword=password \
  --set auth.database=scdast_db
```

It installs PostgreSQL and creates a database called **scdast_db** with `postgres/password` credentials.

### Create a Docker Registry Secret
Most of the Fortify docker images can be found in the private Docker Hub repository **fortifydocker**. To pull these images, you need to create a secret with your Docker Hub credentials and name it **fortifydocker**.

```commandline
$ kubectl create secret docker-registry fortifydocker --docker-username <USERNAME> --docker-password <PASSWORD>
```

### Create SSC secret

SSC chart requires to create a secret manually before installing. We must prepare several files in advance. Create a directory called **ssc-secret** and place these files:

- **ssc.autoconfig**

SSC will run in autoconfig mode. This file provides the configuration for that step.
These are the contents of the file:

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

In this case we provide the JDBC connection string to authenticate to the MySQL database. It also enables the automated migration of the DB.

- **fortify.license**

Copy fortify.license file to this directory.

- **ssc-service.jks**

Copy ssc-service.jks to the directory.

- **truststore**

Copy truststore file to the directory.

#### Generate the secret

Change directory to **ssc-secret** and run:

```commandline
$ kubectl create secret generic ssc \
  --from-file=. \
  --from-literal=ssc-service.jks.password=changeme \
  --from-literal=ssc-service.jks.key.password=changeme \
  --from-literal=truststore.password=changeme
```

Go back to the previous directory.

## Install Fortify charts

We will parametrize the charts using the helm command, but it is possible to use the provided values files too.

### Add Fortify Helm repository

```commandline
$ helm repo add fortify https://fortify.github.io/helm3-charts
```

### Install SSC chart

```commandline
$ helm install ssc fortify/ssc --version 1.1.2220176 \
  --set urlHost=ssc.192-168-49-2.nip.io \
  --set imagePullSecrets[0].name=fortifydocker \
  --set secretRef.name=ssc \
  --set secretRef.keys.sscLicenseEntry=fortify.license \
  --set secretRef.keys.sscAutoconfigEntry=ssc.autoconfig \
  --set secretRef.keys.httpCertificateKeystoreFileEntry=ssc-service.jks \
  --set secretRef.keys.httpCertificateKeystorePasswordEntry=ssc-service.jks.password \
  --set secretRef.keys.httpCertificateKeyPasswordEntry=ssc-service.jks.key.password \
  --set secretRef.keys.jvmTruststoreFileEntry=truststore \
  --set secretRef.keys.jmvTruststorePasswordEntry=truststore.password \
  --set resources=null
```

On the first run, SSC will initialize the database. It can take several minutes before SSC is ready.

We must create an ingress for SSC too:

```commandline
$ kubectl create ingress ssc-ingress \
  --rule='ssc.192-168-49-2.nip.io/*=ssc-service:443,tls=wildcard-certificate' \
  --annotation nginx.ingress.kubernetes.io/backend-protocol=HTTPS
```

Notice the ingress annotation: `nginx.ingress.kubernetes.io/backend-protocol=HTTPS`. It means that the SSC internal endpoint is using HTTPS. By default, NGINX expects the backend endpoints to serve HTTP and will not be able to communicate if the protocol is HTTPS unless that annotation is added.

### Install ScanCentral SAST chart

```commandline
$ helm install scancentral-sast fortify/scancentral-sast --version 22.2.0 \
  --set imagePullSecrets[0].name=fortifydocker \
  --set-file fortifyLicense=fortify.license \
  --set controller.thisUrl='https://scsast.192-168-49-2.nip.io/scancentral-ctrl' \
  --set controller.sscUrl='https://ssc.192-168-49-2.nip.io' \
  --set-file controller.trustedCertificates[0]=certificates/certificate.pem \
  --set controller.persistence.enabled=false \
  --set controller.ingress.enabled=true \
  --set controller.ingress.hosts[0].host=scsast.192-168-49-2.nip.io \
  --set controller.ingress.hosts[0].paths[0].path=/ \
  --set controller.ingress.hosts[0].paths[0].pathType=Prefix \
  --set controller.ingress.tls[0].secretName=wildcard-certificate \
  --set controller.ingress.tls[0].hosts[0]=scsast.192-168-49-2.nip.io
```

This will output Notes to retrieve auto-generated secrets like the shared key between SSC and SAST Controller.

Use this command to retrieve **SSC and Scancentral controller shared secret**:

```commandline
$ kubectl get secret scancentral-sast -o jsonpath="{.data.scancentral-ssc-scancentral-ctrl-secret}" | base64 -d
```

### SSC and ScanCentral SAST Configuration

Log into https://ssc.192-168-49-2.nip.io with `admin/admin` credentials. Change the default admin password when requested. In this example we will use `Toughpass1!`

At `Administration > Configuration > ScanCentral SAST`, enable ScanCentral SAST, enter **https://scsast.192-168-49-2.nip.io/scancentral-ctrl/** at **Scancentral controller URL** box and **SSC and Scancentral controller shared secret**.

SSC pod needs to be restarted after this configuration change. Run:

```commandline
$ kubectl delete pod ssc-webapp-0
```

This will delete the pod and a new one will be started right after. You should be able to see the Scancentral SAST section at SSC now.

### Install ScanCentral DAST chart

In order to install ScanCentral DAST, SSC must be running. Prepare the following information in order to install it:

- SSC URL and credentials.
- LIM API URL and credentials. Also, the WebInspect license pool name and password. **It is important to use a LIM API URL**. LIM Service URL does not work on with Linux sensors.
- The docker image repository and tag for the config tool with SecureBase. In the example it is placed at **fortify-docker.svsartifactory.swinfra.net/fortify/dast-config-sb/22.2.0/22.2.0.271-ubi8.6.0:latest** .

```commandline
$ helm install scancentral-dast fortify/scancentral-dast --version 22.2.0 --timeout 40m \
  --set imagePullSecrets[0].name=fortifydocker \
  --set images.upgradeJob.repository=fortify-docker.svsartifactory.swinfra.net/fortify/dast-config-sb/22.2.0/22.2.0.271-ubi8.6.0 \
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

Notice the `--timeout 40m` argument. Scancentral DAST helm chart uses helm hooks to run the configuration tool to initialize, migrate and apply the configuration to the database. This happens before anything is deployed. Helm has a 10 minute timeout for hooks to complete but DAST DB initialization takes around 30 minutes. That is why we use the `--timeout` argument.

### ScanCentral DAST Configuration at SSC

At `Administration > Configuration > ScanCentral DAST`, enter **https://scdastapi.192-168-49-2.nip.io**.
This will enable the DAST section in SSC.