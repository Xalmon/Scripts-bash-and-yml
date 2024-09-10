#!/bin/bash

# Variables
PROJECT_DIR="/path/to/your/frontend/project"
BUILD_DIR="${PROJECT_DIR}/build"  
S3_BUCKET="your-s3-bucket-name"
AWS_REGION="your-aws-region"  
CLOUDFRONT_COMMENT="My CloudFront distribution"
AWS_PROFILE="your-aws-profile"  
CLOUDFRONT_ORIGIN_PATH=""  

chmod +x $0

create_cloudfront_distribution() {
    echo "Creating CloudFront distribution..."
    DISTRIBUTION_CONFIG=$(cat <<EOF
{
    "CallerReference": "$(date +%s)",  # Unique reference
    "Comment": "$CLOUDFRONT_COMMENT",
    "Origins": {
        "Items": [
            {
                "Id": "$S3_BUCKET-origin",
                "DomainName": "$S3_BUCKET.s3.amazonaws.com",
                "OriginPath": "$CLOUDFRONT_ORIGIN_PATH",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            }
        ],
        "Quantity": 1
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "$S3_BUCKET-origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 7,
            "Items": ["HEAD", "GET", "POST", "PUT", "PATCH", "OPTIONS", "DELETE"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["HEAD", "GET"]
            }
        },
        "Compress": true,
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0
    },
    "Enabled": true
}
EOF
    )

    CLOUDFRONT_DIST_ID=$(aws cloudfront create-distribution \
        --distribution-config "$DISTRIBUTION_CONFIG" \
        --profile $AWS_PROFILE --output text --query 'Distribution.Id')

    echo "CloudFront distribution created with ID: $CLOUDFRONT_DIST_ID"
}

invalidate_cloudfront_cache() {
    echo "Invalidating CloudFront cache..."
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id $CLOUDFRONT_DIST_ID \
        --paths "/*" \
        --profile $AWS_PROFILE \
        --output text --query 'Invalidation.Id')

    echo "Invalidation created with ID: $INVALIDATION_ID"
}

cd $PROJECT_DIR

echo "Installing dependencies..."
npm install

echo "Building the project..."
npm run build

echo "Deploying to S3 bucket..."
aws s3 sync $BUILD_DIR s3://$S3_BUCKET --region $AWS_REGION --delete --profile $AWS_PROFILE

CLOUDFRONT_DIST_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Origins.Items[0].DomainName=='$S3_BUCKET.s3.amazonaws.com'].Id | [0]" \
    --output text --profile $AWS_PROFILE)

if [ "$CLOUDFRONT_DIST_ID" == "None" ]; then
    echo "No CloudFront distribution found for bucket $S3_BUCKET."
    create_cloudfront_distribution
else
    echo "CloudFront distribution already exists with ID: $CLOUDFRONT_DIST_ID"
fi

invalidate_cloudfront_cache

echo "Deployment complete."
