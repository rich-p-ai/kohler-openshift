# Registry Policy Component

This component configures cluster-wide image registry policies for OpenShift.

## What it does

- **Allowed Registries**: Defines which registries pods can pull images from
- **Trusted CA**: Configures additional CA certificates for external registries
- **Insecure Registries**: Allows HTTP (non-HTTPS) registries if needed

## Registries Allowed

- `kohler-registry-quay-quay.apps.ocp-host.kohlerco.com` - Internal Quay registry
- `registry.kohlerco.com` - Kohler internal registry
- `quay.apps.ocp.kohlerco.com` - Legacy Quay instance
- `quay.kohlerco.com` - Kohler Quay
- `quay.io` - Red Hat Quay public
- `registry.redhat.io` - Red Hat registry
- `image-registry.openshift-image-registry.svc:5000` - OpenShift internal registry
- `docker.io` - Docker Hub
- `kohlercitregistry.azurecr.io` - Azure Container Registry

## Configuration

### Adding CA Certificates

If your external registries use custom CA certificates, add them to `registry-ca-configmap.yaml`:

```yaml
data:
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    # Your CA certificate content
    -----END CERTIFICATE-----
```

### Adding New Registries

Add new registry hostnames to the `allowedRegistries` list in `image-cluster.yaml`.

## Deployment

This component is deployed via ArgoCD with sync wave 5, ensuring it's applied after core infrastructure but before applications that need to pull images.

## Troubleshooting

### Image Pull Errors

If pods fail to pull images:

1. Check if the registry is in the allowed list:
   ```bash
   oc get image.config.openshift.io/cluster -o jsonpath='{.spec.registrySources.allowedRegistries}'
   ```

2. Verify CA trust is configured:
   ```bash
   oc get image.config.openshift.io/cluster -o jsonpath='{.spec.additionalTrustedCA.name}'
   oc -n openshift-config get cm registry-config
   ```

3. Check pod events for specific error messages:
   ```bash
   oc describe pod <pod-name>
   ```

### Common Errors

- **"registry not allowed"**: Add the registry to `allowedRegistries`
- **"x509: certificate signed by unknown authority"**: Add the CA to the ConfigMap
- **"unauthorized"**: Ensure proper image pull secrets are configured in the namespace
