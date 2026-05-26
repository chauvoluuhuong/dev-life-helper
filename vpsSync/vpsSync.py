#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import getpass
import shlex

# Config directory and paths in user's home directory to keep it git-ignored and secure
CONFIG_DIR = os.path.expanduser("~/.vps-sync")
CONNECTIONS_FILE = os.path.join(CONFIG_DIR, "connections.json")
PROJECTS_FILE = os.path.join(CONFIG_DIR, "projects.json")

# Text styles for premium CLI look
BOLD = "\033[1m"
GREEN = "\033[32m"
BLUE = "\033[34m"
YELLOW = "\033[33m"
RED = "\033[31m"
RESET = "\033[0m"

def print_header(title):
    print(f"\n{BOLD}{BLUE}==================================================")
    print(f"  {title.upper()}")
    print(f"=================================================={RESET}")

def init_config():
    """Create the global configurations folder and files with secure permissions (chmod 600)"""
    os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
    for path in [CONNECTIONS_FILE, PROJECTS_FILE]:
        if not os.path.exists(path):
            with open(path, 'w') as f:
                json.dump({}, f)
        os.chmod(path, 0o600)

def load_json(filepath):
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def save_json(filepath, data):
    try:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=4)
        os.chmod(filepath, 0o600)
    except Exception as e:
        print(f"{RED}Error saving configuration to {filepath}: {e}{RESET}")

def get_connections():
    return load_json(CONNECTIONS_FILE)

def save_connection(name, connection_info):
    connections = get_connections()
    connections[name] = connection_info
    save_json(CONNECTIONS_FILE, connections)

def get_projects():
    data = load_json(PROJECTS_FILE)
    migrated = False
    for path, val in list(data.items()):
        if isinstance(val, dict) and "connection" in val:
            # Migrate old single-connection format to multi-connection dict on the fly
            conn_name = val["connection"]
            data[path] = {
                conn_name: {
                    "destination": val["destination"],
                    "ignores": val["ignores"]
                }
            }
            migrated = True
    if migrated:
        save_json(PROJECTS_FILE, data)
    return data

def save_project_target(local_path, connection_name, destination, ignores):
    projects = get_projects()
    if local_path not in projects or not isinstance(projects[local_path], dict) or "connection" in projects[local_path]:
        projects[local_path] = {}
    projects[local_path][connection_name] = {
        "destination": destination,
        "ignores": ignores
    }
    save_json(PROJECTS_FILE, projects)

def select_or_create_connection():
    connections = get_connections()
    
    while True:
        print_header("VPS Connection Setup")
        if connections:
            print("Select an existing connection profile or create a new one:")
            profile_names = list(connections.keys())
            for idx, name in enumerate(profile_names, 1):
                conn = connections[name]
                print(f"  [{idx}] {BOLD}{name}{RESET} ({conn['username']}@{conn['host']}:{conn['port']})")
            print(f"  [{len(profile_names) + 1}] Create a new VPS connection profile...")
            print(f"  [q] Quit")
            
            choice = input(f"\nEnter choice (1-{len(profile_names) + 1}, q): ").strip()
            if choice.lower() == 'q':
                print(f"{YELLOW}Operation cancelled by user.{RESET}")
                sys.exit(0)
            
            if choice.isdigit():
                val = int(choice)
                if 1 <= val <= len(profile_names):
                    selected_name = profile_names[val - 1]
                    print(f"{GREEN}Selected profile: {selected_name}{RESET}")
                    return selected_name, connections[selected_name]
                elif val == len(profile_names) + 1:
                    name, info = create_new_connection()
                    return name, info
            print(f"{RED}Invalid selection. Please try again.{RESET}")
        else:
            print("No saved connection profiles found. Let's create a new one!")
            name, info = create_new_connection()
            return name, info

def create_new_connection():
    print_header("Create New VPS Connection")
    connections = get_connections()
    
    # Get a unique profile name
    while True:
        name = input("Enter a Profile Name (e.g. staging-server): ").strip()
        if not name:
            print(f"{RED}Profile name cannot be empty.{RESET}")
            continue
        if name in connections:
            overwrite = input(f"{YELLOW}A profile named '{name}' already exists. Overwrite? (y/N): {RESET}").strip().lower()
            if overwrite != 'y':
                continue
        break

    host = input("Enter VPS IP or Hostname: ").strip()
    while not host:
        host = input(f"{RED}Host cannot be empty. Enter VPS IP or Hostname: {RESET}").strip()

    port_input = input("Enter SSH Port (default: 22): ").strip()
    port = 22
    if port_input:
        while not port_input.isdigit():
            port_input = input(f"{RED}Port must be a number. Enter SSH Port: {RESET}").strip()
        port = int(port_input)

    username = input("Enter SSH Username (default: root): ").strip()
    if not username:
        username = "root"

    # Select authentication method
    print("\nAuthentication Methods:")
    print("  [1] Username & Password")
    print("  [2] SSH Private Key File")
    
    auth_choice = ""
    while auth_choice not in ['1', '2']:
        auth_choice = input("Select authentication method (1 or 2): ").strip()
        
    auth_info = {}
    if auth_choice == '1':
        password = getpass.getpass("Enter SSH Password (will be masked): ")
        auth_info = {
            "type": "password",
            "password": password
        }
    else:
        key_path = input("Enter absolute path to SSH Private Key (default: ~/.ssh/id_rsa): ").strip()
        if not key_path:
            key_path = os.path.expanduser("~/.ssh/id_rsa")
        else:
            key_path = os.path.expanduser(key_path)
        
        while not os.path.exists(key_path):
            print(f"{YELLOW}Warning: SSH Key file not found at {key_path}{RESET}")
            retry = input("Re-enter key path? (y/N): ").strip().lower()
            if retry == 'y':
                key_path = input("Enter SSH Private Key path: ").strip()
                key_path = os.path.expanduser(key_path)
            else:
                break
                
        auth_info = {
            "type": "key",
            "key_path": key_path
        }

    connection_info = {
        "host": host,
        "port": port,
        "username": username,
        "auth": auth_info
    }
    
    save_connection(name, connection_info)
    print(f"{GREEN}Connection profile '{name}' successfully created and saved secure.{RESET}")
    return name, connection_info

def select_ignores_interactive():
    local_dir = os.getcwd()
    print_header("Configure Ignored Folders/Files")
    print(f"Scanning directory: {BOLD}{local_dir}{RESET}")
    
    items = sorted(os.listdir(local_dir))
    if not items:
        print("The current directory is empty. Nothing to ignore.")
        return []
        
    # Sort with directories first
    dirs = [item for item in items if os.path.isdir(os.path.join(local_dir, item))]
    files = [item for item in items if os.path.isfile(os.path.join(local_dir, item))]
    all_items = dirs + files

    recommended = ['.git', 'node_modules', '.DS_Store', 'dist', 'build', '.env', '.antigravitycli']
    defaults_to_ignore = []

    print("\nSelect the files/folders you want to IGNORE. They will NOT be copied to the VPS.")
    print(f"Recommended exclusions are marked with {BOLD}{YELLOW}*{RESET} and pre-selected as defaults.\n")

    for idx, item in enumerate(all_items, 1):
        is_dir = os.path.isdir(os.path.join(local_dir, item))
        suffix = "/" if is_dir else ""
        rec_str = ""
        if item in recommended:
            rec_str = f" {BOLD}{YELLOW}* [RECOMMENDED TO IGNORE]{RESET}"
            defaults_to_ignore.append(item)
        print(f"  [{idx}] {item}{suffix}{rec_str}")

    print(f"\n- To ignore the recommended defaults ({', '.join(defaults_to_ignore)}), simply press {BOLD}Enter{RESET}.")
    print(f"- To ignore custom items, enter their numbers separated by commas (e.g. {BOLD}1,3,5{RESET}).")
    print(f"- To ignore NOTHING (copy absolutely everything), type {BOLD}none{RESET}.")
    
    user_input = input("\nEnter choice: ").strip()
    
    if not user_input:
        print(f"{GREEN}Using recommended defaults: {', '.join(defaults_to_ignore)}{RESET}")
        return defaults_to_ignore
        
    if user_input.lower() == 'none':
        print(f"{GREEN}Copying all files and folders (no exclusions).{RESET}")
        return []

    ignores = []
    parts = [p.strip() for p in user_input.split(',')]
    for part in parts:
        if part.isdigit():
            val = int(part)
            if 1 <= val <= len(all_items):
                ignores.append(all_items[val - 1])
            else:
                print(f"{YELLOW}Warning: Number {val} is out of range, skipped.{RESET}")
        else:
            if part:
                print(f"{YELLOW}Warning: '{part}' is not a valid number, skipped.{RESET}")

    print(f"{GREEN}Selected exclusions: {', '.join(ignores) if ignores else 'None'}{RESET}")
    return ignores

def ensure_remote_dir(connection_info, destination):
    """Pre-create destination directory structure recursively on the remote VPS via SSH"""
    host = connection_info['host']
    port = connection_info['port']
    username = connection_info['username']
    auth = connection_info['auth']
    
    print(f"\n{BLUE}Ensuring remote destination directory exists...{RESET}")
    
    if auth['type'] == 'key':
        ssh_key_path = auth['key_path']
        cmd = [
            "ssh", "-p", str(port), "-i", ssh_key_path, "-o", "StrictHostKeyChecking=no",
            f"{username}@{host}", f"mkdir -p {destination}"
        ]
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            print(f"{GREEN}Remote directory verified/created successfully.{RESET}")
        except subprocess.CalledProcessError as e:
            print(f"{YELLOW}Warning: Pre-creating remote directory failed: {e}. Syncing may fail if parent paths do not exist.{RESET}")
    elif auth['type'] == 'password':
        password = auth['password']
        cmd = [
            "ssh", "-p", str(port), "-o", "StrictHostKeyChecking=no",
            f"{username}@{host}", f"mkdir -p {destination}"
        ]
        escaped_cmd = shlex.join(cmd)
        
        env = os.environ.copy()
        env["SYNC_PASSWORD"] = password
        
        expect_script = f"""
        set timeout 15
        set pass $env(SYNC_PASSWORD)
        spawn bash -c {{{escaped_cmd}}}
        expect {{
            "Are you sure you want to continue connecting" {{
                send "yes\\r"
                exp_continue
            }}
            "password:" {{
                send "$pass\\r"
                exp_continue
            }}
            eof
        }}
        """
        try:
            proc = subprocess.Popen(
                ["/usr/bin/expect"],
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                text=True,
                env=env
            )
            proc.communicate(input=expect_script)
            if proc.returncode == 0:
                print(f"{GREEN}Remote directory verified/created successfully.{RESET}")
            else:
                print(f"{YELLOW}Warning: Pre-creating remote directory returned exit code {proc.returncode}. Syncing may fail if parent paths do not exist.{RESET}")
        except Exception as e:
            print(f"{YELLOW}Warning: Error verifying remote directory: {e}. Attempting sync anyway...{RESET}")

def run_sync(connection_info, ignores, destination):
    local_dir = os.getcwd()
    host = connection_info['host']
    port = connection_info['port']
    username = connection_info['username']
    auth = connection_info['auth']

    print_header("Sync Summary")
    print(f"  Local Source  : {BOLD}{local_dir}{RESET}")
    print(f"  Remote Dest   : {BOLD}{username}@{host}:{destination}{RESET}")
    print(f"  SSH Port      : {port}")
    print(f"  Ignored items : {', '.join(ignores) if ignores else 'None'}")
    auth_desc = "Password" if auth['type'] == 'password' else f"SSH Key ({auth['key_path']})"
    print(f"  Auth Method   : {auth_desc}")
    
    # Pre-create the directory on the VPS recursively
    ensure_remote_dir(connection_info, destination)
    
    dry_run_input = input(f"\nDo you want to run a Dry Run first? (Y/n): ").strip().lower()
    dry_run = dry_run_input != 'n'

    # Build the rsync command
    rsync_cmd = ["rsync", "-avz"]
    
    # Add exclude arguments
    for item in ignores:
        rsync_cmd.append(f"--exclude={item}")
        
    if dry_run:
        rsync_cmd.append("--dry-run")
        print(f"\n{YELLOW}--- STARTING DRY RUN (No changes will be made) ---{RESET}\n")
    else:
        print(f"\n{GREEN}--- STARTING RECURSIVE COPY TO VPS ---{RESET}\n")

    # Handle SSH Key auth vs Password auth
    if auth['type'] == 'key':
        ssh_key_path = auth['key_path']
        rsync_cmd.extend([
            "-e", 
            f"ssh -p {port} -i {sh_key_path} -o StrictHostKeyChecking=no", 
            f"{local_dir}/", 
            f"{username}@{host}:{destination}"
        ])
        
        try:
            subprocess.run(rsync_cmd, stdout=sys.stdout, stderr=sys.stderr, check=True)
            if dry_run:
                print(f"\n{GREEN}Dry run completed successfully! Review the listed changes above.{RESET}")
                run_real_sync = input("Do you want to perform the actual copy now? (y/N): ").strip().lower()
                if run_real_sync == 'y':
                    # Recursive call but without dry run
                    # Temporarily mutate the command to remove dry run
                    rsync_cmd.remove("--dry-run")
                    print(f"\n{GREEN}--- STARTING RECURSIVE COPY TO VPS ---{RESET}\n")
                    subprocess.run(rsync_cmd, stdout=sys.stdout, stderr=sys.stderr, check=True)
                    print(f"\n{GREEN}Sync successfully completed!{RESET}")
            else:
                print(f"\n{GREEN}Sync successfully completed!{RESET}")
        except subprocess.CalledProcessError as e:
            print(f"\n{RED}Error: Sync command failed with exit code {e.returncode}{RESET}")
            sys.exit(1)
            
    elif auth['type'] == 'password':
        password = auth['password']
        rsync_cmd.extend([
            "-e", 
            f"ssh -p {port} -o StrictHostKeyChecking=no", 
            f"{local_dir}/", 
            f"{username}@{host}:{destination}"
        ])
        
        # Escape command properly using shell join
        escaped_cmd = shlex.join(rsync_cmd)
        
        # Prepare environment with the password to pass securely to expect without escaping issues
        env = os.environ.copy()
        env["SYNC_PASSWORD"] = password

        # Use macOS expect to safely feed password interactively
        expect_script = f"""
        set timeout -1
        set pass $env(SYNC_PASSWORD)
        spawn bash -c {{{escaped_cmd}}}
        expect {{
            "Are you sure you want to continue connecting" {{
                send "yes\\r"
                exp_continue
            }}
            "password:" {{
                send "$pass\\r"
                exp_continue
            }}
            eof
        }}
        """
        
        try:
            proc = subprocess.Popen(
                ["/usr/bin/expect"],
                stdin=subprocess.PIPE,
                stdout=sys.stdout,
                stderr=sys.stderr,
                text=True,
                env=env
            )
            proc.communicate(input=expect_script)
            
            if proc.returncode == 0:
                if dry_run:
                    print(f"\n{GREEN}Dry run completed successfully! Review the listed changes above.{RESET}")
                    run_real_sync = input("Do you want to perform the actual copy now? (y/N): ").strip().lower()
                    if run_real_sync == 'y':
                        # Run actual copy
                        rsync_cmd.remove("--dry-run")
                        escaped_cmd_real = shlex.join(rsync_cmd)
                        
                        # Prepare environment with the password
                        env_real = os.environ.copy()
                        env_real["SYNC_PASSWORD"] = password

                        expect_script_real = f"""
                        set timeout -1
                        set pass $env(SYNC_PASSWORD)
                        spawn bash -c {{{escaped_cmd_real}}}
                        expect {{
                            "Are you sure you want to continue connecting" {{
                                send "yes\\r"
                                exp_continue
                            }}
                            "password:" {{
                                send "$pass\\r"
                                exp_continue
                            }}
                            eof
                        }}
                        """
                        print(f"\n{GREEN}--- STARTING RECURSIVE COPY TO VPS ---{RESET}\n")
                        proc_real = subprocess.Popen(
                            ["/usr/bin/expect"],
                            stdin=subprocess.PIPE,
                            stdout=sys.stdout,
                            stderr=sys.stderr,
                            text=True,
                            env=env_real
                        )
                        proc_real.communicate(input=expect_script_real)
                        if proc_real.returncode == 0:
                            print(f"\n{GREEN}Sync successfully completed!{RESET}")
                        else:
                            print(f"\n{RED}Error: Sync command failed.{RESET}")
                            sys.exit(1)
                else:
                    print(f"\n{GREEN}Sync successfully completed!{RESET}")
            else:
                print(f"\n{RED}Error: Sync command failed.{RESET}")
                sys.exit(1)
        except Exception as e:
            print(f"\n{RED}Error executing expect script: {e}{RESET}")
            sys.exit(1)

def main():
    try:
        init_config()
        local_dir = os.getcwd()
        projects = get_projects()
        connections = get_connections()
        
        connection_name = None
        connection_info = None
        ignores = None
        destination = None
        
        # Check if saved targets exist for this folder
        if local_dir in projects and projects[local_dir]:
            folder_targets = projects[local_dir]
            
            # Filter out targets whose connection profiles have been deleted
            active_targets = [t for t in folder_targets.keys() if t in connections]
            
            if active_targets:
                print_header("Saved Sync Targets Found")
                print(f"Folder: {BOLD}{local_dir}{RESET}")
                print("Select a saved VPS sync target to use, or set up a new one:")
                
                for idx, t_name in enumerate(active_targets, 1):
                    t_info = folder_targets[t_name]
                    conn = connections[t_name]
                    print(f"  [{idx}] {BOLD}{t_name}{RESET} (Dest: {t_info['destination']}, Server: {conn['username']}@{conn['host']})")
                    
                new_target_idx = len(active_targets) + 1
                print(f"  [{new_target_idx}] Sync to a new connection profile...")
                print(f"  [q] Quit")
                
                choice = input(f"\nSelect choice (1-{new_target_idx}, q) [default: 1]: ").strip()
                if not choice:
                    choice = "1"
                
                if choice.lower() == 'q':
                    print(f"{YELLOW}Operation cancelled by user.{RESET}")
                    sys.exit(0)
                    
                if choice.isdigit():
                    val = int(choice)
                    if 1 <= val <= len(active_targets):
                        connection_name = active_targets[val - 1]
                        connection_info = connections[connection_name]
                        target_config = folder_targets[connection_name]
                        destination = target_config["destination"]
                        ignores = target_config["ignores"]
                        print(f"{GREEN}Using saved settings for target: {connection_name}{RESET}")
                    elif val == new_target_idx:
                        pass # Proceed to new connection setup flow
                    else:
                        print(f"{RED}Invalid choice. Proceeding with new setup flow...{RESET}")
                else:
                    print(f"{RED}Invalid choice. Proceeding with new setup flow...{RESET}")
        
        # If no saved config, user chose a new sync target, or invalid option chosen
        if not connection_info:
            connection_name, connection_info = select_or_create_connection()
            
            # If the chosen connection already has saved settings for this folder, ask to reuse or overwrite
            has_existing = (local_dir in projects and 
                            isinstance(projects[local_dir], dict) and 
                            connection_name in projects[local_dir])
                            
            if has_existing:
                existing_cfg = projects[local_dir][connection_name]
                print_header(f"Saved Config Exists for {connection_name}")
                print(f"  - Remote Destination : {existing_cfg['destination']}")
                print(f"  - Ignored items      : {', '.join(existing_cfg['ignores']) if existing_cfg['ignores'] else 'None'}")
                
                reuse = input(f"\nDo you want to reuse these saved settings? (Y/n): ").strip().lower()
                if reuse != 'n':
                    destination = existing_cfg['destination']
                    ignores = existing_cfg['ignores']
                    print(f"{GREEN}Reusing settings for connection profile: {connection_name}{RESET}")
            
            # If no existing config or user chose to reconfigure/overwrite
            if not destination:
                ignores = select_ignores_interactive()
                
                # Destination selection
                print_header("Remote Destination Folder")
                destination = input("Enter the destination directory on the VPS (e.g. /var/www/my-app): ").strip()
                while not destination:
                    destination = input(f"{RED}Destination cannot be empty. Enter VPS directory: {RESET}").strip()
                
                # Save settings specifically for this workspace folder under this connection profile
                save_project_target(local_dir, connection_name, destination, ignores)
                print(f"{GREEN}Saved sync settings for this directory under target '{connection_name}'.{RESET}")

        # Run copy operation
        run_sync(connection_info, ignores, destination)
        
    except KeyboardInterrupt:
        print(f"\n\n{YELLOW}Operation interrupted by user. Exiting gracefully...{RESET}")
        sys.exit(0)

if __name__ == "__main__":
    main()
