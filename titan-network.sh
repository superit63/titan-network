#!/bin/bash

# Function to install Docker on CentOS
function install_docker_centos() {
    sudo yum update -y
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to install Titan Node
function install_node() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null
    then
        echo "Installing Docker..."
        install_docker_centos
    else
        echo "Docker is already installed."
    fi

    # Identity code
    read -p "Identity code: " uid
    # Node count
    read -p "Node count: " docker_count

    # Pull Docker image
    sudo docker pull nezha123/titan-edge:1.5

    # Start containers
    titan_port=40000
    for ((i=1; i<=docker_count; i++))
    do
        current_port=$((titan_port + i - 1))
        # Create storage directory
        mkdir -p "$HOME/titan_storage_$i"

        # Start node
        container_id=$(sudo docker run -d --restart always \
                        -v "$HOME/titan_storage_$i:/root/.titanedge/storage" \
                        --name "titan$i" --net=host \
                        -e UDP_RECV_BUFFER_SIZE=2048k \ # Thêm dòng này để cấu hình kích thước bộ đệm nhận
                        nezha123/titan-edge:1.5)
        echo "Node titan$i has started. Container ID: $container_id"
        sleep 30

        # Configure storage and port
        sudo docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = 50/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Container titan'$i' storage set to 50 GB, port set to $current_port'"

        sudo docker restart $container_id

        # Start mining
        sudo docker exec $container_id bash -c "\
            titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan$i has started mining."
    done

    echo "==============================Deployment completed=============================="
}

# Function to check node status
function check_service_status() {
    sudo docker ps
}

# Function to check node tasks
function check_node_cache() {
    for container in $(sudo docker ps -q); do
        echo "Checking node: $container tasks:"
        sudo docker exec -it "$container" titan-edge cache
    done
}

# Function to stop nodes
function stop_node() {
    for container in $(sudo docker ps -q); do
        echo "Stopping node: $container "
        sudo docker exec -it "$container" titan-edge daemon stop
    done
}

# Function to start nodes
function start_node() {
    for container in $(sudo docker ps -q); do
        echo "Starting node: $container "
        sudo docker exec -it "$container" titan-edge daemon start
    done
}

# Function to update identity code
function update_uid() {
    # Identity code
    read -p "Identity code: " uid
    for container in $(sudo docker ps -q); do
        echo "Starting node: $container "
        sudo docker exec -it "$container" bash -c "\
            titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node $container has started mining."
    done
}

# Main menu function
function main_menu() {
    while true; do
        clear
        echo "===============Titan Network Deployment Script==============="
        echo "Telegram group: https://t.me/lumaogogogo"
        echo "Minimum requirements: 1C2G64G; Recommended: 6C12G300G"
        echo "1. Install Node"
        echo "2. Check Node Status"
        echo "3. Check Node Tasks"
        echo "4. Stop Node"
        echo "5. Start Node"
        echo "6. Update Identity Code"
        echo "0. Exit Script"
        read -r -p "Enter option: " OPTION

        case $OPTION in
        1) install_node ;;
        2) check_service_status ;;
        3) check_node_cache ;;
        4) stop_node ;;
        5) start_node ;;
        6) update_uid ;;
        0) echo "Exiting script."; exit 0 ;;
        *) echo "Invalid option. Please try again."; sleep 3 ;;
        esac
        echo "Press any key to return to the main menu..."
        read -n 1
    done
}

# Show menu
main_menu
