#!/usr/bin/env bash
#
# Spawn quadrotor with gimbal camera in coast
# Usage: ./spawn_quadrotor_gimbal.sh [vehicle_name] [x] [y] [z]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

VEHICLE_NAME="${1:-quadrotor_1}"
X="${2:--1500}"
Y="${3:-2}"
Z="${4:-4.3}"

echo "============================================"
echo "Spawning Quadrotor with Gimbal Camera"
echo "============================================"
echo "Vehicle: $VEHICLE_NAME"
echo "Position: x=$X, y=$Y, z=$Z"
echo ""

# Source ROS2
source_ros2

# Check if simulation is running
if ! check_sim_running; then
    error "Simulation not running! Start it first:"
    echo "  ./tests/start_coast.sh"
    exit 1
fi

info "Spawning quadrotor with gimbal camera..."

ros2 launch mbzirc_ign spawn.launch.py \
    name:=${VEHICLE_NAME} \
    world:=coast \
    model:=mbzirc_quadrotor \
    x:=${X} \
    y:=${Y} \
    z:=${Z} \
    R:=0 \
    P:=0 \
    Y:=0 \
    slot0:=mbzirc_gimbal_camera

sleep 3
info "Waiting 5 seconds for vehicle to initialize..."
sleep 5

echo ""
success "Vehicle spawned!"
echo ""
echo "Next steps:"
echo "  ./tests/check_topics.sh ${VEHICLE_NAME}"
echo "  ./tests/test_gimbal_control.sh ${VEHICLE_NAME}"
