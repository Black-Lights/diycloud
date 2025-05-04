# Resource Management Module: Implementation Guide

This guide provides detailed instructions for implementing the Resource Management Module of the DIY Cloud Platform.

## 1. Overview

The Resource Management Module is responsible for:
- CPU resource allocation
- Memory limitations
- Disk quota management
- GPU access control (if available)
- Cross-distribution resource management compatibility
- Support for both cgroups v1 and v2

## 2. Directory Structure

```
/opt/diycloud/resources/
├── cpu_manager.sh          # CPU resource management
├── mem_manager.sh          # Memory resource management
├── disk_manager.sh         # Disk quota management
├── gpu_manager.sh          # GPU access management
└── apply_limits.sh         # Apply resource limits to user
```

## 3. CPU Resource Management (cpu_manager.sh)

### 3.1. cgroups v1 Implementation

For distributions using cgroups v1:
- Create CPU cgroups for each user
- Set CPU shares (relative weight)
- Set CPU quota (absolute limit)
- Add user processes to cgroup

Example implementation:
```bash
# For cgroups v1 (CPU limits)
setup_cpu_cgroup_v1() {
    local username="$1"
    
    # Create user cgroup
    mkdir -p /sys/fs/cgroup/cpu/user/$username
    
    # Set CPU shares (relative weight)
    echo $CPU_SHARES > /sys/fs/cgroup/cpu/user/$username/cpu.shares
    
    # Set CPU quota (absolute limit in microseconds)
    echo $CPU_QUOTA > /sys/fs/cgroup/cpu/user/$username/cpu.cfs_quota_us
    
    # Add user processes to cgroup
    echo $USERNAME > /sys/fs/cgroup/cpu/user/$username/tasks
}
```

### 3.2. cgroups v2 Implementation

For distributions using cgroups v2:
- Create user cgroup in unified hierarchy
- Enable CPU controller
- Set CPU weight (equivalent to shares)
- Set CPU max (quota and period)
- Add user processes to cgroup

Example implementation:
```bash
# For cgroups v2 (unified hierarchy)
setup_cpu_cgroup_v2() {
    local username="$1"
    
    # Create user cgroup
    mkdir -p /sys/fs/cgroup/user/$username
    
    # Enable controllers
    echo "+cpu" > /sys/fs/cgroup/cgroup.subtree_control
    
    # Set CPU weight (equivalent to shares)
    echo $CPU_WEIGHT > /sys/fs/cgroup/user/$username/cpu.weight
    
    # Set CPU max (quota and period)
    echo "$CPU_MAX $CPU_PERIOD" > /sys/fs/cgroup/user/$username/cpu.max
    
    # Add user processes to cgroup
    echo $$ > /sys/fs/cgroup/user/$username/cgroup.procs
}
```

### 3.3. Cross-Distribution Compatibility

Use the Distribution Abstraction Layer to detect the cgroup version and apply the appropriate configuration:

```bash
# Apply CPU limit based on cgroup version
apply_cpu_limit() {
    local username="$1"
    local limit="$2"
    
    # Use the Distribution Abstraction Layer to detect cgroup version
    if [[ "${CGROUP_VERSION}" == "v1" ]]; then
        setup_cpu_cgroup_v1 "$username" "$limit"
    elif [[ "${CGROUP_VERSION}" == "v2" ]]; then
        setup_cpu_cgroup_v2 "$username" "$limit"
    else
        log_message "Unknown cgroup version: ${CGROUP_VERSION}" "error"
        return 1
    fi
}
```

## 4. Memory Resource Management (mem_manager.sh)

### 4.1. cgroups v1 Implementation

For distributions using cgroups v1:
- Create memory cgroups for each user
- Set memory limit
- Add user processes to cgroup

Example implementation:
```bash
# For cgroups v1 (memory limits)
setup_memory_cgroup_v1() {
    local username="$1"
    local memory_limit="$2"  # in MB
    
    # Convert to bytes
    local limit_bytes=$((memory_limit * 1024 * 1024))
    
    # Create user cgroup
    mkdir -p /sys/fs/cgroup/memory/user/$username
    
    # Set memory limit
    echo $limit_bytes > /sys/fs/cgroup/memory/user/$username/memory.limit_in_bytes
    
    # Add user processes to cgroup
    echo $USERNAME > /sys/fs/cgroup/memory/user/$username/tasks
}
```

### 4.2. cgroups v2 Implementation

For distributions using cgroups v2:
- Create user cgroup in unified hierarchy
- Enable memory controller
- Set memory maximum
- Add user processes to cgroup

Example implementation:
```bash
# For cgroups v2 (unified hierarchy)
setup_memory_cgroup_v2() {
    local username="$1"
    local memory_limit="$2"  # in MB
    
    # Convert to bytes
    local limit_bytes=$((memory_limit * 1024 * 1024))
    
    # Create user cgroup
    mkdir -p /sys/fs/cgroup/user/$username
    
    # Enable controllers
    echo "+memory" > /sys/fs/cgroup/cgroup.subtree_control
    
    # Set memory limit
    echo $limit_bytes > /sys/fs/cgroup/user/$username/memory.max
    
    # Add user processes to cgroup
    echo $$ > /sys/fs/cgroup/user/$username/cgroup.procs
}
```

## 5. Disk Quota Management (disk_manager.sh)

### 5.1. Disk Quota Implementation

Set up disk quotas for users:
- Enable quota on the filesystem
- Set user quota (soft and hard limits)
- Apply quota settings

Example implementation:
```bash
# Setup disk quota for a user
setup_disk_quota() {
    local username="$1"
    local soft_limit="$2"  # in MB
    local hard_limit="$3"  # in MB
    local mount_point="${4:-/home}"
    
    # Convert to blocks (1 block = 1KB on most systems)
    local soft_blocks=$((soft_limit * 1024))
    local hard_blocks=$((hard_limit * 1024))
    
    # Set default inode limits
    local soft_inodes=0
    local hard_inodes=0
    
    # Enable quota on filesystem
    if ! grep -q "usrquota" /etc/fstab; then
        log_message "Quota not enabled in /etc/fstab for $mount_point" "warning"
        return 1
    fi
    
    # Ensure quota tools are installed
    install_package "quota"
    
    # Run quotacheck to update quota files
    quotacheck -ugm $mount_point
    
    # Enable quota on the filesystem
    quotaon -v $mount_point
    
    # Set user quota
    setquota -u $username $soft_blocks $hard_blocks $soft_inodes $hard_inodes $mount_point
}
```

### 5.2. Cross-Distribution Compatibility

Different distributions may have different quota tools and configurations. Use the Distribution Abstraction Layer to handle these differences:

```bash
# Setup disk quota based on distribution
setup_disk_quota_for_distro() {
    local username="$1"
    local soft_limit="$2"
    local hard_limit="$3"
    
    case "${DISTRO_FAMILY}" in
        debian)
            setup_disk_quota_debian "$username" "$soft_limit" "$hard_limit"
            ;;
        redhat)
            setup_disk_quota_redhat "$username" "$soft_limit" "$hard_limit"
            ;;
        arch)
            setup_disk_quota_arch "$username" "$soft_limit" "$hard_limit"
            ;;
        suse)
            setup_disk_quota_suse "$username" "$soft_limit" "$hard_limit"
            ;;
        *)
            log_message "Unsupported distribution family: ${DISTRO_FAMILY}" "error"
            return 1
            ;;
    esac
}
```

## 6. GPU Access Management (gpu_manager.sh)

### 6.1. NVIDIA GPU Implementation

For systems with NVIDIA GPUs:
- Check if NVIDIA GPU is available
- Configure NVIDIA Docker integration (if Docker is used)
- Set up device access permissions

Example implementation:
```bash
# Check if NVIDIA GPU is available
is_nvidia_gpu_available() {
    if command_exists "nvidia-smi"; then
        nvidia-smi -L &> /dev/null
        return $?
    fi
    return 1
}

# Enable GPU access for a user
enable_gpu_access() {
    local username="$1"
    
    # Check if NVIDIA GPU is available
    if ! is_nvidia_gpu_available; then
        log_message "No NVIDIA GPU available" "warning"
        return 1
    fi
    
    # Add user to video group
    usermod -a -G video "$username"
    
    # If using Docker, configure NVIDIA Docker
    if command_exists "docker"; then
        # Ensure NVIDIA Docker is installed
        install_package "nvidia-docker2"
        
        # Configure Docker to use NVIDIA runtime
        if [[ -f "/etc/docker/daemon.json" ]]; then
            # Backup existing configuration
            cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
            
            # Add NVIDIA runtime to configuration
            jq '.["default-runtime"] = "nvidia"' /etc/docker/daemon.json > /tmp/daemon.json
            mv /tmp/daemon.json /etc/docker/daemon.json
            
            # Restart Docker service
            restart_service "docker"
        fi
    fi
}
```

## 7. Unified Resource Management (apply_limits.sh)

### 7.1. Apply Resource Limits

Create a unified script to apply all resource limits:
- Apply CPU limits
- Apply memory limits
- Set up disk quotas
- Configure GPU access (if available)

Example implementation:
```bash
# Apply all resource limits for a user
apply_user_resource_limits() {
    local username="$1"
    local cpu_limit="$2"
    local mem_limit="$3"
    local disk_quota="$4"
    local gpu_access="${5:-false}"
    
    # Apply CPU limit
    apply_cpu_limit "$username" "$cpu_limit"
    
    # Apply memory limit
    apply_memory_limit "$username" "$mem_limit"
    
    # Setup disk quota
    setup_disk_quota "$username" "$disk_quota" "$((disk_quota * 2))"
    
    # Configure GPU access if requested
    if [[ "$gpu_access" == "true" ]]; then
        enable_gpu_access "$username"
    fi
}
```

## 8. Integration with Distribution Abstraction Layer

Use the Distribution Abstraction Layer for:
- Distribution detection
- Package management
- Service management
- Path resolution
- Resource management adaptations

Example:
```bash
# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/resource_adapter.sh
source /opt/diycloud/lib/common.sh

# Get cgroup path
cgroup_path=$(get_cgroup_path)
```

## 9. Testing

Create tests for:
1. CPU limit application
2. Memory limit application
3. Disk quota setting
4. GPU access control
5. Combined resource limits

## 10. Security Considerations

- Ensure proper isolation between users
- Prevent resource limit bypassing
- Protect cgroup configurations
- Monitor resource usage
- Implement proper error handling and rollback
