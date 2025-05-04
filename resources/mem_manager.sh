#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/resource_adapter.sh
source /opt/diycloud/lib/common.sh

# Setup memory cgroup for a user (cgroups v1)
setup_memory_cgroup_v1() {
    local username="$1"
    local mem_limit="$2"  # MB
    
    log_message "Setting up memory cgroup (v1) for user: ${username}" "info"
    
    # Convert to bytes
    local limit_bytes=$((mem_limit * 1024 * 1024))
    
    # Create user cgroup
    local cgroup_path="/sys/fs/cgroup/memory/user/${username}"
    ensure_directory "${cgroup_path}" "root:root" "755"
    
    # Set memory limit
    echo "${limit_bytes}" > "${cgroup_path}/memory.limit_in_bytes"
    
    # Add user processes to cgroup
    local user_processes=$(pgrep -u "${username}" || echo "")
    if [[ -n "${user_processes}" ]]; then
        for pid in ${user_processes}; do
            echo "${pid}" > "${cgroup_path}/tasks" 2>/dev/null || true
        done
    fi
    
    return 0
}

# Setup memory cgroup for a user (cgroups v2)
setup_memory_cgroup_v2() {
    local username="$1"
    local mem_limit="$2"  # MB
    
    log_message "Setting up memory cgroup (v2) for user: ${username}" "info"
    
    # Convert to bytes
    local limit_bytes=$((mem_limit * 1024 * 1024))
    
    # Create user cgroup
    local cgroup_path="/sys/fs/cgroup/user/${username}"
    ensure_directory "${cgroup_path}" "root:root" "755"
    
    # Enable memory controller
    echo "+memory" > "/sys/fs/cgroup/cgroup.subtree_control"
    
    # Set memory limit
    echo "${limit_bytes}" > "${cgroup_path}/memory.max"
    
    # Add user processes to cgroup
    local user_processes=$(pgrep -u "${username}" || echo "")
    if [[ -n "${user_processes}" ]]; then
        for pid in ${user_processes}; do
            echo "${pid}" > "${cgroup_path}/cgroup.procs" 2>/dev/null || true
        done
    fi
    
    return 0
}

# Apply memory limit to a user
apply_memory_limit() {
    local username="$1"
    local mem_limit="$2"  # MB
    
    log_message "Applying memory limit for user: ${username}" "info"
    
    # Use the Distribution Abstraction Layer to detect cgroup version
    if [[ "${CGROUP_VERSION}" == "v1" ]]; then
        setup_memory_cgroup_v1 "${username}" "${mem_limit}"
    elif [[ "${CGROUP_VERSION}" == "v2" ]]; then
        setup_memory_cgroup_v2 "${username}" "${mem_limit}"
    else
        log_message "Unknown cgroup version: ${CGROUP_VERSION}" "error"
        return 1
    fi
    
    return 0
}