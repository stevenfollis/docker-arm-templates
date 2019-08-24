#!/bin/bash
#
# Install Docker Enterprise Edition Engine on Ubuntu

# Store license URL
readonly DOCKER_EE_URL=$1

# Repository name for Docker EE Engine
readonly DOCKER_EE_VERSION=$2

installEngine() {

  echo "=================================================="
  echo "Beginning installation of Docker Enterprise Engine"
  echo "=================================================="
  
  # Update the apt package index
  sudo apt-get -qq update

  # Install packages to allow apt to use a repository over HTTPS
  sudo apt-get -qq install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  # Add Docker’s official GPG key using your customer Docker EE repository URL
  curl -fsSL "$DOCKER_EE_URL"/ubuntu/gpg | sudo apt-key add -

  # Set up the Docker repository
  sudo add-apt-repository \
   "deb [arch=$(dpkg --print-architecture)] $DOCKER_EE_URL/ubuntu \
   $(lsb_release -cs) \
   $DOCKER_EE_VERSION"

  # Update the apt package index
  sudo apt-get -qq update

  # Install the latest version of Docker EE
  # dpkg produces lots of chatter
  # redirect to abyss via https://askubuntu.com/a/258226
  sudo apt-get -qq install docker-ee docker-ee-cli containerd.io

  # Finished
  echo "=================================================="
  echo "Finished installing Docker EE Engine"
  echo "=================================================="

}

main() {
  installEngine
}

main