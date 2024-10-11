#!/bin/bash
########################
# include the magic
########################
. demo-magic.sh
source ./common.sh
# TODO: Configure fleet-level defaults
p "Create GKE clusters"
pe "gcloud container clusters create gke-us-central1 --zone=us-central1-c --workload-pool=$PROJECT_ID.svc.id.goog --enable-fleet --async"
pe "gcloud container clusters create gke-us-west1 --zone=us-west1-a --workload-pool=$PROJECT_ID.svc.id.goog --enable-fleet --async"
pe "gcloud container clusters create gke-europe-north1 --zone=europe-north1-a --workload-pool=$PROJECT_ID.svc.id.goog --enable-fleet --async"
pe "gcloud container clusters create gke-europe-west1 --zone=europe-west1-b --workload-pool=$PROJECT_ID.svc.id.goog --enable-fleet --async"
# TODO: Wait for clusters to be RUNNING and then add the demo label to the memberships. Also add language labels
p "Create service account for Cloud Build"
pe "gcloud iam service-accounts create cfgdelivery-cloud-build-sa"
pe "gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:cfgdelivery-cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com --role=roles/configdelivery.resourceBundlePublisher --condition=None"
pe "gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:cfgdelivery-cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com --role=roles/logging.logWriter --condition=None"
p "Enable policy controller API on the project"
pe "gcloud services enable anthospolicycontroller.googleapis.com"
p "Enable policy controller on the two europe clusters"
pe "gcloud container fleet policycontroller enable --memberships=gke-europe-north1"
pe "gcloud container fleet policycontroller enable --memberships=gke-europe-west1"
PROMPT="%B%F{240}demo%f %(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )%{$reset_color%}"
