#!/bin/bash

# Comprehensive AWS resource cleanup for SiriusScan demo
# This script ensures all demo resources are properly removed

set -e

echo "🧹 Starting comprehensive AWS resource cleanup..."

# Function to check if a resource exists
resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    
    case "$resource_type" in
        "role")
            aws iam get-role --role-name "$resource_name" >/dev/null 2>&1
            ;;
        "instance-profile")
            aws iam get-instance-profile --instance-profile-name "$resource_name" >/dev/null 2>&1
            ;;
        "security-group")
            aws ec2 describe-security-groups --group-ids "$resource_name" --region us-west-2 >/dev/null 2>&1
            ;;
        "instance")
            aws ec2 describe-instances --instance-ids "$resource_name" --region us-west-2 >/dev/null 2>&1
            ;;
    esac
}

# Function to wait for resource deletion
wait_for_deletion() {
    local resource_type="$1"
    local resource_name="$2"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ! resource_exists "$resource_type" "$resource_name"; then
            echo "✅ $resource_type $resource_name deleted successfully"
            return 0
        fi
        echo "⏳ Waiting for $resource_type $resource_name to be deleted... (attempt $((attempt+1))/$max_attempts)"
        sleep 10
        attempt=$((attempt+1))
    done
    
    echo "⚠️ Timeout waiting for $resource_type $resource_name to be deleted"
    return 1
}

# 1. Clean up EC2 instances
echo "🖥️ Cleaning up EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --region us-west-2 \
    --filters "Name=tag:Name,Values=sirius-demo" "Name=instance-state-name,Values=running,pending,stopping" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")

if [ ! -z "$INSTANCE_IDS" ] && [ "$INSTANCE_IDS" != "None" ]; then
    echo "Found instances to terminate: $INSTANCE_IDS"
    for instance_id in $INSTANCE_IDS; do
        echo "Terminating instance: $instance_id"
        aws ec2 terminate-instances --instance-ids "$instance_id" --region us-west-2 || true
    done
    
    # Wait for instances to terminate
    for instance_id in $INSTANCE_IDS; do
        wait_for_deletion "instance" "$instance_id" || true
    done
else
    echo "No instances found to terminate"
fi

# 1.5. Clean up Elastic IPs
echo "🌐 Cleaning up Elastic IPs..."
EIP_ALLOCATIONS=$(aws ec2 describe-addresses --region us-west-2 \
    --filters "Name=tag:Name,Values=sirius-demo-eip*" \
    --query 'Addresses[*].AllocationId' --output text 2>/dev/null || echo "")

if [ ! -z "$EIP_ALLOCATIONS" ] && [ "$EIP_ALLOCATIONS" != "None" ]; then
    echo "Found Elastic IPs to release: $EIP_ALLOCATIONS"
    for allocation_id in $EIP_ALLOCATIONS; do
        echo "Releasing Elastic IP: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region us-west-2 || true
    done
else
    echo "No Elastic IPs found to release"
fi

# 2. Clean up security groups
echo "🔒 Cleaning up security groups..."
SG_IDS=$(aws ec2 describe-security-groups --region us-west-2 \
    --filters "Name=group-name,Values=sirius-demo-sg*" "Name=vpc-id,Values=vpc-416eeb39" \
    --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")

if [ ! -z "$SG_IDS" ] && [ "$SG_IDS" != "None" ]; then
    for sg_id in $SG_IDS; do
        echo "Deleting security group: $sg_id"
        aws ec2 delete-security-group --group-id "$sg_id" --region us-west-2 || true
    done
else
    echo "No security groups found to delete"
fi

# 3. Clean up IAM resources (in correct order)
echo "👤 Cleaning up IAM resources..."

# Get all roles and instance profiles with sirius-demo prefix
ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, 'sirius-demo-instance-role')].RoleName" --output text 2>/dev/null || echo "")
INSTANCE_PROFILES=$(aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, 'sirius-demo-instance-profile')].InstanceProfileName" --output text 2>/dev/null || echo "")

# Clean up instance profiles first
if [ ! -z "$INSTANCE_PROFILES" ] && [ "$INSTANCE_PROFILES" != "None" ]; then
    for profile_name in $INSTANCE_PROFILES; do
        echo "Found instance profile: $profile_name"
        
        # Get the role name from the instance profile
        ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name "$profile_name" --query 'InstanceProfile.Roles[0].RoleName' --output text 2>/dev/null || echo "")
        
        if [ ! -z "$ROLE_NAME" ] && [ "$ROLE_NAME" != "None" ]; then
            echo "Removing role $ROLE_NAME from instance profile $profile_name..."
            aws iam remove-role-from-instance-profile \
                --instance-profile-name "$profile_name" \
                --role-name "$ROLE_NAME" || true
        fi
        
        echo "Deleting instance profile: $profile_name"
        aws iam delete-instance-profile --instance-profile-name "$profile_name" || true
        wait_for_deletion "instance-profile" "$profile_name" || true
    done
else
    echo "No instance profiles found to delete"
fi

# Clean up roles
if [ ! -z "$ROLES" ] && [ "$ROLES" != "None" ]; then
    for role_name in $ROLES; do
        echo "Found IAM role: $role_name"
        
        # Detach policies
        echo "Detaching policies from role: $role_name"
        aws iam detach-role-policy \
            --role-name "$role_name" \
            --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy || true
        
        aws iam detach-role-policy \
            --role-name "$role_name" \
            --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore || true
        
        # Delete role
        echo "Deleting IAM role: $role_name"
        aws iam delete-role --role-name "$role_name" || true
        wait_for_deletion "role" "$role_name" || true
    done
else
    echo "No IAM roles found to delete"
fi

# 4. Clean up any remaining EBS volumes (if any)
echo "💾 Cleaning up orphaned EBS volumes..."
VOLUME_IDS=$(aws ec2 describe-volumes --region us-west-2 \
    --filters "Name=tag:Name,Values=sirius-demo" "Name=state,Values=available" \
    --query 'Volumes[].VolumeId' --output text 2>/dev/null || echo "")

if [ ! -z "$VOLUME_IDS" ] && [ "$VOLUME_IDS" != "None" ]; then
    for volume_id in $VOLUME_IDS; do
        echo "Deleting volume: $volume_id"
        aws ec2 delete-volume --volume-id "$volume_id" --region us-west-2 || true
    done
else
    echo "No orphaned volumes found"
fi

echo "✅ AWS resource cleanup completed!"
