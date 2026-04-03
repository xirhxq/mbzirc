#!/usr/bin/env bash
#
# Test gimbal HFOV (zoom) control with dynamics
# Usage: ./test_hfov.sh [vehicle_name]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

VEHICLE_NAME="${1:-test_gimbal}"

# HFOV control topic
HFOV_TOPIC="/${VEHICLE_NAME}/slot0/gimbal/set_hfov"

echo "============================================"
echo "Gimbal HFOV (Zoom) Control Test"
echo "Vehicle: $VEHICLE_NAME"
echo "============================================"
echo ""

# Check if topic exists
if ! ros2 topic list 2>/dev/null | grep -q "$HFOV_TOPIC"; then
    error "Vehicle $VEHICLE_NAME not found!"
    echo ""
    echo "Available HFOV topics:"
    ros2 topic list 2>/dev/null | grep "set_hfov" || echo "  None found"
    exit 1
fi

echo "Testing HFOV zoom control with dynamics:"
echo "  Focal length range: 4.5mm - 135mm"
echo "  Transition time: ~15 seconds (full range)"
echo "  HFOV range: ~2.4° - 84°"
echo ""

# Calculate HFOV from focal length: HFOV = 2 * atan(sensor_width / (2 * f))
# sensor_width = 6.17mm
hfov_from_focal() {
    local f=$1
    awk "BEGIN {rad = 2 * atan2(6.17, 2 * $f); deg = rad * 57.296; printf \"%.1f\", deg}"
}

echo "============================================"
echo "  Test           | Command      | Resulting HFOV"
echo "============================================"

# Test 1: Wide angle (4.5mm focal length)
printf "  1. Wide angle  | 4.5mm focal  | "
ros2 topic pub -r 1 --once "$HFOV_TOPIC" std_msgs/msg/Float64 "data: 84.0" >/dev/null 2>&1
echo "$(hfov_from_focal 4.5)° (HFOV: 84°)"
echo ""

# Test 2: Mid zoom (30mm focal length)
printf "  2. Mid zoom     | 30mm focal   | "
ros2 topic pub -r 1 --once "$HFOV_TOPIC" std_msgs/msg/Float64 "data: 11.8" >/dev/null 2>&1
echo "$(hfov_from_focal 30)° (HFOV: 11.8°)"
echo "     (Transition takes ~4.4 seconds)"
echo ""

# Test 3: Full zoom (135mm focal length)
printf "  3. Full zoom     | 135mm focal  | "
ros2 topic pub -r 1 --once "$HFOV_TOPIC" std_msgs/msg/Float64 "data: 2.6" >/dev/null 2>&1
echo "$(hfov_from_focal 135)° (HFOV: 2.6°)"
echo "     (Transition from wide takes ~15 seconds)"
echo ""

# Test 4: Back to wide
printf "  4. Back to wide | 4.5mm focal  | "
ros2 topic pub -r 1 --once "$HFOV_TOPIC" std_msgs/msg/Float64 "data: 84.0" >/dev/null 2>&1
echo "$(hfov_from_focal 4.5)° (HFOV: 84°)"
echo "     (Transition takes ~15 seconds)"

echo "============================================"
echo ""
success "HFOV zoom test completed!"
echo ""
echo "Control topic (HFOV in degrees):"
echo "  $HFOV_TOPIC"
echo ""
echo "Quick test commands:"
echo "  Wide (84°):   ros2 topic pub -1 $HFOV_TOPIC std_msgs/msg/Float64 'data: 84.0'"
echo "  Mid (11.8°):  ros2 topic pub -1 $HFOV_TOPIC std_msgs/msg/Float64 'data: 11.8'"
echo "  Tele (2.6°):  ros2 topic pub -1 $HFOV_TOPIC std_msgs/msg/Float64 'data: 2.6'"
echo ""
