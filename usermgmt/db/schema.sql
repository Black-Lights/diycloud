-- DIY Cloud Platform - User Management Database Schema

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

-- Session Table
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_token TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Activity Log Table
CREATE TABLE activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    activity_type TEXT NOT NULL,
    description TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Initial admin user (password will be set during initialization)
INSERT INTO users (username, password_hash, email, role, is_active) 
VALUES ('admin', 'PLACEHOLDER', 'admin@localhost', 'admin', 1);

-- Insert the admin's resource allocation
INSERT INTO resource_allocations (user_id, cpu_limit, mem_limit, disk_quota, gpu_access)
VALUES (1, 2, '4G', '10G', 1);