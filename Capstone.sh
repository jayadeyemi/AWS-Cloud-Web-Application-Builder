#!/bin/bash

# Check for required arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <staticwebsite-895>"
  exit 1
fi

staticwebsite-895=$1

# Ensure AWS CLI is configured
if ! aws s3api list-buckets > /dev/null 2>&1; then
  echo "AWS CLI is not configured properly. Please configure it and try again."
  exit 1
fi

# Confirm bucket exists
if ! aws s3api head-bucket --bucket "$staticwebsite-895" 2>/dev/null; then
  echo "Bucket $staticwebsite-895 does not exist or you do not have permission to access it."
  exit 1
fi

echo "Removing public access from all objects in the bucket: $staticwebsite-895"

# List all objects in the bucket and remove public access
aws s3api list-objects-v2 --bucket "$staticwebsite-895" --query 'Contents[].Key' --output text | while read -r OBJECT_KEY; do
  echo "Removing public ACL for object: $OBJECT_KEY"
  aws s3api put-object-acl --bucket "$staticwebsite-895" --key "$OBJECT_KEY" --acl private
done


