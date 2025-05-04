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
# DIY Cloud Platform - PAM Configuration Script
#
# This script configures PAM for authentication in the DIY Cloud Platform

# Exit on error
set -e

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/common.sh

# PAM configuration directory
PAM_DIR="/etc/pam.d"
SERVICE_NAME="diycloud"

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Configure PAM for DIY Cloud Platform authentication"
    echo ""
    echo "Options:"
    echo "  --help              Show this help message"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --help)
        usage
        ;;
        *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

# Function to create PAM configuration
create_pam_config() {
    log_message "Creating PAM configuration..." "info"
    
    # Check if PAM directory exists
    if [[ ! -d "${PAM_DIR}" ]]; then
        log_message "PAM directory not found: ${PAM_DIR}" "error"
        return 1
    fi
    
    # Create PAM configuration file
    log_message "Creating PAM configuration file: ${PAM_DIR}/${SERVICE_NAME}" "info"
    
    # Different configurations based on distribution
    case "${DISTRO_FAMILY}" in
        debian)
            create_pam_config_debian
            ;;
        redhat)
            create_pam_config_redhat
            ;;
        arch)
            create_pam_config_arch
            ;;
        suse)
            create_pam_config_suse
            ;;
        *)
            log_message "Unsupported distribution family: ${DISTRO_FAMILY}" "error"
            return 1
            ;;
    esac
    
    log_message "PAM configuration created successfully" "info"
    return 0
}

# Function to create PAM configuration for Debian-based distributions
create_pam_config_debian() {
    cat > "${PAM_DIR}/${SERVICE_NAME}" << EOF
# DIY Cloud Platform PAM Configuration

# Authentication
auth    required        pam_unix.so nullok_secure
auth    optional        pam_permit.so

# Account management
account required        pam_unix.so
account optional        pam_permit.so

# Password management
password required       pam_unix.so nullok obscure sha512

# Session management
session required        pam_unix.so
session optional        pam_limits.so
session optional        pam_systemd.so
session optional        pam_env.so
session optional        pam_permit.so
EOF

    # Check if configuration was created
    if [[ ! -f "${PAM_DIR}/${SERVICE_NAME}" ]]; then
        log_message "Failed to create PAM configuration" "error"
        return 1
    fi
    
    # Set proper permissions
    chmod 644 "${PAM_DIR}/${SERVICE_NAME}"
    
    log_message "Debian PAM configuration created" "info"
    return 0
}

# Function to create PAM configuration for RedHat-based distributions
create_pam_config_redhat() {
    cat > "${PAM_DIR}/${SERVICE_NAME}" << EOF
# DIY Cloud Platform PAM Configuration

# Authentication
auth    required        pam_unix.so nullok
auth    optional        pam_permit.so

# Account management
account required        pam_unix.so
account optional        pam_permit.so

# Password management
password required       pam_unix.so nullok sha512 shadow try_first_pass use_authtok

# Session management
session required        pam_unix.so
session optional        pam_limits.so
session optional        pam_systemd.so
session optional        pam_env.so
session optional        pam_permit.so
EOF

    # Check if configuration was created
    if [[ ! -f "${PAM_DIR}/${SERVICE_NAME}" ]]; then
        log_message "Failed to create PAM configuration" "error"
        return 1
    fi
    
    # Set proper permissions
    chmod 644 "${PAM_DIR}/${SERVICE_NAME}"
    
    log_message "RedHat PAM configuration created" "info"
    return 0
}

# Function to create PAM configuration for Arch Linux
create_pam_config_arch() {
    cat > "${PAM_DIR}/${SERVICE_NAME}" << EOF
# DIY Cloud Platform PAM Configuration

# Authentication
auth    required        pam_unix.so nullok
auth    optional        pam_permit.so

# Account management
account required        pam_unix.so
account optional        pam_permit.so

# Password management
password required       pam_unix.so nullok sha512 shadow

# Session management
session required        pam_unix.so
session optional        pam_limits.so
session optional        pam_systemd.so
session optional        pam_env.so
session optional        pam_permit.so
EOF

    # Check if configuration was created
    if [[ ! -f "${PAM_DIR}/${SERVICE_NAME}" ]]; then
        log_message "Failed to create PAM configuration" "error"
        return 1
    fi
    
    # Set proper permissions
    chmod 644 "${PAM_DIR}/${SERVICE_NAME}"
    
    log_message "Arch PAM configuration created" "info"
    return 0
}

# Function to create PAM configuration for SUSE Linux
create_pam_config_suse() {
    cat > "${PAM_DIR}/${SERVICE_NAME}" << EOF
# DIY Cloud Platform PAM Configuration

# Authentication
auth    required        pam_unix.so nullok
auth    optional        pam_permit.so

# Account management
account required        pam_unix.so
account optional        pam_permit.so

# Password management
password required       pam_unix.so nullok use_authtok

# Session management
session required        pam_unix.so
session optional        pam_limits.so
session optional        pam_systemd.so
session optional        pam_env.so
session optional        pam_permit.so
EOF

    # Check if configuration was created
    if [[ ! -f "${PAM_DIR}/${SERVICE_NAME}" ]]; then
        log_message "Failed to create PAM configuration" "error"
        return 1
    fi
    
    # Set proper permissions
    chmod 644 "${PAM_DIR}/${SERVICE_NAME}"
    
    log_message "SUSE PAM configuration created" "info"
    return 0
}

# Function to configure limits.conf
configure_limits_conf() {
    log_message "Configuring limits.conf..." "info"
    
    local limits_conf="/etc/security/limits.conf"
    
    # Check if limits.conf exists
    if [[ ! -f "${limits_conf}" ]]; then
        log_message "limits.conf not found: ${limits_conf}" "error"
        return 1
    fi
    
    # Backup existing configuration
    cp "${limits_conf}" "${limits_conf}.bak"
    
    # Add DIY Cloud Platform limits
    if ! grep -q "# DIY Cloud Platform limits" "${limits_conf}"; then
        cat >> "${limits_conf}" << EOF

# DIY Cloud Platform limits
# These limits are managed by the DIY Cloud Platform and should not be edited manually
*               soft    nproc           1024
*               hard    nproc           4096
*               soft    nofile          1024
*               hard    nofile          65536
*               soft    stack           8192
*               hard    stack           65536
EOF
    fi
    
    log_message "limits.conf configured successfully" "info"
    return 0
}

# Function to setup groups
setup_groups() {
    log_message "Setting up groups..." "info"
    
    # Create diycloud group if it doesn't exist
    if ! getent group diycloud &>/dev/null; then
        groupadd diycloud
    fi
    
    # Create diycloud-admin group if it doesn't exist
    if ! getent group diycloud-admin &>/dev/null; then
        groupadd diycloud-admin
    fi
    
    # Create diycloud-user group if it doesn't exist
    if ! getent group diycloud-user &>/dev/null; then
        groupadd diycloud-user
    fi
    
    log_message "Groups created successfully" "info"
    return 0
}

# Main function
main() {
    log_message "Configuring PAM for DIY Cloud Platform..." "info"
    
    # Create PAM configuration
    create_pam_config
    
    # Configure limits.conf
    configure_limits_conf
    
    # Setup groups
    setup_groups
    
    log_message "PAM configuration completed successfully" "info"
    return 0
}

# Run the main function
main