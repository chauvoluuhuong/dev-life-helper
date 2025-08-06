#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display the main menu
show_main_menu() {
    clear
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}     Docker Manager CLI${NC}"
    echo -e "${CYAN}==================================${NC}"
    echo -e "${GREEN}1.${NC} Run Docker Compose"
    echo -e "${GREEN}2.${NC} List All Images"
    echo -e "${GREEN}3.${NC} Manage Containers"
    echo -e "${GREEN}4.${NC} Manage Volumes"
    echo -e "${GREEN}5.${NC} Clean Resources"
    echo -e "${GREEN}6.${NC} Container Logs"
    echo -e "${GREEN}7.${NC} Exit"
    echo -e "${CYAN}==================================${NC}"
}

# Function to find docker-compose files
find_compose_files() {
    echo -e "${YELLOW}Searching for docker-compose files...${NC}"
    # Use a more compatible approach instead of mapfile
    compose_files=()
    while IFS= read -r line; do
        compose_files+=("$line")
    done < <(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml" | sort)
    
    if [ ${#compose_files[@]} -eq 0 ]; then
        echo -e "${RED}No docker-compose files found in current directory${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Found docker-compose files:${NC}"
    for i in "${!compose_files[@]}"; do
        echo -e "${BLUE}$((i+1)).${NC} ${compose_files[$i]}"
    done
    
    echo -e "${YELLOW}Select a file (1-${#compose_files[@]}) or 0 to cancel:${NC}"
    read -r selection
    
    if [[ "$selection" == "0" ]]; then
        return 1
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#compose_files[@]}" ]; then
        selected_file="${compose_files[$((selection-1))]}"
        return 0
    else
        echo -e "${RED}Invalid selection${NC}"
        return 1
    fi
}

# Function to run docker-compose
run_docker_compose() {
    if find_compose_files; then
        echo -e "${GREEN}Selected: $selected_file${NC}"
        echo -e "${YELLOW}Choose action:${NC}"
        echo "1. up -d (start in detached mode)"
        echo "2. up (start in foreground)"
        echo "3. down (stop and remove)"
        echo "4. restart"
        echo "0. Cancel"
        
        read -r action
        
        case $action in
            1)
                echo -e "${GREEN}Running: docker-compose -f $selected_file up -d${NC}"
                docker-compose -f "$selected_file" up -d
                ;;
            2)
                echo -e "${GREEN}Running: docker-compose -f $selected_file up${NC}"
                docker-compose -f "$selected_file" up
                ;;
            3)
                echo -e "${GREEN}Running: docker-compose -f $selected_file down${NC}"
                docker-compose -f "$selected_file" down
                ;;
            4)
                echo -e "${GREEN}Running: docker-compose -f $selected_file restart${NC}"
                docker-compose -f "$selected_file" restart
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid action${NC}"
                ;;
        esac
    fi
    
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to list all images
list_images() {
    echo -e "${CYAN}Docker Images:${NC}"
    echo -e "${YELLOW}============================================${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}"
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to manage containers
manage_containers() {
    while true; do
        clear
        echo -e "${CYAN}Container Management${NC}"
        echo -e "${YELLOW}============================================${NC}"
        
        # List containers with formatting
        echo -e "${GREEN}All Containers:${NC}"
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        
        echo -e "\n${YELLOW}Options:${NC}"
        echo "1. Stop a container"
        echo "2. Remove a container"
        echo "3. Stop all containers"
        echo "4. Remove all stopped containers"
        echo "0. Back to main menu"
        
        read -r choice
        
        case $choice in
            1)
                echo -e "${YELLOW}Enter container ID or name to stop:${NC}"
                read -r container_id
                if [ -n "$container_id" ]; then
                    docker stop "$container_id"
                    echo -e "${GREEN}Container stopped${NC}"
                fi
                ;;
            2)
                echo -e "${YELLOW}Enter container ID or name to remove:${NC}"
                read -r container_id
                if [ -n "$container_id" ]; then
                    docker rm "$container_id"
                    echo -e "${GREEN}Container removed${NC}"
                fi
                ;;
            3)
                echo -e "${YELLOW}Stopping all containers...${NC}"
                docker stop $(docker ps -q) 2>/dev/null
                echo -e "${GREEN}All containers stopped${NC}"
                ;;
            4)
                echo -e "${YELLOW}Removing all stopped containers...${NC}"
                docker container prune -f
                echo -e "${GREEN}Stopped containers removed${NC}"
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo -e "${YELLOW}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

# Function to manage volumes
manage_volumes() {
    while true; do
        clear
        echo -e "${CYAN}Volume Management${NC}"
        echo -e "${YELLOW}============================================${NC}"
        
        # List volumes
        echo -e "${GREEN}Docker Volumes:${NC}"
        docker volume ls --format "table {{.Driver}}\t{{.Name}}"
        
        echo -e "\n${YELLOW}Options:${NC}"
        echo "1. Remove a volume"
        echo "2. Remove all unused volumes"
        echo "3. Inspect a volume"
        echo "0. Back to main menu"
        
        read -r choice
        
        case $choice in
            1)
                echo -e "${YELLOW}Enter volume name to remove:${NC}"
                read -r volume_name
                if [ -n "$volume_name" ]; then
                    docker volume rm "$volume_name"
                    echo -e "${GREEN}Volume removed${NC}"
                fi
                ;;
            2)
                echo -e "${YELLOW}Removing all unused volumes...${NC}"
                docker volume prune -f
                echo -e "${GREEN}Unused volumes removed${NC}"
                ;;
            3)
                echo -e "${YELLOW}Enter volume name to inspect:${NC}"
                read -r volume_name
                if [ -n "$volume_name" ]; then
                    docker volume inspect "$volume_name"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo -e "${YELLOW}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

# Function to manage container logs
manage_container_logs() {
    while true; do
        clear
        echo -e "${CYAN}Container Logs Management${NC}"
        echo -e "${YELLOW}============================================${NC}"
        
        # List running containers
        echo -e "${GREEN}Running Containers:${NC}"
        docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        
        echo -e "\n${GREEN}All Containers (including stopped):${NC}"
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        
        echo -e "\n${YELLOW}Options:${NC}"
        echo "1. View logs for a specific container"
        echo "2. Follow logs for a specific container"
        echo "3. View logs with timestamps"
        echo "4. View logs for last N lines"
        echo "5. View logs for a docker-compose service"
        echo "0. Back to main menu"
        
        read -r choice
        
        case $choice in
            1)
                echo -e "${YELLOW}Enter container ID or name:${NC}"
                read -r container_id
                if [ -n "$container_id" ]; then
                    echo -e "${GREEN}Showing logs for container: $container_id${NC}"
                    echo -e "${YELLOW}Press Ctrl+C to exit logs view${NC}"
                    docker logs "$container_id"
                fi
                ;;
            2)
                echo -e "${YELLOW}Enter container ID or name:${NC}"
                read -r container_id
                if [ -n "$container_id" ]; then
                    echo -e "${GREEN}Following logs for container: $container_id${NC}"
                    echo -e "${YELLOW}Press Ctrl+C to stop following logs${NC}"
                    docker logs -f "$container_id"
                fi
                ;;
            3)
                echo -e "${YELLOW}Enter container ID or name:${NC}"
                read -r container_id
                if [ -n "$container_id" ]; then
                    echo -e "${GREEN}Showing logs with timestamps for container: $container_id${NC}"
                    echo -e "${YELLOW}Press Ctrl+C to exit logs view${NC}"
                    docker logs -t "$container_id"
                fi
                ;;
            4)
                echo -e "${YELLOW}Enter container ID or name:${NC}"
                read -r container_id
                echo -e "${YELLOW}Enter number of lines to show (default: 50):${NC}"
                read -r lines
                if [ -z "$lines" ]; then
                    lines=50
                fi
                if [ -n "$container_id" ]; then
                    echo -e "${GREEN}Showing last $lines lines for container: $container_id${NC}"
                    docker logs --tail "$lines" "$container_id"
                fi
                ;;
            5)
                if find_compose_files; then
                    echo -e "${GREEN}Selected: $selected_file${NC}"
                    echo -e "${YELLOW}Enter service name:${NC}"
                    read -r service_name
                    if [ -n "$service_name" ]; then
                        echo -e "${GREEN}Showing logs for service: $service_name${NC}"
                        echo -e "${YELLOW}Press Ctrl+C to exit logs view${NC}"
                        docker-compose -f "$selected_file" logs "$service_name"
                    fi
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo -e "${YELLOW}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

# Function to get project name from docker-compose file
get_project_name() {
    local compose_file="$1"
    local dir_name=$(dirname "$compose_file" | xargs basename)
    
    # Try to extract project name from docker-compose file
    if command -v yq &> /dev/null; then
        local project_name=$(yq e '.name // ""' "$compose_file" 2>/dev/null)
        if [ -n "$project_name" ]; then
            echo "$project_name"
            return
        fi
    fi
    
    # Default to directory name
    echo "${dir_name//[^a-zA-Z0-9_-]/_}"
}

# Function to list containers that will be removed
list_containers_to_remove() {
    local containers=$(docker ps -aq 2>/dev/null)
    if [ -n "$containers" ]; then
        echo -e "${YELLOW}Containers to be removed:${NC}"
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo
    else
        echo -e "${GREEN}No containers to remove${NC}"
    fi
}

# Function to list images that will be removed
list_images_to_remove() {
    local images=$(docker images -q 2>/dev/null)
    if [ -n "$images" ]; then
        echo -e "${YELLOW}Images to be removed:${NC}"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
        echo
    else
        echo -e "${GREEN}No images to remove${NC}"
    fi
}

# Function to list volumes that will be removed
list_volumes_to_remove() {
    local volumes=$(docker volume ls -q 2>/dev/null)
    if [ -n "$volumes" ]; then
        echo -e "${YELLOW}Volumes to be removed:${NC}"
        docker volume ls --format "table {{.Driver}}\t{{.Name}}"
        echo
    else
        echo -e "${GREEN}No volumes to remove${NC}"
    fi
}

# Function to find docker stacks
find_docker_stacks() {
    echo -e "${YELLOW}Searching for docker stacks...${NC}"
    
    # Get all docker stacks using docker compose ls
    local stacks=()
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            stacks+=("$line")
        fi
    done < <(docker compose ls -q 2>/dev/null)
    
    if [ ${#stacks[@]} -eq 0 ]; then
        echo -e "${RED}No docker stacks found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Found docker stacks:${NC}"
    for i in "${!stacks[@]}"; do
        echo -e "${BLUE}$((i+1)).${NC} ${stacks[$i]}"
    done
    
    echo -e "${YELLOW}Select a stack (1-${#stacks[@]}) or 0 to cancel:${NC}"
    read -r selection
    
    if [[ "$selection" == "0" ]]; then
        return 1
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#stacks[@]}" ]; then
        selected_stack="${stacks[$((selection-1))]}"
        return 0
    else
        echo -e "${RED}Invalid selection${NC}"
        return 1
    fi
}

# Function to list stack-specific resources
list_stack_resources() {
    local stack_name="$1"
    
    echo -e "${YELLOW}Stack: $stack_name${NC}"
    echo
    
    # List stack services (using docker compose)
    local stack_services=$(docker compose -p "$stack_name" ps --services 2>/dev/null)
    if [ -n "$stack_services" ]; then
        echo -e "${YELLOW}Stack services to be removed:${NC}"
        docker compose -p "$stack_name" ps --format "table {{.ID}}\t{{.Service}}\t{{.Image}}\t{{.Status}}"
        echo
    else
        echo -e "${GREEN}No stack services found${NC}"
    fi
    
    # List stack containers (filter by project name)
    local stack_containers=$(docker ps -a --filter "label=com.docker.compose.project=$stack_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$stack_containers" ]; then
        echo -e "${YELLOW}Stack containers to be removed:${NC}"
        docker ps -a --filter "label=com.docker.compose.project=$stack_name" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo
    else
        echo -e "${GREEN}No stack containers found${NC}"
    fi
    
    # List stack networks
    local stack_networks=$(docker network ls --filter "label=com.docker.compose.project=$stack_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$stack_networks" ]; then
        echo -e "${YELLOW}Stack networks to be removed:${NC}"
        docker network ls --filter "label=com.docker.compose.project=$stack_name" --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}"
        echo
    else
        echo -e "${GREEN}No stack networks found${NC}"
    fi
    
    # List stack configs
    local stack_configs=$(docker config ls --filter "label=com.docker.compose.project=$stack_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$stack_configs" ]; then
        echo -e "${YELLOW}Stack configs to be removed:${NC}"
        docker config ls --filter "label=com.docker.compose.project=$stack_name" --format "table {{.ID}}\t{{.Name}}\t{{.CreatedAt}}"
        echo
    else
        echo -e "${GREEN}No stack configs found${NC}"
    fi
    
    # List stack secrets
    local stack_secrets=$(docker secret ls --filter "label=com.docker.compose.project=$stack_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$stack_secrets" ]; then
        echo -e "${YELLOW}Stack secrets to be removed:${NC}"
        docker secret ls --filter "label=com.docker.compose.project=$stack_name" --format "table {{.ID}}\t{{.Name}}\t{{.CreatedAt}}"
        echo
    else
        echo -e "${GREEN}No stack secrets found${NC}"
    fi
    
    # List stack volumes (if any are specifically created for this stack)
    local stack_volumes=$(docker volume ls -q | grep "^${stack_name}_" 2>/dev/null)
    if [ -n "$stack_volumes" ]; then
        echo -e "${YELLOW}Stack volumes to be removed:${NC}"
        docker volume ls | grep "^${stack_name}_"
        echo
    else
        echo -e "${GREEN}No stack volumes found${NC}"
    fi
}

# Function to remove stack resources
remove_stack_resources() {
    local stack_name="$1"
    
    echo -e "${YELLOW}Removing stack: $stack_name${NC}"
    
    # Remove the stack using docker compose down
    echo -e "${YELLOW}Stopping and removing stack services...${NC}"
    docker compose -p "$stack_name" down
    
    # Remove volumes if they exist
    echo -e "${YELLOW}Removing stack volumes...${NC}"
    docker compose -p "$stack_name" down -v
    
    # Remove images if they exist
    echo -e "${YELLOW}Removing stack images...${NC}"
    docker compose -p "$stack_name" down --rmi all
    
    # Remove any remaining containers that might be stuck
    local remaining_containers=$(docker ps -a --filter "label=com.docker.compose.project=$stack_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$remaining_containers" ]; then
        echo -e "${YELLOW}Removing remaining stack containers...${NC}"
        docker rm -f $remaining_containers 2>/dev/null
    fi
    
    # Remove any stack-specific volumes
    local stack_volumes=$(docker volume ls -q | grep "^${stack_name}_" 2>/dev/null)
    if [ -n "$stack_volumes" ]; then
        echo -e "${YELLOW}Removing stack volumes...${NC}"
        docker volume rm -f $stack_volumes 2>/dev/null
    fi
    
    echo -e "${GREEN}Stack resources removed${NC}"
}

# Function to list project-specific resources
list_project_resources() {
    local project_name="$1"
    local compose_file="$2"
    
    echo -e "${YELLOW}Project: $project_name${NC}"
    echo -e "${YELLOW}Compose file: $compose_file${NC}"
    echo
    
    # List project containers
    local project_containers=$(docker ps -a --filter "label=com.docker.compose.project=$project_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$project_containers" ]; then
        echo -e "${YELLOW}Project containers to be removed:${NC}"
        docker ps -a --filter "label=com.docker.compose.project=$project_name" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo
    else
        echo -e "${GREEN}No project containers found${NC}"
    fi
    
    # List project volumes
    local project_volumes=$(docker volume ls -q | grep "^${project_name}_" 2>/dev/null)
    if [ -n "$project_volumes" ]; then
        echo -e "${YELLOW}Project volumes to be removed:${NC}"
        docker volume ls | grep "^${project_name}_"
        echo
    else
        echo -e "${GREEN}No project volumes found${NC}"
    fi
    
    # List project networks
    local project_networks=$(docker network ls --filter "label=com.docker.compose.project=$project_name" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$project_networks" ]; then
        echo -e "${YELLOW}Project networks to be removed:${NC}"
        docker network ls --filter "label=com.docker.compose.project=$project_name" --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}"
        echo
    else
        echo -e "${GREEN}No project networks found${NC}"
    fi
}

# Function to list unused resources
list_unused_resources() {
    echo -e "${YELLOW}Unused resources to be removed:${NC}"
    echo
    
    # List stopped containers
    local stopped_containers=$(docker ps -a --filter "status=exited" --filter "status=created" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$stopped_containers" ]; then
        echo -e "${YELLOW}Stopped containers to be removed:${NC}"
        docker ps -a --filter "status=exited" --filter "status=created" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo
    else
        echo -e "${GREEN}No stopped containers to remove${NC}"
    fi
    
    # List unused images (dangling and unused)
    local unused_images=$(docker images -f "dangling=true" -q 2>/dev/null)
    if [ -n "$unused_images" ]; then
        echo -e "${YELLOW}Unused images to be removed:${NC}"
        docker images -f "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
        echo
    else
        echo -e "${GREEN}No unused images to remove${NC}"
    fi
    
    # List unused volumes (those not attached to any container)
    local unused_volumes=$(docker volume ls -q 2>/dev/null)
    if [ -n "$unused_volumes" ]; then
        echo -e "${YELLOW}Unused volumes to be removed:${NC}"
        docker volume ls --format "table {{.Driver}}\t{{.Name}}"
        echo
    else
        echo -e "${GREEN}No unused volumes to remove${NC}"
    fi
    
    # List unused networks (custom networks not used by any container)
    local unused_networks=$(docker network ls --filter "type=custom" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$unused_networks" ]; then
        echo -e "${YELLOW}Unused networks to be removed:${NC}"
        docker network ls --filter "type=custom" --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}"
        echo
    else
        echo -e "${GREEN}No unused networks to remove${NC}"
    fi
}

# Function to clean resources
clean_resources() {
    while true; do
        clear
        echo -e "${CYAN}Clean Docker Resources${NC}"
        echo -e "${YELLOW}============================================${NC}"
        echo -e "${RED}WARNING: These operations cannot be undone!${NC}"
        echo
        echo "1. Remove all resources (containers, images, volumes, networks)"
        echo "2. Remove resources related to a docker stack"
        echo "3. Remove unused resources (dangling images, stopped containers, unused volumes/networks)"
        echo "4. Force system cleanup (docker system prune -a --volumes -f)"
        echo "0. Back to main menu"
        
        read -r choice
        
        case $choice in
            1)
                echo -e "${RED}This will remove ALL Docker resources.${NC}"
                echo
                list_containers_to_remove
                list_images_to_remove
                list_volumes_to_remove
                echo -e "${RED}Are you sure you want to remove ALL these resources? (yes/no):${NC}"
                read -r confirm
                if [ "$confirm" == "yes" ]; then
                    echo -e "${YELLOW}Stopping all containers...${NC}"
                    docker stop $(docker ps -q) 2>/dev/null
                    
                    echo -e "${YELLOW}Removing all containers...${NC}"
                    docker rm -f $(docker ps -aq) 2>/dev/null
                    
                    echo -e "${YELLOW}Removing all images...${NC}"
                    docker rmi -f $(docker images -q) 2>/dev/null
                    
                    echo -e "${YELLOW}Removing all volumes...${NC}"
                    docker volume rm -f $(docker volume ls -q) 2>/dev/null
                    
                    echo -e "${YELLOW}Removing all networks...${NC}"
                    docker network prune -f
                    
                    echo -e "${GREEN}All resources removed${NC}"
                fi
                ;;
            2)
                if find_docker_stacks; then
                    echo -e "${GREEN}Selected stack: $selected_stack${NC}"
                    
                    echo -e "${RED}This will remove all resources for this stack.${NC}"
                    echo
                    list_stack_resources "$selected_stack"
                    echo -e "${RED}Are you sure you want to remove all these stack resources? (yes/no):${NC}"
                    read -r confirm
                    
                    if [ "$confirm" == "yes" ]; then
                        remove_stack_resources "$selected_stack"
                    fi
                fi
                ;;
            3)
                echo -e "${RED}This will remove unused Docker resources.${NC}"
                echo
                list_unused_resources
                echo -e "${RED}Are you sure you want to remove these unused resources? (yes/no):${NC}"
                read -r confirm
                
                if [ "$confirm" == "yes" ]; then
                    echo -e "${YELLOW}Removing unused resources...${NC}"
                    
                    echo -e "${YELLOW}Removing stopped containers...${NC}"
                    docker container prune -f
                    
                    echo -e "${YELLOW}Removing unused images...${NC}"
                    docker image prune -a -f
                    
                    echo -e "${YELLOW}Removing unused volumes...${NC}"
                    docker volume prune -f
                    
                    echo -e "${YELLOW}Removing unused networks...${NC}"
                    docker network prune -f
                    
                    echo -e "${GREEN}Unused resources removed${NC}"
                fi
                ;;
            4)
                echo -e "${RED}FORCE SYSTEM CLEANUP - This will remove:${NC}"
                echo -e "${YELLOW}- All stopped containers${NC}"
                echo -e "${YELLOW}- All networks not used by at least one container${NC}"
                echo -e "${YELLOW}- All images without at least one container${NC}"
                echo -e "${YELLOW}- All build cache${NC}"
                echo -e "${YELLOW}- All anonymous volumes not used by at least one container${NC}"
                echo
                echo -e "${YELLOW}Resources that will be removed:${NC}"
                echo
                list_unused_resources
                echo -e "${RED}This is equivalent to: docker system prune -a --volumes -f${NC}"
                echo -e "${RED}Are you absolutely sure? (yes/no):${NC}"
                read -r confirm
                
                if [ "$confirm" == "yes" ]; then
                    echo -e "${YELLOW}Performing force system cleanup...${NC}"
                    docker system prune -a --volumes -f
                    echo -e "${GREEN}Force system cleanup completed${NC}"
                    
                    # Show disk space reclaimed
                    echo
                    echo -e "${CYAN}Current Docker disk usage:${NC}"
                    docker system df
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo -e "${YELLOW}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

# Main loop
main() {
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
    
    while true; do
        show_main_menu
        echo -e "${YELLOW}Select an option (1-7):${NC}"
        read -r option
        
        case $option in
            1)
                run_docker_compose
                ;;
            2)
                list_images
                ;;
            3)
                manage_containers
                ;;
            4)
                manage_volumes
                ;;
            5)
                clean_resources
                ;;
            6)
                manage_container_logs
                ;;
            7)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run the main function
main 