// DIY Cloud Platform - Main JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Initialize the web portal
    initPortal();
});

/**
 * Initialize the web portal functionality
 */
function initPortal() {
    // Set up event listeners for service buttons
    setupServiceButtons();
    
    // Check service statuses
    checkServiceStatus();
    
    // Set current year in the footer
    setCurrentYear();
}

/**
 * Set up event listeners for service buttons
 */
function setupServiceButtons() {
    const serviceButtons = document.querySelectorAll('.service-btn.disabled');
    
    serviceButtons.forEach(button => {
        button.addEventListener('click', function(event) {
            event.preventDefault();
            
            // Show a message that the service is not available yet
            const serviceName = this.textContent.replace('Access ', '');
            showNotification(`${serviceName} is not available yet. It will be implemented in a future phase.`, 'warning');
        });
    });
}

/**
 * Check the status of services
 */
function checkServiceStatus() {
    // This is a placeholder function
    // In the future, this will make API calls to check service status
    console.log('Checking service status...');
    
    // For now, we'll just simulate that the Core Platform is active
    // and all other services are pending
}

/**
 * Show a notification message
 * @param {string} message - The message to display
 * @param {string} type - The type of notification (info, success, warning, error)
 */
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.innerHTML = `
        <span class="message">${message}</span>
        <button class="close-btn">&times;</button>
    `;
    
    // Add notification to the DOM
    document.body.appendChild(notification);
    
    // Add event listener to close button
    notification.querySelector('.close-btn').addEventListener('click', function() {
        notification.remove();
    });
    
    // Auto-remove after 5 seconds
    setTimeout(function() {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
    
    // Add styles if not already in the CSS
    if (!document.getElementById('notification-styles')) {
        const style = document.createElement('style');
        style.id = 'notification-styles';
        style.innerHTML = `
            .notification {
                position: fixed;
                bottom: 20px;
                right: 20px;
                padding: 15px 20px;
                border-radius: 4px;
                background-color: white;
                box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                display: flex;
                align-items: center;
                justify-content: space-between;
                max-width: 300px;
                z-index: 1000;
                animation: slide-in 0.3s ease-out forwards;
            }
            
            .notification.info {
                border-left: 4px solid #3498db;
            }
            
            .notification.success {
                border-left: 4px solid #2ecc71;
            }
            
            .notification.warning {
                border-left: 4px solid #f39c12;
            }
            
            .notification.error {
                border-left: 4px solid #e74c3c;
            }
            
            .notification .message {
                flex-grow: 1;
                margin-right: 10px;
            }
            
            .notification .close-btn {
                background: none;
                border: none;
                font-size: 18px;
                cursor: pointer;
                color: #95a5a6;
            }
            
            .notification .close-btn:hover {
                color: #7f8c8d;
            }
            
            @keyframes slide-in {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
        `;
        document.head.appendChild(style);
    }
}

/**
 * Set the current year in the footer copyright text
 */
function setCurrentYear() {
    const yearElement = document.querySelector('.footer-bottom p');
    if (yearElement) {
        const currentYear = new Date().getFullYear();
        yearElement.textContent = yearElement.textContent.replace('2025', currentYear);
    }
}
