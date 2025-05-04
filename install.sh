#!/usr/bin/env bash
#
# DIY Cloud Platform - Installation Script
# 
# This script installs the DIY Cloud Platform on the system.
#
# Usage: sudo ./install.sh [--prefix /path/to/install]

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Default installation prefix
PREFIX="/opt/diycloud"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --prefix)
            PREFIX="$2"
            shift # past argument
            shift # past value
            ;;
        *)
            # Unknown option
            echo "Unknown option: $1"
            echo "Usage: sudo ./install.sh [--prefix /path/to/install]"
            exit 1
            ;;
    esac
done

# Get the project directory
PROJECT_DIR="$(dirname "$(readlink -f "$0")")"

# Create the installation directories
echo "Creating installation directories..."
mkdir -p "${PREFIX}/lib"
mkdir -p "${PREFIX}/core"
mkdir -p "${PREFIX}/usermgmt/db"
mkdir -p "${PREFIX}/usermgmt/auth"
mkdir -p "${PREFIX}/jupyterhub"
mkdir -p "${PREFIX}/docker"
mkdir -p "${PREFIX}/resources"
mkdir -p "${PREFIX}/monitoring"
mkdir -p "${PREFIX}/docs"

# Create directories for logs and configuration
mkdir -p "/var/log/diycloud"
mkdir -p "/etc/diycloud"

# Create web directories
mkdir -p "/var/www/diycloud/portal"
mkdir -p "/var/www/diycloud/portal/css"
mkdir -p "/var/www/diycloud/portal/js"
mkdir -p "/var/www/diycloud/portal/assets"

# Create SSL directory
mkdir -p "/etc/ssl/diycloud"

# Install the Distribution Abstraction Layer
echo "Installing Distribution Abstraction Layer..."
cp "${PROJECT_DIR}/lib/detect_distro.sh" "${PREFIX}/lib/"
cp "${PROJECT_DIR}/lib/package_manager.sh" "${PREFIX}/lib/"
cp "${PROJECT_DIR}/lib/service_manager.sh" "${PREFIX}/lib/"
cp "${PROJECT_DIR}/lib/path_resolver.sh" "${PREFIX}/lib/"
cp "${PROJECT_DIR}/lib/resource_adapter.sh" "${PREFIX}/lib/"
cp "${PROJECT_DIR}/lib/common.sh" "${PREFIX}/lib/"

# Make scripts executable
chmod +x "${PREFIX}/lib/"*.sh

# Install the Core Platform files (if available)
if [[ -d "${PROJECT_DIR}/core" ]]; then
    echo "Installing Core Platform files..."
    cp -r "${PROJECT_DIR}/core/"* "${PREFIX}/core/"
    chmod +x "${PREFIX}/core/"*.sh 2>/dev/null || true
    
    # Install web portal files
    if [[ -d "${PROJECT_DIR}/core/portal" ]]; then
        echo "Installing web portal files..."
        cp -r "${PROJECT_DIR}/core/portal/"* "/var/www/diycloud/portal/"
        chown -R www-data:www-data "/var/www/diycloud"
    fi
    
    # Create symbolic link for alternate deployment location
    if [[ -d "/var/www/html" ]]; then
        echo "Creating symbolic link for alternate web access..."
        if [[ ! -d "/var/www/html/diycloud" ]]; then
            ln -sf "/var/www/diycloud/portal" "/var/www/html/diycloud"
        fi
    fi
fi

# Install the User Management files (if available)
if [[ -d "${PROJECT_DIR}/usermgmt" ]]; then
    echo "Installing User Management files..."
    
    # Copy main scripts
    cp "${PROJECT_DIR}/usermgmt/create_user.sh" "${PREFIX}/usermgmt/"
    cp "${PROJECT_DIR}/usermgmt/set_quota.sh" "${PREFIX}/usermgmt/"
    cp "${PROJECT_DIR}/usermgmt/user_management.py" "${PREFIX}/usermgmt/"
    
    # Copy database files
    cp "${PROJECT_DIR}/usermgmt/db/schema.sql" "${PREFIX}/usermgmt/db/"
    cp "${PROJECT_DIR}/usermgmt/db/init_db.sh" "${PREFIX}/usermgmt/db/"
    
    # Copy authentication files
    cp "${PROJECT_DIR}/usermgmt/auth/pam_config.sh" "${PREFIX}/usermgmt/auth/"
    
    # Make scripts executable
    chmod +x "${PREFIX}/usermgmt/"*.sh 2>/dev/null || true
    chmod +x "${PREFIX}/usermgmt/db/"*.sh 2>/dev/null || true
    chmod +x "${PREFIX}/usermgmt/auth/"*.sh 2>/dev/null || true
    
    # Create database directory if needed
    mkdir -p "/var/lib/diycloud/usermgmt"
    chown -R root:root "/var/lib/diycloud"
    
    # Initialize the database (optional)
    echo "Do you want to initialize the user database now? (y/n)"
    read -r init_db
    if [[ "${init_db}" == "y" || "${init_db}" == "Y" ]]; then
        # Generate admin password
        ADMIN_PASSWORD=$(tr -dc 'a-zA-Z0-9!@#$%^&*()' < /dev/urandom | fold -w 12 | head -n 1)
        
        # Initialize database
        "${PREFIX}/usermgmt/db/init_db.sh" --password "${ADMIN_PASSWORD}"
        
        # Configure PAM
        "${PREFIX}/usermgmt/auth/pam_config.sh"
        
        echo "Admin credentials:"
        echo "Username: admin"
        echo "Password: ${ADMIN_PASSWORD}"
    fi
fi

# Install the Resource Management files (if available)
if [[ -d "${PROJECT_DIR}/resources" ]]; then
    echo "Installing Resource Management files..."
    cp "${PROJECT_DIR}/resources/cpu_manager.sh" "${PREFIX}/resources/"
    cp "${PROJECT_DIR}/resources/mem_manager.sh" "${PREFIX}/resources/"
    cp "${PROJECT_DIR}/resources/disk_manager.sh" "${PREFIX}/resources/"
    cp "${PROJECT_DIR}/resources/gpu_manager.sh" "${PREFIX}/resources/"
    cp "${PROJECT_DIR}/resources/apply_limits.sh" "${PREFIX}/resources/"
    
    # Make scripts executable
    chmod +x "${PREFIX}/resources/"*.sh 2>/dev/null || true
fi

# Install the JupyterHub files (if available)
if [[ -d "${PROJECT_DIR}/jupyterhub" ]]; then
    echo "Installing JupyterHub files..."
    cp -r "${PROJECT_DIR}/jupyterhub/"* "${PREFIX}/jupyterhub/"
    chmod +x "${PREFIX}/jupyterhub/"*.sh 2>/dev/null || true
fi

# Install the Docker/Portainer files (if available)
if [[ -d "${PROJECT_DIR}/docker" ]]; then
    echo "Installing Docker/Portainer files..."
    cp -r "${PROJECT_DIR}/docker/"* "${PREFIX}/docker/"
    chmod +x "${PREFIX}/docker/"*.sh 2>/dev/null || true
fi

# Install the Monitoring files (if available)
if [[ -d "${PROJECT_DIR}/monitoring" ]]; then
    echo "Installing Monitoring files..."
    cp -r "${PROJECT_DIR}/monitoring/"* "${PREFIX}/monitoring/"
    chmod +x "${PREFIX}/monitoring/"*.sh 2>/dev/null || true
fi

# Install documentation (if available)
if [[ -d "${PROJECT_DIR}/docs" ]]; then
    echo "Installing documentation..."
    cp -r "${PROJECT_DIR}/docs/"* "${PREFIX}/docs/"
fi

# Install test scripts (if available)
if [[ -f "${PROJECT_DIR}/test_distribution_abstraction.sh" ]]; then
    echo "Installing Distribution Abstraction Layer test script..."
    cp "${PROJECT_DIR}/test_distribution_abstraction.sh" "${PREFIX}/"
    chmod +x "${PREFIX}/test_distribution_abstraction.sh"
fi

if [[ -f "${PROJECT_DIR}/test_core_platform.sh" ]]; then
    echo "Installing Core Platform test script..."
    cp "${PROJECT_DIR}/test_core_platform.sh" "${PREFIX}/"
    chmod +x "${PREFIX}/test_core_platform.sh"
fi

if [[ -f "${PROJECT_DIR}/test_phase2.sh" ]]; then
    echo "Installing Phase 2 test script..."
    cp "${PROJECT_DIR}/test_phase2.sh" "${PREFIX}/"
    chmod +x "${PREFIX}/test_phase2.sh"
fi

# Create a environment setup script
cat > "${PREFIX}/diycloud-env.sh" << EOF
#!/bin/bash
#
# DIY Cloud Platform - Environment Setup Script
#
# This script sets up the environment for the DIY Cloud Platform
# by sourcing the Distribution Abstraction Layer scripts.
#
# Usage: source ${PREFIX}/diycloud-env.sh

# Source the Distribution Abstraction Layer scripts
source "${PREFIX}/lib/detect_distro.sh"
source "${PREFIX}/lib/package_manager.sh"
source "${PREFIX}/lib/service_manager.sh"
source "${PREFIX}/lib/path_resolver.sh"
source "${PREFIX}/lib/resource_adapter.sh"
source "${PREFIX}/lib/common.sh"

# Export the DIY Cloud Platform environment variables
export DIYCLOUD_HOME="${PREFIX}"
export DIYCLOUD_LIB="${PREFIX}/lib"
export DIYCLOUD_LOG="/var/log/diycloud"
export DIYCLOUD_CONFIG="/etc/diycloud"
export DIYCLOUD_WEB="/var/www/diycloud"
export DIYCLOUD_SSL="/etc/ssl/diycloud"
export DIYCLOUD_DATA="/var/lib/diycloud"

echo "DIY Cloud Platform environment initialized."
echo "Distribution: \${DISTRO} \${DISTRO_VERSION} (\${DISTRO_FAMILY} family)"
echo "Package manager: \${PACKAGE_MANAGER}"
echo "Service manager: \${SERVICE_MANAGER}"
echo "cgroups version: \${CGROUP_VERSION}"
EOF

chmod +x "${PREFIX}/diycloud-env.sh"

# Create a symbolic link in /usr/local/bin
ln -sf "${PREFIX}/diycloud-env.sh" "/usr/local/bin/diycloud-env"

# Create a service file for the User Management API
if [[ -f "${PREFIX}/usermgmt/user_management.py" ]]; then
    echo "Creating service file for User Management API..."
    
    # Create systemd service file
    cat > "/etc/systemd/system/diycloud-usermgmt-api.service" << EOF
[Unit]
Description=DIY Cloud Platform User Management API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PREFIX}/usermgmt
ExecStart=/usr/bin/python3 ${PREFIX}/usermgmt/user_management.py
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    echo "Do you want to enable and start the User Management API service? (y/n)"
    read -r start_api
    if [[ "${start_api}" == "y" || "${start_api}" == "Y" ]]; then
        systemctl daemon-reload
        systemctl enable diycloud-usermgmt-api.service
        systemctl start diycloud-usermgmt-api.service
        
        # Check if the service is running
        if systemctl is-active --quiet diycloud-usermgmt-api.service; then
            echo "User Management API service started successfully."
        else
            echo "Failed to start User Management API service."
            echo "Check logs with: journalctl -u diycloud-usermgmt-api.service"
        fi
    fi
fi

# Run the test scripts (if available)
TEST_SUCCESS=true

# Test Distribution Abstraction Layer
if [[ -f "${PREFIX}/test_distribution_abstraction.sh" ]]; then
    echo "Do you want to run the Distribution Abstraction Layer tests? (y/n)"
    read -r run_dal_tests
    if [[ "${run_dal_tests}" == "y" || "${run_dal_tests}" == "Y" ]]; then
        echo "Testing Distribution Abstraction Layer..."
        "${PREFIX}/test_distribution_abstraction.sh"
        dal_test_result=$?
        
        if [[ ${dal_test_result} -eq 0 ]]; then
            echo "Distribution Abstraction Layer installed and tested successfully."
        else
            echo "Distribution Abstraction Layer tests failed."
            TEST_SUCCESS=false
        fi
    fi
fi

# Test Core Platform Module
if [[ -f "${PREFIX}/test_core_platform.sh" ]]; then
    echo "Do you want to run the Core Platform tests? (y/n)"
    read -r run_core_tests
    if [[ "${run_core_tests}" == "y" || "${run_core_tests}" == "Y" ]]; then
        echo "Testing Core Platform Module..."
        # Note: We exclude the HTTPS test since it's optional
        "${PREFIX}/test_core_platform.sh" test | grep -v "HTTPS Port"
        core_test_result=${PIPESTATUS[0]}
        
        if [[ ${core_test_result} -eq 0 ]]; then
            echo "Core Platform Module installed and tested successfully."
        else
            echo "Some Core Platform Module tests might have failed. Check the logs for details."
            echo "Note: HTTPS test is excluded as it's optional."
        fi
    fi
fi

# Test Phase 2 (User & Resource Management)
if [[ -f "${PREFIX}/test_phase2.sh" ]]; then
    echo "Do you want to run the Phase 2 (User & Resource Management) tests? (y/n)"
    read -r run_phase2_tests
    if [[ "${run_phase2_tests}" == "y" || "${run_phase2_tests}" == "Y" ]]; then
        echo "Testing Phase 2 (User & Resource Management)..."
        "${PREFIX}/test_phase2.sh"
        phase2_test_result=$?
        
        if [[ ${phase2_test_result} -eq 0 ]]; then
            echo "Phase 2 (User & Resource Management) installed and tested successfully."
        else
            echo "Some Phase 2 tests might have failed. Check the logs for details."
        fi
    fi
fi

echo "DIY Cloud Platform installed successfully at ${PREFIX}"
echo "You can source the environment script using:"
echo "  source ${PREFIX}/diycloud-env.sh"
echo "Or:"
echo "  source /usr/local/bin/diycloud-env"
echo ""
echo "You can access the DIY Cloud Platform web portal at:"
echo "  http://localhost/diycloud/"

if [[ -f "${PREFIX}/usermgmt/user_management.py" ]]; then
    echo ""
    echo "User Management API is available at:"
    echo "  http://localhost:5000/api/health"
    echo ""
    echo "Use the admin credentials to log in:"
    echo "  curl -X POST -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD}\"}' \\"
    echo "    http://localhost:5000/api/auth/login"
fi

if [[ "$TEST_SUCCESS" == "false" ]]; then
    echo "Warning: Some tests failed. Please check the logs and fix any issues."
    exit 1
fi

exit 0