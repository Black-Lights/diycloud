#!/usr/bin/env bash
#
# DIY Cloud Platform - Package Management Abstraction Script
# 
# This script provides package management functions that abstract away
# distribution-specific package manager implementations.
#
# Usage: source package_manager.sh

# Ensure detect_distro.sh is sourced
if [[ -z "${DISTRO}" || -z "${PACKAGE_MANAGER}" ]]; then
    if [[ -f "$(dirname "$0")/detect_distro.sh" ]]; then
        source "$(dirname "$0")/detect_distro.sh"
    else
        echo "Error: detect_distro.sh not found or not sourced"
        return 1
    fi
fi

# Package name translation table
declare -A PACKAGE_NAMES

# Debian/Ubuntu package names
PACKAGE_NAMES["debian:nginx"]="nginx"
PACKAGE_NAMES["debian:python"]="python3"
PACKAGE_NAMES["debian:pip"]="python3-pip"
PACKAGE_NAMES["debian:nodejs"]="nodejs"
PACKAGE_NAMES["debian:npm"]="npm"
PACKAGE_NAMES["debian:docker"]="docker.io"
PACKAGE_NAMES["debian:prometheus"]="prometheus"
PACKAGE_NAMES["debian:grafana"]="grafana"
PACKAGE_NAMES["debian:quota"]="quota"

# RedHat family package names
PACKAGE_NAMES["redhat:nginx"]="nginx"
PACKAGE_NAMES["redhat:python"]="python3"
PACKAGE_NAMES["redhat:pip"]="python3-pip"
PACKAGE_NAMES["redhat:nodejs"]="nodejs"
PACKAGE_NAMES["redhat:npm"]="npm"
PACKAGE_NAMES["redhat:docker"]="docker-ce"
PACKAGE_NAMES["redhat:prometheus"]="prometheus"
PACKAGE_NAMES["redhat:grafana"]="grafana"
PACKAGE_NAMES["redhat:quota"]="quota"

# Arch Linux package names
PACKAGE_NAMES["arch:nginx"]="nginx"
PACKAGE_NAMES["arch:python"]="python"
PACKAGE_NAMES["arch:pip"]="python-pip"
PACKAGE_NAMES["arch:nodejs"]="nodejs"
PACKAGE_NAMES["arch:npm"]="npm"
PACKAGE_NAMES["arch:docker"]="docker"
PACKAGE_NAMES["arch:prometheus"]="prometheus"
PACKAGE_NAMES["arch:grafana"]="grafana"
PACKAGE_NAMES["arch:quota"]="quota-tools"

# OpenSUSE package names
PACKAGE_NAMES["suse:nginx"]="nginx"
PACKAGE_NAMES["suse:python"]="python3"
PACKAGE_NAMES["suse:pip"]="python3-pip"
PACKAGE_NAMES["suse:nodejs"]="nodejs"
PACKAGE_NAMES["suse:npm"]="npm"
PACKAGE_NAMES["suse:docker"]="docker"
PACKAGE_NAMES["suse:prometheus"]="prometheus"
PACKAGE_NAMES["suse:grafana"]="grafana"
PACKAGE_NAMES["suse:quota"]="quota"

# Function to get distribution-specific package name
# Usage: get_package_name "generic_name"
get_package_name() {
    local generic_name="$1"
    local distro_key="${DISTRO_FAMILY}:${generic_name}"
    
    # Return the distribution-specific package name if it exists
    if [[ -n "${PACKAGE_NAMES[${distro_key}]}" ]]; then
        echo "${PACKAGE_NAMES[${distro_key}]}"
        return 0
    fi
    
    # If no mapping exists, return the generic name
    echo "${generic_name}"
    return 0
}

# Function to update package lists
# Usage: update_package_lists
update_package_lists() {
    echo "Updating package lists..."
    
    case "${PACKAGE_MANAGER}" in
        apt)
            apt-get update -qq
            ;;
        dnf|yum)
            if [[ "${PACKAGE_MANAGER}" == "dnf" ]]; then
                dnf check-update -q || true  # Returns 100 if updates available
            else
                yum check-update -q || true  # Returns 100 if updates available
            fi
            ;;
        pacman)
            pacman -Sy --noconfirm
            ;;
        zypper)
            zypper refresh -q
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to install a package
# Usage: install_package "package_name" [options]
install_package() {
    local package_name="$1"
    local options="${2:-}"
    local distro_package_name
    
    # Get distribution-specific package name
    distro_package_name=$(get_package_name "${package_name}")
    
    echo "Installing package: ${distro_package_name}"
    
    case "${PACKAGE_MANAGER}" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y ${options} "${distro_package_name}"
            ;;
        dnf)
            dnf install -y ${options} "${distro_package_name}"
            ;;
        yum)
            yum install -y ${options} "${distro_package_name}"
            ;;
        pacman)
            pacman -S --noconfirm ${options} "${distro_package_name}"
            ;;
        zypper)
            zypper install -y ${options} "${distro_package_name}"
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "Package ${distro_package_name} installed successfully"
    else
        echo "Failed to install package ${distro_package_name}"
    fi
    
    return $result
}

# Function to remove a package
# Usage: remove_package "package_name" [options]
remove_package() {
    local package_name="$1"
    local options="${2:-}"
    local distro_package_name
    
    # Get distribution-specific package name
    distro_package_name=$(get_package_name "${package_name}")
    
    echo "Removing package: ${distro_package_name}"
    
    case "${PACKAGE_MANAGER}" in
        apt)
            apt-get remove -y ${options} "${distro_package_name}"
            ;;
        dnf)
            dnf remove -y ${options} "${distro_package_name}"
            ;;
        yum)
            yum remove -y ${options} "${distro_package_name}"
            ;;
        pacman)
            pacman -R --noconfirm ${options} "${distro_package_name}"
            ;;
        zypper)
            zypper remove -y ${options} "${distro_package_name}"
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to check if a package is installed
# Usage: is_package_installed "package_name"
is_package_installed() {
    local package_name="$1"
    local distro_package_name
    
    # Get distribution-specific package name
    distro_package_name=$(get_package_name "${package_name}")
    
    case "${PACKAGE_MANAGER}" in
        apt)
            dpkg -s "${distro_package_name}" &> /dev/null
            ;;
        dnf|yum)
            rpm -q "${distro_package_name}" &> /dev/null
            ;;
        pacman)
            pacman -Q "${distro_package_name}" &> /dev/null
            ;;
        zypper)
            rpm -q "${distro_package_name}" &> /dev/null
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to add a repository
# Usage: add_repository "repository_name" "repository_url"
add_repository() {
    local repo_name="$1"
    local repo_url="$2"
    
    echo "Adding repository: ${repo_name}"
    
    case "${PACKAGE_MANAGER}" in
        apt)
            if ! grep -q "^deb .*${repo_url}" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
                add-apt-repository -y "${repo_url}"
                apt-get update -qq
            fi
            ;;
        dnf)
            dnf config-manager --add-repo "${repo_url}"
            ;;
        yum)
            yum-config-manager --add-repo "${repo_url}"
            ;;
        pacman)
            # For Arch, repositories are managed in /etc/pacman.conf
            echo "Manual configuration required for pacman repositories"
            return 0
            ;;
        zypper)
            zypper addrepo "${repo_url}" "${repo_name}"
            zypper refresh
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to upgrade all packages
# Usage: upgrade_system [options]
upgrade_system() {
    local options="${1:-}"
    
    echo "Upgrading system packages..."
    
    case "${PACKAGE_MANAGER}" in
        apt)
            apt-get upgrade -y ${options}
            ;;
        dnf)
            dnf upgrade -y ${options}
            ;;
        yum)
            yum upgrade -y ${options}
            ;;
        pacman)
            pacman -Su --noconfirm ${options}
            ;;
        zypper)
            zypper update -y ${options}
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to install a group of packages
# Usage: install_package_group "group_name"
install_package_group() {
    local group_name="$1"
    
    echo "Installing package group: ${group_name}"
    
    case "${PACKAGE_MANAGER}" in
        apt)
            # Debian/Ubuntu doesn't have a direct equivalent of package groups
            # This is a simplified approach
            case "${group_name}" in
                "development")
                    apt-get install -y build-essential
                    ;;
                "web")
                    apt-get install -y nginx apache2
                    ;;
                *)
                    echo "Unknown package group: ${group_name}"
                    return 1
                    ;;
            esac
            ;;
        dnf)
            dnf group install -y "${group_name}"
            ;;
        yum)
            yum groupinstall -y "${group_name}"
            ;;
        pacman)
            # Arch Linux uses package groups but naming may differ
            pacman -S --noconfirm "${group_name}"
            ;;
        zypper)
            # OpenSUSE uses patterns
            zypper install -y -t pattern "${group_name}"
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Function to clean package cache
# Usage: clean_package_cache
clean_package_cache() {
    echo "Cleaning package cache..."
    
    case "${PACKAGE_MANAGER}" in
        apt)
            apt-get clean
            ;;
        dnf)
            dnf clean all
            ;;
        yum)
            yum clean all
            ;;
        pacman)
            pacman -Sc --noconfirm
            ;;
        zypper)
            zypper clean
            ;;
        *)
            echo "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
    
    return $?
}

# Export functions
export -f get_package_name
export -f update_package_lists
export -f install_package
export -f remove_package
export -f is_package_installed
export -f add_repository
export -f upgrade_system
export -f install_package_group
export -f clean_package_cache
