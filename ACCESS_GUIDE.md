# AKS Private Cluster Access Guide

This guide explains how to access the private AKS cluster after deployment.

## Prerequisites

- Azure CLI installed locally
- kubectl installed locally
- Appropriate Azure RBAC permissions on the AKS cluster

## Access Methods

### 1. Azure Bastion + Jump Box (Most Secure)

1. Deploy the bastion resources (see `bastion.tf.example`)
2. Connect to the jump box:
   ```bash
   az network bastion ssh \
     --name bastion-aks-spark-cluster \
     --resource-group rg-aks-spark-prod \
     --target-resource-id /subscriptions/{subscription-id}/resourceGroups/rg-aks-spark-prod/providers/Microsoft.Compute/virtualMachines/vm-jumpbox-aks-spark-cluster \
     --auth-type ssh-key \
     --username azureuser \
     --ssh-key ~/.ssh/id_rsa
   ```

3. Once connected to the jump box:
   ```bash
   # Login to Azure
   az login
   
   # Get AKS credentials
   az aks get-credentials \
     --resource-group rg-aks-spark-prod \
     --name aks-spark-cluster
   
   # Verify access
   kubectl get nodes
   ```

### 2. VPN/ExpressRoute Connection

If your organization has site-to-site connectivity:

1. Ensure VNet peering exists between AKS VNet and your connectivity VNet
2. Connect to corporate VPN
3. Run kubectl commands from your local machine:
   ```bash
   az aks get-credentials \
     --resource-group rg-aks-spark-prod \
     --name aks-spark-cluster
   kubectl get nodes
   ```

### 3. Azure Cloud Shell with VNet Integration

1. Configure Cloud Shell storage in the same region
2. Integrate Cloud Shell with a subnet in the AKS VNet
3. Access from Azure Portal Cloud Shell:
   ```bash
   az aks get-credentials \
     --resource-group rg-aks-spark-prod \
     --name aks-spark-cluster
   kubectl get nodes
   ```

### 4. AKS Run Command (Emergency Access)

For quick commands without VNet access:

```bash
# Run a single command
az aks command invoke \
  --resource-group rg-aks-spark-prod \
  --name aks-spark-cluster \
  --command "kubectl get nodes"

# Run a command with a file
az aks command invoke \
  --resource-group rg-aks-spark-prod \
  --name aks-spark-cluster \
  --command "kubectl apply -f deployment.yaml" \
  --file deployment.yaml
```

### 5. CI/CD Pipeline Access

For automated deployments:

1. Deploy a self-hosted agent/runner in the AKS VNet
2. Use managed identity or service principal authentication
3. Example GitHub Actions workflow:
   ```yaml
   - name: Azure Login
     uses: azure/login@v1
     with:
       creds: ${{ secrets.AZURE_CREDENTIALS }}
   
   - name: Get AKS Credentials
     run: |
       az aks get-credentials \
         --resource-group rg-aks-spark-prod \
         --name aks-spark-cluster
   
   - name: Deploy to AKS
     run: kubectl apply -f manifests/
   ```

## Spark Workload Access

Once connected to the cluster, deploy Spark workloads to the dedicated Spark node pool:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-driver
spec:
  nodeSelector:
    nodepool-type: spark
  tolerations:
  - key: workload
    operator: Equal
    value: spark
    effect: NoSchedule
  containers:
  - name: spark
    image: apache/spark:latest
    # ... rest of configuration
```

## Network Connectivity Summary

- **Cluster API Endpoint**: Private only (10.248.x.x range)
- **Service CIDR**: 10.250.0.0/16
- **DNS Service IP**: 10.250.0.10
- **System Nodes**: 10.248.0.0/24
- **Spark Nodes**: 10.248.1.0/25

## Security Considerations

1. **No Public Endpoints**: The cluster API is not accessible from the internet
2. **Network Policies**: Enabled for pod-to-pod traffic control
3. **Azure AD RBAC**: All access is authenticated via Azure AD
4. **Workload Identity**: Pods can authenticate to Azure services using managed identities
5. **Key Vault Integration**: Secrets are managed through Azure Key Vault

## Troubleshooting

### Cannot reach cluster API
- Verify you're connected to the VNet (via VPN, Bastion, or Cloud Shell)
- Check NSG rules allow traffic to the API server
- Ensure private DNS zone is linked to your VNet

### DNS Resolution Issues
- Verify the private DNS zone `privatelink.eastus.azmk8s.io` exists
- Check VNet link is active
- Try using the private IP directly instead of FQDN

### Spark Pods Not Scheduling
- Verify node pool has the correct taints: `workload=spark:NoSchedule`
- Ensure pods have matching tolerations
- Check node pool has available capacity (min 4 nodes)