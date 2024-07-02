#!/bin/bash

# Function to check if apt process is running
function check_apt_process() {
    while pgrep -x "apt" >/dev/null; do
        echo "Killing other apt processes..."
        sudo pkill -x apt
        sleep 5
    done
}

# Function to automatically reconfigure dpkg if it was interrupted
function dpkg_configure_auto_yes() {
    echo "Reconfiguring dpkg..."
    sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a
}

# Function to install L2 node
function l2_install_node() {
    read -p "Please enter the UUID: " UUID  # Prompt user to input UUID

    # Check and kill other apt processes
    check_apt_process

    # Check if dpkg was interrupted
    if [ -f /var/lib/dpkg/lock ]; then
        echo "dpkg was interrupted. Reconfiguring..."
        dpkg_configure_auto_yes
    fi

    # Automatically update and upgrade packages without prompting
    sudo DEBIAN_FRONTEND=noninteractive apt update -y
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::="--force-confnew" -o Dpkg::Options::="--force-confdef"

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker is already installed."
    fi

    sudo docker pull nezha123/titan-edge
    mkdir -p ~/.titanedge
    sudo docker run --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge
    sudo docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding

    echo "Deployment completed"
}

# Main function to execute l2_install_node
function main() {
    l2_install_node
}

main
