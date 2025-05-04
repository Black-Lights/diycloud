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