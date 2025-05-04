# User Management Module: Implementation Guide

This guide provides detailed instructions for implementing the User Management Module of the DIY Cloud Platform.

## 1. Overview

The User Management Module is responsible for:
- User creation and deletion
- Authentication
- Role-based access control
- User profile management
- Integration with the Distribution Abstraction Layer

## 2. Directory Structure

```
/opt/diycloud/usermgmt/
├── create_user.sh          # User creation script
├── set_quota.sh            # Set user quotas
├── user_management.py      # Python API for user management
├── db/                     # Database files
│   ├── init_db.sh          # Database initialization script
│   └── schema.sql          # Database schema
└── auth/                   # Authentication files
    └── pam_config.sh       # PAM configuration script
```

## 3. Database Implementation

### 3.1. Schema Design (schema.sql)

The database will use SQLite for simplicity and portability. The schema consists of:

- `users` table for user accounts
- `resource_allocations` table for user resource limits

Create the schema file with the following contents:

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

-- Initial admin user (password will be set during initialization)
INSERT INTO users (username, password_hash, email, role, is_active) 
VALUES ('admin', 'PLACEHOLDER', 'admin@localhost', 'admin', 1);
```

### 3.2. Database Initialization (init_db.sh)

Create the database initialization script that:
1. Creates the SQLite database
2. Applies the schema
3. Sets the admin password

The script should:
- Check if SQLite is installed
- Create the database directory
- Initialize the database with the schema
- Generate a secure password for the admin user if not provided
- Update the admin user with the password hash

## 4. User Management Implementation

### 4.1. User Creation Script (create_user.sh)

The user creation script should:
1. Create the system user
2. Set up the user's home directory
3. Add the user to the database
4. Apply resource limits

Key functions:
- `create_system_user()`: Create the Linux user account
- `setup_user_home()`: Configure the user's home directory
- `add_user_to_db()`: Add user to the SQLite database
- `apply_resource_limits()`: Apply CPU, memory, and disk limits

### 4.2. User Quota Setting (set_quota.sh)

This script allows changing resource limits for existing users:
- Update CPU allocation
- Change memory limits
- Modify disk quotas
- Enable/disable GPU access

### 4.3. User Management API (user_management.py)

Create a Python-based API for user management with the following features:
- List all users
- Get user details
- Create new users
- Update user information
- Delete users
- Manage resource allocations

The API should use Flask or a similar lightweight framework and provide JSON responses.

## 5. Authentication Implementation

### 5.1. PAM Configuration (pam_config.sh)

Configure PAM for authentication:
- Create a PAM service configuration for the platform
- Set up authentication against the system users
- Configure session management

### 5.2. Role-Based Access Control

Implement roles and permissions:
- Admin: Full access to all features
- User: Access to their own resources only
- Guest: Limited, read-only access

## 6. Integration with Distribution Abstraction Layer

Use the Distribution Abstraction Layer for:
- Package installation (SQLite, Python dependencies)
- User creation across different distributions
- Service management (database, API)
- Path resolution for configuration files

Example:
```bash
# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/common.sh

# Install required packages
install_package "sqlite3"
install_package "python3"
install_package "python3-pip"

# Get paths
config_path=$(get_config_path "diycloud")
```

## 7. Testing

Create tests for:
1. User creation and deletion
2. Authentication
3. Role-based access control
4. Resource allocation
5. API endpoints

## 8. Security Considerations

- Use strong password hashing (bcrypt/Argon2)
- Implement proper session management
- Use prepared statements for database queries
- Apply principle of least privilege
- Audit user actions
