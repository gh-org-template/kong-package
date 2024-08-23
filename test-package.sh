#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

# Retries a command a configurable number of times with backoff.
function with_backoff {
  local max_attempts=${ATTEMPTS-5}
  local timeout=${TIMEOUT-5}
  local attempt=1
  local exitCode=0

  while (( $attempt < $max_attempts ))
  do
    if "$@"
    then
      return 0
    else
      exitCode=$?
    fi

    echo "Failure! Retrying in $timeout.." 1>&2
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done

  if [[ $exitCode != 0 ]]
  then
    echo "You've failed me for the last time! ($@)" 1>&2
  fi

  return $exitCode
}

function run_kong_tests() {
  local container_name="$1"

  # Perform Kong start/stop tests as Kong user
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong start'"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong health'"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "ps aux | grep nginx | grep -v grep | grep -q kong"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong restart'"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong health'"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "ps aux | grep nginx | grep -v grep | grep -q kong"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong stop'"

  # Perform Kong start/stop tests as root user
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "KONG_DATABASE=off kong start"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "KONG_DATABASE=off kong health"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "ps aux | grep nginx | grep -v grep | grep -q root"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "KONG_DATABASE=off kong restart"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "KONG_DATABASE=off kong health"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "ps aux | grep nginx | grep -v grep | grep -q root"
  docker exec ${USE_TTY} "${container_name}" /bin/bash -c "KONG_DATABASE=off kong stop"

  docker exec ${USE_TTY} "${container_name}" /bin/sh -c "ls -l /etc/kong/kong.conf.default"
  docker exec ${USE_TTY} "${container_name}" /bin/sh -c "ls -l /etc/kong/kong*.logrotate"
  docker exec ${USE_TTY} "${container_name}" /bin/sh -c "ls -l /usr/local/kong/include/google/protobuf/*.proto"
  docker exec ${USE_TTY} "${container_name}" /bin/sh -c "ls -l /usr/local/kong/include/openssl/*.h"
}

function main() {
  ARCHITECTURE=${ARCHITECTURE:-amd64}
  PACKAGE_TYPE=${PACKAGE_TYPE:-deb}

  USE_TTY="-t"
  test -t 1 && USE_TTY="-it"

  if [[ "$PACKAGE_TYPE" == "apk" ]]; then
    echo "Package type is APK, exiting..."
    exit 0
  fi

  if [[ "$PACKAGE_TYPE" == "rpm" ]]; then
    for OS_IMAGE in "redhat/ubi9" "amazonlinux:2023"; do
      container_name="package-validation-tests-${OS_IMAGE//[:.\/]/-}"

      docker run -d --rm \
        --name "${container_name}" \
        --platform="linux/$ARCHITECTURE" \
        -v "${PWD}/package:/src" \
        ${OS_IMAGE} \
        tail -f /dev/null || true

      docker exec ${USE_TTY} "${container_name}" /bin/bash -c "yum install -y /src/*.rpm procps util-linux"
      docker exec ${USE_TTY} "${container_name}" /bin/bash -c "kong version"

      run_kong_tests "${container_name}"
      docker kill "${container_name}"
      sleep 5
    done
  elif [[ "$PACKAGE_TYPE" == "deb" ]]; then
    for OS_IMAGE in "ubuntu:22.04" "debian:12"; do
      container_name="package-validation-tests-${OS_IMAGE//[:.]/-}"

      docker run -d --rm \
        --name "${container_name}" \
        --platform="linux/$ARCHITECTURE" \
        -v "${PWD}/package:/src" \
        ${OS_IMAGE} \
        tail -f /dev/null || true

      docker exec ${USE_TTY} "${container_name}" /bin/bash -c "apt-get update"
      docker exec ${USE_TTY} "${container_name}" /bin/bash -c "apt-get install -y perl-base zlib1g-dev procps"
      docker exec ${USE_TTY} "${container_name}" /bin/bash -c "apt install --yes /src/*.deb"
      docker exec ${USE_TTY} "${container_name}" /bin/bash -c "kong version"

      run_kong_tests "${container_name}"
      docker kill "${container_name}"
      sleep 5
    done
  fi
}

main "$@"
