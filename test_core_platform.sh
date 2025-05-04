#!/usr/bin/env bash
#
# DIY Cloud Platform - Core Platform Module Test Script
#
# This script tests the Core Platform Module to ensure it's working correctly
# across different Linux distributions.

# Exit on error
set -e

# Get the script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Source the Distribution Abstraction Layer
source "$SCRIPT_DIR/lib/detect_distro.sh"
source "$SCRIPT_DIR/lib/package_manager.sh"
source "$SCRIPT_DIR/lib/service_manager.sh"
source "$SCRIPT_DIR/lib/path_resolver.sh"
source "$SCRIPT_DIR/lib/common.sh"

# Detect distribution
detect_distribution
log_message "Testing on distribution: $DISTRO $DISTRO_VERSION ($DISTRO_FAMILY family)"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   log_message "This script must be run as root" "error"
   exit 1
fi

# Test results counter
tests_total=0
tests_passed=0
tests_failed=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_message "Running test: $test_name..."
    tests_total=$((tests_total + 1))
    
    if eval "$test_command"; then
        log_message "Test passed: $test_name" "success"
        tests_passed=$((tests_passed + 1))
        return 0
    else
        log_message "Test failed: $test_name" "error"
        tests_failed=$((tests_failed + 1))
        return 1
    fi
}

# Test if a specific package is installed
test_package_installed() {
    local package_name="$1"
    if is_package_installed "$package_name"; then
        return 0
    else
        return 1
    fi
}

# Test if a service is running
test_service_running() {
    local service_name="$1"
    if is_service_active "$service_name"; then
        return 0
    else
        return 1
    fi
}

# Test if a directory exists
test_directory_exists() {
    local directory="$1"
    if [[ -d "$directory" ]]; then
        return 0
    else
        return 1
    fi
}

# Test if a file exists
test_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    else
        return 1
    fi
}

# Test if a port is open
test_port_open() {
    local port="$1"
    if command_exists "nc"; then
        if nc -z localhost "$port"; then
            return 0
        else
            return 1
        fi
    elif command_exists "curl"; then
        if curl -s "http://localhost:$port" >/dev/null; then
            return 0
        else
            return 1
        fi
    else
        log_message "No tool available to check port (nc or curl)" "warning"
        return 1
    fi
}

# Test if HTTPS is properly configured
test_https_config() {
    local url="$1"
    if command_exists "curl"; then
        if curl -k -s "https://$url" >/dev/null; then
            return 0
        else
            return 1
        fi
    else
        log_message "curl not available to check HTTPS" "warning"
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    log_message "Starting Core Platform Module tests..."
    
    # Test Base Directories
    run_test "Base Directories" "test_directory_exists \"/opt/diycloud\""
    run_test "Web Directory" "test_directory_exists \"/var/www/diycloud\""
    run_test "SSL Directory" "test_directory_exists \"/etc/ssl/diycloud\""
    
    # Test Nginx Installation
    run_test "Nginx Package" "test_package_installed \"nginx\""
    run_test "Nginx Service" "test_service_running \"nginx\""
    
    # Test Nginx Configuration
    nginx_conf_dir=$(get_config_path "nginx")
    run_test "Nginx Configuration File" "test_file_exists \"$nginx_conf_dir/nginx.conf\""
    
    nginx_sites_dir=$(get_config_path "nginx_sites")
    run_test "Portal Configuration File" "test_file_exists \"$nginx_sites_dir/diycloud-portal.conf\""
    
    # Test SSL Certificates
    run_test "SSL Certificate" "test_file_exists \"/etc/ssl/diycloud/diycloud.crt\""
    run_test "SSL Private Key" "test_file_exists \"/etc/ssl/diycloud/diycloud.key\""
    
    # Test Web Portal Files
    run_test "Portal Index File" "test_file_exists \"/var/www/diycloud/portal/index.html\""
    run_test "Portal CSS File" "test_file_exists \"/var/www/diycloud/portal/css/style.css\""
    run_test "Portal JS File" "test_file_exists \"/var/www/diycloud/portal/js/scripts.js\""
    run_test "Portal Logo File" "test_file_exists \"/var/www/diycloud/portal/assets/logo.svg\""
    
    # Test Network Services
    run_test "HTTP Redirect Port" "test_port_open 80"
    run_test "HTTPS Port" "test_port_open 443"
    
    # Test HTTPS Configuration
    run_test "HTTPS Configuration" "test_https_config \"localhost\""
    
    # Print test results
    log_message "Tests completed: $tests_total total, $tests_passed passed, $tests_failed failed" "info"
    
    if [[ $tests_failed -eq 0 ]]; then
        log_message "All tests passed!" "success"
        return 0
    else
        log_message "Some tests failed. Check the log for details." "warning"
        return 1
    fi
}

# Function to test the setup script
test_setup_script() {
    log_message "Testing setup-base.sh script..."
    
    # Check if the script exists
    if [[ ! -f "$SCRIPT_DIR/core/setup-base.sh" ]]; then
        log_message "setup-base.sh not found in $SCRIPT_DIR/core/" "error"
        return 1
    fi
    
    # Make it executable
    chmod +x "$SCRIPT_DIR/core/setup-base.sh"
    
    # Run the script
    log_message "Running setup-base.sh..."
    if "$SCRIPT_DIR/core/setup-base.sh"; then
        log_message "setup-base.sh executed successfully" "success"
        return 0
    else
        log_message "setup-base.sh failed to execute" "error"
        return 1
    fi
}

# Main execution
main() {
    local action="${1:-test}"
    
    case "$action" in
        setup)
            test_setup_script
            ;;
        test)
            run_all_tests
            ;;
        all)
            test_setup_script && run_all_tests
            ;;
        *)
            log_message "Unknown action: $action" "error"
            log_message "Usage: $0 [setup|test|all]" "info"
            exit 1
            ;;
    esac
}

# Run the main function with provided arguments
main "$@"