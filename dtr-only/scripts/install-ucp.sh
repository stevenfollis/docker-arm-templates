#!/bin/sh
#
# Install Docker Universal Control Plane on Ubuntu

# UCP URL
readonly UCP_FQDN=$1

# Is node a worker or manager?
readonly NODE_ROLE=$2

# Version of UCP to be installed
readonly UCP_VERSION=$3

# Name of current node
readonly NODE_NAME=$(cat /etc/hostname)

# UCP Administrator Credentials
readonly UCP_ADMIN='admin'
readonly UCP_PASSWORD='DockerEE123!'

# Non-standard UCP port
readonly UCP_CONTROLLER_PORT=5000

# Install jq library for parsing JSON
sudo apt-get -qq install jq -y

checkUCP() {

    # Check if UCP exists by attempting to hit its load balancer
    STATUS=$(curl --request GET --url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}" --insecure --silent --output /dev/null -w '%{http_code}' --max-time 5)
    
    echo "checkUCP: API status for ${UCP_FQDN}:${UCP_CONTROLLER_PORT} returned as: ${STATUS}"

    if [ "$STATUS" -eq 200 ]; then
        echo "checkUCP: Successfully queried the UCP API. UCP is installed. Joining node to existing cluster."
        joinUCP
    else
        echo "checkUCP: Failed to query the UCP API. UCP is not installed. Installing UCP."
        installUCP
    fi

}

installUCP() {
    
    echo "installUCP: Installing Docker Universal Control Plane (UCP)"

    # Install Universal Control Plane
    docker run \
        --rm \
        --name ucp \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        docker/ucp:"${UCP_VERSION}" install \
        --admin-username "${UCP_ADMIN}" \
        --admin-password "${UCP_PASSWORD}" \
        --controller-port "${UCP_CONTROLLER_PORT}" \
        --san "${UCP_FQDN}" \
        --skip-cloud-provider-check \
        --unmanaged-cni

    # Wait for node to reach a ready state
    until [ $(curl --request GET --url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}/_ping" --insecure --silent --header 'Accept: application/json' | grep OK) ]
    do
        echo '...created cluster, waiting for a ready state'
        sleep 5
    done

    echo "installUCP: Cluster's ping returned a ready state"

    echo "installUCP: Finished installing Docker Universal Control Plane (UCP)"

}

joinUCP() {

    # Get Authentication Token
    AUTH_TOKEN=$(curl --request POST --url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}/auth/login" --insecure --silent --header 'Accept: application/json' --data '{ "username": "'${UCP_ADMIN}'", "password": "'${UCP_PASSWORD}'" }' | jq --raw-output .auth_token)

    # Get Swarm Manager IP Address + Port
    UCP_MANAGER_ADDRESS=$(curl --request GET --url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}/info" --insecure --silent --header 'Accept: application/json' --header "Authorization: Bearer ${AUTH_TOKEN}" | jq --raw-output .Swarm.RemoteManagers[0].Addr)
    
    # Get Swarm Join Tokens
    UCP_JOIN_TOKENS=$(curl --request GET --url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}/swarm" --insecure --silent --header 'Accept: application/json' --header "Authorization: Bearer ${AUTH_TOKEN}" | jq .JoinTokens)
    UCP_JOIN_TOKEN_MANAGER=$(echo "${UCP_JOIN_TOKENS}" | jq --raw-output .Manager)
    UCP_JOIN_TOKEN_WORKER=$(echo "${UCP_JOIN_TOKENS}" | jq --raw-output .Worker)

    # Join Swarm
    if [ "$NODE_ROLE" = "Manager" ]
    then
        echo "joinUCP: Joining Swarm as a Manager"
        docker swarm join --token "${UCP_JOIN_TOKEN_MANAGER}" "${UCP_MANAGER_ADDRESS}"
    else
        echo "joinUCP: Joining Swarm as a Worker"
        docker swarm join --token "${UCP_JOIN_TOKEN_WORKER}" "${UCP_MANAGER_ADDRESS}"
    fi

    # Wait for node to reach a ready state
    while [ "$(curl --request GET --url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}/nodes/${NODE_NAME}" --insecure --silent --header 'Accept: application/json' --header "Authorization: Bearer ${AUTH_TOKEN}" | jq --raw-output .Status.State)" != "ready" ]
    do
        echo '...node joined, waiting for a ready state'
        sleep 5
    done

    echo "joinUCP: Finished joining node to UCP"

}

main() {
  checkUCP
}

main