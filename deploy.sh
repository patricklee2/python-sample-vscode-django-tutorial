#!/bin/bash

# ----------------------
# KUDU Deployment Script
# Version: 1.0.17
# ----------------------

# Helpers
# -------

exitWithMessageOnError () {
  if [ ! $? -eq 0 ]; then
    echo "An error has occurred during web site deployment."
    echo $1
    exit 1
  fi
}

# Prerequisites
# -------------

# Verify node.js installed
hash node 2>/dev/null
exitWithMessageOnError "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment."

# Setup
# -----

SCRIPT_DIR="${BASH_SOURCE[0]%\\*}"
SCRIPT_DIR="${SCRIPT_DIR%/*}"
ARTIFACTS=$SCRIPT_DIR/../artifacts
KUDU_SYNC_CMD=${KUDU_SYNC_CMD//\"}

if [[ ! -n "$DEPLOYMENT_SOURCE" ]]; then
  DEPLOYMENT_SOURCE=$SCRIPT_DIR
fi

if [[ ! -n "$NEXT_MANIFEST_PATH" ]]; then
  NEXT_MANIFEST_PATH=$ARTIFACTS/manifest

  if [[ ! -n "$PREVIOUS_MANIFEST_PATH" ]]; then
    PREVIOUS_MANIFEST_PATH=$NEXT_MANIFEST_PATH
  fi
fi

if [[ ! -n "$DEPLOYMENT_TARGET" ]]; then
  DEPLOYMENT_TARGET=$ARTIFACTS/wwwroot
else
  KUDU_SERVICE=true
fi

if [[ ! -n "$KUDU_SYNC_CMD" ]]; then
  # Install kudu sync
  echo Installing Kudu Sync
  npm install kudusync -g --silent
  exitWithMessageOnError "npm failed"

  if [[ ! -n "$KUDU_SERVICE" ]]; then
    # In case we are running locally this is the correct location of kuduSync
    KUDU_SYNC_CMD=kuduSync
  else
    # In case we are running on kudu service this is the correct location of kuduSync
    KUDU_SYNC_CMD=$APPDATA/npm/node_modules/kuduSync/bin/kuduSync
  fi
fi

# Node Helpers
# ------------

selectPythonVersion () {
  if [[ -n "$KUDU_SELECT_PYTHON_VERSION_CMD" ]]; then
    SELECT_PYTHON_VERSION="$KUDU_SELECT_PYTHON_VERSION_CMD \"$DEPLOYMENT_SOURCE\" \"$DEPLOYMENT_TARGET\" \"$DEPLOYMENT_TEMP\""
    eval $SELECT_PYTHON_VERSION
    exitWithMessageOnError "select pyhon version failed"

    if [[ -e "$DEPLOYMENT_TEMP/__PYTHON_RUNTIME.tmp" ]]; then
      PYTHON_RUNTIME=`cat "$DEPLOYMENT_TEMP/__PYTHON_RUNTIME.tmp"`
      exitWithMessageOnError "getting python runtime failed"
    fi

    if [[ -e "$DEPLOYMENT_TEMP/__PYTHON_VER.tmp" ]]; then
      PYTHON_VER=`cat "$DEPLOYMENT_TEMP/__PYTHON_VER.tmp"`
      exitWithMessageOnError "getting python version failed"
    fi

    if [[ -e "$DEPLOYMENT_TEMP/__PYTHON_ENV_MODULE.tmp" ]]; then
      PYTHON_ENV_MODULE=`cat "$DEPLOYMENT_TEMP/__PYTHON_ENV_MODULE.tmp"`
      exitWithMessageOnError "getting python env failed"
    fi
    
    if [[ -e "$DEPLOYMENT_TEMP/__PYTHON_EXE.tmp" ]]; then
      PYTHON_EXE=`cat "$DEPLOYMENT_TEMP/__PYTHON_EXE.tmp"`
      exitWithMessageOnError "getting python exe failed"
    fi

    if [[ ! -n "$PYTHON_EXE" ]]; then
      PYTHON_EXE=python
    fi

  else
    PYTHON_RUNTIME=python-2.7
    PYTHON_VER=2.7
    PYTHON_ENV_MODULE=virtualenv
  fi
}

##################################################################################################################################
# Deployment
# ----------

echo Handling django deployment.

# 1. KuduSync
if [[ "$IN_PLACE_DEPLOYMENT" -ne "1" ]]; then
  "$KUDU_SYNC_CMD" -v 50 -f "$DEPLOYMENT_SOURCE" -t "$DEPLOYMENT_TARGET" -n "$NEXT_MANIFEST_PATH" -p "$PREVIOUS_MANIFEST_PATH" -i ".git;.hg;.deployment;deploy.sh"
  exitWithMessageOnError "Kudu Sync failed"
fi

# 2. Select python version
selectPythonVersion

:: 4. Install packages
echo Pip install requirements.
$DEPLOYMENT_TARGET/antenv/scripts/pip install -r requirements.txt

$DEPLOYMENT_TARGET/antenv/scripts/python manage.py migrate

#$DEPLOYMENT_TARGET/antenv/scripts/python manage.py runserver

##################################################################################################################################
echo "Finished successfully."
