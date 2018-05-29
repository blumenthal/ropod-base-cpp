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
    --with-rwm-deps        If set, also install cpp dependencies for the ROPOD World Model (RWM). 		 
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
RWM_DEPS=false

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

    --with-rwm-deps)       
      RWM_DEPS=true
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
echo "[Parameter] Option to install RWM dependencies is set to: ${RWM_DEPS}"

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

### Optional JSON library; used for validation; Requires libyaml-dev to be installed.
echo "Lib yaml" #Reqired correct parsing at BRICS_3D
${SUDO} apt-get install -y libyaml-dev

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

####################### RWM dependencies (optional) #######################
if [ "$RWM_DEPS" = true ]; then

  echo "" 
  echo "### Dependencies for the BRICS_3D libraries ###"
  echo "Boost:"
  ${SUDO} apt-get update
  ${SUDO} apt-get install -y libboost-dev \
                             libboost-thread-dev \
                             libboost-regex-dev

  echo "Eigen 3:"
  ${SUDO} apt-get install -y libeigen3-dev

  echo "Lib Cppunit for unit tests (optional):"
  ${SUDO} apt-get install -y libcppunit-dev

  echo "Lib Xerces for loading Open Street Maps"
  ${SUDO} apt-get install -y libxerces-c-dev

  #NOTE: apt-get install -y libyaml-dev is already installed earlier

  echo ""
  echo "### Compile and install BRICS_3D ###"

  if [ ! -d brics_3d ]; then
    git clone https://github.com/brics/brics_3d.git
    cd brics_3d
  else
    cd brics_3d
    git pull origin master
  fi

  mkdir build -p && cd build
  cmake -DEIGEN_INCLUDE_DIR=/usr/include/eigen3 -DUSE_JSON=true -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..
  # A note on the used flags: For some reason the CMake find script has problems to find Eigen3 thus we currently
  # have to provide the path as a flag. JSON support has to be enabled because it is not a default option.
  make ${J}
  cd ..
  #echo "export BRICS_3D_DIR=$PWD" >> ~/.bashrc
  export BRICS_3D_DIR=$PWD 
  #The BRICS_3D_DIR environment variable is needed for the other (below) modules to find BRICS_3D properly.
  #source ~/.bashrc .
  cd ..


  ######## BRICS_3D Function Blocks (plugins) ###########
  echo ""
  echo "###  BRICS_3D Function Blocks (plugins)  ###"

  echo "brics_3d_function_blocks:"
  # In case the BRICS_3D library is alredy installed
  # in another location you can use the environment
  # variable BRICS_3D_DIR to point to another installation location.
  if [ ! -d brics_3d_function_blocks ]; then 
    git clone https://github.com/blumenthal/brics_3d_function_blocks.git
    cd brics_3d_function_blocks
    git checkout develop
  else
    cd brics_3d_function_blocks
    git pull origin develop
  fi

  mkdir build -p && cd build
  cmake -DUSE_FBX=ON -DUSE_UBX=OFF -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..
  # In case you retrive a "Could NOT find BRICS_3D" delete the
  # CMake cache and try again. Sometimes the FindBRICS_3D script 
  # keeps the variables BRICS_3D_NOT_FOUND though the system is setup correctly. 
  make ${J}
  # Per default the UBX modules are installed to /usr/local
  # this can be adjusted be setting the CMake variable
  # CMAKE_INSTALL_PREFIX to another folder. 
  cd ..
  #echo "export FBX_MODULES=$PWD" >> ~/.bashrc
  export FBX_MODULES="${PWD}"
  # The FBX_MODULES environment variable is needed for the other (below) 
  # modules to find the BRICS_3D function blocks and typs.
  #source ~/.bashrc .
  cd ..


  echo "############################ATTENTION###############################"
  echo " ATTENTION: Please add the following environment variables:"
  echo ""
  echo "echo \"export BRICS_3D_DIR=${BRICS_3D_DIR}\" >> ~/.bashrc"
  echo "echo \"export FBX_MODULES=${FBX_MODULES}\" >> ~/.bashrc"


cd ..

fi

cd ${SCRIPT_DIR} # go back
set +e
echo "SUCCESS"
