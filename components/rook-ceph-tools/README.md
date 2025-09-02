# Rook Ceph Tools

This component deploys the Rook Ceph tools container that provides debugging and monitoring capabilities for Ceph clusters managed by OpenShift Data Foundation (ODF).

## Purpose

The rook-ceph-tools deployment provides:

- **Ceph CLI Tools**: Direct access to `ceph`, `rados`, `rbd`, and other Ceph command-line utilities
- **Cluster Diagnostics**: Tools for troubleshooting Ceph cluster health and performance issues
- **RADOS Gateway Admin**: `radosgw-admin` for managing object storage
- **Debugging Environment**: A persistent container for running Ceph diagnostic commands

## Usage

### Accessing the Tools

```bash
# Get the pod name
oc get pods -n openshift-storage -l app=rook-ceph-tools

# Exec into the tools container
oc rsh -n openshift-storage deployment/rook-ceph-tools
```

### Common Commands

Once inside the container, you can run:

```bash
# Check cluster status
ceph status

# Check cluster health
ceph health detail

# View OSD tree
ceph osd tree

# Check placement group status
ceph pg stat

# Check monitor status
ceph mon stat

# View cluster utilization
ceph df

# RBD operations
rbd list

# RADOS Gateway operations
radosgw-admin bucket list
```

## Deployment Details

- **Namespace**: openshift-storage
- **Replicas**: 1
- **Image**: Uses the same Ceph image as the cluster for compatibility
- **Resources**: Minimal resource requirements (128Mi memory, 100m CPU)
- **Affinity**: Runs on storage nodes when available
- **Security**: Non-root user, minimal privileges, dropped capabilities

## Troubleshooting

### Pod Not Running

1. Check Ceph cluster health:
   ```bash
   oc get cephcluster -n openshift-storage
   oc describe cephcluster -n openshift-storage
   ```

2. Check storage cluster status:
   ```bash
   oc get storagecluster -n openshift-storage
   oc describe storagecluster -n openshift-storage
   ```

3. Check pod events:
   ```bash
   oc get events -n openshift-storage --field-selector involvedObject.name=rook-ceph-tools
   ```

4. Check pod logs:
   ```bash
   oc logs deployment/rook-ceph-tools -n openshift-storage
   ```

### Connection Issues

If you can't connect to Ceph from the tools container:

1. Verify the Ceph configuration is mounted:
   ```bash
   oc exec deployment/rook-ceph-tools -n openshift-storage -- ls -la /etc/ceph/
   ```

2. Check the Ceph monitor endpoints:
   ```bash
   oc get configmap rook-ceph-mon-endpoints -n openshift-storage -o yaml
   ```

3. Verify the admin secret exists:
   ```bash
   oc get secret rook-ceph-mon -n openshift-storage
   ```

## Security Considerations

- The tools container has read-only access to Ceph configuration
- RBAC is configured with minimal required permissions
- Container runs as non-root user with dropped capabilities
- No privileged access to the host system

## Integration with ODF Operator

This component is designed to be deployed alongside the ODF operator and will automatically:

- Use the correct Ceph image version matching the cluster
- Mount the appropriate configuration and secrets
- Follow the same update cycle as other ODF components
- Respect cluster-wide security policies

## ArgoCD Integration

This component includes ArgoCD annotations for automated deployment:

- **Sync Wave**: 15 (deploys after core ODF components)
- **Labels**: Standard ODF labeling for monitoring and management
- **Dependencies**: Depends on ODF operator and Ceph cluster being available
