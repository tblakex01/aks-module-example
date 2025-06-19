#!/bin/bash

# Script to validate network CIDR configurations across all environments
# This script checks that our CIDR addressing is correct in each environment

echo "🔍 Validating Network CIDR Configurations..."
echo "=============================================="

# Function to validate CIDR in a file
validate_cidr() {
    local env=$1
    local expected_vnet=$2
    local expected_system=$3
    local expected_spark=$4
    local expected_endpoints=$5
    
    echo ""
    echo "📁 Checking $env environment..."
    echo "Expected VNet: $expected_vnet"
    echo "Expected System subnet: $expected_system" 
    echo "Expected Spark subnet: $expected_spark"
    echo "Expected Endpoints subnet: $expected_endpoints"
    
    # Check locals.tf
    local locals_file="envs/$env/locals.tf"
    if [ -f "$locals_file" ]; then
        echo "✓ Found $locals_file"
        
        # Check VNet CIDR
        if grep -q "$expected_vnet" "$locals_file"; then
            echo "✅ VNet CIDR correct: $expected_vnet"
        else
            echo "❌ VNet CIDR incorrect in $locals_file"
            echo "   Found: $(grep -o '10\.[0-9]\+\.[0-9]\+\.[0-9]\+/[0-9]\+' "$locals_file" | head -1)"
        fi
        
        # Check subnet CIDRs
        if grep -q "$expected_system" "$locals_file"; then
            echo "✅ System subnet CIDR correct: $expected_system"
        else
            echo "❌ System subnet CIDR incorrect in $locals_file"
        fi
        
        if grep -q "$expected_spark" "$locals_file"; then
            echo "✅ Spark subnet CIDR correct: $expected_spark"
        else
            echo "❌ Spark subnet CIDR incorrect in $locals_file"
        fi
        
        if grep -q "$expected_endpoints" "$locals_file"; then
            echo "✅ Endpoints subnet CIDR correct: $expected_endpoints"
        else
            echo "❌ Endpoints subnet CIDR incorrect in $locals_file"
        fi
    else
        echo "❌ $locals_file not found"
    fi
    
    # Check main.tf for service CIDR
    local main_file="envs/$env/main.tf"
    if [ -f "$main_file" ]; then
        if grep -q "service_cidr.*=.*\"10.0.0.0/16\"" "$main_file"; then
            echo "✅ Service CIDR correct: 10.0.0.0/16"
        else
            echo "❌ Service CIDR incorrect in $main_file"
            echo "   Found: $(grep -o 'service_cidr.*=.*"[^"]*"' "$main_file")"
        fi
        
        if grep -q "dns_service_ip.*=.*\"10.0.0.10\"" "$main_file"; then
            echo "✅ DNS Service IP correct: 10.0.0.10"
        else
            echo "❌ DNS Service IP incorrect in $main_file"
            echo "   Found: $(grep -o 'dns_service_ip.*=.*"[^"]*"' "$main_file")"
        fi
    fi
}

# Validate each environment with its expected CIDR ranges
validate_cidr "dev" "10.0.1.0/24" "10.0.1.0/26" "10.0.1.64/26" "10.0.1.128/25"
validate_cidr "qa" "10.0.2.0/24" "10.0.2.0/26" "10.0.2.64/26" "10.0.2.128/25"
validate_cidr "staging" "10.0.3.0/24" "10.0.3.0/26" "10.0.3.64/26" "10.0.3.128/25"
validate_cidr "prod" "10.0.4.0/24" "10.0.4.0/26" "10.0.4.64/26" "10.0.4.128/25"

echo ""
echo "🔍 Checking for legacy CIDR references..."
echo "=========================================="

# Check for old CIDR ranges that should not exist
legacy_patterns=("10.248" "10.250" "10.1.0.0/16" "10.2.0.0/16")

for pattern in "${legacy_patterns[@]}"; do
    echo "Checking for legacy pattern: $pattern"
    found_files=$(find envs/ -name "*.tf" -exec grep -l "$pattern" {} \; 2>/dev/null)
    if [ -n "$found_files" ]; then
        echo "❌ Found legacy CIDR pattern '$pattern' in:"
        echo "$found_files" | sed 's/^/   /'
    else
        echo "✅ No legacy pattern '$pattern' found"
    fi
done

echo ""
echo "🏁 Validation Complete!"
echo "======================="