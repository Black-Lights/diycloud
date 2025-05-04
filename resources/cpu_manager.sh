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
source /opt/diycloud/lib/resource_adapter.sh
source /opt/diycloud/lib/common.sh

# Setup CPU cgroup for a user (cgroups v1)
setup_cpu_cgroup_v1() {
    local username="$1"
    local cpu_limit="$2"  # Cores
    
    log_message "Setting up CPU cgroup (v1) for user: ${username}" "info"
    
    # Convert CPU limit to shares (1 core = 1024 shares)
    local cpu_shares=$((cpu_limit * 1024))
    
    # Convert CPU limit to quota (in microseconds)
    local period=100000  # 100ms
    local quota=$((cpu_limit * period))
    
    # Create user cgroup
    local cgroup_path="/sys/fs/cgroup/cpu/user/${username}"
    ensure_directory "${cgroup_path}" "root:root" "755"
    
    # Set CPU shares
    echo "${cpu_shares}" > "${cgroup_path}/cpu.shares"
    
    # Set CPU quota
    echo "${period}" > "${cgroup_path}/cpu.cfs_period_us"
    echo "${quota}" > "${cgroup_path}/cpu.cfs_quota_us"
    
    # Add user processes to cgroup
    local user_processes=$(pgrep -u "${username}" || echo "")
    if [[ -n "${user_processes}" ]]; then
        for pid in ${user_processes}; do
            echo "${pid}" > "${cgroup_path}/tasks" 2>/dev/null || true
        done
    fi
    
    return 0
}

# Setup CPU cgroup for a user (cgroups v2)
setup_cpu_cgroup_v2() {
    local username="$1"
    local cpu_limit="$2"  # Cores
    
    log_message "Setting up CPU cgroup (v2) for user: ${username}" "info"
    
    # Convert CPU limit to weight (1 core = 100 weight)
    local cpu_weight=$((cpu_limit * 100))
    if [[ ${cpu_weight} -lt 1 ]]; then
        cpu_weight=1
    fi
    
    # Convert CPU limit to max
    local period=100000  # 100ms
    local max=$((cpu_limit * period))
    
    # Create user cgroup
    local cgroup_path="/sys/fs/cgroup/user/${username}"
    ensure_directory "${cgroup_path}" "root:root" "755"
    
    # Enable CPU controller
    echo "+cpu" > "/sys/fs/cgroup/cgroup.subtree_control"
    
    # Set CPU weight
    echo "${cpu_weight}" > "${cgroup_path}/cpu.weight"
    
    # Set CPU max
    echo "${max} ${period}" > "${cgroup_path}/cpu.max"
    
    # Add user processes to cgroup
    local user_processes=$(pgrep -u "${username}" || echo "")
    if [[ -n "${user_processes}" ]]; then
        for pid in ${user_processes}; do
            echo "${pid}" > "${cgroup_path}/cgroup.procs" 2>/dev/null || true
        done
    fi
    
    return 0
}

# Apply CPU limit to a user
apply_cpu_limit() {
    local username="$1"
    local cpu_limit="$2"  # Cores
    
    log_message "Applying CPU limit for user: ${username}" "info"
    
    # Use the Distribution Abstraction Layer to detect cgroup version
    if [[ "${CGROUP_VERSION}" == "v1" ]]; then
        setup_cpu_cgroup_v1 "${username}" "${cpu_limit}"
    elif [[ "${CGROUP_VERSION}" == "v2" ]]; then
        setup_cpu_cgroup_v2 "${username}" "${cpu_limit}"
    else
        log_message "Unknown cgroup version: ${CGROUP_VERSION}" "error"
        return 1
    fi
    
    return 0
}