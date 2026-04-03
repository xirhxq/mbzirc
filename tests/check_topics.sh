#!/usr/bin/env bash
#
# Check available gimbal topics
# Usage: ./check_topics.sh [vehicle_name]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

VEHICLE_NAME="${1:-test_gimbal}"

echo "============================================"
echo "Checking Gimbal Topics"
echo "Vehicle: $VEHICLE_NAME"
echo "============================================"
echo ""

# Source ROS2
source_ros2

echo "--- All topics for ${VEHICLE_NAME} ---"
ros2 topic list | grep "/${VEHICLE_NAME}/" | sort

echo ""
echo "--- Gimbal Control Topics ---"
echo "Pitch control: /${VEHICLE_NAME}/slot0/gimbal/pitch/cmd_pos"
echo "Yaw control:   /${VEHICLE_NAME}/slot0/gimbal/yaw/cmd_pos"
echo ""

echo "--- Camera Topics ---"
echo "Image:          /${VEHICLE_NAME}/slot0/image_raw"
echo "Camera info:    /${VEHICLE_NAME}/slot0/camera_info"
echo ""

echo "--- Joint State Feedback ---"
echo "Joint states:   /${VEHICLE_NAME}/slot0/gimbal/joint_states"
echo ""

echo "--- Test with ---"
echo "  ros2 topic echo /${VEHICLE_NAME}/slot0/gimbal/joint_states"
echo "  ros2 run rqt_image_view rqt_image_view"
