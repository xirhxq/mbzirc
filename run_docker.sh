#!/usr/bin/env bash

#
# Script to run MBZIRC simulator with gimbal camera modifications
# Uses official osrf/mbzirc:mbzirc_sim_latest image with local code mount
#

set -e

# Configuration
DOCKER_IMAGE="osrf/mbzirc:mbzirc_sim_latest"
LOCAL_WS="${MBZIRC_WS:-/home/tbg/Repos/mbzirc_ws}"
LOCAL_MBZIRC="${LOCAL_WS}/src/mbzirc"
CONTAINER_NAME="mbzirc_sim"

# X11 authentication setup
XAUTH=/tmp/.docker.xauth
if [ ! -f $XAUTH ]; then
    xauth_list=$(xauth nlist $DISPLAY)
    if [ ! -z "$xauth_list" ]; then
        xauth_list=$(sed -e 's/^..../ffff/' <<< "$xauth_list")
        echo "$xauth_list" | xauth -f $XAUTH nmerge -
    else
        touch $XAUTH
    fi
    chmod a+r $XAUTH
fi

# NVIDIA runtime detection
DOCKER_OPTS=
if dpkg --compare-versions 19.03 gt "$(dpkg-query -f='${Version}' --show docker-ce 2>/dev/null | sed 's/[0-9]://')"; then
    echo "Using nvidia-docker2 runtime"
    DOCKER_OPTS="$DOCKER_OPTS --runtime=nvidia"
else
    DOCKER_OPTS="$DOCKER_OPTS --gpus all"
fi

echo "============================================"
echo "MBZIRC Gimbal Camera Docker Run Script"
echo "============================================"
echo "Image: $DOCKER_IMAGE"
echo "Local workspace: $LOCAL_WS"
echo "Local mbzirc: $LOCAL_MBZIRC"
echo ""
echo "Starting container..."
echo ""

# Check if local code exists
if [ ! -d "$LOCAL_MBZIRC" ]; then
    echo "Error: $LOCAL_MBZIRC does not exist!"
    echo "Please set MBZIRC_WS environment variable or ensure code is at $LOCAL_WS"
    exit 1
fi

# Run container
docker run -it \
    --name $CONTAINER_NAME \
    -e DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    -e XAUTHORITY=$XAUTH \
    -e IGNITION_VERSION=fortress \
    -v "$XAUTH:$XAUTH" \
    -v "/tmp/.X11-unix:/tmp/.X11-unix" \
    -v "/etc/localtime:/etc/localtime:ro" \
    -v "/dev/input:/dev/input" \
    -v "$LOCAL_MBZIRC:/home/developer/mbzirc_ws/src/mbzirc" \
    -v "$LOCAL_WS/install:/home/developer/mbzirc_ws/install" \
    -v "$LOCAL_WS/build:/home/developer/mbzirc_ws/build" \
    --network host \
    --rm \
    --privileged \
    --security-opt seccomp=unconfined \
    $DOCKER_OPTS \
    $DOCKER_IMAGE \
    /bin/bash

echo ""
echo "Container exited."
echo ""
echo "To rebuild mbzirc_ign package inside container:"
echo "  cd ~/mbzirc_ws"
echo "  source /opt/ros/galactic/setup.bash"
echo "  colcon build --packages-select mbzirc_ign --symlink-install"
echo "  source install/setup.bash"
