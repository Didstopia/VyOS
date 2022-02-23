#!/usr/bin/env bash

# Enable debugging.
# set -x

## TODO: Copy this script to a temp file, then execute it, passing in
##       any arguments that were passed to this script.
##       Would this even work? Could we terminate the parent script,
##       while transferring control to the child? How?

# Start the script with a newline.
echo

# Setup error handling.
set -eE -o functrace -o pipefail

SCRIPT_PATH_FULL=$(realpath $0)
SCRIPT_PATH_DIR=$(dirname $SCRIPT_PATH_FULL)
# echo "SCRIPT_PATH_FULL: $SCRIPT_PATH_FULL"
# echo "SCRIPT_PATH_DIR: $SCRIPT_PATH_DIR"

# Switch to the script directory and store its full path.
CWD="$( cd "${SCRIPT_PATH_DIR}" && pwd )"
# echo "Switching to directory: $CWD"

# Setup default global variables.
VYOS_VERSION="equuleus"
VYOS_BUILD_CLEAN="false"

# Install GNU getopt to parse command line arguments,
# if we're on macOS and Homebrew is installed.
GETOPT_BIN="$(which getopt)"
if [ "$(uname)" == "Darwin" ]; then
  if [ -x "$(command -v brew)" ]; then
    ## FIXME: This path should be figured out automatically
    GETOPT_BIN_BREW="/usr/local/opt/gnu-getopt/bin/getopt"
    if [ ! -x "${GETOPT_BIN}" ]; then
      echoWarning "GNU getopt missing, installing..."
      brew install gnu-getopt
    fi
    GETOPT_BIN="${GETOPT_BIN_BREW}"
  fi
fi

# Function for displaying general usage.
help() {
  echo "Usage: [ -v | --version ]  <vyos-version>  (default: current)
       [ -c | --clean   ]                  (default: false)
       [ -h | --help    ]"
  exit 2
}

# Start by parsing command line arguments.
SHORT_OPTS=v:,c,h
LONG_OPTS=version:,clean,help
OPTS=$(${GETOPT_BIN} --alternative --options $SHORT_OPTS --longoptions $LONG_OPTS -- "$@") 

# Exit if there are any errors parsing the arguments.
if [ $? -ne 0 ]; then
  echo -e "\033[31mError parsing arguments.\033[0m"
  exit 1
fi

eval set -- "$OPTS"

# Override default variables with command line arguments.
while :
do
  case "$1" in
    -v | --version )
      VYOS_VERSION="$2"
      shift 2
      ;;
    -c | --clean )
      VYOS_BUILD_CLEAN="true"
      shift;
      break
      ;;
    -h | --help)
      help
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo -e "\033[31mUnexpected option: $1\033[0m"
      help
      ;;
  esac
done

# Validate the user specified VyOS version.
if [ "${VYOS_VERSION}" != "crux" ] && [ "${VYOS_VERSION}" != "equuleus" ] && [ "${VYOS_VERSION}" != "sagitta" ] && [ "${VYOS_VERSION}" != "current" ]; then
  echo -e "\033[31mUnexpected VyOS version: ${VYOS_VERSION}\033[0m"
  echo -e "Valid values: crux, equuleus, sagitta, current"
  exit 2
fi

# Validate the user specified VyOS build clean flag.
if [ "${VYOS_BUILD_CLEAN}" != "true" ] && [ "${VYOS_BUILD_CLEAN}" != "false" ]; then
  echo -e "\033[31mUnexpected VyOS build clean flag: ${VYOS_BUILD_CLEAN}\033[0m"
  echo -e "Valid values: true, false"
  exit 2
fi

# Function that returns the contents of
# a specific line in a file.
lineContents() {
  local lineno=$1
  sed -n ${lineno}p "${2}"
}

echoSuccess() {
  echo -e "\e[32m$1\e[0m"
}
echoError() {
  echo -e "\033[31m$1\033[0m"
}
echoWarning() {
  echo -e "\033[33m$1\033[0m"
}
echoLightGrey() {
  echo -e "\033[37m$1\033[0m"
}
echoGrey() {
  echo -e "\033[90m$1\033[0m"
}
echoSilver() {
  echo -e "\033[37m$1\033[0m"
}
# echoInfo() {
#   echo -e "\033[32m$1\033[0m"
# }
echoTrace() {
  echo -e "\033[34m$1\033[0m"
}
echoUnderline() {
  echo -e "\033[4m$1\033[0m"
}

# Function for reporting the error and line number.
failure() {
  # set -x
  local this="${SCRIPT_PATH_FULL}"
  local lineno=$1
  local cmd=$(echo $(eval "echo $2"))
  local script="${3:-${this}}"
  local contents=$(lineContents $lineno $this)
  echoError "[ERROR] [${script}:${lineno}]: ${cmd}"
  echo -n "  "
  echoUnderline "$(echo -e "${contents}" | sed 's/^[ \t]*//;s/[ \t]*$//')"
  # set +x
}

# Trap all errors and redirect to the failure function.
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

# Function for building the project.
build() {
  echoTrace "Building VyOS with parameters:"
  echoTrace "* Version: ${VYOS_VERSION}"
  echoTrace "* Clean Build: ${VYOS_BUILD_CLEAN}"
  echo

  # Ensure the working directory exists.
  mkdir -p .build

  # Clean the build directory if requested.
  if [ "${VYOS_BUILD_CLEAN}" == "true" ]; then
    echoTrace "Cleaning the build directory..."
    rm -rf .build/*
    echo
  fi

  ## FIXME: Checkout the correct version/branch and fetch latest changes (only if not a clean build?)
  # Clone the VyOS repository if it doesn't yet exist.
  if [ ! -d .build/.git ]; then
    echoTrace "Cloning the VyOS repository..."
    # git clone -b ${VYOS_VERSION} --depth 1 --single-branch https://github.com/vyos/vyos-build .build/
    # git clone -b ${VYOS_VERSION} --depth 1 https://github.com/vyos/vyos-build .build/
    git clone -b ${VYOS_VERSION} https://github.com/vyos/vyos-build .build/
    echo
  else
    echoTrace "Ensuring the VyOS repository is up to date..."
    cd .build
    set -x
    git fetch --depth 1 --prune
    git checkout ${VYOS_VERSION}
    git reset --hard origin/${VYOS_VERSION}
    set +x
    cd ..
    # (cd .build/ && git fetch --depth 1 --prune && git checkout ${VYOS_VERSION} && git reset --hard origin/${VYOS_VERSION})
    echo
  fi

  # Switch to the build directory.
  cd .build

  # Build the build container.
  echoTrace "Building the VyOS build container..."
  if [ "${VYOS_BUILD_CLEAN}" == "true" ]; then
    docker build --no-cache -q -t vyos/vyos-build:${VYOS_VERSION} docker
  else
    docker build -q -t vyos/vyos-build:${VYOS_VERSION} docker
  fi
  echo

  # Build the VyOS image.
  echoTrace "Building the VyOS image..."
  VYOS_ARCH="amd64"
  # VYOS_OS="buster64"
  # if [ "${VYOS_VERSION}" == "current" ]; then
  #   VYOS_OS="buster64"
  # elif [ "${VYOS_VERSION}" == "sagitta" ]; then
  #   VYOS_OS="buster64"
  # elif [ "${VYOS_VERSION}" == "equuleus" ]; then
  #   VYOS_OS="buster64"
  # elif [ "${VYOS_VERSION}" == "crux" ]; then
  #   VYOS_OS="jessie64"
  # fi
  BUILD_CMD="apt-get update && apt-get install -y --no-install-recommends dpkg-dev && ./configure --architecture ${VYOS_ARCH} --build-by Didstopia --build-type release --version 1.3.0 && sudo make iso && ls -l ./build/"
  docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:${VYOS_VERSION} bash -c "${BUILD_CMD}"
  echo

  # VyOS build complete.
  echoSuccess "Successfully built VyOS '${VYOS_VERSION}'!"
}

# Kick off the script by building VyOS from source.
build

# Exit cleanly.
exit 0
