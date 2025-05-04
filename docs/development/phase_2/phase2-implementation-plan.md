# Phase 2: User & Resource Management - Implementation Plan

## 1. Directory Structure

```
/opt/diycloud/
├── usermgmt/                   # User Management Module
│   ├── create_user.sh          # User creation script
│   ├── set_quota.sh            # Set user quotas
│   ├── user_management.py      # Python API for user management
│   ├── db/                     # Database files
│   │   ├── init_db.sh          # Database initialization script
│   │   └── schema.sql          # Database schema
│   └── auth/                   # Authentication files
│       └── pam_config.sh       # PAM configuration script
│
└── resources/                  # Resource Management Module
    ├── cpu_manager.sh          # CPU resource management
    ├── mem_manager.sh          # Memory resource management
    ├── disk_manager.sh         # Disk quota management
    ├── gpu_manager.sh          # GPU access management
    └── apply_limits.sh         # Apply resource limits to user
```

## 2. Implementation Stages

### Stage 1: User Management Module (usermgmt/)

- Create database schema and initialization scripts
- Implement user creation and management scripts
- Implement PAM authentication integration
- Create user profile management
- Implement role-based access control
- Create API endpoints for user management

### Stage 2: Resource Management Module (resources/)

- Implement CPU resource allocation with cgroups v1/v2 support
- Implement memory limitation features
- Set up disk quota management
- Create GPU access control (if available)
- Develop unified resource limit application

### Stage 3: Integration with Core Platform

- Update web portal for user management interface
- Set up Nginx configuration for API endpoints
- Configure user home directories and permissions
- Implement resource monitoring display

### Stage 4: Testing and Validation

- Create comprehensive test scripts
- Test on multiple distributions
- Verify integration with Phases 0 and 1

## 3. Database Schema Design

### Users Table
```sql
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
```

### Resource Allocations Table
```sql
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

## 4. Implementation Timeline

- Day 1-4: User Management Module
  - Database schema and initialization
  - User creation and management
  - Authentication integration
  - Role-based access control

- Day 5-8: Resource Management Module
  - CPU resource allocation
  - Memory limitations
  - Disk quota management
  - GPU access control
  - Resource limits application

- Day 9-12: Integration and Testing
  - Core Platform integration
  - Cross-distribution testing
  - Documentation

- Day 13-14: Finalization
  - Bug fixes and optimization
  - Final testing
  - Documentation updates
