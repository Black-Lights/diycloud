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
# DIY Cloud Platform - Distribution Abstraction Layer Test Script
# 
# This script tests the functionality of the Distribution Abstraction Layer
# across different Linux distributions.
#
# Usage: sudo ./test_distribution_abstraction.sh

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Get the script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Set paths for the project (development) or installed version
if [[ -d "${SCRIPT_DIR}/lib" ]]; then
    # Running from project directory
    LIB_DIR="${SCRIPT_DIR}/lib"
elif [[ -d "/opt/diycloud/lib" ]]; then
    # Running from installed version
    LIB_DIR="/opt/diycloud/lib"
else
    echo "Distribution Abstraction Layer not found in project or system directories"
    exit 1
fi

# Include the Distribution Abstraction Layer scripts
source "${LIB_DIR}/detect_distro.sh"
source "${LIB_DIR}/package_manager.sh"
source "${LIB_DIR}/service_manager.sh"
source "${LIB_DIR}/path_resolver.sh"
source "${LIB_DIR}/resource_adapter.sh"
source "${LIB_DIR}/common.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test result counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
# Usage: run_test "test_name" "test_command"
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${YELLOW}Test: ${test_name}${NC}"
    ((TESTS_TOTAL++))
    
    # Run the test command
    eval "${test_command}"
    local result=$?
    
    if [[ ${result} -eq 0 ]]; then
        echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Test failed: ${test_name}${NC}"
        ((TESTS_FAILED++))
    fi
    
    echo ""
    return ${result}
}

# Test function for Distribution Detection
test_distribution_detection() {
    echo "Testing Distribution Detection..."
    echo "Detected distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)"
    echo "Package manager: ${PACKAGE_MANAGER}"
    echo "Service manager: ${SERVICE_MANAGER}"
    echo "cgroups version: ${CGROUP_VERSION}"
    
    # Check that required variables are set
    if [[ -z "${DISTRO}" || -z "${DISTRO_FAMILY}" || -z "${PACKAGE_MANAGER}" || -z "${SERVICE_MANAGER}" ]]; then
        echo "Failed to detect distribution correctly"
        return 1
    fi
    
    return 0
}

# Test function for Package Management
test_package_management() {
    echo "Testing Package Management..."
    
    # Test package name resolution
    local nginx_package=$(get_package_name "nginx")
    echo "Nginx package name: ${nginx_package}"
    
    # Test if a package is installed
    if is_package_installed "bash"; then
        echo "bash is installed, as expected"
    else
        echo "bash should be installed!"
        return 1
    fi
    
    # Test package installation
    echo "Installing htop package..."
    install_package "htop"
    if [[ $? -ne 0 ]]; then
        echo "Failed to install htop package"
        return 1
    fi
    
    # Test if package is installed
    if is_package_installed "htop"; then
        echo "htop is installed successfully"
    else
        echo "htop should be installed!"
        return 1
    fi
    
    # Test package removal
    echo "Removing htop package..."
    remove_package "htop"
    if [[ $? -ne 0 ]]; then
        echo "Failed to remove htop package"
        return 1
    fi
    
    return 0
}

# Test function for Service Management
test_service_management() {
    echo "Testing Service Management..."
    
    # Test if a core service is active
    if is_service_active "ssh" || is_service_active "sshd"; then
        echo "SSH service is active, as expected"
    else
        echo "SSH service should be active!"
        # This is not a failure as SSH might not be installed
        echo "SSH service not active, but this is not a critical failure"
    fi
    
    # Create a test service
    echo "Creating test service..."
    create_systemd_service "diycloud-test" "DIY Cloud Platform Test Service" "/bin/sleep 3600" "root" "/"
    if [[ $? -ne 0 ]]; then
        echo "Failed to create test service"
        return 1
    fi
    
    # Start the test service
    echo "Starting test service..."
    start_service "diycloud-test"
    if [[ $? -ne 0 ]]; then
        echo "Failed to start test service"
        return 1
    fi
    
    # Check if the service is active
    if is_service_active "diycloud-test"; then
        echo "Test service is active, as expected"
    else
        echo "Test service should be active!"
        return 1
    fi
    
    # Stop the test service
    echo "Stopping test service..."
    stop_service "diycloud-test"
    if [[ $? -ne 0 ]]; then
        echo "Failed to stop test service"
        return 1
    fi
    
    # Check if the service is inactive
    if ! is_service_active "diycloud-test"; then
        echo "Test service is inactive, as expected"
    else
        echo "Test service should be inactive!"
        return 1
    fi
    
    # Remove the test service
    echo "Removing test service..."
    rm -f "/etc/systemd/system/diycloud-test.service"
    if [[ "${SERVICE_MANAGER}" == "systemd" ]]; then
        systemctl daemon-reload
    fi
    
    return 0
}

# Test function for Path Resolution
test_path_resolution() {
    echo "Testing Path Resolution..."
    
    # Test config path resolution
    local nginx_config=$(get_config_path "nginx")
    echo "Nginx config path: ${nginx_config}"
    
    # Test log path resolution
    local nginx_log=$(get_log_path "nginx")
    echo "Nginx log path: ${nginx_log}"
    
    # Test binary path resolution
    local python_bin=$(get_bin_path "python")
    echo "Python binary path: ${python_bin}"
    
    # Test cgroup path resolution
    local cgroup_path=$(get_cgroup_path)
    echo "cgroup path: ${cgroup_path}"
    
    # Ensure directories can be created
    echo "Creating test directory..."
    local test_dir="/tmp/diycloud-test-dir"
    ensure_directory "${test_dir}" "root:root" "755"
    if [[ ! -d "${test_dir}" ]]; then
        echo "Failed to create test directory"
        return 1
    fi
    
    # Cleanup
    rm -rf "${test_dir}"
    
    return 0
}

# Test function for Resource Management
test_resource_management() {
    echo "Testing Resource Management..."
    
    # Test system resource detection
    echo "System resources:"
    get_system_resources
    
    # Create a test user
    local test_user="diycloud-test-user"
    echo "Creating test user: ${test_user}"
    
    # Check if user already exists
    if id "${test_user}" &>/dev/null; then
        echo "Test user already exists, using existing user"
    else
        useradd -m "${test_user}"
        if [[ $? -ne 0 ]]; then
            echo "Failed to create test user"
            return 1
        fi
    fi
    
    # Test user cgroup setup
    echo "Setting up cgroup for test user..."
    setup_user_cgroup "${test_user}"
    if [[ $? -ne 0 ]]; then
        echo "Failed to setup cgroup for test user"
        userdel -r "${test_user}" 2>/dev/null
        return 1
    fi
    
    # Test CPU limit application
    echo "Applying CPU limit for test user..."
    apply_cpu_limit "${test_user}" "0.5"
    if [[ $? -ne 0 ]]; then
        echo "Failed to apply CPU limit for test user"
        userdel -r "${test_user}" 2>/dev/null
        return 1
    fi
    
    # Test memory limit application
    echo "Applying memory limit for test user..."
    apply_memory_limit "${test_user}" "256"
    if [[ $? -ne 0 ]]; then
        echo "Failed to apply memory limit for test user"
        userdel -r "${test_user}" 2>/dev/null
        return 1
    fi
    
    # Test disk quota setup (This might fail if quota is not supported)
    echo "Setting up disk quota for test user..."
    setup_disk_quota "${test_user}" "100" "200" "/home" || true
    
    # Test getting resource usage and limits
    echo "User resource limits:"
    get_user_resource_limits "${test_user}" || true
    
    # Cleanup: remove test user
    echo "Removing test user..."
    userdel -r "${test_user}" 2>/dev/null
    
    return 0
}

# Test function for Common Utilities
test_common_utilities() {
    echo "Testing Common Utilities..."
    
    # Test log message function
    echo "Testing log message function..."
    log_message "This is a test log message" "info"
    
    # Test password generation
    echo "Testing password generation..."
    local password=$(generate_password 12)
    echo "Generated password: ${password}"
    if [[ ${#password} -ne 12 ]]; then
        echo "Password length is incorrect"
        return 1
    fi
    
    # Test IP validation
    echo "Testing IP validation..."
    if is_valid_ip "192.168.1.1"; then
        echo "IP validation successful"
    else
        echo "Failed to validate valid IP address"
        return 1
    fi
    
    if is_valid_ip "not.an.ip.address"; then
        echo "Failed to reject invalid IP address"
        return 1
    else
        echo "Invalid IP rejected successfully"
    fi
    
    # Test directory creation
    echo "Testing directory creation..."
    local test_dir="/tmp/diycloud-common-test"
    create_directory "${test_dir}" "root:root" "755"
    if [[ ! -d "${test_dir}" ]]; then
        echo "Failed to create test directory"
        return 1
    fi
    
    # Cleanup
    rm -rf "${test_dir}"
    
    return 0
}

# Run all tests
echo "=== DIY Cloud Platform - Distribution Abstraction Layer Tests ==="
echo "Running on: $(get_hostname) ($(get_primary_ip))"
echo "Version: $(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "Development")"
echo ""

# Run individual tests
run_test "Distribution Detection" "test_distribution_detection"
run_test "Package Management" "test_package_management"
run_test "Service Management" "test_service_management"
run_test "Path Resolution" "test_path_resolution"
run_test "Resource Management" "test_resource_management"
run_test "Common Utilities" "test_common_utilities"

# Print summary
echo "=== Test Summary ==="
echo "Total tests: ${TESTS_TOTAL}"
echo "Passed: ${TESTS_PASSED}"
echo "Failed: ${TESTS_FAILED}"

if [[ ${TESTS_FAILED} -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${TESTS_FAILED} test(s) failed!${NC}"
    exit 1
fi
