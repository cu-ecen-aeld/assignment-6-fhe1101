#!/bin/bash
# Script to build image for qemu.
# Author: Siddhant Jajoo.

git submodule init
git submodule sync
git submodule update

# local.conf won't exist until this step on first execution
source poky/oe-init-build-env

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

# Add proxy settings if HTTP_PROXY is set
if [ -n "${HTTP_PROXY}" ]; then
	echo "Configuring proxy settings for Bitbake"
	echo "ALL_PROXY = \"${HTTP_PROXY}\"" >> conf/local.conf
	echo "HTTP_PROXY = \"${HTTP_PROXY}\"" >> conf/local.conf
	echo "HTTPS_PROXY = \"${HTTP_PROXY}\"" >> conf/local.conf
	if [ -n "${NO_PROXY}" ]; then
		echo "NO_PROXY = \"${NO_PROXY}\"" >> conf/local.conf
	fi
	# Disable SSL certificate verification if proxy has issues
	echo "BB_FETCH_DISABLE_SSL = \"0\"" >> conf/local.conf
fi

set -e
bitbake core-image-aesd
