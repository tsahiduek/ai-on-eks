#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'No model file supplied'
    exit 1
fi

# Load the variables
set -a  # Mark all variables for export
source $1 # Read the input variables from the environment file
set +a  # Stop auto-exporting

# Perform the substitution
envsubst < vllm-deployment.yaml > $SERVICE_NAME-$(date +%F_%H_%M_%S).yaml
