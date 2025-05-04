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
# DIY Cloud Platform - Distribution Detection Script
# 
# This script detects the Linux distribution and version and sets
# global variables for use by other scripts in the Distribution Abstraction Layer.
#
# Usage: source detect_distro.sh

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   return 1
fi

# Initialize variables
DISTRO=""
DISTRO_VERSION=""
DISTRO_VERSION_ID=""
DISTRO_CODENAME=""
DISTRO_FAMILY=""
PACKAGE_MANAGER=""
SERVICE_MANAGER=""
CGROUP_VERSION=""

# Function to detect the Linux distribution
detect_distribution() {
    # If /etc/os-release exists, use it as primary source
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="${ID}"
        DISTRO_VERSION="${VERSION}"
        DISTRO_VERSION_ID="${VERSION_ID}"
        DISTRO_CODENAME="${VERSION_CODENAME:-""}"
    # Fall back to other methods if /etc/os-release doesn't exist
    elif [[ -f /etc/lsb-release ]]; then
        source /etc/lsb-release
        DISTRO="${DISTRIB_ID,,}"
        DISTRO_VERSION="${DISTRIB_RELEASE}"
        DISTRO_CODENAME="${DISTRIB_CODENAME}"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        DISTRO_VERSION="$(cat /etc/debian_version)"
    elif [[ -f /etc/centos-release ]]; then
        DISTRO="centos"
        DISTRO_VERSION="$(cat /etc/centos-release | sed 's/.*release \([0-9.]*\).*/\1/')"
    elif [[ -f /etc/fedora-release ]]; then
        DISTRO="fedora"
        DISTRO_VERSION="$(cat /etc/fedora-release | sed 's/.*release \([0-9.]*\).*/\1/')"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="redhat"
        DISTRO_VERSION="$(cat /etc/redhat-release | sed 's/.*release \([0-9.]*\).*/\1/')"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
        DISTRO_VERSION="rolling"
    elif [[ -f /etc/SuSE-release ]] || [[ -f /etc/openSUSE-release ]]; then
        DISTRO="opensuse"
        if [[ -f /etc/openSUSE-release ]]; then
            DISTRO_VERSION="$(cat /etc/openSUSE-release | sed 's/.*openSUSE \(.*\)/\1/')"
        else
            DISTRO_VERSION="$(cat /etc/SuSE-release | sed 's/.*VERSION = \(.*\)/\1/')"
        fi
    else
        echo "Unable to determine Linux distribution"
        return 1
    fi

    # Determine distribution family
    case ${DISTRO} in
        ubuntu|debian|pop|mint|kali|elementary|deepin)
            DISTRO_FAMILY="debian"
            PACKAGE_MANAGER="apt"
            ;;
        rhel|centos|fedora|rocky|alma|oracle)
            DISTRO_FAMILY="redhat"
            if [[ "${DISTRO}" == "fedora" ]]; then
                PACKAGE_MANAGER="dnf"
            elif [[ "${DISTRO_VERSION_ID%%.*}" -ge 8 ]]; then
                PACKAGE_MANAGER="dnf"
            else
                PACKAGE_MANAGER="yum"
            fi
            ;;
        arch|manjaro|endeavour)
            DISTRO_FAMILY="arch"
            PACKAGE_MANAGER="pacman"
            ;;
        opensuse*|suse*)
            DISTRO_FAMILY="suse"
            PACKAGE_MANAGER="zypper"
            ;;
        *)
            echo "Unsupported Linux distribution: ${DISTRO}"
            return 1
            ;;
    esac

    # Determine service manager
    if command -v systemctl &> /dev/null; then
        SERVICE_MANAGER="systemd"
    elif command -v service &> /dev/null; then
        SERVICE_MANAGER="sysv"
    else
        echo "Unable to determine service manager"
        return 1
    fi

    # Determine cgroups version
    if [[ -d /sys/fs/cgroup/unified ]]; then
        # Hybrid hierarchy (both v1 and v2 present)
        CGROUP_VERSION="hybrid"
    elif [[ $(stat -fc %T /sys/fs/cgroup) == "cgroup2fs" ]]; then
        # Pure cgroups v2
        CGROUP_VERSION="v2"
    elif [[ -d /sys/fs/cgroup/cpu ]]; then
        # cgroups v1
        CGROUP_VERSION="v1"
    else
        echo "Unable to determine cgroups version"
        CGROUP_VERSION="unknown"
    fi

    echo "Detected distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)"
    echo "Package manager: ${PACKAGE_MANAGER}"
    echo "Service manager: ${SERVICE_MANAGER}"
    echo "cgroups version: ${CGROUP_VERSION}"

    # Export variables to make them available to other scripts
    export DISTRO
    export DISTRO_VERSION
    export DISTRO_VERSION_ID
    export DISTRO_CODENAME
    export DISTRO_FAMILY
    export PACKAGE_MANAGER
    export SERVICE_MANAGER
    export CGROUP_VERSION

    return 0
}

# Run the detection function
detect_distribution
