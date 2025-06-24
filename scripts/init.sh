#!/bin/bash

set -e

# Check if frappe already exists
if [[ -d "/workspaces/frappe_codespace/frappe-bench/apps/frappe" ]]; then
    echo "Bench already exists, skipping init"
    exit 0
fi

# Remove .git directory if it exists
if [[ -d "/workspaces/frappe_codespace/.git" ]]; then
    echo "Removing existing .git directory"
    rm -rf /workspaces/frappe_codespace/.git
fi

# Load NVM and set Node.js version
source /home/frappe/.nvm/nvm.sh
nvm install v20.9.0
nvm alias default v20.9.0
nvm use v20.9.0

# Install Yarn globally if not already installed
if ! command -v yarn &> /dev/null; then
    echo "Installing yarn..."
    npm install -g yarn
else
    echo "Yarn already installed"
fi

# Persist nvm use
if ! grep -q "nvm use v20.9.0" ~/.bashrc; then
    echo "nvm use v20.9.0" >> ~/.bashrc
fi

cd /workspace

# Initialize bench if it doesn't exist
if [[ ! -d "frappe-bench" ]]; then
    echo "Initializing frappe bench..."
    bench init \
        --ignore-exist \
        --skip-redis-config-generation \
        frappe-bench
else
    echo "Frappe bench already initialized"
fi

cd frappe-bench

# Configure service hosts
echo "Setting up MariaDB and Redis hosts..."
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis-cache:6379
bench set-redis-queue-host redis://redis-queue:6379
bench set-redis-socketio-host redis://redis-socketio:6379

# Remove redis entries from Procfile if they exist
if grep -q "redis" ./Procfile; then
    echo "Cleaning up redis from Procfile..."
    sed -i '/redis/d' ./Procfile
fi

# Create new site if it doesn't exist
if [[ ! -d "sites/app.localhost" ]]; then
    echo "Creating new site app.localhost..."
    bench new-site app.localhost \
        --mariadb-root-username root \
        --mariadb-root-password 123 \
        --admin-password admin \
        --mariadb-user-host-login-scope='%' \
        --force
else
    echo "Site app.localhost already exists"
fi

# Configure and install app
echo "Configuring site..."
bench --site app.localhost set-config developer_mode 1
bench --site app.localhost clear-cache
bench use app.localhost

# Check if app is already fetched
if [[ ! -d "apps/print_designer" ]]; then
    echo "Getting print_designer app..."
    bench get-app print_designer
else
    echo "print_designer app already exists"
fi

# Install app if not already installed
if ! bench --site app.localhost list-apps | grep -q "print_designer"; then
    echo "Installing print_designer app..."
    bench --site app.localhost install-app print_designer
else
    echo "print_designer already installed on app.localhost"
fi
