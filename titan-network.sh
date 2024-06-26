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

# Node installation function
function install_node() {
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
    if ! command -v docker &> /dev/null
    then
        echo "Installing Docker..."
        sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker is already installed."
    fi

    # Identity code
    read -p "Identity code: " uid

    # Default node count
    docker_count=1

    # Pull Docker image
    sudo docker pull nezha123/titan-edge:1.5
    
    # Create and start container
    titan_port=40000
    for ((i=1; i<=docker_count; i++))
    do
        current_port=$((titan_port + i - 1))
        # Create storage directory
        mkdir -p "$HOME/titan_storage_$i"
    
        # Start node
        container_id=$(sudo docker run -d --restart always -v "$HOME/titan_storage_$i:/root/.titanedge/storage" --name "titan$i" --net=host nezha123/titan-edge:1.5)
        echo "Node titan$i started, container ID $container_id"
        sleep 30
    
        # Configure storage and port
        sudo docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = 50/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Container titan'$i' storage set to 50 GB, port set to $current_port'"
    
        sudo docker restart $container_id
    
        # Start binding
        sudo docker exec $container_id bash -c "\
            titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan$i started binding."
    
    done
    
    echo "============================== Deployment Complete ==============================="
}

# Automatically install and start node
install_node

echo "Script execution complete."
