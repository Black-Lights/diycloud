#!/usr/bin/env bash
#
# DIY Cloud Platform - Common Utilities
# 
# This script provides common utility functions for the DIY Cloud Platform.
#
# Usage: source common.sh

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   return 1
fi

# Set default directory paths
DEFAULT_INSTALL_DIR="/opt/diycloud"
DEFAULT_CONFIG_DIR="/etc/diycloud"
DEFAULT_LOG_DIR="/var/log/diycloud"
DEFAULT_DATA_DIR="/var/lib/diycloud"

# Create a timestamp for logs
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Function to log messages
# Usage: log_message "message" ["error"|"warning"|"info"]
log_message() {
    local message="$1"
    local level="${2:-info}"
    local log_file="/var/log/diycloud/install.log"
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "${log_file}")"
    
    # Format the log message
    echo "[${TIMESTAMP}] [${level^^}] ${message}" | tee -a "${log_file}"
    
    return 0
}

# Function to check command success and log result
# Usage: check_result $? "Success message" "Error message"
check_result() {
    local result=$1
    local success_message="$2"
    local error_message="$3"
    
    if [[ ${result} -eq 0 ]]; then
        log_message "${success_message}" "info"
        return 0
    else
        log_message "${error_message}" "error"
        return 1
    fi
}

# Function to create a directory if it doesn't exist
# Usage: create_directory "directory_path" ["owner:group"] ["permissions"]
create_directory() {
    local dir_path="$1"
    local owner_group="${2:-root:root}"
    local permissions="${3:-755}"
    
    if [[ ! -d "${dir_path}" ]]; then
        log_message "Creating directory: ${dir_path}"
        mkdir -p "${dir_path}"
        check_result $? "Directory created: ${dir_path}" "Failed to create directory: ${dir_path}"
        
        # Set permissions
        chmod "${permissions}" "${dir_path}"
        # Set owner:group
        chown "${owner_group}" "${dir_path}"
    else
        log_message "Directory already exists: ${dir_path}"
    fi
    
    return 0
}

# Function to backup a file before modifying it
# Usage: backup_file "file_path"
backup_file() {
    local file_path="$1"
    local backup_path="${file_path}.bak-$(date +%Y%m%d%H%M%S)"
    
    if [[ -f "${file_path}" ]]; then
        log_message "Backing up file: ${file_path} -> ${backup_path}"
        cp "${file_path}" "${backup_path}"
        check_result $? "File backed up: ${backup_path}" "Failed to backup file: ${file_path}"
    else
        log_message "File does not exist, no backup needed: ${file_path}" "warning"
    fi
    
    return 0
}

# Function to generate a secure random password
# Usage: generate_password [length]
generate_password() {
    local length="${1:-16}"
    
    # Check if openssl is available
    if command -v openssl &> /dev/null; then
        openssl rand -base64 $((length * 2)) | tr -dc 'a-zA-Z0-9' | head -c "${length}"
    else
        # Fallback to /dev/urandom
        < /dev/urandom tr -dc 'a-zA-Z0-9' | head -c "${length}"
    fi
    
    return 0
}

# Function to validate an IP address
# Usage: is_valid_ip "ip_address"
is_valid_ip() {
    local ip="$1"
    
    # Simple regex to validate IPv4 address
    if [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a port is available
# Usage: is_port_available "port_number"
is_port_available() {
    local port="$1"
    
    # Check if the port is in use
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":${port}\\b"; then
            return 1
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":${port}\\b"; then
            return 1
        fi
    else
        # Fallback to direct check
        if [[ -n $(lsof -i :"${port}" 2>/dev/null) ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Function to generate a self-signed SSL certificate
# Usage: generate_ssl_cert "domain" "output_dir"
generate_ssl_cert() {
    local domain="$1"
    local output_dir="$2"
    local days=3650  # 10 years
    
    # Create output directory if it doesn't exist
    create_directory "${output_dir}"
    
    # Generate key and certificate
    log_message "Generating self-signed SSL certificate for ${domain}"
    openssl req -x509 -nodes -days "${days}" -newkey rsa:2048 \
        -keyout "${output_dir}/${domain}.key" \
        -out "${output_dir}/${domain}.crt" \
        -subj "/CN=${domain}" \
        -addext "subjectAltName=DNS:${domain},DNS:www.${domain},IP:127.0.0.1"
    
    check_result $? "SSL certificate generated: ${output_dir}/${domain}.crt" "Failed to generate SSL certificate"
    
    return 0
}

# Function to get the primary IP address of the system
# Usage: get_primary_ip
get_primary_ip() {
    local ip
    
    # Try various methods to get the IP address
    if command -v ip &> /dev/null; then
        ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
    elif command -v hostname &> /dev/null; then
        ip=$(hostname -I | awk '{print $1}')
    elif command -v ifconfig &> /dev/null; then
        ip=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n 1)
    else
        log_message "Unable to determine primary IP address" "warning"
        ip="127.0.0.1"
    fi
    
    echo "${ip}"
    return 0
}

# Function to get the hostname of the system
# Usage: get_hostname
get_hostname() {
    hostname
    return 0
}

# Function to get the fully qualified domain name (FQDN)
# Usage: get_fqdn
get_fqdn() {
    local fqdn
    
    if command -v hostname &> /dev/null; then
        fqdn=$(hostname -f 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            # Fallback to hostname
            fqdn=$(hostname)
        fi
    else
        # Fallback to hostname
        fqdn=$(hostname)
    fi
    
    echo "${fqdn}"
    return 0
}

# Function to validate a username
# Usage: is_valid_username "username"
is_valid_username() {
    local username="$1"
    
    # Check if username is valid (alphanumeric plus underscore and dash)
    if [[ "${username}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to prompt for user input
# Usage: prompt_input "prompt" ["default_value"]
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "${default}" ]]; then
        read -p "${prompt} [${default}]: " response
        response="${response:-${default}}"
    else
        read -p "${prompt}: " response
    fi
    
    echo "${response}"
    return 0
}

# Function to prompt for password input (with masking)
# Usage: prompt_password "prompt"
prompt_password() {
    local prompt="$1"
    local password
    
    read -s -p "${prompt}: " password
    echo
    
    echo "${password}"
    return 0
}

# Function to prompt for yes/no input
# Usage: prompt_yn "prompt" ["default_yn"]
prompt_yn() {
    local prompt="$1"
    local default="${2:-y}"
    local yn
    
    if [[ "${default}" == "y" ]]; then
        read -p "${prompt} [Y/n]: " yn
        yn="${yn:-y}"
    else
        read -p "${prompt} [y/N]: " yn
        yn="${yn:-n}"
    fi
    
    if [[ "${yn}" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a command exists
# Usage: command_exists "command_name"
command_exists() {
    command -v "$1" &> /dev/null
    return $?
}

# Function to wait for a service to be ready
# Usage: wait_for_service "host" "port" ["timeout_seconds"]
wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-60}"
    local start_time
    local end_time
    
    log_message "Waiting for service at ${host}:${port} to be ready (timeout: ${timeout}s)"
    
    start_time=$(date +%s)
    end_time=$((start_time + timeout))
    
    while [[ $(date +%s) -lt ${end_time} ]]; do
        if command_exists nc; then
            nc -z "${host}" "${port}" && return 0
        elif command_exists curl; then
            curl -s -o /dev/null "${host}:${port}" && return 0
        else
            # Fallback to a simple check
            if (echo > /dev/tcp/"${host}"/"${port}") 2>/dev/null; then
                return 0
            fi
        fi
        
        sleep 1
    done
    
    log_message "Timeout waiting for service at ${host}:${port}" "warning"
    return 1
}

# Function to ensure a directory exists with proper permissions
ensure_directory() {
    local dir="$1"
    local owner="${2:-root:root}"
    local perms="${3:-755}"
    
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
        chown "${owner}" "${dir}"
        chmod "${perms}" "${dir}"
        return 0
    fi
    
    return 0
}

# Export functions
export -f log_message
export -f check_result
export -f create_directory
export -f backup_file
export -f generate_password
export -f is_valid_ip
export -f is_port_available
export -f generate_ssl_cert
export -f get_primary_ip
export -f get_hostname
export -f get_fqdn
export -f is_valid_username
export -f prompt_input
export -f prompt_password
export -f prompt_yn
export -f command_exists
export -f wait_for_service
export -f ensure_directory

# Export variables
export DEFAULT_INSTALL_DIR
export DEFAULT_CONFIG_DIR
export DEFAULT_LOG_DIR
export DEFAULT_DATA_DIR
