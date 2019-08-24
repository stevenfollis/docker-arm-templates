#!/bin/sh
#
# Install Docker Trusted Registry on Ubuntu

# UCP URL
readonly UCP_FQDN=$1

# DTR URL
readonly DTR_FQDN=$2

# Version of DTR to be installed
readonly DTR_VERSION=$3

# Azure Storage Account
readonly AZURE_STORAGE_ACCOUNT=$4
readonly AZURE_STORAGE_KEY=$5
readonly AZURE_STORAGE_CONTAINER=$6

# Node to install DTR on
readonly UCP_NODE=$(cat /etc/hostname)

# UCP Admin credentials
readonly UCP_USERNAME="admin"
readonly UCP_PASSWORD='DockerEE123!'

# Non-standard UCP port
readonly UCP_CONTROLLER_PORT=5000

checkDTR() {

  # Check if DTR exists by attempting to hit its load balancer
  STATUS=$(curl --request GET --url "https://${DTR_FQDN}/_ping" --insecure --silent --output /dev/null -w '%{http_code}' --max-time 5)
  
  echo "checkDTR: API status for ${DTR_FQDN} returned as: ${STATUS}"

  if [ "$STATUS" -eq 200 ]; then
      echo "checkDTR: Successfully queried the DTR API. DTR is installed. Joining node to existing cluster."
      joinDTR
  else
      echo "checkDTR: Failed to query the DTR API. DTR is not installed. Installing DTR."
      installDTR
  fi

}

installDTR() {

  echo "installDTR: Installing ${DTR_VERSION} Docker Trusted Registry (DTR) on ${UCP_NODE} for UCP at ${UCP_FQDN} and with a DTR Load Balancer at ${DTR_FQDN}"

  # Install Docker Trusted Registry
  docker run \
    --rm \
    docker/dtr:${DTR_VERSION} install \
    --dtr-external-url "https://${DTR_FQDN}" \
    --ucp-url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}" \
    --ucp-node "${UCP_NODE}" \
    --ucp-username "${UCP_USERNAME}" \
    --ucp-password "${UCP_PASSWORD}" \
    --ucp-insecure-tls 

  echo "installDTR: Finished installing Docker Trusted Registry (DTR)"

  configureStorage

}

joinDTR() {

  # Get DTR Replica ID
  REPLICA_ID=$(curl --request GET --insecure --silent --url "https://${DTR_FQDN}/api/v0/meta/settings" --user "${UCP_USERNAME}":"${UCP_PASSWORD}" --header 'Accept: application/json' | jq --raw-output .replicaID)
  echo "joinDTR: Joining DTR with Replica ID ${REPLICA_ID}"

  # Join an existing Docker Trusted Registry
  docker run \
    --rm \
    docker/dtr:${DTR_VERSION} join \
    --existing-replica-id "${REPLICA_ID}" \
    --ucp-url "https://${UCP_FQDN}:${UCP_CONTROLLER_PORT}" \
    --ucp-node "${UCP_NODE}" \
    --ucp-username "${UCP_USERNAME}" \
    --ucp-password "${UCP_PASSWORD}" \
    --ucp-insecure-tls

}

configureStorage() {

  echo "configureStorage: Beginning configuration of Azure Storage"

  curl \
    --insecure \
    --request PUT \
    --url "https://${DTR_FQDN}/api/v0/admin/settings/registry/simple" \
    --user "${UCP_USERNAME}":"${UCP_PASSWORD}" \
    --header 'content-type: application/json' \
    --data "{
      \"storage\": {
        \"azure\": {
          \"accountkey\": \"${AZURE_STORAGE_KEY}\",
          \"accountname\": \"${AZURE_STORAGE_ACCOUNT}\",
          \"container\": \"${AZURE_STORAGE_CONTAINER}\",
          \"realm\": \"core.windows.net\"
        },
        \"delete\": {
          \"enabled\": true
        },
        \"maintenance\": {
          \"readonly\": {
            \"enabled\": false
          }
        }
      }
    }"

  echo "configureStorage: Finished configuration of Azure Storage"

}

main() {
  checkDTR
}

main