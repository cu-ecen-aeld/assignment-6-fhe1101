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

# Note: Proxy settings are passed via environment variables
# HTTP_PROXY, HTTPS_PROXY, and NO_PROXY are automatically used by bitbake fetchers
if [ -n "${HTTP_PROXY}" ]; then
	echo "Using proxy settings from environment: HTTP_PROXY=${HTTP_PROXY}"
fi

set -e
bitbake core-image-aesd
