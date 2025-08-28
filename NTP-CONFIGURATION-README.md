# NTP Configuration for OpenShift Cluster

This document describes the NTP (Network Time Protocol) configuration implementation for all OpenShift cluster nodes including master, worker, infra, ODF, and Quay nodes.

## Overview

All cluster nodes are configured to synchronize time with `timehost.kohlerco.com` NTP server using chrony daemon with the following configuration:

```bash
timehost.kohlerco.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
```

## Files Created

### MachineConfig Files
- `clusters/ocp2/99-master-chrony.yaml` - NTP config for master nodes
- `clusters/ocp2/99-worker-chrony.yaml` - NTP config for worker nodes
- `clusters/ocp2/99-infra-chrony.yaml` - NTP config for infra nodes
- `clusters/ocp2/99-odf-chrony.yaml` - NTP config for ODF storage nodes
- `clusters/ocp2/99-quay-chrony.yaml` - NTP config for Quay registry nodes

### GitOps Component
- `components/ntp-configuration/kustomization.yaml` - Kustomization for NTP configs
- `components/ntp-configuration/99-*-chrony.yaml` - Copied NTP configs for GitOps

### ArgoCD Application
- `ntp-configuration-app.yaml` - ArgoCD application for automated NTP deployment

### Deployment Scripts
- `deploy-ntp-configuration.sh` - Script to manually deploy NTP configurations
- `verify-ntp-configuration.sh` - Script to verify NTP configuration on all nodes

## Deployment Methods

### Method 1: GitOps Deployment (Recommended)

1. Apply the ArgoCD application:
   ```bash
   oc apply -f ntp-configuration-app.yaml
   ```

2. The ArgoCD application will automatically:
   - Deploy NTP MachineConfigs to all node types
   - Monitor configuration rollout
   - Ensure configurations remain in sync

### Method 2: Manual Deployment

1. Run the deployment script:
   ```bash
   ./deploy-ntp-configuration.sh
   ```

2. This will:
   - Apply NTP configurations to all node types
   - Wait for MachineConfigPool updates
   - Provide status feedback

## Verification

### Automated Verification
```bash
./verify-ntp-configuration.sh
```

### Manual Verification

1. Check MachineConfig status:
   ```bash
   oc get mcp
   oc get mc | grep chrony
   ```

2. Check NTP configuration on a specific node:
   ```bash
   oc debug node/<node-name> -- chroot /host cat /etc/chrony.conf
   ```

3. Check NTP synchronization status:
   ```bash
   oc debug node/<node-name> -- chroot /host chronyc tracking
   oc debug node/<node-name> -- chroot /host chronyc sources
   ```

4. Check chrony service status:
   ```bash
   oc debug node/<node-name> -- chroot /host systemctl status chronyd
   ```

## Node Type Coverage

| Node Type | MachineConfig | Label Selector |
|-----------|---------------|----------------|
| Master | `99-master-chrony` | `machineconfiguration.openshift.io/role: master` |
| Worker | `99-worker-chrony` | `machineconfiguration.openshift.io/role: worker` |
| Infra | `99-infra-chrony` | `machineconfiguration.openshift.io/role: infra` |
| ODF | `99-odf-chrony` | `machineconfiguration.openshift.io/role: odf` |
| Quay | `99-quay-chrony` | `machineconfiguration.openshift.io/role: quay` |

## Troubleshooting

### Common Issues

1. **MachineConfigPool stuck in Updating state:**
   ```bash
   oc get mcp
   oc describe mcp/<pool-name>
   oc logs -n openshift-machine-config-operator deployment/machine-config-operator
   ```

2. **NTP service not running:**
   ```bash
   oc debug node/<node-name> -- chroot /host systemctl restart chronyd
   ```

3. **Time synchronization issues:**
   ```bash
   oc debug node/<node-name> -- chroot /host chronyc makestep
   ```

### Rollback

To rollback NTP configurations:
```bash
# Delete MachineConfigs
oc delete mc 99-master-chrony 99-worker-chrony 99-infra-chrony 99-odf-chrony 99-quay-chrony

# Or rollback via GitOps by removing from ArgoCD application
```

## Security Considerations

- NTP server `timehost.kohlerco.com` should be accessible from all cluster nodes
- Consider implementing NTP authentication if security requirements demand
- Monitor NTP synchronization status as part of regular cluster health checks

## Monitoring

Add NTP monitoring to your observability stack:

```yaml
# Example Prometheus rule for NTP monitoring
groups:
- name: ntp_monitoring
  rules:
  - alert: NtpOffsetTooHigh
    expr: abs(ntp_offset) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "NTP offset too high on {{ $labels.instance }}"
```

## Maintenance

- Review NTP server configuration annually
- Monitor NTP server availability and performance
- Update chrony configuration if new requirements arise
- Test NTP configuration during cluster upgrades

---

**Note**: Ensure the NTP server `timehost.kohlerco.com` is reachable from all cluster nodes before deploying these configurations.
