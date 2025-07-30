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
    echo -e "${GREEN}6.${NC} Exit"
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

# Function to clean resources
clean_resources() {
    while true; do
        clear
        echo -e "${CYAN}Clean Docker Resources${NC}"
        echo -e "${YELLOW}============================================${NC}"
        echo -e "${RED}WARNING: These operations cannot be undone!${NC}"
        echo
        echo "1. Remove all resources (containers, images, volumes, networks)"
        echo "2. Remove resources related to a docker-compose project"
        echo "3. Remove unused resources (dangling images, stopped containers, unused volumes/networks)"
        echo "4. Force system cleanup (docker system prune -a --volumes -f)"
        echo "0. Back to main menu"
        
        read -r choice
        
        case $choice in
            1)
                echo -e "${RED}This will remove ALL Docker resources. Are you sure? (yes/no):${NC}"
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
                if find_compose_files; then
                    echo -e "${GREEN}Selected: $selected_file${NC}"
                    
                    # Get project name
                    project_name=$(get_project_name "$selected_file")
                    echo -e "${YELLOW}Project name: $project_name${NC}"
                    
                    echo -e "${RED}This will remove all resources for this project. Are you sure? (yes/no):${NC}"
                    read -r confirm
                    
                    if [ "$confirm" == "yes" ]; then
                        echo -e "${YELLOW}Stopping project...${NC}"
                        docker-compose -f "$selected_file" -p "$project_name" down
                        
                        echo -e "${YELLOW}Removing project volumes...${NC}"
                        docker-compose -f "$selected_file" -p "$project_name" down -v
                        
                        echo -e "${YELLOW}Removing project images...${NC}"
                        docker-compose -f "$selected_file" -p "$project_name" down --rmi all
                        
                        # Remove any remaining project-specific volumes
                        docker volume ls -q | grep "^${project_name}_" | xargs -r docker volume rm -f 2>/dev/null
                        
                        echo -e "${GREEN}Project resources removed${NC}"
                    fi
                fi
                ;;
            3)
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
                ;;
            4)
                echo -e "${RED}FORCE SYSTEM CLEANUP - This will remove:${NC}"
                echo -e "${YELLOW}- All stopped containers${NC}"
                echo -e "${YELLOW}- All networks not used by at least one container${NC}"
                echo -e "${YELLOW}- All images without at least one container${NC}"
                echo -e "${YELLOW}- All build cache${NC}"
                echo -e "${YELLOW}- All anonymous volumes not used by at least one container${NC}"
                echo
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
        echo -e "${YELLOW}Select an option (1-6):${NC}"
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