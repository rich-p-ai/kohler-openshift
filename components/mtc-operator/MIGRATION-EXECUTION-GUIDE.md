# 🚀 Migration Execution Guide: ocp-prd → ocp2

## 📋 **Migration Plan Overview**

This guide will help you execute the migration of applications from **ocp-prd** to **ocp2** using the Migration Toolkit for Containers (MTC).

## 🎯 **Applications to Migrate**

### **Phase 1: Core Business Applications (Priority 1)**
- `balance-fit-prd` - Balance Fit Production
- `humanresourceapps` - Human Resource Apps
- `kitchenandbathapps` - Plumbing Kitchen & Bath
- `corporateapps` - Corporate Applications
- `crmapplications` - CRM Applications
- `financeapps2` - Finance Applications 2
- `legalapps` - Legal Apps

### **Phase 2: Infrastructure & Tools (Priority 2)**
- `cert-manager` - Certificate Manager
- `kohler-devsecops` - DevSecOps Tools
- `kohler-historian` - Historian System
- `kohler-smartfactory` - Smart Factory

### **Phase 3: Data & File Services (Priority 3)**
- `data-analytics` - Data Analytics
- `meslite` - Manufacturing Execution
- `acf1-sftp-prd` - SFTP Services

### **Phase 4: Development & Testing (Priority 4)**
- `coldfusion` - ColdFusion Apps
- `fmv-poc` - FMV Proof of Concept
- `kohler-az-agents` - Azure Agents

## 🔧 **Prerequisites Check**

Before starting migration, verify:

```bash
# Check migration clusters are ready
oc get migcluster -n openshift-migration

# Check migration storage is ready
oc get migstorage -n openshift-migration

# Verify MTC operator is running
oc get pods -n openshift-migration
```

## 🚀 **Migration Execution Steps**

### **Step 1: Apply Migration Plan**

```bash
# Apply the migration plan
oc apply -f migration-plan.yaml

# Verify the plan was created
oc get migplan -n openshift-migration
```

### **Step 2: Validate Migration Plan**

```bash
# Check plan validation status
oc describe migplan ocp-prd-to-ocp2-migration -n openshift-migration

# Look for validation errors and warnings
oc get migplan ocp-prd-to-ocp2-migration -n openshift-migration -o yaml
```

### **Step 3: Execute Migration**

```bash
# Create the migration execution
oc create -f - <<EOF
apiVersion: migration.openshift.io/v1alpha1
kind: MigMigration
metadata:
  name: ocp-prd-to-ocp2-migration
  namespace: openshift-migration
spec:
  migPlanRef:
    name: ocp-prd-to-ocp2-migration
EOF
```

### **Step 4: Monitor Migration Progress**

```bash
# Watch migration status
oc get migmigration -n openshift-migration -w

# Check detailed status
oc describe migmigration ocp-prd-to-ocp2-migration -n openshift-migration

# Monitor migration pods
oc get pods -n openshift-migration -l app=migration
```

## 📊 **Migration Phases**

### **Phase 1: Backup (Stage 1)**
- Creates backup of source applications
- Validates storage and network connectivity
- **Duration**: 30-60 minutes per namespace

### **Phase 2: Restore (Stage 2)**
- Restores applications to target cluster
- Updates storage classes and registry references
- **Duration**: 15-30 minutes per namespace

### **Phase 3: Verification (Stage 3)**
- Validates application functionality
- Checks data integrity
- **Duration**: 10-20 minutes per namespace

## 🔍 **Monitoring and Troubleshooting**

### **Check Migration Status**
```bash
# Overall migration status
oc get migmigration -n openshift-migration

# Detailed migration logs
oc logs -n openshift-migration deployment/migration-controller

# Check for errors
oc get events -n openshift-migration --sort-by='.lastTimestamp'
```

### **Common Issues and Solutions**

#### **Storage Class Mismatch**
```bash
# Check available storage classes in target cluster
oc get storageclass

# Update migration plan if needed
oc edit migplan ocp-prd-to-ocp2-migration -n openshift-migration
```

#### **Image Registry Issues**
```bash
# Verify image registry connectivity
oc get imagestreams -n <namespace>

# Check for image pull errors
oc get events -n <namespace> | grep -i image
```

#### **Resource Conflicts**
```bash
# Check for duplicate resources
oc get all -n <namespace>

# Resolve conflicts manually if needed
oc delete <resource-type> <resource-name> -n <namespace>
```

## ✅ **Post-Migration Verification**

### **Application Health Checks**
```bash
# Check pod status
oc get pods -n <namespace>

# Verify services are running
oc get svc -n <namespace>

# Check routes are accessible
oc get routes -n <namespace>
```

### **Data Integrity Verification**
```bash
# Check PVC status
oc get pvc -n <namespace>

# Verify data persistence
oc exec -n <namespace> <pod-name> -- <data-verification-command>
```

### **Network Connectivity**
```bash
# Test internal communication
oc exec -n <namespace> <pod-name> -- curl <service-name>

# Verify external access
oc get routes -n <namespace> -o wide
```

## 🚨 **Rollback Procedures**

### **If Migration Fails**
```bash
# Delete the failed migration
oc delete migmigration ocp-prd-to-ocp2-migration -n openshift-migration

# Clean up target cluster resources
oc delete namespace <namespace> --force --grace-period=0

# Restart migration from beginning
```

### **Partial Rollback**
```bash
# Identify failed namespaces
oc get migmigration -n openshift-migration -o yaml

# Delete specific failed resources
oc delete <resource-type> <resource-name> -n <namespace>

# Re-run migration for specific namespaces
```

## 📈 **Performance Optimization**

### **Parallel Migration**
```bash
# Run multiple migrations simultaneously
oc create -f migration-plan-namespace1.yaml
oc create -f migration-plan-namespace2.yaml
oc create -f migration-plan-namespace3.yaml
```

### **Resource Allocation**
```bash
# Monitor resource usage
oc top nodes
oc top pods -n openshift-migration

# Adjust resource limits if needed
oc edit deployment migration-controller -n openshift-migration
```

## 🎯 **Success Criteria**

Migration is considered successful when:
- ✅ All applications are running in target cluster
- ✅ Data integrity is verified
- ✅ Network connectivity is confirmed
- ✅ Performance meets requirements
- ✅ Monitoring and logging are functional

## 📚 **Next Steps After Migration**

1. **Update DNS records** to point to new cluster
2. **Configure monitoring** for new applications
3. **Update CI/CD pipelines** to target new cluster
4. **Document changes** and update runbooks
5. **Plan decommissioning** of old cluster

## 🔗 **Useful Commands Reference**

```bash
# Quick status check
oc get migplan,migmigration,migcluster,migstorage -n openshift-migration

# View migration logs
oc logs -f deployment/migration-controller -n openshift-migration

# Check cluster connectivity
oc get migcluster -n openshift-migration -o yaml

# Monitor migration progress
watch oc get migmigration -n openshift-migration
```

