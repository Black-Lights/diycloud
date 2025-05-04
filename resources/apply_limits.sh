#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/resource_adapter.sh
source /opt/diycloud/lib/common.sh

# Source individual resource manager scripts
source /opt/diycloud/resources/cpu_manager.sh
source /opt/diycloud/resources/mem_manager.sh
source /opt/diycloud/resources/disk_manager.sh
source /opt/diycloud/resources/gpu_manager.sh

# Setup user cgroup
setup_user_cgroup() {
    local username="$1"
    
    log_message "Setting up user cgroup for: ${username}" "info"
    
    # Handle different cgroup versions
    if [[ "${CGROUP_VERSION}" == "v1" ]]; then
        # Create cgroup directories for each subsystem
        ensure_directory "/sys/fs/cgroup/cpu/user/${username}" "root:root" "755"
        ensure_directory "/sys/fs/cgroup/memory/user/${username}" "root:root" "755"
    elif [[ "${CGROUP_VERSION}" == "v2" ]]; then
        # Create unified cgroup directory
        ensure_directory "/sys/fs/cgroup/user/${username}" "root:root" "755"
        
        # Enable controllers
        echo "+cpu +memory" > "/sys/fs/cgroup/cgroup.subtree_control" 2>/dev/null || true
    else
        log_message "Unknown cgroup version: ${CGROUP_VERSION}" "error"
        return 1
    fi
    
    return 0
}

# Apply all resource limits for a user
apply_user_resource_limits() {
    local username="$1"
    local cpu_limit="$2"
    local mem_limit="$3"
    local disk_quota="$4"
    local gpu_access="${5:-false}"
    
    log_message "Applying resource limits for user: ${username}" "info"
    
    # Setup user cgroup
    setup_user_cgroup "${username}"
    
    # Apply CPU limit
    apply_cpu_limit "${username}" "${cpu_limit}"
    
    # Apply memory limit
    apply_memory_limit "${username}" "${mem_limit}"
    
    # Setup disk quota
    setup_disk_quota "${username}" "${disk_quota}" "$((disk_quota * 2))"
    
    # Configure GPU access if requested
    if [[ "${gpu_access}" == "true" ]]; then
        enable_gpu_access "${username}"
    else
        disable_gpu_access "${username}"
    fi
    
    log_message "Resource limits applied for user: ${username}" "info"
    return 0
}

# Update resource limits for a user
update_user_resource_limits() {
    local username="$1"
    local cpu_limit="$2"
    local mem_limit="$3"
    local disk_quota="$4"
    local gpu_access="${5:-false}"
    
    log_message "Updating resource limits for user: ${username}" "info"
    
    # Apply the new limits
    apply_user_resource_limits "${username}" "${cpu_limit}" "${mem_limit}" "${disk_quota}" "${gpu_access}"
    
    # Update database if it exists
    local db_file="/opt/diycloud/usermgmt/db/users.db"
    if [[ -f "${db_file}" ]]; then
        local user_id=$(sqlite3 "${db_file}" "SELECT id FROM users WHERE username='${username}';")
        if [[ -n "${user_id}" ]]; then
            log_message "Updating resource limits in database for user: ${username}" "info"
            sqlite3 "${db_file}" <<EOF
UPDATE resource_allocations 
SET cpu_limit=${cpu_limit}, mem_limit='${mem_limit}M', disk_quota='${disk_quota}M', gpu_access=${gpu_access} 
WHERE user_id=${user_id};
EOF
        fi
    fi
    
    return 0
}

# Get resource usage for a user
get_user_resource_usage() {
    local username="$1"
    
    log_message "Getting resource usage for user: ${username}" "info"
    
    # Get CPU usage
    echo "CPU Usage:"
    ps -u "${username}" -o %cpu,command | sort -nr | head -5
    
    # Get memory usage
    echo -e "\nMemory Usage:"
    ps -u "${username}" -o %mem,vsz,rss,command | sort -nr | head -5
    
    # Get disk usage
    echo -e "\nDisk Usage:"
    get_disk_usage "${username}"
    
    # Get GPU usage if available
    if is_nvidia_gpu_available; then
        echo -e "\nGPU Usage:"
        nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | \
            grep -E "$(pgrep -u ${username} | tr '\n' '|' | sed 's/|$//')" || echo "No GPU usage"
    fi
    
    return 0
}

# If this script is run directly (not sourced), perform a test
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for required argument
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <username> [cpu_limit] [mem_limit] [disk_quota] [gpu_access]"
        exit 1
    fi
    
    # Get arguments
    USERNAME="$1"
    CPU_LIMIT="${2:-1.0}"
    MEM_LIMIT="${3:-2048}"
    DISK_QUOTA="${4:-5120}"
    GPU_ACCESS="${5:-false}"
    
    # Apply resource limits
    apply_user_resource_limits "${USERNAME}" "${CPU_LIMIT}" "${MEM_LIMIT}" "${DISK_QUOTA}" "${GPU_ACCESS}"
    
    # Show resource usage
    get_user_resource_usage "${USERNAME}"
fi