#!/bin/bash
########################
# include the magic
########################
. demo-magic.sh
source ./common.sh
checkCluster() {
    if gcloud container clusters list | grep "$1" &> /dev/null; then
        echo "cluster $1 found"
    else
        echo "cluster $1 not found"
        exit 1
    fi
}
checkConfigSync() {
    if gcloud beta container fleet config-management status | grep "$1" &> /dev/null; then
        echo "cluster $1 has Config Sync"
    else
        echo "cluster $1 does not have Config Sync"
        exit 1
    fi
}
checkCloudBuildRepository() {
    if gcloud builds repositories list --region=us-central1 --connection=$1 | grep "$2" &> /dev/null; then
        echo "repository $2 is available"
    else
        echo "repository $2 for connection $1 was not found"
        exit 1
    fi
}
p "Setting fleetpackages-demo as the gcloud project"
pe "gcloud config set project fleetpackages-demo"
p "Validate that the expected clusters are available"
checkCluster "gke-us-central1"
checkCluster "gke-us-west1"
checkCluster "gke-europe-north1"
checkCluster "gke-europe-west1"
p "Set membership labels to the correct values"
pe "gcloud container fleet memberships update gke-us-central1 --update-labels=cluster-visibility=public,cluster-type=demo,language=en"
pe "gcloud container fleet memberships update gke-us-west1 --update-labels=cluster-visibility=public,cluster-type=demo,language=en"
pe "gcloud container fleet memberships update gke-europe-north1 --update-labels=cluster-visibility=private,cluster-type=demo,language=nb"
pe "gcloud container fleet memberships update gke-europe-west1 --update-labels=cluster-visibility=private,cluster-type=demo,language=es"
p "Validate that Config Sync is installed"
checkConfigSync "gke-us-central1"
checkConfigSync "gke-us-west1"
checkConfigSync "gke-europe-north1"
checkConfigSync "gke-europe-west1"
p "Enable policy controller on the two europe clusters"
pe "gcloud container fleet policycontroller enable --memberships=gke-europe-north1"
pe "gcloud container fleet policycontroller enable --memberships=gke-europe-west1"
p "Disable Policy Controller on the two US clusters"
pe "gcloud container fleet policycontroller disable --memberships=gke-us-central1"
pe "gcloud container fleet policycontroller disable --memberships=gke-us-west1"
p "Validate that the Cloud Build Repositories connections are available"
checkCloudBuildRepository "github" "nginx-demo"
checkCloudBuildRepository "github" "policy-demo"
