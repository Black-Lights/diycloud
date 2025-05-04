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
# DIY Cloud Platform - Path Resolution Script
# 
# This script provides path resolution functions that abstract away
# distribution-specific file paths and locations.
#
# Usage: source path_resolver.sh

# Ensure detect_distro.sh is sourced
if [[ -z "${DISTRO}" || -z "${DISTRO_FAMILY}" ]]; then
    if [[ -f "$(dirname "$0")/detect_distro.sh" ]]; then
        source "$(dirname "$0")/detect_distro.sh"
    else
        echo "Error: detect_distro.sh not found or not sourced"
        return 1
    fi
fi

# Path mapping tables
declare -A CONFIG_PATHS
declare -A LOG_PATHS
declare -A LIB_PATHS
declare -A BIN_PATHS
declare -A SERVICE_PATHS

# Configuration paths by distribution family
# Debian family (Ubuntu, Debian)
CONFIG_PATHS["debian:nginx"]="/etc/nginx"
CONFIG_PATHS["debian:nginx_sites"]="/etc/nginx/sites-available"
CONFIG_PATHS["debian:nginx_enabled"]="/etc/nginx/sites-enabled"
CONFIG_PATHS["debian:jupyterhub"]="/etc/jupyterhub"
CONFIG_PATHS["debian:docker"]="/etc/docker"
CONFIG_PATHS["debian:prometheus"]="/etc/prometheus"
CONFIG_PATHS["debian:grafana"]="/etc/grafana"
CONFIG_PATHS["debian:systemd"]="/etc/systemd/system"
CONFIG_PATHS["debian:supervisor"]="/etc/supervisor/conf.d"
CONFIG_PATHS["debian:cron"]="/etc/cron.d"

# RedHat family (RHEL, CentOS, Fedora)
CONFIG_PATHS["redhat:nginx"]="/etc/nginx"
CONFIG_PATHS["redhat:nginx_sites"]="/etc/nginx/conf.d"
CONFIG_PATHS["redhat:nginx_enabled"]="/etc/nginx/conf.d"
CONFIG_PATHS["redhat:jupyterhub"]="/etc/jupyterhub"
CONFIG_PATHS["redhat:docker"]="/etc/docker"
CONFIG_PATHS["redhat:prometheus"]="/etc/prometheus"
CONFIG_PATHS["redhat:grafana"]="/etc/grafana"
CONFIG_PATHS["redhat:systemd"]="/etc/systemd/system"
CONFIG_PATHS["redhat:supervisor"]="/etc/supervisord.d"
CONFIG_PATHS["redhat:cron"]="/etc/cron.d"

# Arch family (Arch Linux, Manjaro)
CONFIG_PATHS["arch:nginx"]="/etc/nginx"
CONFIG_PATHS["arch:nginx_sites"]="/etc/nginx/sites-available"
CONFIG_PATHS["arch:nginx_enabled"]="/etc/nginx/sites-enabled"
CONFIG_PATHS["arch:jupyterhub"]="/etc/jupyterhub"
CONFIG_PATHS["arch:docker"]="/etc/docker"
CONFIG_PATHS["arch:prometheus"]="/etc/prometheus"
CONFIG_PATHS["arch:grafana"]="/etc/grafana"
CONFIG_PATHS["arch:systemd"]="/etc/systemd/system"
CONFIG_PATHS["arch:supervisor"]="/etc/supervisor.d"
CONFIG_PATHS["arch:cron"]="/etc/cron.d"

# SuSE family (OpenSUSE)
CONFIG_PATHS["suse:nginx"]="/etc/nginx"
CONFIG_PATHS["suse:nginx_sites"]="/etc/nginx/vhosts.d"
CONFIG_PATHS["suse:nginx_enabled"]="/etc/nginx/vhosts.d"
CONFIG_PATHS["suse:jupyterhub"]="/etc/jupyterhub"
CONFIG_PATHS["suse:docker"]="/etc/docker"
CONFIG_PATHS["suse:prometheus"]="/etc/prometheus"
CONFIG_PATHS["suse:grafana"]="/etc/grafana"
CONFIG_PATHS["suse:systemd"]="/etc/systemd/system"
CONFIG_PATHS["suse:supervisor"]="/etc/supervisor.d"
CONFIG_PATHS["suse:cron"]="/etc/cron.d"

# Log paths by distribution family
# Debian family
LOG_PATHS["debian:nginx"]="/var/log/nginx"
LOG_PATHS["debian:jupyterhub"]="/var/log/jupyterhub"
LOG_PATHS["debian:docker"]="/var/log/docker"
LOG_PATHS["debian:prometheus"]="/var/log/prometheus"
LOG_PATHS["debian:grafana"]="/var/log/grafana"
LOG_PATHS["debian:syslog"]="/var/log/syslog"
LOG_PATHS["debian:auth"]="/var/log/auth.log"

# RedHat family
LOG_PATHS["redhat:nginx"]="/var/log/nginx"
LOG_PATHS["redhat:jupyterhub"]="/var/log/jupyterhub"
LOG_PATHS["redhat:docker"]="/var/log/docker"
LOG_PATHS["redhat:prometheus"]="/var/log/prometheus"
LOG_PATHS["redhat:grafana"]="/var/log/grafana"
LOG_PATHS["redhat:syslog"]="/var/log/messages"
LOG_PATHS["redhat:auth"]="/var/log/secure"

# Arch family
LOG_PATHS["arch:nginx"]="/var/log/nginx"
LOG_PATHS["arch:jupyterhub"]="/var/log/jupyterhub"
LOG_PATHS["arch:docker"]="/var/log/docker"
LOG_PATHS["arch:prometheus"]="/var/log/prometheus"
LOG_PATHS["arch:grafana"]="/var/log/grafana"
LOG_PATHS["arch:syslog"]="/var/log/syslog.log"
LOG_PATHS["arch:auth"]="/var/log/auth.log"

# SuSE family
LOG_PATHS["suse:nginx"]="/var/log/nginx"
LOG_PATHS["suse:jupyterhub"]="/var/log/jupyterhub"
LOG_PATHS["suse:docker"]="/var/log/docker"
LOG_PATHS["suse:prometheus"]="/var/log/prometheus"
LOG_PATHS["suse:grafana"]="/var/log/grafana"
LOG_PATHS["suse:syslog"]="/var/log/messages"
LOG_PATHS["suse:auth"]="/var/log/secure"

# Library paths by distribution family
# Debian family
LIB_PATHS["debian:python"]="/usr/lib/python3/dist-packages"
LIB_PATHS["debian:node"]="/usr/lib/node_modules"
LIB_PATHS["debian:systemd"]="/lib/systemd"
LIB_PATHS["debian:nginx"]="/usr/lib/nginx"

# RedHat family
LIB_PATHS["redhat:python"]="/usr/lib/python3.*/site-packages"
LIB_PATHS["redhat:node"]="/usr/lib/node_modules"
LIB_PATHS["redhat:systemd"]="/usr/lib/systemd"
LIB_PATHS["redhat:nginx"]="/usr/lib64/nginx"

# Arch family
LIB_PATHS["arch:python"]="/usr/lib/python3.*/site-packages"
LIB_PATHS["arch:node"]="/usr/lib/node_modules"
LIB_PATHS["arch:systemd"]="/usr/lib/systemd"
LIB_PATHS["arch:nginx"]="/usr/lib/nginx"

# SuSE family
LIB_PATHS["suse:python"]="/usr/lib/python3.*/site-packages"
LIB_PATHS["suse:node"]="/usr/lib/node_modules"
LIB_PATHS["suse:systemd"]="/usr/lib/systemd"
LIB_PATHS["suse:nginx"]="/usr/lib/nginx"

# Binary paths by distribution family
# These are generally more consistent across distributions
BIN_PATHS["common:python"]="/usr/bin/python3"
BIN_PATHS["common:pip"]="/usr/bin/pip3"
BIN_PATHS["common:node"]="/usr/bin/node"
BIN_PATHS["common:npm"]="/usr/bin/npm"
BIN_PATHS["common:docker"]="/usr/bin/docker"
BIN_PATHS["common:jupyter"]="/usr/local/bin/jupyter"
BIN_PATHS["common:jupyterhub"]="/usr/local/bin/jupyterhub"

# Service paths by distribution family
# Debian family
SERVICE_PATHS["debian:nginx"]="nginx"
SERVICE_PATHS["debian:docker"]="docker"
SERVICE_PATHS["debian:jupyterhub"]="jupyterhub"
SERVICE_PATHS["debian:prometheus"]="prometheus"
SERVICE_PATHS["debian:grafana"]="grafana"

# RedHat family
SERVICE_PATHS["redhat:nginx"]="nginx"
SERVICE_PATHS["redhat:docker"]="docker"
SERVICE_PATHS["redhat:jupyterhub"]="jupyterhub"
SERVICE_PATHS["redhat:prometheus"]="prometheus"
SERVICE_PATHS["redhat:grafana"]="grafana"

# Arch family
SERVICE_PATHS["arch:nginx"]="nginx"
SERVICE_PATHS["arch:docker"]="docker"
SERVICE_PATHS["arch:jupyterhub"]="jupyterhub"
SERVICE_PATHS["arch:prometheus"]="prometheus"
SERVICE_PATHS["arch:grafana"]="grafana"

# SuSE family
SERVICE_PATHS["suse:nginx"]="nginx"
SERVICE_PATHS["suse:docker"]="docker"
SERVICE_PATHS["suse:jupyterhub"]="jupyterhub"
SERVICE_PATHS["suse:prometheus"]="prometheus"
SERVICE_PATHS["suse:grafana"]="grafana"

# Function to get configuration path for a service
# Usage: get_config_path "service_name"
get_config_path() {
    local service_name="$1"
    local distro_key="${DISTRO_FAMILY}:${service_name}"
    
    # Return the distribution-specific config path if it exists
    if [[ -n "${CONFIG_PATHS[${distro_key}]}" ]]; then
        echo "${CONFIG_PATHS[${distro_key}]}"
        return 0
    fi
    
    # Default fallback path
    echo "/etc/${service_name}"
    return 0
}

# Function to get log path for a service
# Usage: get_log_path "service_name"
get_log_path() {
    local service_name="$1"
    local distro_key="${DISTRO_FAMILY}:${service_name}"
    
    # Return the distribution-specific log path if it exists
    if [[ -n "${LOG_PATHS[${distro_key}]}" ]]; then
        echo "${LOG_PATHS[${distro_key}]}"
        return 0
    fi
    
    # Default fallback path
    echo "/var/log/${service_name}"
    return 0
}

# Function to get library path
# Usage: get_lib_path "library_name"
get_lib_path() {
    local library_name="$1"
    local distro_key="${DISTRO_FAMILY}:${library_name}"
    
    # Return the distribution-specific library path if it exists
    if [[ -n "${LIB_PATHS[${distro_key}]}" ]]; then
        echo "${LIB_PATHS[${distro_key}]}"
        return 0
    fi
    
    # Check common paths
    if [[ -n "${LIB_PATHS[common:${library_name}]}" ]]; then
        echo "${LIB_PATHS[common:${library_name}]}"
        return 0
    fi
    
    # Default fallback path
    echo "/usr/lib/${library_name}"
    return 0
}

# Function to get binary path
# Usage: get_bin_path "binary_name"
get_bin_path() {
    local binary_name="$1"
    
    # Check common paths first
    if [[ -n "${BIN_PATHS[common:${binary_name}]}" ]]; then
        echo "${BIN_PATHS[common:${binary_name}]}"
        return 0
    fi
    
    # Check for distribution-specific paths
    local distro_key="${DISTRO_FAMILY}:${binary_name}"
    if [[ -n "${BIN_PATHS[${distro_key}]}" ]]; then
        echo "${BIN_PATHS[${distro_key}]}"
        return 0
    fi
    
    # Try to find the binary in PATH
    if command -v "${binary_name}" &> /dev/null; then
        command -v "${binary_name}"
        return 0
    fi
    
    # Default fallback path
    echo "/usr/bin/${binary_name}"
    return 0
}

# Function to get service name
# Usage: get_service_name "service_identifier"
get_service_name() {
    local service_identifier="$1"
    local distro_key="${DISTRO_FAMILY}:${service_identifier}"
    
    # Return the distribution-specific service name if it exists
    if [[ -n "${SERVICE_PATHS[${distro_key}]}" ]]; then
        echo "${SERVICE_PATHS[${distro_key}]}"
        return 0
    fi
    
    # Default fallback is the service identifier itself
    echo "${service_identifier}"
    return 0
}

# Function to get cgroup path
# Usage: get_cgroup_path ["subsystem"]
get_cgroup_path() {
    local subsystem="${1:-}"
    
    # Handle cgroups v1 vs v2
    if [[ "${CGROUP_VERSION}" == "v2" ]]; then
        if [[ -z "${subsystem}" ]]; then
            echo "/sys/fs/cgroup"
        else
            echo "/sys/fs/cgroup"
        fi
    elif [[ "${CGROUP_VERSION}" == "hybrid" ]]; then
        if [[ -z "${subsystem}" ]]; then
            echo "/sys/fs/cgroup"
        elif [[ -d "/sys/fs/cgroup/${subsystem}" ]]; then
            echo "/sys/fs/cgroup/${subsystem}"
        else
            echo "/sys/fs/cgroup/unified"
        fi
    else
        # cgroups v1
        if [[ -z "${subsystem}" ]]; then
            echo "/sys/fs/cgroup"
        elif [[ -d "/sys/fs/cgroup/${subsystem}" ]]; then
            echo "/sys/fs/cgroup/${subsystem}"
        else
            echo "/sys/fs/cgroup"
        fi
    fi
    
    return 0
}

# Function to get Python executable path
# Usage: get_python_path
get_python_path() {
    # Try to find python3 first
    if command -v python3 &> /dev/null; then
        command -v python3
        return 0
    fi
    
    # Fall back to python
    if command -v python &> /dev/null; then
        command -v python
        return 0
    fi
    
    # Default fallback
    echo "/usr/bin/python3"
    return 0
}

# Function to get pip executable path
# Usage: get_pip_path
get_pip_path() {
    # Try to find pip3 first
    if command -v pip3 &> /dev/null; then
        command -v pip3
        return 0
    fi
    
    # Fall back to pip
    if command -v pip &> /dev/null; then
        command -v pip
        return 0
    fi
    
    # Default fallback
    echo "/usr/bin/pip3"
    return 0
}

# Function to create directory if it doesn't exist
# Usage: ensure_directory "directory_path" ["owner:group"] ["permissions"]
ensure_directory() {
    local directory_path="$1"
    local owner_group="${2:-}"
    local permissions="${3:-755}"
    
    if [[ ! -d "${directory_path}" ]]; then
        echo "Creating directory: ${directory_path}"
        mkdir -p "${directory_path}"
        if [[ $? -ne 0 ]]; then
            echo "Failed to create directory: ${directory_path}"
            return 1
        fi
    fi
    
    # Set permissions
    chmod "${permissions}" "${directory_path}"
    
    # Set owner:group if specified
    if [[ -n "${owner_group}" ]]; then
        chown "${owner_group}" "${directory_path}"
    fi
    
    return 0
}

# Function to get the primary user data directory
# Usage: get_user_data_directory
get_user_data_directory() {
    # This is fairly consistent across distributions
    echo "/home"
    return 0
}

# Export functions
export -f get_config_path
export -f get_log_path
export -f get_lib_path
export -f get_bin_path
export -f get_service_name
export -f get_cgroup_path
export -f get_python_path
export -f get_pip_path
export -f ensure_directory
export -f get_user_data_directory
