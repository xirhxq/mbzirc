#!/usr/bin/env bash
#
# Start coast environment only (no vehicles)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

echo "============================================"
echo "Starting Coast Environment"
echo "============================================"
echo "Warning: Coast world is large and takes ~60 seconds to load"
echo ""

# Source ROS2
source_ros2

# Check if already running
if check_sim_running; then
    warn "Simulation is already running!"
    exit 1
fi

info "Launching coast environment..."
echo "GUI should appear in ~60 seconds..."
echo ""

ros2 launch mbzirc_ros competition_local.launch.py ign_args:="-v 4 -r coast.sdf"

# This will keep running until Ctrl+C
