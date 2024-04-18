#!/usr/bin/env bash

# Ensure that the AMI name pattern is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <AMI Name Pattern>"
    exit 1
fi

AMI_NAME_PATTERN=$1
declare -a AMIS_TO_DELETE

# Get the list of all enabled regions for the AWS account
REGIONS=$(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text)

echo "Searching for AMIs with name pattern '$AMI_NAME_PATTERN' across all enabled regions..."

# Gather AMIs across all regions
for REGION in $REGIONS; do
    echo "Checking region: $REGION"
    # Modify the query to also retrieve the name of the AMI
    AMIS=$(aws ec2 describe-images \
        --region "$REGION" \
        --filters "Name=name,Values=$AMI_NAME_PATTERN" \
        --query 'Images[].[ImageId, Name]' \
        --output text)

    if [ -n "$AMIS" ]; then
        echo "Found AMIs in region $REGION:"
        while IFS=$'\t' read -r AMI_ID AMI_NAME; do
            echo "    $AMI_ID ($AMI_NAME)"
            AMIS_TO_DELETE+=("$REGION:$AMI_ID:$AMI_NAME")
        done <<< "$AMIS"
    else
        echo "    No AMIs found."
    fi
done

# Check if there are any AMIs to delete
if [ ${#AMIS_TO_DELETE[@]} -eq 0 ]; then
    echo "No AMIs found matching pattern '$AMI_NAME_PATTERN' across all regions."
    exit 0
fi

# Confirmation before proceeding with deletion
echo "You are about to delete the above listed AMIs and their associated snapshots across all regions."
read -rp "Are you sure you want to proceed? (yes/no): " CONFIRMATION

if [[ "$CONFIRMATION" != "yes" ]]; then
    echo "Deletion cancelled."
    exit 0
fi

# Function to delete AMIs and associated snapshots
delete_amis_and_snapshots() {
    REGION=$1
    AMI_ID=$2
    AMI_NAME=$3

    # Find associated snapshots before deregistering the AMI
    SNAPSHOTS=$(aws ec2 describe-snapshots --owner-ids self --region "$REGION" \
                --filters "Name=description,Values=*${AMI_ID}*" \
                --query 'Snapshots[].SnapshotId' --output text)

    # Deregister the AMI
    echo "Deregistering AMI: $AMI_ID ($AMI_NAME) in region $REGION"
    aws ec2 deregister-image --image-id "$AMI_ID" --region "$REGION"

    # Delete associated snapshots
    if [ -n "$SNAPSHOTS" ]; then
        echo "Deleting snapshots associated with AMI $AMI_ID ($AMI_NAME):"
        for SNAPSHOT_ID in $SNAPSHOTS; do
            echo "    Deleting snapshot $SNAPSHOT_ID in region $REGION"
            aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID" --region "$REGION"
        done
    else
        echo "    No snapshots found for AMI $AMI_ID ($AMI_NAME) in region $REGION."
    fi
}

# Loop through each element in AMIS_TO_DELETE and delete AMIs if confirmed
for AMI_INFO in "${AMIS_TO_DELETE[@]}"; do
    IFS=':' read -r REGION AMI_ID AMI_NAME <<< "$AMI_INFO"
    delete_amis_and_snapshots "$REGION" "$AMI_ID" "$AMI_NAME"
done

echo "Operation completed."
