#!/usr/bin/env bash

set -euo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function main {
  mkdir -p /tmp/build/lib/systemd/system/
  cp ${SCRIPT_DIR}/kong.service /tmp/build/lib/systemd/system/kong.service
  cp ${SCRIPT_DIR}/kong.logrotate /tmp/build/etc/kong/kong.logrotate
  cp $SCRIPT_DIR/.rpmmacros /root/.rpmmacros

  # Keep sync'd with the Dockerfile ARGS
  KONG_PACKAGE_NAME="${KONG_PACKAGE_NAME:=kong}"
  PACKAGE_CONFLICTS=${PACKAGE_CONFLICTS:=kong-enterprise-edition}
  PACKAGE_PROVIDES=${PACKAGE_PROVIDES:=kong-community-edition}
  PACKAGE_REPLACES=${PACKAGE_REPLACES:=kong-community-edition}
  PACKAGE_TYPE=${PACKAGE_TYPE:=deb}
  # Read the KONG_VERSION from /tmp/kong-version
  if [ -f /tmp/kong-version ]; then
    KONG_VERSION=$(cat /tmp/kong-version)
  else
    # Fallback if the file is not found or empty
    KONG_VERSION=${KONG_VERSION:=3.0.1}
  fi
  ARCHITECTURE=${ARCHITECTURE:=x86_64}
  TARGETARCH="amd64"
  if [ "${ARCHITECTURE}" == "x86_64" ]; then
    TARGETARCH="amd64"
  elif [ "${ARCHITECTURE}" == "aarch64" ]; then
    TARGETARCH="arm64"
  fi

  FPM_PARAMS=
  if [ "$PACKAGE_TYPE" == "deb" ]; then
    FPM_PARAMS="-d libpcre3 -d perl -d zlib1g-dev -d unzip"
  elif [ "$PACKAGE_TYPE" == "rpm" ]; then
    FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes -d zlib -d zlib-devel -d unzip"
    FPM_PARAMS="${FPM_PARAMS} -d hostname"
    FPM_PARAMS="${FPM_PARAMS} -d /usr/sbin/useradd -d /usr/sbin/groupadd"
    FPM_PARAMS="${FPM_PARAMS} -d libxcrypt-compat"
  fi

  PACKAGE_SUFFIX=""
  if [ "$PACKAGE_TYPE" == "apk" ]; then
    PACKAGE_SUFFIX=".${TARGETARCH}.apk"
    pushd /tmp/build
      mkdir /output
      tar -zcvf /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${PACKAGE_SUFFIX}.tar.gz usr etc
    popd
  else
    PACKAGE_SUFFIX="${PACKAGE_SUFFIX}.${TARGETARCH}"
    pushd /tmp/build
      set -x
      fpm -f -s dir \
        -t ${PACKAGE_TYPE} \
        -m 'support@konghq.com' \
        -n ${KONG_PACKAGE_NAME} \
        -v ${KONG_VERSION} \
        $FPM_PARAMS \
        --description 'Kong is a distributed gateway for APIs and Microservices, focused on high performance and reliability.' \
        --vendor 'Kong Inc.' \
        --license "ASL 2.0" \
        --conflicts $PACKAGE_CONFLICTS \
        --provides $PACKAGE_PROVIDES \
        --replaces $PACKAGE_REPLACES \
        --after-install '/fpm/after-install.sh' \
        --url 'https://getkong.org/' usr etc lib \
      && mkdir /output/ \
      && mv kong*.* /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${PACKAGE_SUFFIX}.${PACKAGE_TYPE}
      set -x
      if [ "${PACKAGE_TYPE}" == "rpm" ] && [ ! -z "${PRIVATE_KEY_PASSPHRASE:-}" ]; then
        apt-get update
        apt-get install -y expect
        mkdir -p ~/.gnupg/
        touch ~/.gnupg/gpg.conf
        echo use-agent >> ~/.gnupg/gpg.conf
        echo pinentry-mode loopback >> ~/.gnupg/gpg.conf
        echo allow-loopback-pinentry >> ~/.gnupg/gpg-agent.conf
        echo RELOADAGENT | gpg-connect-agent
        cp /.rpmmacros ~/
        gpg --batch --import /kong.private.asc
        /sign-rpm.exp /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${PACKAGE_SUFFIX}.${PACKAGE_TYPE}
      fi
    popd
  fi
}

main
