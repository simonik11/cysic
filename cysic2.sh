#!/bin/bash

# Function: Check if a command executed successfully
check_command() {
    if [ $? -ne 0 ]; then
        echo "Command failed: $1"
        exit 1
    fi
}

# Check if Node.js, npm, and PM2 are installed
check_installed() {
    command -v node >/dev/null 2>&1 && NODE_INSTALLED=true || NODE_INSTALLED=false
    command -v npm >/dev/null 2>&1 && NPM_INSTALLED=true || NPM_INSTALLED=false
    command -v pm2 >/dev/null 2>&1 && PM2_INSTALLED=true || PM2_INSTALLED=false
}

# Install Node.js and PM2
install_dependencies() {
    echo "Updating package list..."
    sudo apt update
    check_command "Failed to update package list"

    echo "Installing Node.js and PM2..."
    if ! curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -; then
        echo "Failed to add NodeSource repository, trying fallback..."
        if ! curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -; then
            echo "Failed to add NodeSource repository, exiting."
            exit 1
        fi
    fi

    if ! sudo apt-get install -y nodejs; then
        echo "Failed to install Node.js, exiting."
        exit 1
    fi

    echo "Node.js version: $(node -v)"
    echo "npm version: $(npm -v)"

    # Check if PM2 is installed
    if ! command -v pm2 &> /dev/null; then
        echo "PM2 is not installed, installing..."
        if ! sudo npm install pm2 -g; then
            echo "Failed to install PM2 via npm, exiting."
            exit 1
        fi
    else
        echo "PM2 is already installed, skipping installation."
    fi

    echo "PM2 version: $(pm2 -v)"
}

# Main menu loop
while true; do
    echo "Please choose a command:"
    echo "1. Install PM2 and configure validator"
    echo "2. Start validator"
    echo "3. Stop and remove validator"
    echo "4. Delete phase 1 testnet data"
    echo "5. View logs"
    echo "0. Exit"
    read -p "Enter your choice: " command

    case $command in
        1)
            check_installed
            if [ "$NODE_INSTALLED" = false ] || [ "$NPM_INSTALLED" = false ] || [ "$PM2_INSTALLED" = false ]; then
                install_dependencies
            else
                echo "Node.js, npm, and PM2 are already installed, skipping installation."
            fi
            echo "PM2 and validator configuration completed, returning to main menu..."

            # Prompt user for reward address
            read -p "Enter your reward address: " reward_address

            # Download and configure validator
            echo "Downloading and configuring validator..."
            if curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh -o ~/setup_linux.sh; then
                bash ~/setup_linux.sh "$reward_address"
            else
                echo "Download failed, check the URL or your network connection."
            fi
            ;;

        2)
            # Start validator
            if [ ! -f pm2-start.sh ]; then
                echo "Creating pm2-start.sh script..."
                echo -e '#!/bin/bash\ncd ~/cysic-verifier/ && bash start.sh' > pm2-start.sh
                chmod +x pm2-start.sh
            fi

            echo "Starting validator..."
            if pm2 start ./pm2-start.sh --interpreter bash --name cysic-verifier; then
                echo "Cysic Verifier started successfully, returning to main menu..."
            else
                echo "Startup failed, check PM2 and the script."
            fi
            ;;

        3)
            # Stop and remove validator
            echo "Stopping and removing validator..."
            pm2 stop cysic-verifier
            pm2 delete cysic-verifier
            echo "Validator stopped and removed, returning to main menu..."
            ;;

        4)
            # Delete phase 1 testnet data
            read -p "Are you sure you want to delete phase 1 testnet data? (y/n): " confirm
            if [ "$confirm" = "y" ]; then
                echo "Deleting phase 1 testnet data..."
                sudo rm -rf ~/cysic-verifier
                sudo rm -rf ~/.scr*
                echo "Phase 1 testnet data deleted, returning to main menu..."
            else
                echo "Delete operation cancelled, returning to main menu."
            fi
            ;;

        5)
            # View validator logs
            echo "Viewing validator logs..."
            pm2 logs cysic-verifier
            echo "Press Ctrl+C to exit log view."
            ;;

        0)
            echo "Exiting program."
            exit 0
            ;;

        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done
