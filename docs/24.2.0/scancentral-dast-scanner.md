# helm-scancentral-dast-scanner

A Helm chart for ScanCentral DAST Scanner applications and infrastructure.

![Version: 24.2.0](https://img.shields.io/badge/Version-24.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 24.2.0](https://img.shields.io/badge/AppVersion-24.2.0-informational?style=flat-square)

## Tested On

- ![Kubernetes: v1.28](https://img.shields.io/badge/kubernetes-v1.28-green?style=flat-square)

## Table of Contents

- [Tool Prerequisites](#tool-prerequisites)
- [Installation](#installation)
- [Upgrade](#upgrade)
- [Configurable values](#values)
  - [Required values](#required)
  - [Recommended values](#optional-but-recommended)
  - [Other values](#other-values)

## Tool Prerequisites

These instructions were written and tested using the following tool versions.   It is recommended that the same tool versions be used in order to avoid unpredictable results.

- [kubectl v1.28.7](https://kubernetes.io/docs/reference/kubectl/)
- [helm v3.12.2](https://helm.sh/)

## Installation

> NOTE: The following instructions are for example purposes and are based on a Minikube environment and Linux system.
> Windows systems may require different syntax for certain commands and other Kubernetes Cluster providers may require additional/different configurations.

- [Prepare for installation](#prepare-for-installation)
  - [Ensure ScanCentral DAST Core Services are installed](#ensure-scancentral-dast-core-services-are-installed)
  - [Retrieve core configuration properties](#retrieve-core-configuration-properties)
  - [Ensure image pull secret](#ensure-image-pull-secret)
- [Installing ScanCentral DAST scanner](#installing-scancentral-dast-scanner)

### Prepare for installation

#### Ensure ScanCentral DAST Core Services are installed

Ensure that the ScanCentral DAST core services have been installed and are at the same helm chart revision as this chart prior to installation.

#### Retrieve core configuration properties

1. Run the command following command to get the relevant configuration values needed to populate core services values in this helm chart.

    ```bash
    helm -n <scancentral namespace> get notes <name of scancentral-dast-core release>
    ```

    The values needed are:
    - DAST API service URL (You can obtain this by running 'helm get notes' against the already-deployed scancentral-dast-core helm release.
    - DAST API service account token secret name, previously created during the helm scancentral-dast-core deployment.

#### Ensure image pull secret

If you are utilizing your docker images directly from Docker Hub, ensure that you have the name of your image pull secret ready to provide to the helm configuration.   It should be the same configuration created to install the helm-scancentral-dast-core helm chart.

### Installing ScanCentral DAST scanner

The following command installs ScanCentral DAST utilizing recommended defaults for all services.   In some cases, you may find it necessary to customize these values, and may do so either using the 'set' or by creating an values.yaml override file and passing it to the commandline with -f.   For more information about helm overrides, refer to the Helm documentation. 

For more information about what values can be overriden, consult the 'values' section below.

> Note: These example values presume the default naming referenced in both this and the helm-scancentral-dast-core helm charts.

```bash
helm upgrade -i oci://registry-1.docker.io/fortifydocker/helm-scancentral-dast-scanner --version <chart version> --timeout 60m \
-n <scancentral namespace> \
--set dastApiServiceURL=<URL of the SC-DAST API service> \
--set serviceTokenSecretName=scdast-service-token
```

### Special Considerations for testing environments

By default, the helm chart defines the container resource/requests based on recommended
best-practice values intended to prevent performance issues and unexpected Kubernetes evictions of containers and pods.  These values are often too large for a small test environment, that does not require those level of resources. 

To disable these settings, paste the below values into a file called "resource_override.yaml" and add it to the install commandline with the -f flag. (e.g. -f resource_override.yaml")

> WARNING: Using the below settings in production is not supported and will lead to unstable behaviors.

```yaml
# Set all Kubernetes resources except for the datastores to best-effort mode (no resource requirements)
# DO NOT null out the resource configuration for the 'datastore' containers, this will result in unexpected evictions due to how that service allocates memory.
resources:
  requests:
    cpu: null
    memory: null
  limits:
    cpu: null
    memory: null
wise:
  resources: null
```

## Upgrade

Upgrade helm-scancentral-dast-scanner chart from previous releases

- [Preparing for Upgrade](#preparing-for-upgrade)
- [Perform the upgrade](#perform-the-upgrade)

### Upgrades not applicable for this release

This helm chart does not have a prior version, therefore upgrades are not applicable.  Please reference the steps for  [Installation](#installation).

## Values

The following values are exposed by the Helm Chart. Unless specified as `Required`, values should only be overridden as made necessary by your specific environment.

<table>
	<thead>
		<th>Key</th>
		<th>Type</th>
		<th>Default</th>
		<th>Description</th>
	</thead>
	<tbody>
		<tr>
			<td>additionalEnvironmentVariables</td>
			<td>list</td>
			<td><pre lang="json">
[]
</pre>
</td>
			<td>Defines any additional environment variables to add to the resulting pod.</td>
		</tr>
		<tr>
			<td>affinity</td>
			<td>pod.affinity</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Defines Node Affinity configurations to add to resulting Kubernetes Pod(s).</td>
		</tr>
		<tr>
			<td>allowNonTrustedServerCertificate</td>
			<td>bool</td>
			<td><pre lang="json">
false
</pre>
</td>
			<td>Whether to allow non-trusted Server certificate. NOTE: If Fortify Connect is in use, this must be set to `true`</td>
		</tr>
		<tr>
			<td>containerSecurityContext</td>
			<td>pod.containers[*].securityContext</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Defines security context configurations to add to resulting API container.</td>
		</tr>
		<tr>
			<td>customResources</td>
			<td>object</td>
			<td><pre lang="json">
{
  "enabled": false,
  "resources": {}
}
</pre>
</td>
			<td>Custom map that lets you define Kubernetes resources you want installed and configured as part of this chart. If you provide any resources, be sure to provide them as quoted using `|`, and set `customResources.enabled` to `true`.</td>
		</tr>
		<tr>
			<td>customResources.enabled</td>
			<td>bool</td>
			<td><pre lang="json">
false
</pre>
</td>
			<td>Whether to enable custom resource creation.</td>
		</tr>
		<tr>
			<td>customResources.resources</td>
			<td>Kubernetes YAML</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Custom resources to generate.</td>
		</tr>
		<tr>
			<td>dastApiServiceURL</td>
			<td>string</td>
			<td><pre lang="json">
""
</pre>
</td>
			<td>URL of the ScanCentral DAST API service . Used to reach ScanCentral DAST API over HTTP/HTTPS.  To find out how to retrieve this value, run 'helm get notes <name of scancentral-dast-core release>'</td>
		</tr>
		<tr>
			<td>datastore.additionalEnvironmentVariables</td>
			<td>list</td>
			<td><pre lang="json">
[]
</pre>
</td>
			<td>Defines any additional environment variables to add to the resulting pod.</td>
		</tr>
		<tr>
			<td>datastore.image.digest</td>
			<td>string</td>
			<td><pre lang="json">
null
</pre>
</td>
			<td>Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared.</td>
		</tr>
		<tr>
			<td>datastore.image.pullPolicy</td>
			<td>string</td>
			<td><pre lang="json">
"IfNotPresent"
</pre>
</td>
			<td>Image pull behavior.</td>
		</tr>
		<tr>
			<td>datastore.image.repository</td>
			<td>string</td>
			<td><pre lang="json">
"mcr.microsoft.com/mssql/server"
</pre>
</td>
			<td>Repository where to pull docker image from.</td>
		</tr>
		<tr>
			<td>datastore.image.tag</td>
			<td>string</td>
			<td><pre lang="json">
"2022-latest"
</pre>
</td>
			<td>Version of the docker image to pull.</td>
		</tr>
		<tr>
			<td>datastore.mssqlStorage.sizeLimit</td>
			<td>String</td>
			<td><pre lang="json">
"1500Mi"
</pre>
</td>
			<td>Sets the maximum size of MSSQL's internal storage.   </td>
		</tr>
		<tr>
			<td>datastore.resources</td>
			<td>object</td>
			<td><pre lang="json">
{
  "limits": {
    "cpu": "1",
    "ephemeral-storage": "1500Mi",
    "memory": "4Gi"
  },
  "requests": {
    "cpu": "1",
    "ephemeral-storage": "1500Mi",
    "memory": "4Gi"
  }
}
</pre>
</td>
			<td>Resource requests (guaranteed resources) and limits for the pod            </td>
		</tr>
		<tr>
			<td>disableAdvancedScanPrioritization</td>
			<td>bool</td>
			<td><pre lang="json">
false
</pre>
</td>
			<td>Whether to disable advanced scan prioritization.</td>
		</tr>
		<tr>
			<td>enableRestrictedScanSettings</td>
			<td>bool</td>
			<td><pre lang="json">
false
</pre>
</td>
			<td>Whether to enable restricted scan settings.</td>
		</tr>
		<tr>
			<td>fullnameOverride</td>
			<td>string</td>
			<td><pre lang="json">
null
</pre>
</td>
			<td>Overrides the fully qualified app name of the release.</td>
		</tr>
		<tr>
			<td>image.digest</td>
			<td>string</td>
			<td><pre lang="json">
null
</pre>
</td>
			<td>Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared.</td>
		</tr>
		<tr>
			<td>image.pullPolicy</td>
			<td>string</td>
			<td><pre lang="json">
"IfNotPresent"
</pre>
</td>
			<td>Image pull behavior.</td>
		</tr>
		<tr>
			<td>image.repository</td>
			<td>string</td>
			<td><pre lang="json">
"fortifydocker/dast-scanner"
</pre>
</td>
			<td>Repository where to pull docker image from.</td>
		</tr>
		<tr>
			<td>image.tag</td>
			<td>string</td>
			<td><pre lang="json">
"24.2.ubi.8"
</pre>
</td>
			<td>Version of the docker image to pull.</td>
		</tr>
		<tr>
			<td>imagePullSecrets</td>
			<td>list</td>
			<td><pre lang="json">
[]
</pre>
</td>
			<td>List of references to secrets in the same namespace to use for pulling any of the images used by this release.</td>
		</tr>
		<tr>
			<td>nameOverride</td>
			<td>string</td>
			<td><pre lang="json">
null
</pre>
</td>
			<td>Overrides the name of this chart.</td>
		</tr>
		<tr>
			<td>nodeSelector</td>
			<td>pod.nodeSelector</td>
			<td><pre lang="json">
null
</pre>
</td>
			<td>Defines Node selection constraint configurations to add to resulting Kubernetes Pod(s).</td>
		</tr>
		<tr>
			<td>podAnnotations</td>
			<td>pod.annotations</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Defines annotations to add to resulting Kubernetes Pod(s).</td>
		</tr>
		<tr>
			<td>podLabels</td>
			<td>pod.labels</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Defines labels to add to resulting Kubernetes Pod(s).</td>
		</tr>
		<tr>
			<td>podSecurityContext</td>
			<td>pod.securityContext</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Defines security context configurations to add to resulting Kubernetes Pod(s).</td>
		</tr>
		<tr>
			<td>replicas</td>
			<td>int</td>
			<td><pre lang="json">
1
</pre>
</td>
			<td>Number of Pod(s) to deploy.</td>
		</tr>
		<tr>
			<td>resources.limits.cpu</td>
			<td>string</td>
			<td><pre lang="json">
"7"
</pre>
</td>
			<td>Maximum compute of pod.  MUST match value used for request.</td>
		</tr>
		<tr>
			<td>resources.limits.ephemeral-storage</td>
			<td>string</td>
			<td><pre lang="json">
"30Gi"
</pre>
</td>
			<td>Maximum amount of storage space available to datastore before pod is evicted.</td>
		</tr>
		<tr>
			<td>resources.limits.memory</td>
			<td>string</td>
			<td><pre lang="json">
"32Gi"
</pre>
</td>
			<td>Maximum memory that can be consumed prior to pod eviction. </td>
		</tr>
		<tr>
			<td>resources.requests.cpu</td>
			<td>string</td>
			<td><pre lang="json">
"7"
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>resources.requests.ephemeral-storage</td>
			<td>string</td>
			<td><pre lang="json">
"30Gi"
</pre>
</td>
			<td>Guaranteed amount of storage space allocated to datastore.</td>
		</tr>
		<tr>
			<td>resources.requests.memory</td>
			<td>string</td>
			<td><pre lang="json">
"16Gi"
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>retainCompletedScans</td>
			<td>bool</td>
			<td><pre lang="json">
false
</pre>
</td>
			<td>Whether to retain completed scans.</td>
		</tr>
		<tr>
			<td>scandataStorage.sizeLimit</td>
			<td>String</td>
			<td><pre lang="json">
"15Gi"
</pre>
</td>
			<td>Sets the maximum amount of temporary data that can be stored for a scan.   Must be less than or equal to the amount of ephemeral storage defined.</td>
		</tr>
		<tr>
			<td>scannerDescription</td>
			<td>string</td>
			<td><pre lang="json">
""
</pre>
</td>
			<td>ScannerDescription to add to Scanner container environment.</td>
		</tr>
		<tr>
			<td>scannerPoolID</td>
			<td>string</td>
			<td><pre lang="json">
"0"
</pre>
</td>
			<td>Scanner pool ID.</td>
		</tr>
		<tr>
			<td>scannerType</td>
			<td>string</td>
			<td><pre lang="json">
"Fixed"
</pre>
</td>
			<td>ScannerType to add to Scanner container environment.</td>
		</tr>
		<tr>
			<td>serviceTokenSecretKey</td>
			<td>string</td>
			<td><pre lang="json">
"service-token"
</pre>
</td>
			<td>Name of the Key in the Secret hosting the Service Token.</td>
		</tr>
		<tr>
			<td>serviceTokenSecretName</td>
			<td>Opaque</td>
			<td><pre lang="json">
""
</pre>
</td>
			<td>Name of the Secret hosting the Service Token.</td>
		</tr>
		<tr>
			<td>tolerations</td>
			<td>pod.tolerations</td>
			<td><pre lang="json">
[]
</pre>
</td>
			<td>Defines Toleration configurations to add to resulting Kubernetes Pod(s).</td>
		</tr>
		<tr>
			<td>topologySpreadConstraints</td>
			<td>pod.topologySpreadConstraints</td>
			<td><pre lang="json">
{}
</pre>
</td>
			<td>Defines how Pods are spread across your cluster among failure-domains such as regions, zones, nodes, and other user-defined topology domains.</td>
		</tr>
		<tr>
			<td>wise.additionalEnvironmentVariables</td>
			<td>list</td>
			<td><pre lang="json">
[]
</pre>
</td>
			<td>Defines any additional environment variables to add to the resulting pod.</td>
		</tr>
		<tr>
			<td>wise.image.digest</td>
			<td>string</td>
			<td><pre lang="json">
null
</pre>
</td>
			<td>Version of the docker image to pull in digest format. Takes precedence over image.tag, if both declared.</td>
		</tr>
		<tr>
			<td>wise.image.pullPolicy</td>
			<td>string</td>
			<td><pre lang="json">
"IfNotPresent"
</pre>
</td>
			<td>Image pull behavior.</td>
		</tr>
		<tr>
			<td>wise.image.repository</td>
			<td>string</td>
			<td><pre lang="json">
"fortifydocker/wise"
</pre>
</td>
			<td>Repository where to pull docker image from.</td>
		</tr>
		<tr>
			<td>wise.image.tag</td>
			<td>string</td>
			<td><pre lang="json">
"24.2.ubi.8"
</pre>
</td>
			<td>Version of the docker image to pull.</td>
		</tr>
		<tr>
			<td>wise.resources.limits.cpu</td>
			<td>string</td>
			<td><pre lang="json">
"8"
</pre>
</td>
			<td>Maximum compute of pod.  MUST match value used for request.</td>
		</tr>
		<tr>
			<td>wise.resources.limits.memory</td>
			<td>string</td>
			<td><pre lang="json">
"64Gi"
</pre>
</td>
			<td>Maximum memory that can be consumed prior to pod eviction.</td>
		</tr>
		<tr>
			<td>wise.resources.requests.cpu</td>
			<td>string</td>
			<td><pre lang="json">
"8"
</pre>
</td>
			<td>Compute that K8s sets aside and guarantees availability</td>
		</tr>
		<tr>
			<td>wise.resources.requests.memory</td>
			<td>string</td>
			<td><pre lang="json">
"16Gi"
</pre>
</td>
			<td>Memory that K8s sets aside and guarantees availability</td>
		</tr>
	</tbody>
</table>

