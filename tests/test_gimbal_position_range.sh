#!/usr/bin/env bash
#
# Test gimbal camera position control within specified ranges
# Pitch: test around -30 degrees (downward)
# Yaw: test +/- 60 degrees range
#
# Usage: ./test_gimbal_position_range.sh [vehicle_name]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

VEHICLE_NAME="${1:-quadrotor_1}"

echo "============================================"
echo "Gimbal Camera Position Range Test"
echo "============================================"
echo "Vehicle: $VEHICLE_NAME"
echo "Test Range:"
echo "  Pitch: -30 degrees (downward)"
echo "  Yaw: +/- 60 degrees"
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
if ! ros2 topic list 2>/dev/null | grep -q "${VEHICLE_NAME}/slot0/gimbal/pitch/target_angle"; then
    error "Vehicle $VEHICLE_NAME with gimbal camera not found!"
    echo "  Spawn it first:"
    echo "  ./tests/spawn_quadrotor_gimbal.sh ${VEHICLE_NAME}"
    exit 1
fi

PITCH_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/pitch/target_angle"
YAW_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/yaw/target_angle"
JOINT_STATES_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/joint_states"

# Pre-calculated radian values
PITCH_DOWN_30="-0.5236"
PITCH_CENTER="0.0"
PITCH_UP_30="0.5236"
YAW_LEFT_60="1.0472"
YAW_CENTER="0.0"
YAW_RIGHT_60="-1.0472"

# Function to get current joint position
get_joint_position() {
    local joint_name=$1
    timeout 2 ros2 topic echo "$JOINT_STATES_TOPIC" 2>/dev/null | \
        python3 -c "
import sys
import yaml

# Read YAML from stdin
for doc in yaml.safe_load_all(sys.stdin):
    if doc and 'name' in doc and 'position' in doc:
        try:
            idx = doc['name'].index('$joint_name')
            print(f\"{doc['position'][idx]:.6f}\")
            sys.exit(0)
        except (ValueError, IndexError):
            pass
sys.exit(1)
" 2>/dev/null | head -1
}

# Function to send position command
send_position() {
    local topic=$1
    local angle=$2
    ros2 topic pub --once "$topic" std_msgs/msg/Float64 "{data: $angle}" >/dev/null 2>&1
}

# Function to wait for gimbal to reach target
wait_for_position() {
    local target=$1
    local tolerance=0.05
    local max_wait=8
    local elapsed=0

    while [ $elapsed -lt $max_wait ]; do
        current=$(get_joint_position "pitch_joint")
        if [ -n "$current" ]; then
            # Use Python for floating point comparison
            diff=$(python3 -c "print(abs($current - $target))")
            if python3 -c "exit(0 if $diff < $tolerance else 1)"; then
                return 0
            fi
        fi
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    return 1
}

echo "=========================================="
echo "Phase 1: Center Position (Reset)"
echo "=========================================="
info "Sending center position command..."
send_position "$PITCH_TOPIC" "$PITCH_CENTER"
send_position "$YAW_TOPIC" "$YAW_CENTER"
sleep 5
PITCH_CENTER=$(get_joint_position "pitch_joint")
YAW_CENTER=$(get_joint_position "yaw_joint")
echo "Pitch center: $PITCH_CENTER rad"
echo "Yaw center: $YAW_CENTER rad"
echo ""

echo "=========================================="
echo "Phase 2: Pitch Down -30 degrees (negative = DOWN)"
echo "=========================================="
info "Sending pitch target: $PITCH_DOWN_30 rad (-30 degrees)"
send_position "$PITCH_TOPIC" "$PITCH_DOWN_30"
sleep 6
PITCH_ACTUAL=$(get_joint_position "pitch_joint")
echo "Expected: $PITCH_DOWN_30 rad"
echo "Actual:   $PITCH_ACTUAL rad"
echo ""

echo "=========================================="
echo "Phase 3: Yaw +60 degrees (LEFT)"
echo "=========================================="
info "Sending yaw target: $YAW_LEFT_60 rad (+60 degrees)"
send_position "$YAW_TOPIC" "$YAW_LEFT_60"
sleep 6
YAW_ACTUAL=$(get_joint_position "yaw_joint")
PITCH_ACTUAL=$(get_joint_position "pitch_joint")
echo "Expected: $YAW_LEFT_60 rad"
echo "Actual:   $YAW_ACTUAL rad"
echo "Pitch:   $PITCH_ACTUAL rad"
echo ""

echo "=========================================="
echo "Phase 4: Yaw -60 degrees (RIGHT)"
echo "=========================================="
info "Sending yaw target: $YAW_RIGHT_60 rad (-60 degrees)"
send_position "$YAW_TOPIC" "$YAW_RIGHT_60"
sleep 6
YAW_ACTUAL=$(get_joint_position "yaw_joint")
PITCH_ACTUAL=$(get_joint_position "pitch_joint")
echo "Expected: $YAW_RIGHT_60 rad"
echo "Actual:   $YAW_ACTUAL rad"
echo "Pitch:   $PITCH_ACTUAL rad"
echo ""

echo "=========================================="
echo "Phase 5: Combined - Pitch -30° (DOWN), Yaw +60° (LEFT)"
echo "=========================================="
info "Sending combined command..."
send_position "$PITCH_TOPIC" "$PITCH_DOWN_30"
send_position "$YAW_TOPIC" "$YAW_LEFT_60"
sleep 6
PITCH_ACTUAL=$(get_joint_position "pitch_joint")
YAW_ACTUAL=$(get_joint_position "yaw_joint")
echo "Pitch Expected: $PITCH_DOWN_30 rad (-30°)"
echo "Pitch Actual:   $PITCH_ACTUAL rad"
echo "Yaw Expected:   $YAW_LEFT_60 rad (+60°)"
echo "Yaw Actual:     $YAW_ACTUAL rad"
echo ""

echo "=========================================="
echo "Phase 6: Combined - Pitch -30° (DOWN), Yaw -60° (RIGHT)"
echo "=========================================="
info "Sending combined command..."
send_position "$PITCH_TOPIC" "$PITCH_DOWN_30"
send_position "$YAW_TOPIC" "$YAW_RIGHT_60"
sleep 6
PITCH_ACTUAL=$(get_joint_position "pitch_joint")
YAW_ACTUAL=$(get_joint_position "yaw_joint")
echo "Pitch Expected: $PITCH_DOWN_30 rad (-30°)"
echo "Pitch Actual:   $PITCH_ACTUAL rad"
echo "Yaw Expected:   $YAW_RIGHT_60 rad (-60°)"
echo "Yaw Actual:     $YAW_ACTUAL rad"
echo ""

echo "=========================================="
echo "Phase 7: Reset to Center"
echo "=========================================="
info "Resetting to center position..."
send_position "$PITCH_TOPIC" "$PITCH_CENTER"
send_position "$YAW_TOPIC" "$YAW_CENTER"
sleep 5
PITCH_FINAL=$(get_joint_position "pitch_joint")
YAW_FINAL=$(get_joint_position "yaw_joint")
echo "Pitch final: $PITCH_FINAL rad"
echo "Yaw final:   $YAW_FINAL rad"
echo ""

success "Test completed!"
echo ""
echo "Summary:"
echo "  Pitch control: Negative values = DOWN, Positive = UP"
echo "  Yaw control: Positive values = LEFT, Negative = RIGHT"
