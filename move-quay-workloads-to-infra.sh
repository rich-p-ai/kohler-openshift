#!/bin/bash

echo "=== Checking Quay Infrastructure Nodes Status ==="

# Check if Quay infrastructure MachineSet exists
echo "1. Checking Quay infrastructure MachineSet..."
oc get machinesets -n openshift-machine-api | grep quay-infra

# Check if Quay infra nodes are ready
echo -e "\n2. Checking Quay infrastructure nodes..."
oc get nodes -l node-role.kubernetes.io/quay --show-labels

# Check current Quay pod placement
echo -e "\n3. Checking current Quay pod placement..."
echo "QuayRegistry pods:"
oc get pods -n quay-enterprise -o wide | grep quay

echo -e "\nPostgreSQL pods:"
oc get pods -n quay-enterprise -o wide | grep postgres

echo -e "\nRedis pods:"
oc get pods -n quay-enterprise -o wide | grep redis

echo -e "\n=== Moving Quay Workloads to Infrastructure Nodes ==="

# If nodes are ready, restart Quay workloads to move them to infra nodes
echo "4. Restarting Quay workloads to move to infrastructure nodes..."

# Restart QuayRegistry (this will recreate all Quay operator managed pods)
echo "Restarting QuayRegistry..."
oc patch quayregistry kohler-quay-registry -n quay-enterprise --type='merge' -p='{"spec":{"configBundleSecret":"quay-config-bundle"}}'

# Restart PostgreSQL StatefulSet
echo "Restarting PostgreSQL StatefulSet..."
oc rollout restart statefulset/quay-postgres -n quay-enterprise

# Restart Redis StatefulSet
echo "Restarting Redis StatefulSet..."
oc rollout restart statefulset/quay-redis -n quay-enterprise

echo -e "\n5. Waiting for rollouts to complete..."
oc rollout status statefulset/quay-postgres -n quay-enterprise --timeout=600s
oc rollout status statefulset/quay-redis -n quay-enterprise --timeout=600s

echo -e "\n6. Checking new pod placement..."
echo "QuayRegistry pods:"
oc get pods -n quay-enterprise -o wide | grep quay

echo -e "\nPostgreSQL pods:"
oc get pods -n quay-enterprise -o wide | grep postgres

echo -e "\nRedis pods:"
oc get pods -n quay-enterprise -o wide | grep redis

echo -e "\n=== Verification Complete ==="
echo "All Quay workloads should now be running on infrastructure nodes!"
