#!/bin/bash

# Authors
# -------
#  * Sebastian Blumenthal (blumenthal@locomotec.com)
#

show_usage() {
cat << EOF
Usage: ./${0##*/} [--no-sudo] [--workspace-path=PATH] [--install-path=PATH] [-h|--help] [-j=VALUE] 
E.g. ./${0##*/} --workspace-path=/workspace --install-path=/opt
E.g. as used by the Docker build process: ./${0##*/} --workspace-path=/opt --install-path=/usr/local --no-sudo -j=2
    -h|--help              Display this help and exit
    --no-sudo              In case the system has no sudo command available. ion.
    --workspace-path=PATH  Path to where libraries and bulild. Default is ../
    --install-path=PATH    Path to where libraries and modeles are installed (make install) into.
    --zmq-versions=LABEL   Indicates the version bundle to be used. STABLE is default. Options are STABLE|EDGE
    -j=VALUE               used for make -jVAULE 
EOF
}

# Error handling
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3; echo "ERROR occured. See install_err.log for details."; cd ${SCRIPT_DIR}; return 1' ERR SIGHUP SIGINT SIGQUIT SIGILL SIGABRT SIGTERM
exec > >(tee -a install.log) 2> >(tee -a install_err.log >&2)
#exec 1> install.log
#exec 2> install_err.log


rm -f install.log install_err.log

set -e
# Any subsequent(*) commands which fail will cause the shell script to exit immediately

# Default values
SUDO="sudo"
INSTALL_DIR="/usr/local/"
WORKSPACE_DIR="./" 
J="-j1"
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
ZMQ_VERSION_BUNDLE="STABLE"

# Handle command line options
while :; do
  case $1 in
    -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
      show_usage
      exit
      ;;
    --no-sudo)       
      SUDO=""
      ;;
    --workspace-path)       # Takes an option argument, ensuring it has been specified.
      if [ -n "$2" ]; then
           WORKSPACE_DIR=$2
          shift
       else
           printf 'ERROR: "--workspace-path" requires a non-empty option argument.\n' >&2
           exit 1
       fi
       ;;
    --workspace-path=?*)
       WORKSPACE_DIR=${1#*=} # Delete everything up to "=" and assign the remainder.
       ;;
    --workspace-path=)         # Handle the case of an empty --file=
      printf 'ERROR: "--workspace-path" requires a non-empty option argument.\n' >&2
      exit 1
       ;;
    --install-path)       # Takes an option argument, ensuring it has been specified.
      if [ -n "$2" ]; then
           INSTALL_DIR=$2
          shift
       else
           printf 'ERROR: "--install-path" requires a non-empty option argument.\n' >&2
           exit 1
       fi
       ;;
    --install-path=?*)
       INSTALL_DIR=${1#*=} # Delete everything up to "=" and assign the remainder.
       ;;
    --install-path=)         # Handle the case of an empty --file=
      printf 'ERROR: "--install-path" requires a non-empty option argument.\n' >&2
      exit 1
      ;;

    --zmq-versions)       # Takes an option argument, ensuring it has been specified.
      if [ -n "$2" ]; then
           ZMQ_VERSION_BUNDLE=$2
          shift
       else
           printf 'ERROR: "--zmq-versions" requires a non-empty option argument.\n' >&2
           exit 1
       fi
       ;;
    --zmq-versions=?*)
       ZMQ_VERSION_BUNDLE=${1#*=} # Delete everything up to "=" and assign the remainder.
       ;;
    --zmq-versions=)         # Handle the case of an empty --file=
      printf 'ERROR: "--zmq-versions" requires a non-empty option argument.\n' >&2
      exit 1
      ;;

    -j)       # Takes an option argument, ensuring it has been specified.
      if [ -n "$2" ]; then
           J="-j${2}"
          shift
       else
           printf 'ERROR: "-j" requires a non-empty option argument.\n' >&2
           exit 1
       fi
       ;;
    -j=?*)
       J_TMP=${1#*=} # Delete everything up to "=" and assign the remainder.
       J="-j${J_TMP}"
       ;;
    -j=)         # Handle the case of an empty --file=
      printf 'ERROR: "-j" requires a non-empty option argument.\n' >&2
      exit 1
      ;;


    --)              # End of all options.
       shift
       break
       ;;
    -?*)
       printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
        ;;
    *)               # Default case: If no more options then break out of the loop.
        break
  esac

shift
done

echo "[Parameter] Sudo command is set to: ${SUDO}"
echo "[Parameter] WORKSPACE_DIR is set to: ${WORKSPACE_DIR}"
echo "[Parameter] INSTALL_DIR is set to: ${INSTALL_DIR}"
echo "[Parameter] ZMQ_VERSION_BUNDLE is set to: ${ZMQ_VERSION_BUNDLE}"
echo "[Parameter] Parallel build parameter for make is set to: ${J}"

# Go to workspace
cd ${WORKSPACE_DIR}

################ Communication modules #########################
#             OLDSTABLE   MAX_ARCHIVE LATEST DEVWEEK1 STABLE EDGE
# libsodium   ?           ?           ?      1.0.15         
# libzmq      4.1.2       4.1.4       4.2.5  4.2.2    4.2.2  4.2.2
# czmq        3.0.2       4.0.2       4.1.1  4.0.2    4.0.2  4.1.1
# zyre        1.1.0       2.0.0       2.0.0  2.0.0    2.0.0  2.0.0

# default
ZMQ_VERSION=4.1.2
CZMQ_VERSION=3.0.2
ZYRE_VERSION=1.1.0 

# OLDSTABLE / default (used in SHERPA)
if [ ${ZMQ_VERSION_BUNDLE} = "OLDSTABLE" ]; then
  ZMQ_VERSION=4.1.2
  CZMQ_VERSION=3.0.2
  ZYRE_VERSION=1.1.0 
fi

# Exact version from first developers week (December 2017)
if [ ${ZMQ_VERSION_BUNDLE} = "DEVWEEK1" ]; then
  ZMQ_VERSION=4.2.2
  CZMQ_VERSION=4.0.2
  ZYRE_VERSION=2.0.0
fi

# Version to be used by rolled out version
if [ ${ZMQ_VERSION_BUNDLE} = "STABLE" ]; then
  ZMQ_VERSION=4.2.2
  CZMQ_VERSION=4.0.2
  ZYRE_VERSION=2.0.0
fi

# Version to be used by developers
if [ ${ZMQ_VERSION_BUNDLE} = "EDGE" ]; then
  ZMQ_VERSION=4.2.2
  CZMQ_VERSION=4.0.2
  ZYRE_VERSION=2.0.0
fi


echo ""
echo "### ZMQ communication modules  ###"
echo ""
echo "ZMQ_VERSION  = ${ZMQ_VERSION}"
echo "CZMQ_VERSION = ${CZMQ_VERSION}"
echo "ZYRE_VERSION = ${ZYRE_VERSION}"
echo "" 

echo "CZMQ dependencies:"
if [ ! -d libsodium ]; then
  git clone https://github.com/jedisct1/libsodium.git
fi
cd libsodium
git checkout stable
./autogen.sh
./configure 
make ${J}
${SUDO} make install
${SUDO} ldconfig
cd ..

echo "ZMQ library:"
# Wee need a stable verison of libzmq du to incompatibilities with Zyre. 
# Unfortunately there are no tags github so we have to use a tar ball.
#git clone https://github.com/zeromq/libzmq.git
#cd libzmq
if [ ! -d zeromq-${ZMQ_VERSION} ]; then
  if [ ${ZMQ_VERSION_BUNDLE} = "OLDSTABLE" ]; then
    wget http://download.zeromq.org/zeromq-${ZMQ_VERSION}.tar.gz
  else
    wget https://github.com/zeromq/libzmq/releases/download/v${ZMQ_VERSION}/zeromq-${ZMQ_VERSION}.tar.gz
  fi
  tar -xvf zeromq-${ZMQ_VERSION}.tar.gz
fi 
cd zeromq-${ZMQ_VERSION}
./autogen.sh
./configure --with-libsodium=no --prefix=${INSTALL_DIR}
make ${J}
${SUDO} make install
${SUDO} ldconfig
cd ..

echo "CZMQ library:"
#git clone https://github.com/zeromq/czmq
#cd czmq
if [ ! -d czmq-${CZMQ_VERSION} ]; then
  #wget https://github.com/zeromq/czmq/archive/v${CZMQ_VERSION}.tar.gz
  #tar zxvf v${CZMQ_VERSION}.tar.gz
  wget https://github.com/zeromq/czmq/releases/download/v${CZMQ_VERSION}/czmq-${CZMQ_VERSION}.tar.gz
  tar zxvf czmq-${CZMQ_VERSION}.tar.gz
fi
cd czmq-${CZMQ_VERSION}/
#./autogen.sh
./configure --prefix=${INSTALL_DIR}
make ${J}
${SUDO} make install
${SUDO} ldconfig
cd ..

echo "Zyre library:"
if [ ! -d zyre-${ZYRE_VERSION} ]; then
  wget https://github.com/zeromq/zyre/archive/v${ZYRE_VERSION}.tar.gz
  tar zxvf v${ZYRE_VERSION}.tar.gz
fi
cd zyre-${ZYRE_VERSION}/
sh ./autogen.sh
./configure --prefix=${INSTALL_DIR}
make ${J}
${SUDO} make install
${SUDO} ldconfig
cd ..

### Optional JSON library; used for validation
echo "Libvariant (JSON)"
if [ ! -d libvariant ]; then
  hg clone https://bitbucket.org/gallen/libvariant
fi
cd libvariant
mkdir build -p
cd build
cmake ..
cmake -DBUILD_SHARED_LIBS=true -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..
# Note that UBX modules need the -fPIC flag, thus we have to enable the shared flag for Libvariant.
make ${J}
${SUDO} make install
${SUDO} ldconfig
cd ..
cd ..



cd ${SCRIPT_DIR} # go back
set +e
echo "SUCCESS"
