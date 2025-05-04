#!/usr/bin/env python3
# DIY Cloud Platform - User Management API
#
# This script provides a RESTful API for user management using Flask.

import os
import sys
import json
import sqlite3
import hashlib
import secrets
import subprocess
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, g

# Configuration
DATABASE_PATH = '/opt/diycloud/usermgmt/db/users.db'
RESOURCES_PATH = '/opt/diycloud/resources'
TOKEN_EXPIRY_DAYS = 1
PORT = 5000
DEBUG = False

# Initialize Flask application
app = Flask(__name__)

# Database helper functions
def get_db():
    """Get database connection"""
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE_PATH)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    """Close database connection when app context ends"""
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def query_db(query, args=(), one=False):
    """Query the database"""
    cur = get_db().execute(query, args)
    rv = cur.fetchall()
    cur.close()
    get_db().commit()
    return (rv[0] if rv else None) if one else rv

# Authentication functions
def generate_password_hash(password):
    """Generate a secure password hash"""
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(password, password_hash):
    """Verify password against hash"""
    return generate_password_hash(password) == password_hash

def generate_token():
    """Generate a secure random token"""
    return secrets.token_hex(32)

def authenticate_user(username, password):
    """Authenticate a user and return a token"""
    user = query_db('SELECT * FROM users WHERE username = ?', [username], one=True)
    
    if user and verify_password(password, user['password_hash']):
        # Generate a token
        token = generate_token()
        expires_at = datetime.now() + timedelta(days=TOKEN_EXPIRY_DAYS)
        
        # Store token in database
        query_db(
            'INSERT INTO sessions (user_id, session_token, expires_at, ip_address) VALUES (?, ?, ?, ?)',
            [user['id'], token, expires_at, request.remote_addr]
        )
        
        # Update last login
        query_db(
            'UPDATE users SET last_login = ? WHERE id = ?',
            [datetime.now(), user['id']]
        )
        
        return {
            'token': token,
            'expires_at': expires_at.isoformat(),
            'user_id': user['id'],
            'username': user['username'],
            'role': user['role']
        }
    
    return None

def verify_token(token):
    """Verify a token and return user if valid"""
    session = query_db(
        'SELECT s.*, u.* FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.session_token = ? AND s.expires_at > ?',
        [token, datetime.now()],
        one=True
    )
    
    if session:
        return {
            'user_id': session['user_id'],
            'username': session['username'],
            'role': session['role']
        }
    
    return None

def require_auth(f):
    """Decorator to require authentication for a route"""
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authentication required'}), 401
        
        token = auth_header.split(' ')[1]
        user = verify_token(token)
        
        if not user:
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        return f(user=user, *args, **kwargs)
    
    decorated.__name__ = f.__name__
    return decorated

def require_admin(f):
    """Decorator to require admin role for a route"""
    def decorated(*args, **kwargs):
        user = kwargs.get('user')
        
        if not user or user['role'] != 'admin':
            return jsonify({'error': 'Admin privileges required'}), 403
        
        return f(*args, **kwargs)
    
    decorated.__name__ = f.__name__
    return decorated

# Resource management functions
def apply_resource_limits(username, cpu_limit, mem_limit, disk_quota, gpu_access):
    """Apply resource limits to a user"""
    try:
        script_path = os.path.join(RESOURCES_PATH, 'apply_limits.sh')
        cmd = [
            'bash', script_path, 
            username, 
            str(cpu_limit), 
            str(mem_limit), 
            str(disk_quota), 
            str(gpu_access).lower()
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            app.logger.error(f"Failed to apply resource limits: {result.stderr}")
            return False
        
        return True
    except Exception as e:
        app.logger.error(f"Error applying resource limits: {str(e)}")
        return False

# API Routes
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'ok'})

@app.route('/api/auth/login', methods=['POST'])
def login():
    """User login endpoint"""
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username and password required'}), 400
    
    auth_result = authenticate_user(data['username'], data['password'])
    
    if auth_result:
        return jsonify(auth_result)
    
    return jsonify({'error': 'Invalid username or password'}), 401

@app.route('/api/auth/logout', methods=['POST'])
@require_auth
def logout(user):
    """User logout endpoint"""
    auth_header = request.headers.get('Authorization')
    token = auth_header.split(' ')[1]
    
    query_db('DELETE FROM sessions WHERE session_token = ?', [token])
    
    return jsonify({'message': 'Logged out successfully'})

@app.route('/api/users', methods=['GET'])
@require_auth
@require_admin
def list_users(user):
    """List all users"""
    users = query_db('SELECT id, username, email, role, created_at, last_login, is_active FROM users')
    
    result = []
    for user in users:
        # Get resource allocations
        resource = query_db(
            'SELECT * FROM resource_allocations WHERE user_id = ?',
            [user['id']],
            one=True
        )
        
        user_dict = dict(user)
        if resource:
            user_dict['resources'] = dict(resource)
        
        result.append(user_dict)
    
    return jsonify(result)

@app.route('/api/users/<int:user_id>', methods=['GET'])
@require_auth
def get_user(user, user_id):
    """Get user details"""
    # Regular users can only see their own details
    if user['role'] != 'admin' and user['user_id'] != user_id:
        return jsonify({'error': 'Access denied'}), 403
    
    # Get user details
    user_data = query_db(
        'SELECT id, username, email, role, created_at, last_login, is_active FROM users WHERE id = ?',
        [user_id],
        one=True
    )
    
    if not user_data:
        return jsonify({'error': 'User not found'}), 404
    
    # Get resource allocations
    resource = query_db(
        'SELECT * FROM resource_allocations WHERE user_id = ?',
        [user_id],
        one=True
    )
    
    result = dict(user_data)
    if resource:
        result['resources'] = dict(resource)
    
    return jsonify(result)

@app.route('/api/users', methods=['POST'])
@require_auth
@require_admin
def create_user(user):
    """Create a new user"""
    data = request.get_json()
    
    # Validate required fields
    required_fields = ['username', 'password']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'Missing required field: {field}'}), 400
    
    username = data['username']
    password = data['password']
    email = data.get('email', '')
    role = data.get('role', 'user')
    is_active = data.get('is_active', True)
    
    # Check if username already exists
    existing_user = query_db('SELECT id FROM users WHERE username = ?', [username], one=True)
    if existing_user:
        return jsonify({'error': 'Username already exists'}), 409
    
    # Hash password
    password_hash = generate_password_hash(password)
    
    # Insert user into database
    try:
        query_db(
            'INSERT INTO users (username, password_hash, email, role, is_active) VALUES (?, ?, ?, ?, ?)',
            [username, password_hash, email, role, is_active]
        )
        
        # Get user ID
        user_id = query_db('SELECT id FROM users WHERE username = ?', [username], one=True)['id']
        
        # Set resource allocations
        cpu_limit = data.get('cpu_limit', 1.0)
        mem_limit = data.get('mem_limit', '2G')
        disk_quota = data.get('disk_quota', '5G')
        gpu_access = data.get('gpu_access', False)
        
        query_db(
            'INSERT INTO resource_allocations (user_id, cpu_limit, mem_limit, disk_quota, gpu_access) VALUES (?, ?, ?, ?, ?)',
            [user_id, cpu_limit, mem_limit, disk_quota, gpu_access]
        )
        
        # Create system user
        try:
            # Convert memory and disk values to MB for the script
            mem_mb = int(mem_limit.replace('G', '')) * 1024 if 'G' in mem_limit else int(mem_limit.replace('M', ''))
            disk_mb = int(disk_quota.replace('G', '')) * 1024 if 'G' in disk_quota else int(disk_quota.replace('M', ''))
            
            script_path = '/opt/diycloud/usermgmt/create_user.sh'
            cmd = [
                'bash', script_path,
                '--username', username,
                '--password', password,
                '--email', email,
                '--cpu', str(cpu_limit),
                '--memory', str(mem_mb),
                '--disk', str(disk_mb),
                '--role', role
            ]
            
            if gpu_access:
                cmd.append('--gpu')
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                app.logger.error(f"Failed to create system user: {result.stderr}")
                # Rollback database changes
                query_db('DELETE FROM resource_allocations WHERE user_id = ?', [user_id])
                query_db('DELETE FROM users WHERE id = ?', [user_id])
                return jsonify({'error': 'Failed to create system user', 'details': result.stderr}), 500
            
        except Exception as e:
            app.logger.error(f"Error creating system user: {str(e)}")
            # Rollback database changes
            query_db('DELETE FROM resource_allocations WHERE user_id = ?', [user_id])
            query_db('DELETE FROM users WHERE id = ?', [user_id])
            return jsonify({'error': 'Failed to create system user', 'details': str(e)}), 500
        
        return jsonify({'message': 'User created successfully', 'user_id': user_id}), 201
        
    except Exception as e:
        app.logger.error(f"Error creating user: {str(e)}")
        return jsonify({'error': 'Failed to create user', 'details': str(e)}), 500

@app.route('/api/users/<int:user_id>', methods=['PUT'])
@require_auth
def update_user(user, user_id):
    """Update user details"""
    # Regular users can only update their own details
    if user['role'] != 'admin' and user['user_id'] != user_id:
        return jsonify({'error': 'Access denied'}), 403
    
    data = request.get_json()
    
    # Check if user exists
    existing_user = query_db('SELECT * FROM users WHERE id = ?', [user_id], one=True)
    if not existing_user:
        return jsonify({'error': 'User not found'}), 404
    
    # Fields that can be updated
    updateable_fields = ['email', 'is_active']
    
    # Admin-only fields
    admin_fields = ['role', 'cpu_limit', 'mem_limit', 'disk_quota', 'gpu_access']
    
    # Regular users cannot update admin-only fields
    if user['role'] != 'admin':
        for field in admin_fields:
            if field in data:
                return jsonify({'error': f'Field {field} can only be updated by an admin'}), 403
    else:
        updateable_fields.extend(admin_fields)
    
    # Update user fields
    updates = []
    values = []
    
    for field in updateable_fields:
        if field in data and field not in admin_fields:
            updates.append(f"{field} = ?")
            values.append(data[field])
    
    # Update password if provided
    if 'password' in data:
        updates.append("password_hash = ?")
        values.append(generate_password_hash(data['password']))
    
    # If there are updates to make
    if updates:
        values.append(user_id)
        query = f"UPDATE users SET {', '.join(updates)} WHERE id = ?"
        query_db(query, values)
    
    # Update resource allocations if provided (admin only)
    if user['role'] == 'admin':
        resource_updates = []
        resource_values = []
        
        resource_fields = {'cpu_limit': 'cpu_limit', 'mem_limit': 'mem_limit', 
                          'disk_quota': 'disk_quota', 'gpu_access': 'gpu_access'}
        
        for api_field, db_field in resource_fields.items():
            if api_field in data:
                resource_updates.append(f"{db_field} = ?")
                resource_values.append(data[api_field])
        
        if resource_updates:
            resource_values.append(user_id)
            query = f"UPDATE resource_allocations SET {', '.join(resource_updates)} WHERE user_id = ?"
            query_db(query, resource_values)
            
            # Apply resource limits
            resource = query_db('SELECT * FROM resource_allocations WHERE user_id = ?', [user_id], one=True)
            if resource:
                # Get username
                username = existing_user['username']
                
                # Convert memory and disk values to MB for the script
                mem_limit = resource['mem_limit']
                disk_quota = resource['disk_quota']
                
                mem_mb = int(mem_limit.replace('G', '')) * 1024 if 'G' in mem_limit else int(mem_limit.replace('M', ''))
                disk_mb = int(disk_quota.replace('G', '')) * 1024 if 'G' in disk_quota else int(disk_quota.replace('M', ''))
                
                apply_resource_limits(
                    username,
                    resource['cpu_limit'],
                    mem_mb,
                    disk_mb,
                    resource['gpu_access']
                )
    
    return jsonify({'message': 'User updated successfully'})

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
@require_auth
@require_admin
def delete_user(user, user_id):
    """Delete a user"""
    # Check if user exists
    existing_user = query_db('SELECT * FROM users WHERE id = ?', [user_id], one=True)
    if not existing_user:
        return jsonify({'error': 'User not found'}), 404
    
    # Cannot delete admin user
    if existing_user['username'] == 'admin':
        return jsonify({'error': 'Cannot delete the main admin user'}), 403
    
    # Cannot delete yourself
    if user['user_id'] == user_id:
        return jsonify({'error': 'Cannot delete your own account'}), 403
    
    # Get username for system user deletion
    username = existing_user['username']
    
    # Delete user from database
    query_db('DELETE FROM resource_allocations WHERE user_id = ?', [user_id])
    query_db('DELETE FROM sessions WHERE user_id = ?', [user_id])
    query_db('DELETE FROM activity_log WHERE user_id = ?', [user_id])
    query_db('DELETE FROM users WHERE id = ?', [user_id])
    
    # Delete system user
    try:
        result = subprocess.run(['userdel', '-rf', username], capture_output=True, text=True)
        
        if result.returncode != 0:
            app.logger.error(f"Failed to delete system user: {result.stderr}")
            return jsonify({'error': 'Failed to delete system user', 'details': result.stderr}), 500
        
    except Exception as e:
        app.logger.error(f"Error deleting system user: {str(e)}")
        return jsonify({'error': 'Failed to delete system user', 'details': str(e)}), 500
    
    return jsonify({'message': 'User deleted successfully'})

@app.route('/api/resources/<int:user_id>', methods=['GET'])
@require_auth
def get_resources(user, user_id):
    """Get resource allocations for a user"""
    # Regular users can only see their own resources
    if user['role'] != 'admin' and user['user_id'] != user_id:
        return jsonify({'error': 'Access denied'}), 403
    
    # Check if user exists
    existing_user = query_db('SELECT * FROM users WHERE id = ?', [user_id], one=True)
    if not existing_user:
        return jsonify({'error': 'User not found'}), 404
    
    # Get resource allocations
    resource = query_db('SELECT * FROM resource_allocations WHERE user_id = ?', [user_id], one=True)
    
    if not resource:
        return jsonify({'error': 'Resource allocations not found'}), 404
    
    return jsonify(dict(resource))

@app.route('/api/resources/<int:user_id>/usage', methods=['GET'])
@require_auth
def get_resource_usage(user, user_id):
    """Get current resource usage for a user"""
    # Regular users can only see their own resource usage
    if user['role'] != 'admin' and user['user_id'] != user_id:
        return jsonify({'error': 'Access denied'}), 403
    
    # Check if user exists
    existing_user = query_db('SELECT * FROM users WHERE id = ?', [user_id], one=True)
    if not existing_user:
        return jsonify({'error': 'User not found'}), 404
    
    username = existing_user['username']
    
    # Get resource usage
    try:
        # Get CPU usage
        cpu_cmd = ['ps', '-u', username, '-o', '%cpu', '--no-headers']
        cpu_result = subprocess.run(cpu_cmd, capture_output=True, text=True)
        
        cpu_usage = 0
        if cpu_result.returncode == 0 and cpu_result.stdout:
            cpu_values = [float(line.strip()) for line in cpu_result.stdout.splitlines() if line.strip()]
            cpu_usage = sum(cpu_values)
        
        # Get memory usage
        mem_cmd = ['ps', '-u', username, '-o', 'rss', '--no-headers']
        mem_result = subprocess.run(mem_cmd, capture_output=True, text=True)
        
        mem_usage = 0
        if mem_result.returncode == 0 and mem_result.stdout:
            mem_values = [int(line.strip()) for line in mem_result.stdout.splitlines() if line.strip()]
            mem_usage = sum(mem_values) / 1024  # Convert KB to MB
        
        # Get disk usage
        disk_cmd = ['du', '-sm', f'/home/{username}']
        disk_result = subprocess.run(disk_cmd, capture_output=True, text=True)
        
        disk_usage = 0
        if disk_result.returncode == 0 and disk_result.stdout:
            disk_usage = int(disk_result.stdout.split()[0])
        
        # Get GPU usage (if available)
        gpu_usage = []
        nvidia_cmd = ['nvidia-smi', '--query-compute-apps=pid,used_memory', '--format=csv,noheader']
        
        try:
            nvidia_result = subprocess.run(nvidia_cmd, capture_output=True, text=True)
            
            if nvidia_result.returncode == 0 and nvidia_result.stdout:
                # Get all PIDs for the user
                pid_cmd = ['pgrep', '-u', username]
                pid_result = subprocess.run(pid_cmd, capture_output=True, text=True)
                
                if pid_result.returncode == 0 and pid_result.stdout:
                    user_pids = [line.strip() for line in pid_result.stdout.splitlines()]
                    
                    # Filter GPU processes that belong to the user
                    for line in nvidia_result.stdout.splitlines():
                        parts = line.split(',')
                        if len(parts) >= 2:
                            pid = parts[0].strip()
                            if pid in user_pids:
                                memory = parts[1].strip()
                                gpu_usage.append({'pid': pid, 'memory': memory})
        except:
            # If nvidia-smi fails, ignore GPU usage
            pass
        
        return jsonify({
            'cpu_usage': cpu_usage,
            'mem_usage': mem_usage,
            'disk_usage': disk_usage,
            'gpu_usage': gpu_usage
        })
        
    except Exception as e:
        app.logger.error(f"Error getting resource usage: {str(e)}")
        return jsonify({'error': 'Failed to get resource usage', 'details': str(e)}), 500

@app.route('/api/system/resources', methods=['GET'])
@require_auth
@require_admin
def get_system_resources(user):
    """Get system-wide resource information"""
    try:
        # Get CPU info
        cpu_cmd = ['grep', '-c', 'processor', '/proc/cpuinfo']
        cpu_result = subprocess.run(cpu_cmd, capture_output=True, text=True)
        
        cpu_cores = 0
        if cpu_result.returncode == 0 and cpu_result.stdout:
            cpu_cores = int(cpu_result.stdout.strip())
        
        # Get memory info
        mem_cmd = ['grep', 'MemTotal', '/proc/meminfo']
        mem_result = subprocess.run(mem_cmd, capture_output=True, text=True)
        
        mem_total = 0
        if mem_result.returncode == 0 and mem_result.stdout:
            mem_total = int(mem_result.stdout.split()[1]) / 1024  # Convert KB to MB
        
        # Get disk info
        disk_cmd = ['df', '-m', '/home']
        disk_result = subprocess.run(disk_cmd, capture_output=True, text=True)
        
        disk_total = 0
        disk_used = 0
        disk_available = 0
        
        if disk_result.returncode == 0 and disk_result.stdout:
            lines = disk_result.stdout.splitlines()
            if len(lines) > 1:
                parts = lines[1].split()
                if len(parts) >= 4:
                    disk_total = int(parts[1])
                    disk_used = int(parts[2])
                    disk_available = int(parts[3])
        
        # Check if GPU is available
        gpu_available = False
        gpu_info = []
        
        nvidia_cmd = ['nvidia-smi', '--query-gpu=name,memory.total,memory.used', '--format=csv,noheader']
        
        try:
            nvidia_result = subprocess.run(nvidia_cmd, capture_output=True, text=True)
            
            if nvidia_result.returncode == 0 and nvidia_result.stdout:
                gpu_available = True
                
                for line in nvidia_result.stdout.splitlines():
                    parts = [part.strip() for part in line.split(',')]
                    if len(parts) >= 3:
                        gpu_info.append({
                            'name': parts[0],
                            'memory_total': parts[1],
                            'memory_used': parts[2]
                        })
        except:
            # If nvidia-smi fails, no GPU is available
            pass
        
        return jsonify({
            'cpu': {
                'cores': cpu_cores
            },
            'memory': {
                'total_mb': mem_total
            },
            'disk': {
                'total_mb': disk_total,
                'used_mb': disk_used,
                'available_mb': disk_available
            },
            'gpu': {
                'available': gpu_available,
                'info': gpu_info
            }
        })
        
    except Exception as e:
        app.logger.error(f"Error getting system resources: {str(e)}")
        return jsonify({'error': 'Failed to get system resources', 'details': str(e)}), 500

@app.route('/api/logs', methods=['GET'])
@require_auth
@require_admin
def get_activity_logs(user):
    """Get activity logs"""
    # Parse query parameters
    user_id = request.args.get('user_id')
    limit = request.args.get('limit', 100)
    offset = request.args.get('offset', 0)
    
    # Build query
    query = 'SELECT l.*, u.username FROM activity_log l JOIN users u ON l.user_id = u.id'
    params = []
    
    if user_id:
        query += ' WHERE l.user_id = ?'
        params.append(user_id)
    
    query += ' ORDER BY l.timestamp DESC LIMIT ? OFFSET ?'
    params.extend([limit, offset])
    
    # Execute query
    logs = query_db(query, params)
    
    return jsonify([dict(log) for log in logs])

# Start the application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT, debug=DEBUG)