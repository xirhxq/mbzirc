#!/usr/bin/env bash
#
# Utility functions for test scripts
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in Docker
check_docker_env() {
    if [[ -f /.dockerenv ]]; then
        info "Running inside Docker container"
    else
        warn "Not running in Docker. Use ./run_docker.sh first."
    fi
}

# Source ROS2 setup
source_ros2() {
    if [[ -f /opt/ros/galactic/setup.bash ]]; then
        source /opt/ros/galactic/setup.bash
    fi

    if [[ -f ~/mbzirc_ws/install/setup.bash ]]; then
        source ~/mbzirc_ws/install/setup.bash
    fi
}

# Check if Ignition Gazebo is running
check_sim_running() {
    pgrep -f "gzserver" > /dev/null || pgrep -f "ignition" > /dev/null
}

# Ask yes/no question
ask_yes_no() {
    local prompt="$1"
    local default="$2"

    local yn
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" yn
    yn=${yn:-$default}

    if [[ "$yn" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}
