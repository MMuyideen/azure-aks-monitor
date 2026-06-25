#!/bin/bash


# Login to Azure (if not already logged in)
# az account show 1> /dev/null || az login   Already logged in on local environment

rg=tf-week5-state-rg
sa=tfpracticestorageweek5
container=tfpracticecontainer

# Resource group
az group create \
 --name $rg \
 --location eastus \
 --tags 'Project=Clodopsweek-4' 'Env=Demo'

# account
az storage account create \
 --resource-group $rg \
 --name $sa \
 --sku Standard_LRS \
 --encryption-services blob

# container
az storage container create --name $container \
 --account-name $sa