# Phase 2: User & Resource Management - Quick Start Guide

This guide will help you get started with the development of Phase 2 of the DIY Cloud Platform project - the User Management and Resource Management modules.

## Prerequisites

- Completed Phase 0 (Distribution Abstraction Layer)
- Completed Phase 1 (Core Platform Module)
- Basic knowledge of:
  - Bash scripting
  - SQLite database
  - Python programming
  - Linux user management
  - cgroups and resource limits

## Setup Development Environment

1. Make sure you have the Distribution Abstraction Layer available:
   ```bash
   source /opt/diycloud/lib/detect_distro.sh
   source /opt/diycloud/lib/package_manager.sh
   source /opt/diycloud/lib/service_manager.sh
   source /opt/diycloud/lib/path_resolver.sh
   source /opt/diycloud/lib/resource_adapter.sh
   source /opt/diycloud/lib/common.sh
   ```

2. Create the directory structure for Phase 2:
   ```bash
   # Create User Management directories
   mkdir -p /opt/diycloud/usermgmt/db
   mkdir -p /opt/diycloud/usermgmt/auth
   
   # Create Resource Management directory
   mkdir -p /opt/diycloud/resources
   ```

3. Install required packages:
   ```bash
   # Install SQLite
   install_package "sqlite3"
   
   # Install Python and dependencies
   install_package "python3"
   install_package "python3-pip"
   
   # Install quota tools
   install_package "quota"
   ```

## Step 1: User Management Module

### Database Setup

1. Create the database schema at `/opt/diycloud/usermgmt/db/schema.sql`:
   ```sql
   -- Users Table
   CREATE TABLE users (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       username TEXT UNIQUE NOT NULL,
       password_hash TEXT NOT NULL,
       email TEXT,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       last_login TIMESTAMP,
       role TEXT DEFAULT 'user',
       is_active BOOLEAN DEFAULT 1
   );

   -- Resource Allocations Table
   CREATE TABLE resource_allocations (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       user_id INTEGER NOT NULL,
       cpu_limit REAL NOT NULL DEFAULT 1,
       mem_limit TEXT NOT NULL DEFAULT '2G',
       disk_quota TEXT NOT NULL DEFAULT '5G',
       gpu_access BOOLEAN DEFAULT 0,
       FOREIGN KEY (user_id) REFERENCES users(id)
   );

   -- Initial admin user
   INSERT INTO users (username, password_hash, email, role, is_active) 
   VALUES ('admin', 'PLACEHOLDER', 'admin@localhost', 'admin', 1);
   ```

2. Create the database initialization script at `/opt/diycloud/usermgmt/db/init_db.sh`:
   ```bash
   #!/usr/bin/env bash

   # Source the Distribution Abstraction Layer
   source /opt/diycloud/lib/detect_distro.sh
   source /opt/diycloud/lib/package_manager.sh
   source /opt/diycloud/lib/common.sh

   # Set up database directory
   DB_DIR="/opt/diycloud/usermgmt/db"
   DB_FILE="${DB_DIR}/users.db"
   SCHEMA_FILE="${DB_DIR}/schema.sql"

   # Function to initialize the database
   initialize_database() {
       log_message "Initializing user database..." "info"
       
       # Check if SQLite is installed
       if ! command_exists "sqlite3"; then
           log_message "SQLite3 is not installed" "error"
           return 1
       fi
       
       # Create database directory if it doesn't exist
       ensure_directory "${DB_DIR}" "root:root" "755"
       
       # Check if schema file exists
       if [[ ! -f "${SCHEMA_FILE}" ]]; then
           log_message "Schema file not found: ${SCHEMA_FILE}" "error"
           return 1
       fi
       
       # Create database and apply schema
       sqlite3 "${DB_FILE}" < "${SCHEMA_FILE}"
       
       # Set proper permissions
       chmod 600 "${DB_FILE}"
       
       # Generate admin password if needed
       local admin_password
       if [[ $# -eq 1 ]]; then
           admin_password="$1"
       else
           admin_password=$(generate_password 12)
       fi
       
       # Hash the password (simple hash for example, use bcrypt in production)
       local password_hash=$(echo -n "${admin_password}" | sha256sum | cut -d' ' -f1)
       
       # Update admin user with password
       sqlite3 "${DB_FILE}" "UPDATE users SET password_hash='${password_hash}' WHERE username='admin';"
       
       log_message "Database initialized successfully" "info"
       
       # Output admin password if generated
       if [[ $# -eq 0 ]]; then
           log_message "Generated admin password: ${admin_password}" "info"
       fi
       
       return 0
   }

   # Run the initialization function
   if [[ $# -eq 1 ]]; then
       initialize_database "$1"
   else
       initialize_database
   fi
   ```

3. Create user creation script at `/opt/diycloud/usermgmt/create_user.sh`:
   ```bash
   #!/usr/bin/env bash

   # Source the Distribution Abstraction Layer
   source /opt/diycloud/lib/detect_distro.sh
   source /opt/diycloud/lib/package_manager.sh
   source /opt/diycloud/lib/service_manager.sh
   source /opt/diycloud/lib/path_resolver.sh
   source /opt/diycloud/lib/resource_adapter.sh
   source /opt/diycloud/lib/common.sh

   # Default values
   DB_FILE="/opt/diycloud/usermgmt/db/users.db"
   DEFAULT_CPU_LIMIT="1.0"
   DEFAULT_MEM_LIMIT="2048"  # 2GB in MB
   DEFAULT_DISK_QUOTA="5120"  # 5GB in MB
   DEFAULT_ROLE="user"

   # Function to show usage
   usage() {
       echo "Usage: $0 [OPTIONS]"
       echo "Create a new user for DIY Cloud Platform"
       echo ""
       echo "Options:"
       echo "  --username USERNAME    Username (required)"
       echo "  --password PASSWORD    Password (if not provided, will be generated)"
       echo "  --email EMAIL          Email address"
       echo "  --cpu LIMIT            CPU limit (cores, default: ${DEFAULT_CPU_LIMIT})"
       echo "  --memory LIMIT         Memory limit (MB, default: ${DEFAULT_MEM_LIMIT})"
       echo "  --disk QUOTA           Disk quota (MB, default: ${DEFAULT_DISK_QUOTA})"
       echo "  --role ROLE            User role (user/admin, default: ${DEFAULT_ROLE})"
       echo "  --gpu                  Enable GPU access (disabled by default)"
       echo "  --help                 Show this help message"
       exit 1
   }

   # Parse arguments
   USERNAME=""
   PASSWORD=""
   EMAIL=""
   CPU_LIMIT="${DEFAULT_CPU_LIMIT}"
   MEM_LIMIT="${DEFAULT_MEM_LIMIT}"
   DISK_QUOTA="${DEFAULT_DISK_QUOTA}"
   ROLE="${DEFAULT_ROLE}"
   GPU_ACCESS="false"

   while [[ $# -gt 0 ]]; do
       key="$1"
       case $key in
           --username)
           USERNAME="$2"
           shift
           shift
           ;;
           --password)
           PASSWORD="$2"
           shift
           shift
           ;;
           --email)
           EMAIL="$2"
           shift
           shift
           ;;
           --cpu)
           CPU_LIMIT="$2"
           shift
           shift
           ;;
           --memory)
           MEM_LIMIT="$2"
           shift
           shift
           ;;
           --disk)
           DISK_QUOTA="$2"
           shift
           shift
           ;;
           --role)
           ROLE="$2"
           shift
           shift
           ;;
           --gpu)
           GPU_ACCESS="true"
           shift
           ;;
           --help)
           usage
           ;;
           *)
           echo "Unknown option: $1"
           usage
           ;;
       esac
   done

   # Check required arguments
   if [[ -z "${USERNAME}" ]]; then
       echo "Error: Username is required"
       usage
   fi

   # Generate password if not provided
   if [[ -z "${PASSWORD}" ]]; then
       PASSWORD=$(generate_password 12)
       echo "Generated password: ${PASSWORD}"
   fi

   # Function to create system user
   create_system_user() {
       local username="$1"
       local password="$2"
       
       log_message "Creating system user: ${username}" "info"
       
       # Check if user already exists
       if id "${username}" &>/dev/null; then
           log_message "User already exists: ${username}" "error"
           return 1
       fi
       
       # Create home directory
       local home_dir="/home/${username}"
       
       # Create user with home directory
       useradd -m -s /bin/bash "${username}"
       
       # Set password
       echo "${username}:${password}" | chpasswd
       
       # Create necessary directories
       ensure_directory "${home_dir}/notebooks" "${username}:${username}" "750"
       ensure_directory "${home_dir}/data" "${username}:${username}" "750"
       
       return 0
   }

   # Function to add user to database
   add_user_to_db() {
       local username="$1"
       local password="$2"
       local email="$3"
       local role="$4"
       
       log_message "Adding user to database: ${username}" "info"
       
       # Check if database exists
       if [[ ! -f "${DB_FILE}" ]]; then
           log_message "Database file not found: ${DB_FILE}" "error"
           return 1
       fi
       
       # Hash the password (simple hash for example, use bcrypt in production)
       local password_hash=$(echo -n "${password}" | sha256sum | cut -d' ' -f1)
       
       # Insert user into database
       sqlite3 "${DB_FILE}" <<EOF
   INSERT INTO users (username, password_hash, email, role) 
   VALUES ('${username}', '${password_hash}', '${email}', '${role}');
   EOF
       
       # Get user ID
       local user_id=$(sqlite3 "${DB_FILE}" "SELECT id FROM users WHERE username='${username}';")
       
       # Insert resource allocation
       sqlite3 "${DB_FILE}" <<EOF
   INSERT INTO resource_allocations (user_id, cpu_limit, mem_limit, disk_quota, gpu_access) 
   VALUES (${user_id}, ${CPU_LIMIT}, '${MEM_LIMIT}M', '${DISK_QUOTA}M', ${GPU_ACCESS});
   EOF
       
       return 0
   }

   # Main function
   main() {
       log_message "Creating user: ${USERNAME}" "info"
       
       # Create system user
       create_system_user "${USERNAME}" "${PASSWORD}"
       
       # Add user to database
       add_user_to_db "${USERNAME}" "${PASSWORD}" "${EMAIL}" "${ROLE}"
       
       # Apply resource limits
       source /opt/diycloud/resources/apply_limits.sh
       apply_user_resource_limits "${USERNAME}" "${CPU_LIMIT}" "${MEM_LIMIT}" "${DISK_QUOTA}" "${GPU_ACCESS}"
       
       log_message "User created successfully: ${USERNAME}" "info"
       
       return 0
   }

   # Run the main function
   main
   ```

## Step 2: Resource Management Module

### Resource Management Scripts

1. Create the CPU manager script at `/opt/diycloud/resources/cpu_manager.sh`:
   ```bash
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
   ```

2. Create the memory manager script at `/opt/diycloud/resources/mem_manager.sh`:
   ```bash
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
   ```

3. Create the disk manager script at `/opt/diycloud/resources/disk_manager.sh`:
   ```bash
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
   ```

4. Create the GPU manager script at `/opt/diycloud/resources/gpu_manager.sh`:
   ```bash
   #!/usr/bin/env bash

   # Source the Distribution Abstraction Layer
   source /opt/diycloud/lib/detect_distro.sh
   source /opt/diycloud/lib/package_manager.sh
   source /opt/diycloud/lib/service_manager.sh
   source /opt/diycloud/lib/common.sh

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
       
       log_message "Enabling GPU access for user: ${username}" "info"
       
       # Check if NVIDIA GPU is available
       if ! is_nvidia_gpu_available; then
           log_message "No NVIDIA GPU available" "warning"
           return 1
       fi
       
       # Add user to video group
       usermod -a -G video "${username}"
       
       # If using Docker, ensure NVIDIA Docker is configured
       if command_exists "docker"; then
           if ! is_package_installed "nvidia-docker2"; then
               log_message "NVIDIA Docker not installed, attempting to install..." "info"
               install_package "nvidia-docker2" || true
           fi
           
           # Check if Docker service is running
           if is_service_active "docker"; then
               # Configure Docker to use NVIDIA runtime
               if [[ -f "/etc/docker/daemon.json" ]]; then
                   log_message "Configuring Docker for NVIDIA GPU..." "info"
                   
                   # Backup existing configuration
                   cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
                   
                   # Add NVIDIA runtime to configuration (simple approach)
                   if ! grep -q "nvidia" /etc/docker/daemon.json; then
                       local temp_file=$(mktemp)
                       jq '.["default-runtime"] = "nvidia" | .runtimes += {"nvidia": {"path": "/usr/bin/nvidia-container-runtime", "runtimeArgs": []}}' /etc/docker/daemon.json > "${temp_file}"
                       mv "${temp_file}" /etc/docker/daemon.json
                       
                       # Restart Docker service
                       restart_service "docker"
                   fi
               fi
           fi
       fi
       
       log_message "GPU access enabled for user: ${username}" "info"
       return 0
   }

   # Disable GPU access for a user
   disable_gpu_access() {
       local username="$1"
       
       log_message "Disabling GPU access for user: ${username}" "info"
       
       # Remove user from video group
       gpasswd -d "${username}" video 2>/dev/null || true
       
       log_message "GPU access disabled for user: ${username}" "info"
       return 0
   }
   ```

5. Create the unified resource limits script at `/opt/diycloud/resources/apply_limits.sh`:
   ```bash
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
   ```

## Step 3: Testing

Create a test script at `/opt/diycloud/test_phase2.sh`:
```bash
#!/usr/bin/env bash

# DIY Cloud Platform - Phase 2 Test Script
#
# This script tests the User Management Module and Resource Management Module

# Exit on error
set -e

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/resource_adapter.sh
source /opt/diycloud/lib/common.sh

# Detect distribution
detect_distribution
log_message "Testing on distribution: $DISTRO $DISTRO_VERSION ($DISTRO_FAMILY family)" "info"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   log_message "This script must be run as root" "error"
   exit 1
fi

# Variables
TEST_USER="diycloud-test-user"
TEST_PASSWORD="Test@123"
TEST_EMAIL="test@example.com"
TEST_CPU="0.5"
TEST_MEM="512"
TEST_DISK="1024"
TEST_ROLE="user"

# Function to run and display tests
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "\n===== Testing: ${test_name} ====="
    
    # Run the test command
    eval "${test_command}"
    local result=$?
    
    if [[ ${result} -eq 0 ]]; then
        echo -e "\n✅ PASSED: ${test_name}"
    else
        echo -e "\n❌ FAILED: ${test_name}"
        exit 1
    fi
}

# Test 1: Database Initialization
test_database_init() {
    echo "Testing database initialization..."
    
    if [[ ! -f "/opt/diycloud/usermgmt/db/init_db.sh" ]]; then
        echo "Missing script: /opt/diycloud/usermgmt/db/init_db.sh"
        return 1
    fi
    
    chmod +x /opt/diycloud/usermgmt/db/init_db.sh
    /opt/diycloud/usermgmt/db/init_db.sh "adminpassword"
    
    if [[ ! -f "/opt/diycloud/usermgmt/db/users.db" ]]; then
        echo "Database file was not created"
        return 1
    fi
    
    # Check if admin user exists
    local admin_count=$(sqlite3 /opt/diycloud/usermgmt/db/users.db "SELECT COUNT(*) FROM users WHERE username='admin';")
    if [[ "${admin_count}" -ne 1 ]]; then
        echo "Admin user not found in database"
        return 1
    fi
    
    echo "Database initialized successfully"
    return 0
}

# Test 2: User Creation
test_user_creation() {
    echo "Testing user creation..."
    
    if [[ ! -f "/opt/diycloud/usermgmt/create_user.sh" ]]; then
        echo "Missing script: /opt/diycloud/usermgmt/create_user.sh"
        return 1
    fi
    
    # Remove test user if it exists
    id "${TEST_USER}" &>/dev/null && {
        userdel -rf "${TEST_USER}" || true
        sqlite3 /opt/diycloud/usermgmt/db/users.db "DELETE FROM users WHERE username='${TEST_USER}';" || true
    }
    
    # Create test user
    chmod +x /opt/diycloud/usermgmt/create_user.sh
    /opt/diycloud/usermgmt/create_user.sh --username "${TEST_USER}" --password "${TEST_PASSWORD}" --email "${TEST_EMAIL}" --cpu "${TEST_CPU}" --memory "${TEST_MEM}" --disk "${TEST_DISK}" --role "${TEST_ROLE}"
    
    # Check if user was created
    if ! id "${TEST_USER}" &>/dev/null; then
        echo "System user was not created"
        return 1
    fi
    
    # Check if user was added to database
    local user_count=$(sqlite3 /opt/diycloud/usermgmt/db/users.db "SELECT COUNT(*) FROM users WHERE username='${TEST_USER}';")
    if [[ "${user_count}" -ne 1 ]]; then
        echo "User not found in database"
        return 1
    fi
    
    # Check if home directory was created
    if [[ ! -d "/home/${TEST_USER}" ]]; then
        echo "Home directory was not created"
        return 1
    fi
    
    echo "User created successfully"
    return 0
}

# Test 3: Resource Limits
test_resource_limits() {
    echo "Testing resource limits..."
    
    if [[ ! -f "/opt/diycloud/resources/apply_limits.sh" ]]; then
        echo "Missing script: /opt/diycloud/resources/apply_limits.sh"
        return 1
    fi
    
    chmod +x /opt/diycloud/resources/apply_limits.sh
    /opt/diycloud/resources/apply_limits.sh "${TEST_USER}" "${TEST_CPU}" "${TEST_MEM}" "${TEST_DISK}" "false"
    
    # Check if cgroup was created
    if [[ "${CGROUP_VERSION}" == "v1" ]]; then
        if [[ ! -d "/sys/fs/cgroup/cpu/user/${TEST_USER}" ]]; then
            echo "CPU cgroup (v1) not created"
            return 1
        fi
        if [[ ! -d "/sys/fs/cgroup/memory/user/${TEST_USER}" ]]; then
            echo "Memory cgroup (v1) not created"
            return 1
        fi
    elif [[ "${CGROUP_VERSION}" == "v2" ]]; then
        if [[ ! -d "/sys/fs/cgroup/user/${TEST_USER}" ]]; then
            echo "User cgroup (v2) not created"
            return 1
        fi
    fi

     # Display resource usage
    /opt/diycloud/resources/apply_limits.sh "${TEST_USER}"
    
    echo "Resource limits applied successfully"
    return 0
}

# Test 4: Updating Resource Limits
test_update_limits() {
    echo "Testing resource limit updates..."
    
    # Define new limits
    local new_cpu="1.0"
    local new_mem="1024"
    local new_disk="2048"
    
    # Update limits
    source /opt/diycloud/resources/apply_limits.sh
    update_user_resource_limits "${TEST_USER}" "${new_cpu}" "${new_mem}" "${new_disk}" "false"
    
    # Check if limits were updated in database
    local db_file="/opt/diycloud/usermgmt/db/users.db"
    local user_id=$(sqlite3 "${db_file}" "SELECT id FROM users WHERE username='${TEST_USER}';")
    
    local db_cpu=$(sqlite3 "${db_file}" "SELECT cpu_limit FROM resource_allocations WHERE user_id=${user_id};")
    local db_mem=$(sqlite3 "${db_file}" "SELECT mem_limit FROM resource_allocations WHERE user_id=${user_id};")
    local db_disk=$(sqlite3 "${db_file}" "SELECT disk_quota FROM resource_allocations WHERE user_id=${user_id};")
    
    echo "Database values: CPU=${db_cpu}, Memory=${db_mem}, Disk=${db_disk}"
    
    # Verify database was updated
    if [[ "${db_cpu}" != "${new_cpu}" ]]; then
        echo "CPU limit was not updated in database"
        return 1
    fi
    
    echo "Resource limits updated successfully"
    return 0
}

# Test 5: Cleanup
test_cleanup() {
    echo "Testing cleanup..."
    
    # Remove test user
    userdel -rf "${TEST_USER}" || true
    
    # Remove from database
    sqlite3 /opt/diycloud/usermgmt/db/users.db "DELETE FROM users WHERE username='${TEST_USER}';" || true
    
    # Remove cgroups
    if [[ "${CGROUP_VERSION}" == "v1" ]]; then
        rm -rf "/sys/fs/cgroup/cpu/user/${TEST_USER}" 2>/dev/null || true
        rm -rf "/sys/fs/cgroup/memory/user/${TEST_USER}" 2>/dev/null || true
    elif [[ "${CGROUP_VERSION}" == "v2" ]]; then
        rm -rf "/sys/fs/cgroup/user/${TEST_USER}" 2>/dev/null || true
    fi
    
    echo "Cleanup completed successfully"
    return 0
}

# Run all tests
main() {
    log_message "Starting Phase 2 tests..." "info"
    
    run_test "Database Initialization" "test_database_init"
    run_test "User Creation" "test_user_creation"
    run_test "Resource Limits" "test_resource_limits"
    run_test "Update Resource Limits" "test_update_limits"
    run_test "Cleanup" "test_cleanup"
    
    log_message "All Phase 2 tests passed!" "success"
    return 0
}

# Execute main function
main