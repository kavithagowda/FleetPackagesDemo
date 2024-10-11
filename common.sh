
#!/bin/bash
export BUILD_ACTIVE_TIMEOUT_SECS=20  # 20 seconds
export ACTIVE_ROLLOUT_START_TIMEOUT_SECS=120  # 2 minutes
export FLEETPACKAGE_STATE_TIMEOUT_SECS=20  # 20 seconds
export ROLLOUT_STATE_TIMEOUT_SECS=20  # 20 seconds
export ROLLOUT_COMPLETE_TIMEOUT_SECS=120  # 2 minutes
export ROLLOUT_STALLED_TIMEOUT_SECS=120  # 2 minutes
export POCO_INSTALL_TIMEOUT_SECS=180  # 3 minutes
export PROJECT_ID=fleetpackages-demo
export PROJECT_NUMBER=436345912671
alias gcloud=/google/src/cloud/mortent/config-delivery/google3/blaze-bin/cloud/sdk/gcloud/gcloud
watchUntilBuildActive() {
    SECONDS=0
    until (( SECONDS > BUILD_ACTIVE_TIMEOUT_SECS )); do
        output=$(gcloud alpha container fleet packages list)
        while IFS= read -r line; do
            if ! [[ $line =~ ^"$1" ]]; then
                continue
            fi
            if [[ $line =~ "Build status" ]]; then
                break 2
            fi
        done <<< "$output"
        sleep 2
    done
    (( SECONDS < BUILD_ACTIVE_TIMEOUT_SECS ))
}
watchUntilActiveRollout() {
    SECONDS=0
    rolloutName=""
    until (( SECONDS > ACTIVE_ROLLOUT_START_TIMEOUT_SECS )); do
        line=$(gcloud alpha container fleet packages rollouts list --fleet-package=$1 2>&1 | sed -n '2 p')
        if [[ $line =~ "IN_PROGRESS" ]]; then
            rolloutName=$(echo $line | awk '{print $1;}')
            break
        fi
        sleep 6
    done
    echo $rolloutName
}
#
# $1 is the name of the FleetPackage
# $2 is the desired value of the info.state field
#
waitUntilFleetPackageInfoState() {
    SECONDS=0
    until (( SECONDS > FLEETPACKAGE_STATE_TIMEOUT_SECS )); do
        state=$(gcloud alpha container fleet packages describe $1 --format=json | jq ".info.state")
        if [[ $state =~ $2 ]]; then
            break
        fi
        sleep 2
    done
    (( SECONDS < FLEETPACKAGE_STATE_TIMEOUT_SECS ))
}
waitUntilRolloutState() {
    SECONDS=0
    until (( COUNT > ROLLOUT_STATE_TIMEOUT_SECS )); do
        output=$(gcloud alpha container fleet packages rollouts list --fleet-package=$1 2>&1 | awk "/^$2/")
        if [[ $output =~ $3 ]]; then
            break
        fi
        sleep 2
    done
    (( SECONDS < ROLLOUT_STATE_TIMEOUT_SECS ))
}
watchUntilRolloutComplete() {
    p "watch gcloud alpha container fleet packages rollouts describe $2 --fleet-package=$1"
    tput clear && gcloud alpha container fleet packages rollouts describe $2 --fleet-package=$1
    SECONDS=0
    until (( COUNT > ROLLOUT_COMPLETE_TIMEOUT_SECS )); do
        sleep 10
        output=$(gcloud alpha container fleet packages rollouts describe $2 --fleet-package=$1)
        tput clear && echo "$output"
        rolloutStatus=$(echo "$output" | sed '$!d' | awk '{print $7;}')
        if [[ $rolloutStatus == "COMPLETED" ]]; then
            break
        fi
    done
    (( SECONDS < ROLLOUT_COMPLETE_TIMEOUT_SECS ))
}
watchUntilRolloutStalled() {
    p "watch gcloud alpha container fleet packages rollouts describe $2 --fleet-package=$1"
    tput clear && gcloud alpha container fleet packages rollouts describe $2 --fleet-package=$1
    SECONDS=0
    until (( SECONDS > ROLLOUT_STALLED_TIMEOUT_SECS )); do
        sleep 10
        output=$(gcloud alpha container fleet packages rollouts describe $2 --fleet-package=$1)
        tput clear && echo "$output"
        filtered=$(echo "$output" | awk "/^$3/")
        if [[ $filtered =~ "STALLED" ]]; then
            break
        fi
    done
    (( SECONDS < ROLLOUT_STALLED_TIMEOUT_SECS ))
}
printVersionAndCurlPod() {
    p "curl cluster $1"
    KUBECONFIG=./kubeconfig/$1 gcloud container clusters get-credentials $1 --zone $2 >/dev/null 2>&1
    KUBECONFIG=./kubeconfig/$1 kubectl describe deployments.apps $3 | grep "Image:"
    KUBECONFIG=./kubeconfig/$1 kubectl port-forward deployments/$3 8080:80 >/dev/null 2>&1 & pid=$!
    sleep 3
    curl localhost:8080
    echo ""
    kill $pid
}
#
# $1 is the name of the FleetPackage
#
waitAndWatchRollout() {
    p "Wait for the system to pick up the change..."
    watchUntilBuildActive $1
    pe "gcloud alpha container fleet packages list"
    p "Wait for the rollout to start..."
    rolloutName=$(watchUntilActiveRollout $1)
    if [[ -z $rolloutName ]]
    then
        echo "No rollout started. Check status of the Fleet Package"
        gcloud alpha container fleet packages list
        exit 1
    fi
    pe "gcloud alpha container fleet packages rollouts list --fleet-package=$1"
    p "Describe the latest rollout to see the details"
    if ! watchUntilRolloutComplete $1 $rolloutName
    then
        echo "Rollout didn't complete. Check output for errors"
        exit 1
    fi    
}
#
# $1 is the name of the membership
# $2 is the location of the membership
#
waitUntilPolicyControllerActive() {
    SECONDS=0
    until (( SECONDS > POCO_INSTALL_TIMEOUT_SECS )); do
        status=$(gcloud container fleet policycontroller describe --format=json | jq ".membershipStates.\"projects/$PROJECT_NUMBER/locations/$2/memberships/$1\".policycontroller.policyContentState.templateLibraryState.state")
        if [[ $status =~ "ACTIVE" ]]; then
            break
        fi
        sleep 5
    done
    (( SECONDS < POCO_INSTALL_TIMEOUT_SECS ))
}
