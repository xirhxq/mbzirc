#!/usr/bin/env bash
#
# Test gimbal velocity control
# Usage: ./test_gimbal_control.sh [vehicle_name]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

VEHICLE_NAME="${1:-test_gimbal}"

# Simplified topic names (after bridge)
PITCH_VEL_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/pitch/cmd_vel"
YAW_VEL_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/yaw/cmd_vel"
JOINT_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/joint_states"
IMAGE_TOPIC="/${VEHICLE_NAME}/slot0/image_raw"

echo "============================================"
echo "Gimbal Velocity Control Test"
echo "Vehicle: $VEHICLE_NAME"
echo "============================================"
echo ""

# Check if topics exist
if ! ros2 topic list 2>/dev/null | grep -q "$PITCH_VEL_TOPIC"; then
    error "Vehicle $VEHICLE_NAME not found!"
    echo ""
    echo "Available gimbal topics:"
    ros2 topic list 2>/dev/null | grep "gimbal" | grep "cmd_vel" || echo "  None found"
    exit 1
fi

echo "Testing gimbal velocity control for: $VEHICLE_NAME"
echo ""

echo "Control Mode: Angular Velocity (rad/s)"
echo "Limits: Pitch [0 to -90°], Yaw [±180°]"
echo ""

# Function to display joint states
display_joint_state() {
    local output
    output=$(timeout 0.5 ros2 topic echo "$JOINT_TOPIC" 2>/dev/null || true)
    if [[ -n "$output" ]]; then
        local pitch=$(echo "$output" | grep -A1 "name:.*pitch_joint" | grep "position" | awk '{print $2}')
        local yaw=$(echo "$output" | grep -A1 "name:.*yaw_joint" | grep "position" | awk '{print $2}')
        if [[ -n "$pitch" && -n "$yaw" ]]; then
            local pitch_deg=$(awk "BEGIN{printf \"%.1f\", $pitch * 57.296}")
            local yaw_deg=$(awk "BEGIN{printf \"%.1f\", $yaw * 57.296}")
            printf "    Pitch: %6s° | Yaw: %6s°\n" "$pitch_deg" "$yaw_deg"
            return 0
        fi
    fi
    printf "    No joint state data\n"
    return 1
}

echo "============================================"
echo "  Test           | Command         | Joint State"
echo "============================================"

# Test 1: Stop (zero velocity)
printf "  1. Stop        | pitch: 0 rad/s  | "
ros2 topic pub -r 1 --once "$PITCH_VEL_TOPIC" std_msgs/msg/Float64 "data: 0.0" >/dev/null 2>&1 &
ros2 topic pub -r 1 --once "$YAW_VEL_TOPIC" std_msgs/msg/Float64 "data: 0.0" >/dev/null 2>&1 &
sleep 1.5
display_joint_state

# Test 2: Pitch down velocity
echo ""
printf "  2. Pitch -30°/s | pitch: -0.5 rad/s | "
ros2 topic pub -r 1 --once "$PITCH_VEL_TOPIC" std_msgs/msg/Float64 "data: -0.5" >/dev/null 2>&1
sleep 2
display_joint_state

# Test 3: Pitch down faster
echo ""
printf "  3. Pitch -60°/s | pitch: -1.0 rad/s | "
ros2 topic pub -r 1 --once "$PITCH_VEL_TOPIC" std_msgs/msg/Float64 "data: -1.0" >/dev/null 2>&1
sleep 2
display_joint_state

# Test 4: Stop pitch
echo ""
printf "  4. Stop pitch  | pitch: 0 rad/s  | "
ros2 topic pub -r 1 --once "$PITCH_VEL_TOPIC" std_msgs/msg/Float64 "data: 0.0" >/dev/null 2>&1
sleep 2
display_joint_state

# Test 5: Yaw left velocity
echo ""
printf "  5. Yaw +60°/s  | yaw: 1.0 rad/s   | "
ros2 topic pub -r 1 --once "$YAW_VEL_TOPIC" std_msgs/msg/Float64 "data: 1.0" >/dev/null 2>&1
sleep 2
display_joint_state

# Test 6: Yaw right velocity
echo ""
printf "  6. Yaw -60°/s  | yaw: -1.0 rad/s  | "
ros2 topic pub -r 1 --once "$YAW_VEL_TOPIC" std_msgs/msg/Float64 "data: -1.0" >/dev/null 2>&1
sleep 2
display_joint_state

# Test 7: Stop all
echo ""
printf "  7. Stop all    | all: 0 rad/s   | "
ros2 topic pub -r 1 --once "$PITCH_VEL_TOPIC" std_msgs/msg/Float64 "data: 0.0" >/dev/null 2>&1 &
ros2 topic pub -r 1 --once "$YAW_VEL_TOPIC" std_msgs/msg/Float64 "data: 0.0" >/dev/null 2>&1
sleep 2
display_joint_state

echo "============================================"
echo ""
success "Gimbal velocity control test completed!"
echo ""
echo "Monitor joint states:"
echo "  ros2 topic echo $JOINT_TOPIC"
echo ""
echo "View camera:"
echo "  ros2 run rqt_image_view rqt_image_view"
echo "  Select: $IMAGE_TOPIC"
echo ""
echo "Control topics (angular velocity in rad/s):"
echo "  $PITCH_VEL_TOPIC"
echo "  $YAW_VEL_TOPIC"
