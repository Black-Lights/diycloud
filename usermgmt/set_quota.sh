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
# DIY Cloud Platform - Set User Quota Script
#
# This script sets resource quotas for an existing user

# Exit on error
set -e

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/resource_adapter.sh
source /opt/diycloud/lib/common.sh

# Source the resource management scripts
source /opt/diycloud/resources/apply_limits.sh

# Database file
DB_FILE="/opt/diycloud/usermgmt/db/users.db"

# Default values
DEFAULT_CPU_LIMIT="1.0"
DEFAULT_MEM_LIMIT="2048"  # 2GB in MB
DEFAULT_DISK_QUOTA="5120"  # 5GB in MB
DEFAULT_GPU_ACCESS="false"

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Set resource quotas for an existing user"
    echo ""
    echo "Options:"
    echo "  --username USERNAME    Username (required)"
    echo "  --cpu LIMIT            CPU limit (cores, default: ${DEFAULT_CPU_LIMIT})"
    echo "  --memory LIMIT         Memory limit (MB, default: ${DEFAULT_MEM_LIMIT})"
    echo "  --disk QUOTA           Disk quota (MB, default: ${DEFAULT_DISK_QUOTA})"
    echo "  --gpu BOOLEAN          Enable/disable GPU access (true/false, default: ${DEFAULT_GPU_ACCESS})"
    echo "  --help                 Show this help message"
    exit 1
}

# Parse arguments
USERNAME=""
CPU_LIMIT="${DEFAULT_CPU_LIMIT}"
MEM_LIMIT="${DEFAULT_MEM_LIMIT}"
DISK_QUOTA="${DEFAULT_DISK_QUOTA}"
GPU_ACCESS="${DEFAULT_GPU_ACCESS}"

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --username)
        USERNAME="$2"
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
        --gpu)
        GPU_ACCESS="$2"
        shift
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

# Function to check if user exists
check_user_exists() {
    local username="$1"
    
    # Check if system user exists
    if ! id "${username}" &>/dev/null; then
        log_message "System user does not exist: ${username}" "error"
        return 1
    fi
    
    # Check if database user exists
    if [[ -f "${DB_FILE}" ]]; then
        if ! sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM users WHERE username='${username}';" | grep -q "1"; then
            log_message "Database user does not exist: ${username}" "error"
            return 1
        fi
    else
        log_message "Database file not found: ${DB_FILE}" "warning"
    }
    
    return 0
}

# Function to update database
update_database() {
    local username="$1"
    local cpu_limit="$2"
    local mem_limit="$3"
    local disk_quota="$4"
    local gpu_access="$5"
    
    log_message "Updating database for user: ${username}" "info"
    
    if [[ ! -f "${DB_FILE}" ]]; then
        log_message "Database file not found: ${DB_FILE}" "error"
        return 1
    fi
    
    # Get user ID
    local user_id=$(sqlite3 "${DB_FILE}" "SELECT id FROM users WHERE username='${username}';")
    
    if [[ -z "${user_id}" ]]; then
        log_message "User ID not found for: ${username}" "error"
        return 1
    fi
    
    # Format memory and disk values
    local mem_db="${mem_limit}M"
    local disk_db="${disk_quota}M"
    
    # Update resource allocations
    sqlite3 "${DB_FILE}" <<EOF
UPDATE resource_allocations 
SET cpu_limit=${cpu_limit}, mem_limit='${mem_db}', disk_quota='${disk_db}', gpu_access=${gpu_access} 
WHERE user_id=${user_id};
EOF
    
    log_message "Database updated successfully" "info"
    return 0
}

# Main function
main() {
    log_message "Setting resource quotas for user: ${USERNAME}" "info"
    
    # Check if user exists
    check_user_exists "${USERNAME}" || exit 1
    
    # Update database
    update_database "${USERNAME}" "${CPU_LIMIT}" "${MEM_LIMIT}" "${DISK_QUOTA}" "${GPU_ACCESS}" || true
    
    # Apply resource limits
    apply_user_resource_limits "${USERNAME}" "${CPU_LIMIT}" "${MEM_LIMIT}" "${DISK_QUOTA}" "${GPU_ACCESS}"
    
    # Display updated resource limits
    log_message "Updated resource limits for user: ${USERNAME}" "info"
    get_user_resource_usage "${USERNAME}"
    
    return 0
}

# Run the main function
main