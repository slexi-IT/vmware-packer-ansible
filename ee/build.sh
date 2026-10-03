#!/usr/bin/env bash
# Build the EE with Docker and push it to Harbor.
# Run: ee/build.sh <tag>      e.g. ee/build.sh 2026.10.03-2
# Needs a running Docker daemon and, once, `docker login harbor.bitlex.li` with a robot account
# that may push to the project awxee.
set -euo pipefail
cd "$(dirname "$0")"
TAG=${1:?usage: build.sh <tag>, a new one for every build}
IMAGE=harbor.bitlex.li/awxee/awx-ee-vmware-packer:$TAG

docker build -t "$IMAGE" .
docker push "$IMAGE"
echo "done: $IMAGE - set this tag in awx/config.yml, push, and run Apply AWX config"
