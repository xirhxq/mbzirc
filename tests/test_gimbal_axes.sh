#!/usr/bin/env bash
#
# Test gimbal camera pitch and yaw axis movement
# Usage: ./test_gimbal_axes.sh [vehicle_name]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

VEHICLE_NAME="${1:-quadrotor_1}"
VEHICLE_NS="${VEHICLE_NAME}/${VEHICLE_NAME}"

echo "============================================"
echo "Gimbal Camera Axis Test"
echo "============================================"
echo "Vehicle: $VEHICLE_NAME"
echo ""

# Source ROS2
source_ros2

# Check if simulation is running
if ! check_sim_running; then
    error "Simulation not running! Start it first:"
    echo "  ./tests/start_coast.sh"
    exit 1
fi

# Check if vehicle exists
if ! ros2 topic list 2>/dev/null | grep -q "${VEHICLE_NAME}/slot0/gimbal/pitch/cmd_vel"; then
    error "Vehicle $VEHICLE_NAME with gimbal camera not found!"
    echo "  Spawn it first:"
    echo "  ./tests/spawn_quadrotor_gimbal.sh ${VEHICLE_NAME}"
    exit 1
fi

info "Testing gimbal axis movement..."
echo ""

# Function to stop all ongoing commands
cleanup() {
    pkill -f "gimbal/${VEHICLE_NAME}/" 2>/dev/null || true
}

trap cleanup EXIT

# Test 1: Pitch axis - positive command (should tilt DOWN)
echo "=========================================="
echo "Test 1: Pitch Axis - Positive (DOWN)"
echo "=========================================="
echo "Sending: +0.1 rad/s for 3 seconds"
echo "Expected: Camera should tilt DOWN"
echo ""

ros2 topic pub --rate 10 /${VEHICLE_NAME}/slot0/gimbal/pitch/cmd_vel std_msgs/msg/Float64 "{data: 0.1}" &
PITCH_PID=$!
sleep 3
kill $PITCH_PID 2>/dev/null || true

# Read current pitch position
PITCH_POS=$(timeout 2 ros2 topic echo /${VEHICLE_NAME}/slot0/gimbal/joint_states 2>/dev/null | grep -A1 "pitch_joint" | grep "position:" | head -1 | awk '{print $2}')
echo "Current pitch position: $PITCH_POS rad"
echo ""
read -p "Did the camera tilt DOWN? (y/n) " PITCH_DOWN_OK
echo ""

# Reset pitch to center
echo "Resetting pitch to center..."
ros2 topic pub --rate 10 /${VEHICLE_NAME}/slot0/gimbal/pitch/cmd_vel std_msgs/msg/Float64 "{data: -0.2}" &
RESET_PID=$!
sleep 2
kill $RESET_PID 2>/dev/null || true
sleep 1
echo ""

# Test 2: Yaw axis - positive command
echo "=========================================="
echo "Test 2: Yaw Axis - Positive"
echo "=========================================="
echo "Sending: +0.1 rad/s for 3 seconds"
echo "Expected: Camera should rotate horizontally"
echo ""

ros2 topic pub --rate 10 /${VEHICLE_NAME}/slot0/gimbal/yaw/cmd_vel std_msgs/msg/Float64 "{data: 0.1}" &
YAW_PID=$!
sleep 3
kill $YAW_PID 2>/dev/null || true

# Read current yaw position
YAW_POS=$(timeout 2 ros2 topic echo /${VEHICLE_NAME}/slot0/gimbal/joint_states 2>/dev/null | grep -A1 "yaw_joint" | grep "position:" | head -1 | awk '{print $2}')
echo "Current yaw position: $YAW_POS rad"
echo ""
read -p "Did the camera rotate? (y/n) " YAW_OK
echo ""

# Test 3: Slow continuous movement
echo "=========================================="
echo "Test 3: Slow Continuous Movement"
echo "=========================================="
echo "Sending pitch: +0.05 rad/s, yaw: +0.05 rad/s"
echo "Press Ctrl+C to stop"
echo ""

ros2 topic pub --rate 10 /${VEHICLE_NAME}/slot0/gimbal/pitch/cmd_vel std_msgs/msg/Float64 "{data: 0.05}" &
PITCH_PID=$!
ros2 topic pub --rate 10 /${VEHICLE_NAME}/slot0/gimbal/yaw/cmd_vel std_msgs/msg/Float64 "{data: 0.05}" &
YAW_PID=$!

# Wait for user interrupt
wait $PITCH_PID $YAW_PID

echo ""
success "Test completed!"
echo ""
echo "Summary:"
echo "  Pitch DOWN: ${PITCH_DOWN_OK}"
echo "  Yaw rotate: ${YAW_OK}"
