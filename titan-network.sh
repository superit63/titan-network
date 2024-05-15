#!/bin/bash

# Node installation function
function install_node() {
    if [[ "$(lsb_release -si)" != "Ubuntu" && "$(lsb_release -si)" != "Debian" ]]; then
        echo "This script only supports running on Ubuntu or Debian."
        exit 1
    fi

    sudo -v

    sudo apt update && sudo apt upgrade -y

    # Check if Docker is installed
    if ! command -v docker &> /dev/null
    then
        echo "Installing Docker..."
        sudo apt install -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker is already installed, updating Docker..."
        sudo apt install --only-upgrade docker.io
    fi

    # Default identity code
    uid="anmmklsoooo"
    echo "Using default identity code: $uid"

    # Default node count
    docker_count=1
    echo "Using default node count: $docker_count"

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
        if [ $? -ne 0 ]; then
            echo "Node titan$i failed to start"
            continue
        fi
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

# Check node status
function check_service_status() {
    sudo docker ps
}

# Check node tasks
function check_node_cache() {
    for container in $(sudo docker ps -q); do
        echo "Checking node: $container tasks:"
        sudo docker exec -it "$container" titan-edge cache
    done
}

# Stop node
function stop_node() {
    for container in $(sudo docker ps -q); do
        echo "Stopping node: $container"
        sudo docker exec -it "$container" titan-edge daemon stop
    done
}

# Start node
function start_node() {
    for container in $(sudo docker ps -q); do
        echo "Starting node: $container"
        sudo docker exec -it "$container" titan-edge daemon start
    done
}

# Update identity code
function update_uid() {
    # Identity code
    read -p "Identity code: " uid
    for container in $(sudo docker ps -q); do
        echo "Updating node: $container with new identity code"
        sudo docker exec -it "$container" bash -c "\
            titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node $container started binding."
    done
}

# Automatically install and start node
install_node
start_node

echo "Script execution complete."
