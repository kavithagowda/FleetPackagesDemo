#!/bin/bash
########################
# include the magic
########################
. demo-magic.sh
export PROMPT_TIMEOUT=1
export CBR_CONNECTION=github
export CBR_REPOSITORY=nginx-demo
source ./common.sh
p "Fleet has 4 clusters that we want to target. These have the label 'cluster-type=demo' on their memberships"
pe "gcloud container fleet memberships list --filter='labels.cluster-type=demo'"
p "The memberships have also the 'language' label"
pe "gcloud container fleet memberships describe gke-us-west1 | grep -A 3 'labels:' | grep --color -E 'language.*|$'"
pe "gcloud container fleet memberships describe gke-europe-west1 | grep -A 3 'labels:' | grep --color -E 'language.*|$'"
pe "gcloud container fleet memberships describe gke-us-central1 | grep -A 3 'labels:' | grep --color -E 'language.*|$'"
pe "gcloud container fleet memberships describe gke-europe-north1 | grep -A 3 'labels:' | grep --color -E 'language.*|$'"
p "Create a FleetPackage that installs nginx on all clusters in the fleet that have the label 'cluster-type=demo'"
cat <<EOF >fleet-package-spec.yaml
resourceBundleSelector:
  cloudBuildRepository:
    name: projects/$PROJECT_ID/locations/us-central1/connections/$CBR_CONNECTION/repositories/$CBR_REPOSITORY
    tag: v1.26.1
    serviceAccount: projects/$PROJECT_ID/serviceAccounts/cfgdelivery-cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com
    path: output
    variantsPattern: "*.yaml"
rolloutStrategy:
  rolling:
    maxConcurrent: 1
target:
  fleet:
    project: projects/$PROJECT_ID
    selector:
      matchLabels:
        cluster-type: demo
variantSelector:
  variantNameTemplate: \${membership.labels['language']}
deletionPropagationPolicy: ORPHAN
EOF
pe "grep --color -E 'tag.*|variantName.*|maxConcurrent.*|$' fleet-package-spec.yaml"
pe "gcloud alpha container fleet packages create nginx --source=fleet-package-spec.yaml"
p "Wait for the system to pick up the change..."
watchUntilBuildActive "nginx"
pe "gcloud alpha container fleet packages list"
p "Wait for the rollout to start..."
rolloutName=$(watchUntilActiveRollout "nginx")
if [[ -z $rolloutName ]]
then
    echo "No rollout started. Check status of the Fleet Package"
    gcloud alpha container fleet packages list
    exit 1
fi
pe "gcloud alpha container fleet packages rollouts list --fleet-package=nginx"
p "Describe the latest rollout to see the details"
if ! watchUntilRolloutComplete nginx $rolloutName
then
    echo "Rollout didn't complete. Check output for errors"
    exit 1
fi
p "Check nginx version and language in all clusters"
printVersionAndCurlPod gke-us-central1 us-central1-c nginx
printVersionAndCurlPod gke-us-west1 us-west1-a nginx
printVersionAndCurlPod gke-europe-north1 europe-north1-a nginx
printVersionAndCurlPod gke-europe-west1 europe-west1-b nginx
p "Update to version v1.27.0 of nginx change the number of concurrent clusters to 2"
cat <<EOF >fleet-package-spec.yaml
resourceBundleSelector:
  cloudBuildRepository:
    name: projects/$PROJECT_ID/locations/us-central1/connections/$CBR_CONNECTION/repositories/$CBR_REPOSITORY
    tag: v1.27.0
    serviceAccount: projects/$PROJECT_ID/serviceAccounts/cfgdelivery-cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com
    path: output
    variantsPattern: "*.yaml"
rolloutStrategy:
  rolling:
    maxConcurrent: 2
target:
  fleet:
    project: projects/$PROJECT_ID
    selector:
      matchLabels:
        cluster-type: demo
variantSelector:
  variantNameTemplate: \${membership.labels['language']}
deletionPropagationPolicy: ORPHAN
EOF
pe "grep --color -E 'tag.*|maxConcurrent.*|$' fleet-package-spec.yaml"
pe "gcloud alpha container fleet packages update nginx --source=fleet-package-spec.yaml"
p "Wait for the system to pick up the change..."
watchUntilBuildActive "nginx"
pe "gcloud alpha container fleet packages list"
p "Wait for the rollout to start..."
rolloutName=$(watchUntilActiveRollout "nginx")
if [[ -z $rolloutName ]]
then
    echo "No rollout started. Check status of the Fleet Package"
    gcloud alpha container fleet packages list
    exit 1
fi
pe "gcloud alpha container fleet packages rollouts list --fleet-package=nginx"
p "Describe the latest rollout to see the details"
if ! watchUntilRolloutComplete nginx $rolloutName
then
    echo "Rollout didn't complete. Check output for errors"
    exit 1
fi
p "Check nginx version and language in all clusters"
printVersionAndCurlPod gke-us-central1 us-central1-c nginx
printVersionAndCurlPod gke-us-west1 us-west1-a nginx
printVersionAndCurlPod gke-europe-north1 europe-north1-a nginx
printVersionAndCurlPod gke-europe-west1 europe-west1-b nginx
p "Verify that the FleetPackage has the deletionPropagationPolicy set to ORPHAN. This makes sure configuration is not deleted from the clusters"
pe "gcloud alpha container fleet packages describe nginx | grep --color -E 'deletionPropagationPolicy.*|$'"
p "Delete the FleetPackage. This removes the FleetPackage, but it will leave the configuration on the clusters"
pe "gcloud alpha container fleet packages delete nginx --force"
p "Check that nginx is still running on the clusters"
printVersionAndCurlPod gke-us-central1 us-central1-c nginx
printVersionAndCurlPod gke-us-west1 us-west1-a nginx
printVersionAndCurlPod gke-europe-north1 europe-north1-a nginx
printVersionAndCurlPod gke-europe-west1 europe-west1-b nginx
