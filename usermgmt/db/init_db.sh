#!/usr/bin/env bash
#
# DIY Cloud Platform - Database Initialization Script
#
# This script initializes the SQLite database for the User Management Module.

# Exit on error
set -e

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/common.sh

# Set up database directory and files
DB_DIR="/opt/diycloud/usermgmt/db"
DB_FILE="${DB_DIR}/users.db"
SCHEMA_FILE="${DB_DIR}/schema.sql"

# Function to generate a secure password hash
# In production, use a more secure method like bcrypt
generate_password_hash() {
    local password="$1"
    echo -n "${password}" | sha256sum | cut -d' ' -f1
}

# Function to initialize the database
initialize_database() {
    log_message "Initializing user database..." "info"
    
    # Check if SQLite is installed
    if ! command_exists "sqlite3"; then
        log_message "SQLite3 is not installed, installing..." "warning"
        install_package "sqlite3"
    fi
    
    # Create database directory if it doesn't exist
    ensure_directory "${DB_DIR}" "root:root" "755"
    
    # Check if schema file exists
    if [[ ! -f "${SCHEMA_FILE}" ]]; then
        log_message "Schema file not found: ${SCHEMA_FILE}" "error"
        return 1
    fi
    
    # Backup existing database if it exists
    if [[ -f "${DB_FILE}" ]]; then
        local backup_file="${DB_FILE}.$(date +%Y%m%d%H%M%S).bak"
        log_message "Backing up existing database to ${backup_file}" "info"
        cp "${DB_FILE}" "${backup_file}"
    fi
    
    # Create database and apply schema
    log_message "Creating database and applying schema..." "info"
    sqlite3 "${DB_FILE}" < "${SCHEMA_FILE}"
    
    # Set proper permissions
    chmod 600 "${DB_FILE}"
    
    # Generate admin password if needed
    local admin_password
    if [[ $# -eq 1 ]]; then
        admin_password="$1"
        log_message "Using provided admin password" "info"
    else
        admin_password=$(generate_password 12)
        log_message "Generated admin password: ${admin_password}" "info"
    fi
    
    # Hash the password
    local password_hash=$(generate_password_hash "${admin_password}")
    
    # Update admin user with password
    log_message "Setting admin password..." "info"
    sqlite3 "${DB_FILE}" "UPDATE users SET password_hash='${password_hash}' WHERE username='admin';"
    
    log_message "Database initialized successfully" "info"
    
    # Output admin credentials
    echo "========================================"
    echo "Admin credentials:"
    echo "Username: admin"
    if [[ $# -eq 0 ]]; then
        echo "Password: ${admin_password}"
    else
        echo "Password: [As provided]"
    fi
    echo "========================================"
    
    return 0
}

# Function to check database integrity
check_database() {
    log_message "Checking database integrity..." "info"
    
    if [[ ! -f "${DB_FILE}" ]]; then
        log_message "Database file not found: ${DB_FILE}" "error"
        return 1
    fi
    
    # Run integrity check
    local result=$(sqlite3 "${DB_FILE}" "PRAGMA integrity_check;")
    
    if [[ "${result}" == "ok" ]]; then
        log_message "Database integrity check passed" "info"
        return 0
    else
        log_message "Database integrity check failed: ${result}" "error"
        return 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Initialize the DIY Cloud Platform user database"
    echo ""
    echo "Options:"
    echo "  --password PASSWORD    Set admin password"
    echo "  --check               Check database integrity"
    echo "  --help                Show this help message"
    exit 1
}

# Parse command line arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        --password)
            if [[ $# -lt 2 ]]; then
                echo "Error: Password argument missing"
                usage
            fi
            initialize_database "$2"
            ;;
        --check)
            check_database
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
else
    # Default: initialize database with random password
    initialize_database
fi