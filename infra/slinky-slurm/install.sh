#!/bin/bash

# Parse arguments for setup
RUN_SETUP=true
SETUP_ARGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-setup)
      RUN_SETUP=false
      shift
      ;;
    --help)
      echo "Bubbling up help from setup.sh..."
      ./setup.sh --help
      exit 0
      ;;
    --repo-name|--tag|--region)
      SETUP_ARGS="$SETUP_ARGS $1 $2"
      shift 2
      ;;
    --skip-build|--skip-repo)
      SETUP_ARGS="$SETUP_ARGS $1"
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [[ "$RUN_SETUP" == "true" ]]; then
  echo "Running setup..."
  ./setup.sh $SETUP_ARGS
else
  echo "Skipping setup..."
  # Check required variables in blueprint.tfvars
  if ! grep -q '^image_repository[[:space:]]*=[[:space:]]*\"[^\"]\+\"' ./terraform/blueprint.tfvars || \
     ! grep -q '^image_tag[[:space:]]*=[[:space:]]*\"[^\"]\+\"' ./terraform/blueprint.tfvars || \
     ! grep -q '^ssh_key[[:space:]]*=[[:space:]]*\"[^\"]\+\"' ./terraform/blueprint.tfvars; then
    echo "Error: image_repository, image_tag, and ssh_key must be set in blueprint.tfvars"
    echo "Run without --skip-setup flag to set these values, add --help for help"
    exit 1
  fi
fi

# Copy the base into the folder
mkdir -p ./terraform/_LOCAL
cp -r ../base/terraform/* ./terraform/_LOCAL
cp -r ./terraform/*.tf ./terraform/_LOCAL
cd terraform/_LOCAL

source ./install.sh

REGION="$(echo "var.region" | terraform console -var-file=../blueprint.tfvars | tr -d '"')"

# get the bucket name
S3_BUCKET_NAME=$(terraform output -raw fsx_s3_bucket_name)

# Copy sbatch to S3 bucket for DRA sync
aws s3 cp ../../examples/llama2_7b-training.sbatch s3://${S3_BUCKET_NAME}/ --region $REGION
