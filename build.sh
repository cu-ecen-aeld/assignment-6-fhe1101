#!/bin/bash
# Script to build image for qemu.
# Author: Siddhant Jajoo.

git submodule init
git submodule sync
git submodule update

# local.conf won't exist until this step on first execution
source poky/oe-init-build-env

# Clean up any old proxy settings from local.conf that may cause parsing errors
if [ -f conf/local.conf ]; then
	echo "Cleaning up any broken proxy settings from local.conf"
	# Remove any lines containing proxy-related variables (even incomplete ones)
	sed -i '/ALL_PROXY\|HTTP_PROXY\|HTTPS_PROXY\|NO_PROXY\|BB_FETCH_DISABLE_SSL/d' conf/local.conf
	# Also remove any trailing stray quotes that might have been left
	sed -i '/^"$/d' conf/local.conf
fi

CONFLINE="MACHINE = \"qemuarm64\""

cat conf/local.conf | grep "${CONFLINE}" > /dev/null
local_conf_info=$?

if [ $local_conf_info -ne 0 ];then
	echo "Append ${CONFLINE} in the local.conf file"
	echo ${CONFLINE} >> conf/local.conf
	
else
	echo "${CONFLINE} already exists in the local.conf file"
fi


bitbake-layers show-layers | grep "meta-aesd" > /dev/null
layer_info=$?

if [ $layer_info -ne 0 ];then
	echo "Adding meta-aesd layer"
	bitbake-layers add-layer ../meta-aesd
else
	echo "meta-aesd layer already exists"
fi

# Configure bitbake to use proxy settings from environment variables
if [ -n "${HTTP_PROXY}" ] || [ -n "${HTTPS_PROXY}" ]; then
	echo "Configuring bitbake proxy settings"
	# Add proxy configuration to local.conf - bitbake needs these explicitly
	cat >> conf/local.conf << 'PROXYEOF'

# Proxy settings for fetchers (curl, wget, etc.)
ALL_PROXY ?= "${HTTP_PROXY}"
BB_FETCH_PREMIRRORONLY ?= "0"

# Curl options for proxy - disable SSL verification for corporate proxies doing SSL inspection
BB_FETCH_NETWORK_DLDIR ?= ""
FETCHCMD_wget = "/usr/bin/env wget --passive-ftp -O ${DL_DIR}/${FILE} -P ${DL_DIR} ${URI}"
FETCHCMD_curl = "/usr/bin/env curl -k -L -o ${DL_DIR}/${FILE} ${URI}"

# Allow bitbake to use standard environment proxy variables
PROXYEOF

	if [ -n "${HTTP_PROXY}" ]; then
		echo "HTTP_PROXY=${HTTP_PROXY}" >> conf/local.conf
	fi
	if [ -n "${HTTPS_PROXY}" ]; then
		echo "HTTPS_PROXY=${HTTPS_PROXY}" >> conf/local.conf
	fi
	if [ -n "${NO_PROXY}" ]; then
		echo "NO_PROXY=${NO_PROXY}" >> conf/local.conf
	fi
fi

set -e
bitbake core-image-aesd
