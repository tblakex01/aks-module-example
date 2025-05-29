# ExpressRoute Configuration for AKS Cluster

## Overview

This AKS cluster is configured to route all internal traffic (10.0.0.0/16) through ExpressRoute to reach on-premises and AWS resources. The implementation uses a hub-and-spoke architecture.

## Architecture

```
On-Premises/AWS ←→ ExpressRoute ←→ Hub VNet (10.248.0.0/23) ←→ AKS Spoke VNet (10.248.27.0/24)
                                          ↓
                                   ExpressRoute Gateway
```

## Key Components

### 1. Network Addressing
- **AKS VNet**: 10.248.27.0/24 (spoke)
  - System subnet: 10.248.27.0/26 (64 IPs)
  - Spark subnet: 10.248.27.64/26 (64 IPs)
  - Endpoints subnet: 10.248.27.128/27 (32 IPs)
- **Hub VNet**: 10.248.0.0/23 (existing)
- **Service CIDR**: 10.250.0.0/16 (Kubernetes services)

### 2. VNet Peering
- Bidirectional peering between hub and spoke
- Spoke uses remote gateway (ExpressRoute) from hub
- Hub allows gateway transit to spoke

### 3. Route Table
- Name: `rt-aks-expressroute`
- BGP propagation: Enabled (receives routes from ExpressRoute)
- Custom route: 10.0.0.0/16 → VirtualNetworkGateway

### 4. Network Security Group Rules
- Port 443 (HTTPS) from 10.0.0.0/16
- Ports 1521-1522 (Oracle) from 10.0.0.0/16
- All traffic from hub VNet (10.248.0.0/23)
- Standard AKS requirements (VNet, Azure LB)

### 5. DNS Configuration
- Private DNS zone linked to both spoke and hub VNets
- Enables AKS API resolution from on-premises via ExpressRoute

## Traffic Flow

1. **Outbound from AKS to On-Premises/AWS**:
   - Pod → Node → Route Table → Hub VNet → ExpressRoute Gateway → On-Premises/AWS

2. **Inbound from On-Premises/AWS to AKS**:
   - On-Premises/AWS → ExpressRoute → Hub VNet → Peering → Spoke VNet → AKS

3. **Internet Traffic**:
   - Uses AKS managed outbound IPs (2 IPs configured)
   - Does NOT go through ExpressRoute

## Important Variables

Set these before deployment:
```bash
# Hub resource group containing ExpressRoute Gateway
terraform apply -var="hub_resource_group_name=your-hub-rg"
```

## Validation Steps

After deployment:

1. **Check Peering Status**:
   ```bash
   az network vnet peering show \
     --resource-group rg-aks-spark-prod \
     --vnet-name vnet-aks-spark-spoke \
     --name peer-vnet-aks-spark-spoke-to-net-eastus-hub
   ```

2. **Verify Route Table**:
   ```bash
   az network route-table show \
     --resource-group rg-aks-spark-prod \
     --name rt-aks-expressroute
   ```

3. **Test Connectivity** (from a pod):
   ```bash
   kubectl run test-pod --image=busybox -it --rm -- /bin/sh
   # Inside pod:
   ping 10.0.0.1  # Should route via ExpressRoute
   traceroute 10.0.0.1
   ```

## Troubleshooting

### Cannot reach on-premises resources
1. Verify peering status is "Connected"
2. Check effective routes on node NICs
3. Ensure NSG rules allow required traffic
4. Verify ExpressRoute circuit is provisioned and connected

### DNS resolution issues
1. Check private DNS zone is linked to hub VNet
2. Verify DNS forwarders in hub (if applicable)

### Routing issues
1. Check BGP routes are being received:
   ```bash
   az network nic show-effective-route-table \
     --resource-group MC_rg-aks-spark-prod_aks-spark-cluster_eastus \
     --name <node-nic-name>
   ```

## Security Considerations

1. All cluster management traffic must come through ExpressRoute or Azure-native methods
2. No public endpoint exposed
3. NSG rules restrict traffic to known internal networks only
4. Consider adding Azure Firewall in hub for additional security