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
# DIY Cloud Platform - Service Management Abstraction Script
# 
# This script provides service management functions that abstract away
# distribution-specific service manager implementations.
#
# Usage: source service_manager.sh

# Ensure detect_distro.sh is sourced
if [[ -z "${DISTRO}" || -z "${SERVICE_MANAGER}" ]]; then
    if [[ -f "$(dirname "$0")/detect_distro.sh" ]]; then
        source "$(dirname "$0")/detect_distro.sh"
    else
        echo "Error: detect_distro.sh not found or not sourced"
        return 1
    fi
fi

# Function to start a service
# Usage: start_service "service_name"
start_service() {
    local service_name="$1"
    
    echo "Starting service: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl start "${service_name}"
            ;;
        sysv)
            service "${service_name}" start
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} started successfully"
    else
        echo "Failed to start service ${service_name}"
    fi
    
    return $result
}

# Function to stop a service
# Usage: stop_service "service_name"
stop_service() {
    local service_name="$1"
    
    echo "Stopping service: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl stop "${service_name}"
            ;;
        sysv)
            service "${service_name}" stop
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} stopped successfully"
    else
        echo "Failed to stop service ${service_name}"
    fi
    
    return $result
}

# Function to restart a service
# Usage: restart_service "service_name"
restart_service() {
    local service_name="$1"
    
    echo "Restarting service: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl restart "${service_name}"
            ;;
        sysv)
            service "${service_name}" restart
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} restarted successfully"
    else
        echo "Failed to restart service ${service_name}"
    fi
    
    return $result
}

# Function to enable a service at boot
# Usage: enable_service "service_name"
enable_service() {
    local service_name="$1"
    
    echo "Enabling service to start at boot: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl enable "${service_name}"
            ;;
        sysv)
            if command -v chkconfig &> /dev/null; then
                # RHEL/CentOS
                chkconfig "${service_name}" on
            elif command -v update-rc.d &> /dev/null; then
                # Debian/Ubuntu
                update-rc.d "${service_name}" defaults
            else
                echo "Unable to enable service with SysV init"
                return 1
            fi
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} enabled successfully"
    else
        echo "Failed to enable service ${service_name}"
    fi
    
    return $result
}

# Function to disable a service at boot
# Usage: disable_service "service_name"
disable_service() {
    local service_name="$1"
    
    echo "Disabling service at boot: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl disable "${service_name}"
            ;;
        sysv)
            if command -v chkconfig &> /dev/null; then
                # RHEL/CentOS
                chkconfig "${service_name}" off
            elif command -v update-rc.d &> /dev/null; then
                # Debian/Ubuntu
                update-rc.d "${service_name}" remove
            else
                echo "Unable to disable service with SysV init"
                return 1
            fi
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} disabled successfully"
    else
        echo "Failed to disable service ${service_name}"
    fi
    
    return $result
}

# Function to check service status
# Usage: service_status "service_name"
service_status() {
    local service_name="$1"
    
    echo "Checking status of service: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl status "${service_name}"
            ;;
        sysv)
            service "${service_name}" status
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to check if a service is active/running
# Usage: is_service_active "service_name"
is_service_active() {
    local service_name="$1"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl is-active "${service_name}" &> /dev/null
            ;;
        sysv)
            service "${service_name}" status &> /dev/null
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to check if a service is enabled at boot
# Usage: is_service_enabled "service_name"
is_service_enabled() {
    local service_name="$1"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl is-enabled "${service_name}" &> /dev/null
            ;;
        sysv)
            # This is approximate for SysV init
            if command -v chkconfig &> /dev/null; then
                # RHEL/CentOS
                chkconfig --list "${service_name}" | grep -q "on" &> /dev/null
            elif command -v update-rc.d &> /dev/null; then
                # Debian/Ubuntu - check if there are any symlinks in the rcN.d directories
                ls /etc/rc*.d/S*"${service_name}" &> /dev/null
            else
                echo "Unable to check if service is enabled with SysV init"
                return 1
            fi
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to create a systemd service
# Usage: create_systemd_service "service_name" "description" "exec_start" ["user"] ["working_directory"]
create_systemd_service() {
    local service_name="$1"
    local description="$2"
    local exec_start="$3"
    local user="${4:-root}"
    local working_dir="${5:-/}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    if [[ "${SERVICE_MANAGER}" != "systemd" ]]; then
        echo "This function is only supported on systemd systems"
        return 1
    fi
    
    echo "Creating systemd service: ${service_name}"
    
    cat > "${service_file}" << EOF
[Unit]
Description=${description}
After=network.target

[Service]
User=${user}
WorkingDirectory=${working_dir}
ExecStart=${exec_start}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd to recognize the new service file
    systemctl daemon-reload
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} created successfully"
    else
        echo "Failed to create service ${service_name}"
    fi
    
    return $result
}

# Function to reload service configuration
# Usage: reload_service "service_name"
reload_service() {
    local service_name="$1"
    
    echo "Reloading service configuration: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            systemctl reload "${service_name}"
            ;;
        sysv)
            service "${service_name}" reload
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Service ${service_name} configuration reloaded successfully"
    else
        echo "Failed to reload service ${service_name} configuration"
    fi
    
    return $result
}

# Function to get service logs
# Usage: get_service_logs "service_name" [lines]
get_service_logs() {
    local service_name="$1"
    local lines="${2:-50}"
    
    echo "Getting logs for service: ${service_name}"
    
    case "${SERVICE_MANAGER}" in
        systemd)
            journalctl -u "${service_name}" -n "${lines}"
            ;;
        sysv)
            # Try to find the log file based on service name
            local log_file=""
            
            # Common log locations
            local log_locations=(
                "/var/log/${service_name}.log"
                "/var/log/${service_name}/${service_name}.log"
                "/var/log/syslog"
            )
            
            # Use the first log file that exists
            for loc in "${log_locations[@]}"; do
                if [[ -f "${loc}" ]]; then
                    log_file="${loc}"
                    break
                fi
            done
            
            if [[ -n "${log_file}" ]]; then
                tail -n "${lines}" "${log_file}"
            else
                echo "Unable to find log file for service: ${service_name}"
                return 1
            fi
            ;;
        *)
            echo "Unsupported service manager: ${SERVICE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Export functions
export -f start_service
export -f stop_service
export -f restart_service
export -f enable_service
export -f disable_service
export -f service_status
export -f is_service_active
export -f is_service_enabled
export -f create_systemd_service
export -f reload_service
export -f get_service_logs
