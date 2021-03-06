#!/bin/bash -eu

# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.


# This is a helpful script to build MVFST in the supplied dir
# It pulls in dependencies such as folly and fizz in the _build/deps dir.

# Useful constants
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

usage() {
cat 1>&2 <<EOF

Usage ${0##*/} [-h|?] [-p PATH] [-i INSTALL_PREFIX]
  -p BUILD_DIR                           (optional): Path of the base dir for mvfst
  -i INSTALL_PREFIX                      (optional): install prefix path
  -h|?                                               Show this help message
EOF
}

while getopts ":hp:" arg; do
  case $arg in
    p)
      BUILD_DIR="${OPTARG}"
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done

# Validate required parameters
if [ -z "${BUILD_DIR-}" ] ; then
  echo -e "${COLOR_RED}[ INFO ] Build dir is not set. So going to build into _build ${COLOR_OFF}"
  BUILD_DIR=_build
  mkdir -p $BUILD_DIR
fi

### configure necessary build and install directories

cd $BUILD_DIR || exit
BWD=$(pwd)
DEPS_DIR=$BWD/deps
mkdir -p "$DEPS_DIR"

MVFST_BUILD_DIR=$BWD/build
mkdir -p "$MVFST_BUILD_DIR"

if [ -z "${INSTALL_PREFIX-}" ]; then
  FOLLY_INSTALL_DIR=$DEPS_DIR
  MVFST_INSTALL_DIR=$BWD
else
  FOLLY_INSTALL_DIR=$INSTALL_PREFIX
  MVFST_INSTALL_DIR=$INSTALL_PREFIX
fi

function install_dependencies_linux() {
  sudo apt-get install        \
    g++                       \
    cmake                     \
    libboost-all-dev          \
    libevent-dev              \
    libdouble-conversion-dev  \
    libgoogle-glog-dev        \
    libgflags-dev             \
    libiberty-dev             \
    liblz4-dev                \
    liblzma-dev               \
    libsnappy-dev             \
    make                      \
    zlib1g-dev                \
    binutils-dev              \
    libjemalloc-dev           \
    libssl-dev                \
    pkg-config                \
    libsodium-dev
}

function install_dependencies_mac() {
  # install the default dependencies from homebrew
  brew install               \
    cmake                    \
    boost                    \
    double-conversion        \
    gflags                   \
    glog                     \
    libevent                 \
    lz4                      \
    snappy                   \
    xz                       \
    openssl                  \
    libsodium

  brew link                 \
    boost                   \
    double-conversion       \
    gflags                  \
    glog                    \
    libevent                \
    lz4                     \
    snappy                  \
    xz                      \
    libsodium
}

function setup_folly() {
  FOLLY_DIR=$DEPS_DIR/folly
  FOLLY_BUILD_DIR=$DEPS_DIR/folly/build/

  if [ ! -d "$FOLLY_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning folly repo ${COLOR_OFF}"
    git clone https://github.com/facebook/folly.git "$FOLLY_DIR"
    echo -e "${COLOR_GREEN}[ INFO ] install dependencies ${COLOR_OFF}"
    if [ "$Platform" = "Linux" ]; then
      install_dependencies_linux
    elif [ "$Platform" = "Mac" ]; then
        install_dependencies_mac
    else
      echo -e "${COLOR_RED}[ ERROR ] Unknown platform: $Platform ${COLOR_OFF}"
      exit 1
    fi
  fi
  echo -e "${COLOR_GREEN}Building Folly ${COLOR_OFF}"
  mkdir -p "$FOLLY_BUILD_DIR"
  cd "$FOLLY_BUILD_DIR" || exit
  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo         \
    -DCMAKE_PREFIX_PATH="$FOLLY_INSTALL_DIR"      \
    -DCMAKE_INSTALL_PREFIX="$FOLLY_INSTALL_DIR"   \
    ..
  make -j "$(nproc)"
  make install
  cd "$BWD" || exit
}

function detect_platform() {
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     Platform=Linux;;
      Darwin*)    Platform=Mac;;
      *)          Platform="UNKNOWN:${unameOut}"
  esac
  echo -e "${COLOR_GREEN}Detected platform: $Platform ${COLOR_OFF}"
}

detect_platform
setup_folly

# build mvfst:
cd "$MVFST_BUILD_DIR" || exit
cmake -DCMAKE_PREFIX_PATH="$FOLLY_INSTALL_DIR"    \
 -DCMAKE_INSTALL_PREFIX="$MVFST_INSTALL_DIR"      \
 -DCMAKE_BUILD_TYPE=RelWithDebInfo                \
 -DBUILD_TESTS=On                                 \
  ../..
make -j "$(nproc)"
echo -e "${COLOR_GREEN}MVFST build is complete. To run unit test: \
  cd _build/build && make test ${COLOR_OFF}"
