#!/usr/bin/env bash
#
# Stop all running simulations
#

echo "Stopping all simulations..."

# Kill ignition gazebo processes
pkill -f "ignition gazebo" || true

# Kill ros2 launch processes related to mbzirc
pkill -f "mbzirc_ros" || true
pkill -f "mbzirc_ign" || true

# Wait for processes to terminate
sleep 2

if pgrep -f "ignition gazebo" > /dev/null; then
    echo "Some processes still running. Force killing..."
    pkill -9 -f "ignition gazebo" || true
fi

echo "Done. All simulations stopped."
