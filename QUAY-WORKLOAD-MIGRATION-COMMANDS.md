# Quay Workload Migration to Infrastructure Nodes

## Prerequisites
1. Ensure Quay infrastructure nodes are created and ready
2. Verify nodes have the correct labels and taints

## Step 1: Check Infrastructure Nodes Status

```bash
# Check if Quay infrastructure MachineSet exists
oc get machinesets -n openshift-machine-api | grep quay-infra

# Check if Quay infra nodes are ready
oc get nodes -l node-role.kubernetes.io/quay --show-labels

# Verify nodes have proper labels
oc get nodes -l node-role.kubernetes.io/infra --show-labels
```

## Step 2: Check Current Pod Placement

```bash
# Check where Quay pods are currently running
oc get pods -n quay-enterprise -o wide

# Specifically check each component
oc get pods -n quay-enterprise -o wide | grep quay
oc get pods -n quay-enterprise -o wide | grep postgres  
oc get pods -n quay-enterprise -o wide | grep redis
```

## Step 3: Force Restart Quay Workloads

### Option A: Restart All Quay Components (Recommended)

```bash
# Restart PostgreSQL StatefulSet
oc rollout restart statefulset/quay-postgres -n quay-enterprise

# Restart Redis StatefulSet  
oc rollout restart statefulset/quay-redis -n quay-enterprise

# For QuayRegistry managed pods, restart the operator deployment
oc rollout restart deployment/quay-operator.v3.x.x -n openshift-operators
```

### Option B: Delete Pods (Alternative)

```bash
# Delete PostgreSQL pods (StatefulSet will recreate them)
oc delete pods -l app=quay-postgres -n quay-enterprise

# Delete Redis pods (StatefulSet will recreate them)
oc delete pods -l app=quay-redis -n quay-enterprise

# Delete Quay application pods
oc delete pods -l quay-component=quay-app -n quay-enterprise
```

## Step 4: Monitor Rollout Status

```bash
# Wait for StatefulSets to be ready
oc rollout status statefulset/quay-postgres -n quay-enterprise --timeout=600s
oc rollout status statefulset/quay-redis -n quay-enterprise --timeout=600s

# Watch pods starting up
oc get pods -n quay-enterprise -w
```

## Step 5: Verify New Pod Placement

```bash
# Check final pod placement
oc get pods -n quay-enterprise -o wide

# Verify pods are on infra nodes
oc get pods -n quay-enterprise -o wide | grep quay
oc get pods -n quay-enterprise -o wide | grep postgres
oc get pods -n quay-enterprise -o wide | grep redis

# Check node labels for the nodes where pods are running
oc describe node <node-name> | grep Labels
```

## Troubleshooting

### If Pods Don't Schedule on Infra Nodes:

1. **Check Node Selectors:**
   ```bash
   oc describe quayregistry kohler-quay-registry -n quay-enterprise
   oc describe statefulset quay-postgres -n quay-enterprise
   oc describe statefulset quay-redis -n quay-enterprise
   ```

2. **Check Tolerations:**
   ```bash
   oc get pods -n quay-enterprise -o yaml | grep -A 10 tolerations
   ```

3. **Check Node Taints:**
   ```bash
   oc describe nodes -l node-role.kubernetes.io/quay | grep Taints
   ```

4. **Check if Nodes are Schedulable:**
   ```bash
   oc get nodes -l node-role.kubernetes.io/quay
   ```

### If Infra Nodes Aren't Created:

1. **Check MachineSet Status:**
   ```bash
   oc describe machineset ocp2-mbh44-quay-infra -n openshift-machine-api
   ```

2. **Check ArgoCD Sync Status:**
   ```bash
   oc get applications -n openshift-gitops | grep ocp2
   ```

3. **Force ArgoCD Sync:**
   ```bash
   oc patch application <app-name> -n openshift-gitops --type='merge' -p='{"operation":{"sync":{"syncStrategy":{"hook":{"enabled":true}}}}}'
   ```

## Expected Results

After successful migration, you should see:
- All Quay pods running on nodes with `node-role.kubernetes.io/quay` label
- PostgreSQL and Redis pods on the same infra nodes
- Quay application accessible and functional
- Infrastructure nodes not counted toward OpenShift subscription billing
