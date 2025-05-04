#!/usr/bin/env bash
#
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
    
    # Check if database exists and remove it for clean testing
    if [[ -f "/opt/diycloud/usermgmt/db/users.db" ]]; then
        echo "Removing existing database for clean testing..."
        rm -f "/opt/diycloud/usermgmt/db/users.db"
    fi
    
    chmod +x /opt/diycloud/usermgmt/db/init_db.sh
    /opt/diycloud/usermgmt/db/init_db.sh --password "adminpassword"
    
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