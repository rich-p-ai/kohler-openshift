#!/bin/bash
# Emergency ODF Resource Profile Fix Script
# This script immediately fixes the Ceph monitor quorum issue by reverting resource profile

set -e

echo "=== ODF Emergency Resource Profile Fix ==="
echo "This script will fix the Ceph monitor quorum issue by reverting from 'lean' to 'balanced' resource profile"

# Check current cluster status
echo "Checking current StorageCluster status..."
oc get storagecluster ocs-storagecluster -n openshift-storage -o yaml | grep -E "(resourceProfile|phase)"

# Check node labels and taints
echo "Checking node labels and taints..."
echo "Available storage nodes:"
oc get nodes -l cluster.ocs.openshift.io/openshift-storage --show-labels
echo ""
echo "Node taints:"
oc get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Apply the resource profile and placement fix
echo "Applying resource profile and placement fix..."
oc patch storagecluster ocs-storagecluster -n openshift-storage --type='merge' -p='
{
  "spec": {
    "resourceProfile": "balanced",
    "placement": {
      "all": {
        "nodeAffinity": {
          "requiredDuringSchedulingIgnoredDuringExecution": {
            "nodeSelectorTerms": [
              {
                "matchExpressions": [
                  {
                    "key": "cluster.ocs.openshift.io/openshift-storage",
                    "operator": "Exists"
                  }
                ]
              }
            ]
          }
        },
        "tolerations": [
          {
            "effect": "NoSchedule",
            "key": "node-role.kubernetes.io/infra",
            "operator": "Equal"
          },
          {
            "effect": "NoSchedule",
            "key": "node.ocs.openshift.io/storage",
            "operator": "Equal",
            "value": "true"
          }
        ]
      },
      "mon": {
        "nodeAffinity": {
          "requiredDuringSchedulingIgnoredDuringExecution": {
            "nodeSelectorTerms": [
              {
                "matchExpressions": [
                  {
                    "key": "cluster.ocs.openshift.io/openshift-storage",
                    "operator": "Exists"
                  },
                  {
                    "key": "node-role.kubernetes.io/infra",
                    "operator": "Exists"
                  }
                ]
              }
            ]
          }
        },
        "tolerations": [
          {
            "effect": "NoSchedule",
            "key": "node-role.kubernetes.io/infra",
            "operator": "Equal"
          },
          {
            "effect": "NoSchedule",
            "key": "node.ocs.openshift.io/storage",
            "operator": "Equal",
            "value": "true"
          }
        ]
      }
    },
    "resources": {
      "mgr": {
        "limits": {"cpu": "2", "memory": "4Gi"},
        "requests": {"cpu": "1", "memory": "2Gi"}
      },
      "mon": {
        "limits": {"cpu": "2", "memory": "2Gi"},
        "requests": {"cpu": "1", "memory": "1Gi"}
      },
      "osd": {
        "limits": {"cpu": "2", "memory": "4Gi"},
        "requests": {"cpu": "1", "memory": "2Gi"}
      }
    }
  }
}'

echo "Waiting for StorageCluster to reconcile..."
sleep 30

# Monitor the reconciliation process
echo "Monitoring Ceph monitor pods..."
timeout=600
elapsed=0
while [ $elapsed -lt $timeout ]; do
    mon_status=$(oc get pods -l app=rook-ceph-mon -n openshift-storage -o jsonpath='{.items[*].status.phase}')
    echo "Monitor pod status: $mon_status"

    # Check if all monitors are running
    running_count=$(oc get pods -l app=rook-ceph-mon -n openshift-storage -o jsonpath='{.items[*].status.phase}' | grep -o 'Running' | wc -l)

    if [ "$running_count" -eq 3 ]; then
        echo "✅ All 3 Ceph monitors are now running!"
        break
    fi

    sleep 10
    elapsed=$((elapsed + 10))
done

if [ $elapsed -ge $timeout ]; then
    echo "❌ Timeout waiting for monitors to start. Check cluster status manually."
    exit 1
fi

# Check Ceph cluster health
echo "Checking Ceph cluster health..."
sleep 30
oc get cephcluster -n openshift-storage

echo "=== Resource Profile Fix Complete ==="
echo "The Ceph monitor quorum issue should now be resolved."
echo "Monitor cluster health with: oc get cephcluster -n openshift-storage -w"
