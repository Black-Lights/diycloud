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