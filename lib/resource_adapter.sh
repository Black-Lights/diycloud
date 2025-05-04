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
#
# DIY Cloud Platform - Resource Management Adaptation Script
# 
# This script provides resource management functions that abstract away
# distribution-specific resource management implementations.
# Supports both cgroups v1 and v2.
#
# Usage: source resource_adapter.sh

# Ensure detect_distro.sh and path_resolver.sh are sourced
if [[ -z "${DISTRO}" || -z "${CGROUP_VERSION}" ]]; then
    if [[ -f "$(dirname "$0")/detect_distro.sh" ]]; then
        source "$(dirname "$0")/detect_distro.sh"
    else
        echo "Error: detect_distro.sh not found or not sourced"
        return 1
    fi
fi

if ! type get_cgroup_path &> /dev/null; then
    if [[ -f "$(dirname "$0")/path_resolver.sh" ]]; then
        source "$(dirname "$0")/path_resolver.sh"
    else
        echo "Error: path_resolver.sh not found or not sourced"
        return 1
    fi
fi

# Calculate system resources
CPU_CORES=$(nproc)
TOTAL_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# Convert kB to MB
TOTAL_MEMORY=$((TOTAL_MEMORY / 1024))

# Get swap size and usage
TOTAL_SWAP=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
# Convert kB to MB
TOTAL_SWAP=$((TOTAL_SWAP / 1024))
SWAP_AVAILABLE=0
if [[ ${TOTAL_SWAP} -gt 0 ]]; then
    SWAP_AVAILABLE=1
fi

# Function to check if quota is available on filesystem
# Usage: is_quota_available "filesystem"
is_quota_available() {
    local filesystem="$1"
    
    # Check if quota is installed
    if ! command -v quotacheck &> /dev/null; then
        echo "Quota tools not installed"
        return 1
    fi
    
    # Check if the filesystem supports quota
    if ! grep -q "${filesystem}" /proc/mounts; then
        echo "Filesystem ${filesystem} not mounted"
        return 1
    fi
    
    # Check if quota mount options are enabled
    if ! grep -q "${filesystem}.*usrquota" /proc/mounts && ! grep -q "${filesystem}.*quota" /proc/mounts; then
        echo "Quota not enabled on ${filesystem}"
        return 1
    fi
    
    return 0
}

# Function to setup cgroups for user
# Usage: setup_user_cgroup "username"
setup_user_cgroup() {
    local username="$1"
    local cgroup_path
    
    echo "Setting up cgroup for user: ${username}"
    
    # Get the appropriate cgroup path
    if [[ "${CGROUP_VERSION}" == "v2" ]]; then
        # cgroups v2
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        
        # Ensure the cgroup exists
        mkdir -p "${cgroup_path}"
        
        # Enable controllers
        echo "+cpu +memory +io" > "$(get_cgroup_path)/cgroup.subtree_control"
        
    elif [[ "${CGROUP_VERSION}" == "hybrid" ]]; then
        # Hybrid hierarchy - use unified hierarchy for simplicity
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        
        # Ensure the cgroup exists
        mkdir -p "${cgroup_path}"
        
        # Enable controllers
        echo "+cpu +memory +io" > "$(get_cgroup_path)/cgroup.subtree_control"
        
    else 
        # cgroups v1
        # Create user cgroup for CPU
        cgroup_path="$(get_cgroup_path "cpu")/user/${username}"
        mkdir -p "${cgroup_path}"
        
        # Create user cgroup for memory
        mkdir -p "$(get_cgroup_path "memory")/user/${username}"
    fi
    
    echo "User cgroup created at: ${cgroup_path}"
    return 0
}

# Function to apply CPU limit for a user
# Usage: apply_cpu_limit "username" "cpu_limit"
# cpu_limit is a float representing number of CPU cores
apply_cpu_limit() {
    local username="$1"
    local cpu_limit="$2"
    local cpu_shares
    local cpu_quota
    local cpu_period=100000  # 100ms in microseconds (standard period)
    local cgroup_path
    
    # Calculate CPU shares (for cgroups v1)
    # 1024 is the default share value for 1 CPU
    cpu_shares=$(echo "${cpu_limit} * 1024" | bc | cut -d. -f1)
    
    # Calculate CPU quota (for cgroups v1)
    # This is in microseconds
    cpu_quota=$(echo "${cpu_limit} * ${cpu_period}" | bc | cut -d. -f1)
    
    echo "Applying CPU limit of ${cpu_limit} cores for user ${username}"
    
    if [[ "${CGROUP_VERSION}" == "v2" ]]; then
        # cgroups v2
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        
        # Ensure the cgroup exists
        if [[ ! -d "${cgroup_path}" ]]; then
            setup_user_cgroup "${username}"
        fi
        
        # Set CPU weight (equivalent to shares in v1)
        echo "${cpu_shares}" > "${cgroup_path}/cpu.weight"
        
        # Set CPU max (quota and period)
        echo "${cpu_quota} ${cpu_period}" > "${cgroup_path}/cpu.max"
        
    elif [[ "${CGROUP_VERSION}" == "hybrid" ]]; then
        # Hybrid hierarchy
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        
        # Ensure the cgroup exists
        if [[ ! -d "${cgroup_path}" ]]; then
            setup_user_cgroup "${username}"
        fi
        
        # Set CPU weight (equivalent to shares in v1)
        echo "${cpu_shares}" > "${cgroup_path}/cpu.weight"
        
        # Set CPU max (quota and period)
        echo "${cpu_quota} ${cpu_period}" > "${cgroup_path}/cpu.max"
        
    else
        # cgroups v1
        cgroup_path="$(get_cgroup_path "cpu")/user/${username}"
        
        # Ensure the cgroup exists
        if [[ ! -d "${cgroup_path}" ]]; then
            setup_user_cgroup "${username}"
        fi
        
        # Set CPU shares
        echo "${cpu_shares}" > "${cgroup_path}/cpu.shares"
        
        # Set CPU quota
        echo "${cpu_quota}" > "${cgroup_path}/cpu.cfs_quota_us"
        echo "${cpu_period}" > "${cgroup_path}/cpu.cfs_period_us"
    fi
    
    echo "CPU limit applied successfully for user ${username}"
    return 0
}

# Function to apply memory limit for a user
# Usage: apply_memory_limit "username" "memory_limit" ["swap_limit"]
# memory_limit is in MB
# swap_limit is in MB, if not provided, no swap is allowed
apply_memory_limit() {
    local username="$1"
    local memory_limit="$2"
    local swap_limit="${3:-0}"
    local memory_limit_bytes
    local swap_limit_bytes
    local total_limit_bytes
    local cgroup_path
    
    # Convert MB to bytes
    memory_limit_bytes=$((memory_limit * 1024 * 1024))
    swap_limit_bytes=$((swap_limit * 1024 * 1024))
    total_limit_bytes=$((memory_limit_bytes + swap_limit_bytes))
    
    # Check if swap is available if swap_limit > 0
    if [[ ${swap_limit} -gt 0 && ${SWAP_AVAILABLE} -eq 0 ]]; then
        echo "Warning: Swap requested but not available on the system. Only RAM limits will be applied."
        swap_limit=0
        swap_limit_bytes=0
        total_limit_bytes=${memory_limit_bytes}
    fi
    
    echo "Applying memory limit of ${memory_limit} MB and swap limit of ${swap_limit} MB for user ${username}"
    
    if [[ "${CGROUP_VERSION}" == "v2" ]]; then
        # cgroups v2
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        
        # Ensure the cgroup exists
        if [[ ! -d "${cgroup_path}" ]]; then
            setup_user_cgroup "${username}"
        fi
        
        # Set memory limit (RAM only)
        echo "${memory_limit_bytes}" > "${cgroup_path}/memory.max"
        
        # Set swap limit
        if [[ -f "${cgroup_path}/memory.swap.max" ]]; then
            echo "${swap_limit_bytes}" > "${cgroup_path}/memory.swap.max"
            echo "Swap limit applied: ${swap_limit} MB"
        else
            # If swap control is not available, set high+swap limit
            echo "${total_limit_bytes}" > "${cgroup_path}/memory.max"
            echo "Direct swap control not available, using combined memory limit"
        fi
        
    elif [[ "${CGROUP_VERSION}" == "hybrid" ]]; then
        # Hybrid hierarchy
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        
        # Ensure the cgroup exists
        if [[ ! -d "${cgroup_path}" ]]; then
            setup_user_cgroup "${username}"
        fi
        
        # Set memory limit (RAM only)
        echo "${memory_limit_bytes}" > "${cgroup_path}/memory.max"
        
        # Set swap limit
        if [[ -f "${cgroup_path}/memory.swap.max" ]]; then
            echo "${swap_limit_bytes}" > "${cgroup_path}/memory.swap.max"
            echo "Swap limit applied: ${swap_limit} MB"
        else
            # If swap control is not available, set high+swap limit
            echo "${total_limit_bytes}" > "${cgroup_path}/memory.max"
            echo "Direct swap control not available, using combined memory limit"
        fi
        
    else
        # cgroups v1
        cgroup_path="$(get_cgroup_path "memory")/user/${username}"
        
        # Ensure the cgroup exists
        if [[ ! -d "${cgroup_path}" ]]; then
            setup_user_cgroup "${username}"
        fi
        
        # Set memory limit (RAM only)
        echo "${memory_limit_bytes}" > "${cgroup_path}/memory.limit_in_bytes"
        
        # Set memory+swap limit (total limit)
        if [[ ${swap_limit} -gt 0 ]]; then
            echo "${total_limit_bytes}" > "${cgroup_path}/memory.memsw.limit_in_bytes"
            echo "Total memory+swap limit applied: $((memory_limit + swap_limit)) MB"
        else
            # Disable swap by setting memsw limit to the same as memory limit
            echo "${memory_limit_bytes}" > "${cgroup_path}/memory.memsw.limit_in_bytes" 2>/dev/null || true
            echo "Swap disabled for user ${username}"
        fi
    fi
    
    echo "Memory limit applied successfully for user ${username}"
    return 0
}

# Function to setup disk quota for a user
# Usage: setup_disk_quota "username" "soft_limit" "hard_limit" ["filesystem"]
# soft_limit and hard_limit are in MB
setup_disk_quota() {
    local username="$1"
    local soft_limit="$2"
    local hard_limit="$3"
    local filesystem="${4:-/home}"
    
    # Soft limit and hard limit in blocks (1 block = 1 KB)
    local soft_blocks=$((soft_limit * 1024))
    local hard_blocks=$((hard_limit * 1024))
    
    echo "Setting up disk quota for user ${username} on ${filesystem}"
    
    # Check if quota is available
    if ! is_quota_available "${filesystem}"; then
        echo "Quota not available on ${filesystem}. Setting up..."
        
        # Install quota tools if not installed
        if ! command -v quotacheck &> /dev/null; then
            if [[ "${DISTRO_FAMILY}" == "debian" ]]; then
                apt-get install -y quota
            elif [[ "${DISTRO_FAMILY}" == "redhat" ]]; then
                if command -v dnf &> /dev/null; then
                    dnf install -y quota
                else
                    yum install -y quota
                fi
            elif [[ "${DISTRO_FAMILY}" == "arch" ]]; then
                pacman -S --noconfirm quota-tools
            elif [[ "${DISTRO_FAMILY}" == "suse" ]]; then
                zypper install -y quota
            else
                echo "Unable to install quota tools for unknown distribution family: ${DISTRO_FAMILY}"
                return 1
            fi
        fi
        
        # Check if quota is enabled in fstab
        if ! grep -q "${filesystem}.*usrquota" /etc/fstab && ! grep -q "${filesystem}.*quota" /etc/fstab; then
            echo "Quota mount options not found in fstab. Adding..."
            # Make a backup
            cp /etc/fstab /etc/fstab.bak
            # Add usrquota option
            sed -i "s|\(.*\s${filesystem}\s\+\w\+\s\+\)\(\w\+\)\(.*\)|\1\2,usrquota\3|" /etc/fstab
            
            # Remount with quota options
            mount -o remount "${filesystem}"
        fi
        
        # Initialize quota on the filesystem
        quotacheck -ugm "${filesystem}"
        quotaon -v "${filesystem}"
    fi
    
    # Set the quota for the user
    setquota -u "${username}" "${soft_blocks}" "${hard_blocks}" 0 0 "${filesystem}"
    
    echo "Disk quota set for user ${username}: soft=${soft_limit}MB, hard=${hard_limit}MB"
    return 0
}

# Function to check if NVIDIA GPU is available
# Usage: is_nvidia_gpu_available
is_nvidia_gpu_available() {
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &> /dev/null; then
        return 1
    fi
    
    # Run nvidia-smi to check if GPU is available
    if ! nvidia-smi &> /dev/null; then
        return 1
    fi
    
    return 0
}

# Function to enable GPU access for a user
# Usage: enable_gpu_access "username"
enable_gpu_access() {
    local username="$1"
    
    echo "Enabling GPU access for user: ${username}"
    
    # Check if NVIDIA GPU is available
    if ! is_nvidia_gpu_available; then
        echo "No NVIDIA GPU available on this system"
        return 1
    fi
    
    # Check if the user exists
    if ! id -u "${username}" &> /dev/null; then
        echo "User ${username} does not exist"
        return 1
    fi
    
    # Add user to video group (common approach across distributions)
    usermod -a -G video "${username}"
    
    # Create a udev rule to allow user access to GPU devices
    local udev_rule_file="/etc/udev/rules.d/99-nvidia-${username}.rules"
    
    cat > "${udev_rule_file}" << EOF
# Grant user ${username} access to NVIDIA GPU devices
SUBSYSTEM=="nvidia*", OWNER="root", GROUP="video", MODE="0660"
EOF
    
    # Reload udev rules
    if command -v udevadm &> /dev/null; then
        udevadm control --reload-rules
        udevadm trigger
    else
        echo "udevadm not found, manual reload of udev rules required"
    fi
    
    echo "GPU access enabled for user ${username}"
    return 0
}

# Function to disable GPU access for a user
# Usage: disable_gpu_access "username"
disable_gpu_access() {
    local username="$1"
    
    echo "Disabling GPU access for user: ${username}"
    
    # Check if the user exists
    if ! id -u "${username}" &> /dev/null; then
        echo "User ${username} does not exist"
        return 1
    fi
    
    # Remove user from video group
    gpasswd -d "${username}" video
    
    # Remove udev rule if it exists
    local udev_rule_file="/etc/udev/rules.d/99-nvidia-${username}.rules"
    if [[ -f "${udev_rule_file}" ]]; then
        rm -f "${udev_rule_file}"
        
        # Reload udev rules
        if command -v udevadm &> /dev/null; then
            udevadm control --reload-rules
            udevadm trigger
        fi
    fi
    
    echo "GPU access disabled for user ${username}"
    return 0
}

# Function to get current CPU usage for a user
# Usage: get_user_cpu_usage "username"
get_user_cpu_usage() {
    local username="$1"
    local usage
    
    # Use ps to get CPU usage for all processes owned by the user
    usage=$(ps -U "${username}" -o pcpu= | awk '{sum+=$1} END {print sum}')
    
    echo "${usage}"
    return 0
}

# Function to get current memory usage for a user
# Usage: get_user_memory_usage "username"
get_user_memory_usage() {
    local username="$1"
    local usage
    
    # Use ps to get memory usage (RSS) in KB for all processes owned by the user
    usage=$(ps -U "${username}" -o rss= | awk '{sum+=$1} END {print sum/1024}')
    
    echo "${usage}"
    return 0
}

# Function to get current disk usage for a user
# Usage: get_user_disk_usage "username" ["directory"]
get_user_disk_usage() {
    local username="$1"
    local directory="${2:-/home/${username}}"
    local usage
    
    # Use du to get disk usage in MB
    usage=$(du -sm "${directory}" | cut -f1)
    
    echo "${usage}"
    return 0
}

# Function to apply resource limits for a user
# Usage: apply_user_resource_limits "username" "cpu_limit" "memory_limit" "disk_quota" ["swap_limit"]
# cpu_limit is a float representing number of CPU cores
# memory_limit is in MB
# disk_quota is in MB
# swap_limit is in MB (optional)
apply_user_resource_limits() {
    local username="$1"
    local cpu_limit="${2:-1.0}"
    local memory_limit="${3:-1024}"
    local disk_quota="${4:-5120}"
    local swap_limit="${5:-0}"
    
    echo "Applying resource limits for user ${username}:"
    echo "  CPU: ${cpu_limit} cores"
    echo "  Memory: ${memory_limit} MB"
    if [[ ${swap_limit} -gt 0 ]]; then
        echo "  Swap: ${swap_limit} MB"
    else
        echo "  Swap: Disabled"
    fi
    echo "  Disk: ${disk_quota} MB"
    
    # Apply CPU limit
    apply_cpu_limit "${username}" "${cpu_limit}"
    
    # Apply memory limit (with swap if specified)
    apply_memory_limit "${username}" "${memory_limit}" "${swap_limit}"
    
    # Setup disk quota
    setup_disk_quota "${username}" "${disk_quota}" "$((disk_quota * 2))"
    
    echo "All resource limits applied successfully for user ${username}"
    return 0
}

# Function to get user's resource limits
# Usage: get_user_resource_limits "username"
get_user_resource_limits() {
    local username="$1"
    local cpu_limit
    local memory_limit
    local swap_limit
    local disk_quota
    local cgroup_path
    
    # Get CPU limit
    if [[ "${CGROUP_VERSION}" == "v2" || "${CGROUP_VERSION}" == "hybrid" ]]; then
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        if [[ -f "${cgroup_path}/cpu.max" ]]; then
            local cpu_max=$(cat "${cgroup_path}/cpu.max" | awk '{print $1}')
            local cpu_period=$(cat "${cgroup_path}/cpu.max" | awk '{print $2}')
            cpu_limit=$(echo "scale=2; ${cpu_max}/${cpu_period}" | bc)
        else
            cpu_limit="N/A"
        fi
    else
        # cgroups v1
        cgroup_path="$(get_cgroup_path "cpu")/user/${username}"
        if [[ -f "${cgroup_path}/cpu.cfs_quota_us" && -f "${cgroup_path}/cpu.cfs_period_us" ]]; then
            local cpu_quota=$(cat "${cgroup_path}/cpu.cfs_quota_us")
            local cpu_period=$(cat "${cgroup_path}/cpu.cfs_period_us")
            cpu_limit=$(echo "scale=2; ${cpu_quota}/${cpu_period}" | bc)
        else
            cpu_limit="N/A"
        fi
    fi
    
    # Get memory limit
    if [[ "${CGROUP_VERSION}" == "v2" || "${CGROUP_VERSION}" == "hybrid" ]]; then
        cgroup_path="$(get_cgroup_path)/user.slice/user-$(id -u "${username}").slice"
        if [[ -f "${cgroup_path}/memory.max" ]]; then
            local memory_bytes=$(cat "${cgroup_path}/memory.max")
            memory_limit=$((memory_bytes / 1024 / 1024))
            
            # Get swap limit for cgroups v2
            if [[ -f "${cgroup_path}/memory.swap.max" ]]; then
                local swap_bytes=$(cat "${cgroup_path}/memory.swap.max")
                if [[ "${swap_bytes}" == "max" ]]; then
                    swap_limit="unlimited"
                else
                    swap_limit=$((swap_bytes / 1024 / 1024))
                fi
            else
                swap_limit="N/A"
            fi
        else
            memory_limit="N/A"
            swap_limit="N/A"
        fi
    else
        # cgroups v1
        cgroup_path="$(get_cgroup_path "memory")/user/${username}"
        if [[ -f "${cgroup_path}/memory.limit_in_bytes" ]]; then
            local memory_bytes=$(cat "${cgroup_path}/memory.limit_in_bytes")
            memory_limit=$((memory_bytes / 1024 / 1024))
            
            # Get swap+memory limit for cgroups v1
            if [[ -f "${cgroup_path}/memory.memsw.limit_in_bytes" ]]; then
                local memsw_bytes=$(cat "${cgroup_path}/memory.memsw.limit_in_bytes")
                local swap_only_bytes=$((memsw_bytes - memory_bytes))
                swap_limit=$((swap_only_bytes / 1024 / 1024))
                
                # If swap_limit is 0 or negative, no swap is allowed
                if [[ ${swap_limit} -le 0 ]]; then
                    swap_limit=0
                fi
            else
                swap_limit="N/A"
            fi
        else
            memory_limit="N/A"
            swap_limit="N/A"
        fi
    fi
    
    # Get disk quota
    if command -v quota &> /dev/null; then
        disk_quota=$(quota -u "${username}" | grep "^/dev" | awk '{print $2/1024}')
        if [[ -z "${disk_quota}" ]]; then
            disk_quota="N/A"
        fi
    else
        disk_quota="N/A"
    fi
    
    echo "Resource limits for user ${username}:"
    echo "  CPU: ${cpu_limit} cores"
    echo "  Memory: ${memory_limit} MB"
    if [[ "${swap_limit}" != "N/A" ]]; then
        echo "  Swap: ${swap_limit} MB"
    else
        echo "  Swap: Not configured"
    fi
    echo "  Disk: ${disk_quota} MB"
    return 0
}

# Function to get total system resources
# Usage: get_system_resources
get_system_resources() {
    echo "System resources:"
    echo "  CPU cores: ${CPU_CORES}"
    echo "  Total memory: ${TOTAL_MEMORY} MB"
    
    # Get swap information
    if [[ ${SWAP_AVAILABLE} -eq 1 ]]; then
        echo "  Total swap: ${TOTAL_SWAP} MB"
        local swap_used=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
        local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        local swap_used_mb=$(( (swap_used - swap_free) / 1024 ))
        echo "  Swap used: ${swap_used_mb} MB"
    else
        echo "  Swap: Not available"
    fi
    
    # Get available disk space
    local disk_space=$(df -m / | awk 'NR==2 {print $4}')
    echo "  Available disk space: ${disk_space} MB"
    
    # Check for GPU
    if is_nvidia_gpu_available; then
        local gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | sed 's/,/ - /g')
        echo "  GPU: ${gpu_info} MB"
    else
        echo "  GPU: None detected"
    fi
    
    return 0
}

# Export functions
export -f is_quota_available
export -f setup_user_cgroup
export -f apply_cpu_limit
export -f apply_memory_limit
export -f setup_disk_quota
export -f is_nvidia_gpu_available
export -f enable_gpu_access
export -f disable_gpu_access
export -f get_user_cpu_usage
export -f get_user_memory_usage
export -f get_user_disk_usage
export -f apply_user_resource_limits
export -f get_user_resource_limits
export -f get_system_resources