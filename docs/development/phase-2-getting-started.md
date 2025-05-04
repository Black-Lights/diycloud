# Phase 2: User & Resource Management - Getting Started Guide

Congratulations on completing Phase 0 (Distribution Abstraction Layer) and Phase 1 (Core Platform Module)! This guide will help you get started with Phase 2, which focuses on implementing User Management and Resource Management.

## Overview of Phase 2

According to the project roadmap, Phase 2 includes:

1. **User Management Module**
   - User creation and authentication
   - User profile management
   - Role-based access control

2. **Resource Management Module**
   - CPU resource allocation
   - Memory limitations
   - Disk quota management
   - GPU access control

## Directory Structure

For Phase 2, you'll need to set up the following directory structure:

```
diy-cloud-platform/
├── lib/                        # Distribution Abstraction Layer (completed)
├── core/                       # Core Platform Module (completed)
├── usermgmt/                   # User Management Module (Phase 2)
│   ├── create_user.sh          # User creation script
│   ├── set_quota.sh            # Set user quotas
│   ├── db/                     # Database-related files
│   │   └── schema.sql          # SQLite database schema
│   ├── api/                    # User Management API
│   │   └── user_management.py  # Python API for user management
├── resources/                  # Resource Management Module (Phase 2)
│   ├── cpu_manager.sh          # CPU resource management
│   ├── mem_manager.sh          # Memory resource management
│   ├── disk_manager.sh         # Disk quota management
│   ├── gpu_manager.sh          # GPU access management
│   ├── apply_limits.sh         # Script to apply resource limits
└── test_phase2.sh              # Test script for Phase 2
```

## Prerequisites

Before starting Phase 2, ensure you have:

1. A working Phase 0 (Distribution Abstraction Layer)
2. A working Phase 1 (Core Platform Module)
3. SQLite installed (for the User Management database)
4. Python 3.8+ installed (for API components)

## Implementation Steps

### Step 1: User Management Module

#### 1.1 Create the User Management Directory Structure

```bash
mkdir -p diy-cloud-platform/usermgmt/db
mkdir -p diy-cloud-platform/usermgmt/api
```

#### 1.2 Implement User Creation Script

Create `usermgmt/create_user.sh` that:
- Creates system users
- Sets initial passwords
- Creates home directories
- Initializes user profiles in the database

#### 1.3 Create Database Schema

Create `usermgmt/db/schema.sql` to define:
- Users table
- User roles
- Resource allocations table

#### 1.4 Implement User Management API

Create `usermgmt/api/user_management.py` that provides:
- REST API for user management
- Authentication endpoints
- User profile management

### Step 2: Resource Management Module

#### 2.1 Create the Resource Management Directory Structure

```bash
mkdir -p diy-cloud-platform/resources
```

#### 2.2 Implement CPU Management

Create `resources/cpu_manager.sh` that:
- Sets CPU limits using cgroups
- Supports both cgroups v1 and v2 (via the Distribution Abstraction Layer)
- Implements CPU shares/quota configuration

#### 2.3 Implement Memory Management

Create `resources/mem_manager.sh` that:
- Sets memory limits using cgroups
- Implements memory limit configuration

#### 2.4 Implement Disk Quota Management

Create `resources/disk_manager.sh` that:
- Sets up disk quotas for users
- Implements quota management operations

#### 2.5 Implement GPU Access Management (if applicable)

Create `resources/gpu_manager.sh` that:
- Manages GPU access for users
- Configures NVIDIA Docker integration (if available)

#### 2.6 Create a Combined Resource Limits Script

Create `resources/apply_limits.sh` that:
- Applies all resource limits for a user
- Provides a single interface for resource management

### Step 3: Integration with Core Platform Module

#### 3.1 Update the Web Portal

Add a user management section to the web portal:
- User login page
- Admin interface for user management
- Resource usage dashboard

#### 3.2 Configure API Endpoints

Update Nginx configuration to provide access to the User Management API.

### Step 4: Testing

Create `test_phase2.sh` that:
- Tests user creation and authentication
- Tests resource limit application
- Verifies integration with the Core Platform Module

## Using the Distribution Abstraction Layer

Remember to use the Distribution Abstraction Layer (DAL) for all operations to ensure cross-distribution compatibility:

```bash
# Source the Distribution Abstraction Layer
source lib/detect_distro.sh
source lib/package_manager.sh
source lib/service_manager.sh
source lib/path_resolver.sh
source lib/resource_adapter.sh
source lib/common.sh

# Use DAL functions for package management
install_package "sqlite3"
install_package "python3"

# Use DAL functions for service management
restart_service "nginx"

# Use DAL functions for path resolution
config_path=$(get_config_path "nginx_sites")

# Use DAL functions for resource management
apply_cpu_limit "username" "1.0"
apply_memory_limit "username" "2G"
```

## Database Schema

Here's a suggested SQLite schema for the User Management database:

```sql
-- Users Table
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    role TEXT DEFAULT 'user',
    is_active BOOLEAN DEFAULT 1
);

-- Resource Allocations Table
CREATE TABLE resource_allocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    cpu_limit REAL NOT NULL DEFAULT 1,
    mem_limit TEXT NOT NULL DEFAULT '2G',
    disk_quota TEXT NOT NULL DEFAULT '5G',
    gpu_access BOOLEAN DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

## Best Practices

1. **Modularity**: Keep each component independent but with clear integration points.
2. **Security**: Implement proper authentication and authorization.
3. **Cross-Distribution Testing**: Test on multiple distributions to ensure compatibility.
4. **Documentation**: Document all APIs and configuration options.
5. **Error Handling**: Implement robust error handling and logging.

## Success Criteria for Phase 2

Phase 2 is considered complete when:

1. Users can be created, modified, and deleted
2. Authentication works correctly
3. Resource limits can be applied to users
4. The web portal integrates with the User Management Module
5. All tests pass on all target distributions

## Next Steps

After completing Phase 2, you'll move on to Phase 3: Service Modules, where you'll implement:

- JupyterHub Module
- Docker/Portainer Module

Good luck with Phase 2!
