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

# Configure bitbake to use curl with SSL verification disabled for proxies
if [ -n "${HTTP_PROXY}" ] || [ -n "${HTTPS_PROXY}" ]; then
	echo "Configuring bitbake fetch commands for proxy compatibility"
	# Add curl/wget configuration to local.conf
	# Note: HTTP_PROXY, HTTPS_PROXY, NO_PROXY are passed as environment variables
	cat >> conf/local.conf << 'PROXYEOF'

# Curl options for proxy - disable SSL verification for corporate proxies doing SSL inspection
# and enable redirect following (Ford proxy returns HTTP 302)
FETCHCMD_curl = "/usr/bin/env curl -k -L -o ${DL_DIR}/${FILE} ${URI}"
FETCHCMD_wget = "/usr/bin/env wget --passive-ftp -O ${DL_DIR}/${FILE} -P ${DL_DIR} ${URI}"
PROXYEOF
fi

set -e
bitbake core-image-aesd
