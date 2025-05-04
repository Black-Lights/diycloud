#!/bin/bash
#
# Copyright 2025 Black-Lights
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/common.sh

# Setup disk quota for a user
setup_disk_quota() {
    local username="$1"
    local soft_limit="$2"  # MB
    local hard_limit="$3"  # MB
    local mount_point="${4:-/home}"
    
    log_message "Setting up disk quota for user: ${username}" "info"
    
    # Install quota package if not installed
    if ! is_package_installed "quota"; then
        install_package "quota"
    fi
    
    # Check if quota is enabled on the filesystem
    if ! grep -q "usrquota" /etc/fstab; then
        log_message "Quota not enabled in /etc/fstab for ${mount_point}" "warning"
        log_message "To enable quota, add 'usrquota' to the mount options in /etc/fstab" "info"
        return 1
    fi
    
    # Convert to blocks (1 block = 1KB on most systems)
    local soft_blocks=$((soft_limit * 1024))
    local hard_blocks=$((hard_limit * 1024))
    
    # Set default inode limits
    local soft_inodes=0
    local hard_inodes=0
    
    # Make sure quota is turned on
    if command_exists "quotaon"; then
        quotaon -ugv "${mount_point}" 2>/dev/null || true
    fi
    
    # Set user quota
    if command_exists "setquota"; then
        setquota -u "${username}" "${soft_blocks}" "${hard_blocks}" "${soft_inodes}" "${hard_inodes}" "${mount_point}"
        return $?
    else
        log_message "setquota command not found" "error"
        return 1
    fi
}

# Get disk usage for a user
get_disk_usage() {
    local username="$1"
    local mount_point="${2:-/home}"
    
    if command_exists "quota"; then
        quota -u "${username}" 2>/dev/null || echo "No quota information available"
    elif command_exists "repquota"; then
        repquota -u "${mount_point}" 2>/dev/null | grep "${username}" || echo "No quota information available"
    else
        du -sh "/home/${username}" 2>/dev/null || echo "No usage information available"
    fi
}