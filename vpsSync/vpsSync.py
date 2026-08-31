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

def manage_profile_actions(name):
    while True:
        connections = get_connections()
        if name not in connections:
            print(f"{RED}Profile '{name}' no longer exists.{RESET}")
            return
            
        conn = connections[name]
        print_header(f"Profile: {name}")
        print(f"  - Host     : {conn['host']}")
        print(f"  - Port     : {conn['port']}")
        print(f"  - Username : {conn['username']}")
        auth_type = conn['auth']['type']
        if auth_type == 'password':
            print(f"  - Auth     : Password (masked)")
        else:
            print(f"  - Auth     : SSH Key ({conn['auth']['key_path']})")
            
        print("\nSelect an action:")
        print("  [1] Edit Host")
        print("  [2] Edit Port")
        print("  [3] Edit Username")
        print("  [4] Edit Authentication (Password/Key)")
        print("  [5] Rename Profile")
        print("  [6] Delete Profile")
        print("  [b] Back")
        
        choice = input("\nEnter choice (1-6, b): ").strip()
        if choice.lower() == 'b':
            return
            
        if choice == '1':
            new_host = input(f"Enter new host (current: {conn['host']}): ").strip()
            if new_host:
                conn['host'] = new_host
                save_connection(name, conn)
                print(f"{GREEN}Host updated successfully.{RESET}")
        elif choice == '2':
            new_port = input(f"Enter new port (current: {conn['port']}): ").strip()
            if new_port:
                while not new_port.isdigit():
                    new_port = input(f"{RED}Port must be a number. Enter new port: {RESET}").strip()
                conn['port'] = int(new_port)
                save_connection(name, conn)
                print(f"{GREEN}Port updated successfully.{RESET}")
        elif choice == '3':
            new_user = input(f"Enter new username (current: {conn['username']}): ").strip()
            if new_user:
                conn['username'] = new_user
                save_connection(name, conn)
                print(f"{GREEN}Username updated successfully.{RESET}")
        elif choice == '4':
            print("\nSelect new authentication method:")
            print("  [1] Username & Password")
            print("  [2] SSH Private Key File")
            auth_choice = ""
            while auth_choice not in ['1', '2']:
                auth_choice = input("Select method (1 or 2): ").strip()
            if auth_choice == '1':
                password = getpass.getpass("Enter SSH Password (will be masked): ")
                conn['auth'] = {
                    "type": "password",
                    "password": password
                }
            else:
                key_path = input("Enter SSH Key path (default: ~/.ssh/id_rsa): ").strip()
                if not key_path:
                    key_path = os.path.expanduser("~/.ssh/id_rsa")
                else:
                    key_path = os.path.expanduser(key_path)
                conn['auth'] = {
                    "type": "key",
                    "key_path": key_path
                }
            save_connection(name, conn)
            print(f"{GREEN}Authentication updated successfully.{RESET}")
        elif choice == '5':
            new_name = input(f"Enter new profile name (current: {name}): ").strip()
            if new_name and new_name != name:
                if new_name in connections:
                    print(f"{RED}A profile named '{new_name}' already exists.{RESET}")
                else:
                    connections[new_name] = conn
                    del connections[name]
                    save_json(CONNECTIONS_FILE, connections)
                    print(f"{GREEN}Profile renamed to '{new_name}' successfully.{RESET}")
                    name = new_name
        elif choice == '6':
            confirm = input(f"{RED}Are you sure you want to delete profile '{name}'? (y/N): {RESET}").strip().lower()
            if confirm == 'y':
                del connections[name]
                save_json(CONNECTIONS_FILE, connections)
                print(f"{GREEN}Profile '{name}' deleted successfully.{RESET}")
                return

def manage_connections_menu():
    while True:
        connections = get_connections()
        print_header("Manage Connection Profiles")
        if not connections:
            print("No connection profiles found.")
            input("\nPress Enter to return...")
            return
            
        print("Select a connection profile to edit/delete:")
        profile_names = list(connections.keys())
        for idx, name in enumerate(profile_names, 1):
            conn = connections[name]
            print(f"  [{idx}] {BOLD}{name}{RESET} ({conn['username']}@{conn['host']}:{conn['port']})")
        print(f"  [b] Back")
        
        choice = input(f"\nEnter choice (1-{len(profile_names)}, b): ").strip()
        if choice.lower() == 'b':
            return
            
        if choice.isdigit():
            val = int(choice)
            if 1 <= val <= len(profile_names):
                name = profile_names[val - 1]
                manage_profile_actions(name)
                continue
        print(f"{RED}Invalid selection. Please try again.{RESET}")

def select_or_create_connection():
    while True:
        connections = get_connections()
        print_header("VPS Connection Setup")
        if connections:
            print("Select an existing connection profile or create a new one:")
            profile_names = list(connections.keys())
            for idx, name in enumerate(profile_names, 1):
                conn = connections[name]
                print(f"  [{idx}] {BOLD}{name}{RESET} ({conn['username']}@{conn['host']}:{conn['port']})")
            print(f"  [{len(profile_names) + 1}] Create a new VPS connection profile...")
            print(f"  [m] Manage connection profiles (Edit/Delete)...")
            print(f"  [q] Quit")
            
            choice = input(f"\nEnter choice (1-{len(profile_names) + 1}, m, q): ").strip()
            if choice.lower() == 'q':
                print(f"{YELLOW}Operation cancelled by user.{RESET}")
                sys.exit(0)
            if choice.lower() == 'm':
                manage_connections_menu()
                continue
            
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

RECOMMENDED_PATTERNS = {
    '.git', 'node_modules', '.DS_Store', 'dist', 'build', 
    '.env', '.antigravitycli', '__pycache__', '.venv', 'venv', 
    '.idea', '.vscode', '.pytest_cache', '.next', '.nuxt', 'coverage'
}

def is_recommended_ignore(name):
    basename = os.path.basename(name)
    if basename in RECOMMENDED_PATTERNS:
        return True
    if basename.startswith('.env'):
        return True
    if basename.endswith('.pyc') or basename.endswith('.pyo'):
        return True
    return False

def select_ignores_interactive():
    local_dir = os.getcwd()
    print_header("Configure Ignored Folders/Files")
    print(f"Scanning directory recursively: {BOLD}{local_dir}{RESET}")
    
    try:
        top_items = sorted(os.listdir(local_dir))
    except Exception as e:
        print(f"{RED}Error reading directory: {e}{RESET}")
        return []

    if not top_items:
        print("The current directory is empty. Nothing to ignore.")
        return []

    top_dirs = [item for item in top_items if os.path.isdir(os.path.join(local_dir, item))]
    top_files = [item for item in top_items if os.path.isfile(os.path.join(local_dir, item))]
    
    display_items = []
    added_paths = set()

    # Top-level directories first, then top-level files
    for item in top_dirs + top_files:
        display_items.append(item)
        added_paths.add(item)

    # Recursively scan subfolders to find files/directories with names recommended to ignore
    subfolder_recommended = []
    
    for root, dirs, files in os.walk(local_dir, followlinks=False):
        rel_root = os.path.relpath(root, local_dir)
        
        if rel_root == ".":
            # For root level, prune dirs that match recommended ignore so we don't recurse into them
            dirs[:] = [d for d in dirs if not is_recommended_ignore(d)]
            continue

        prune_dirs = []
        for d in list(dirs):
            rel_path = os.path.normpath(os.path.join(rel_root, d))
            if is_recommended_ignore(d) or is_recommended_ignore(rel_path):
                prune_dirs.append(d)
                if rel_path not in added_paths:
                    subfolder_recommended.append(rel_path)
                    added_paths.add(rel_path)
        
        # Prune matched directories so os.walk does not dive into them
        dirs[:] = [d for d in dirs if d not in prune_dirs]

        for f in files:
            rel_path = os.path.normpath(os.path.join(rel_root, f))
            if is_recommended_ignore(f) or is_recommended_ignore(rel_path):
                if rel_path not in added_paths:
                    subfolder_recommended.append(rel_path)
                    added_paths.add(rel_path)

    subfolder_recommended.sort()
    all_items = display_items + subfolder_recommended

    defaults_to_ignore = []

    print("\nSelect the files/folders you want to IGNORE. They will NOT be copied to the VPS.")
    print(f"Recommended exclusions (found in top level and subfolders) are marked with {BOLD}{YELLOW}*{RESET} and pre-selected as defaults.\n")

    for idx, item in enumerate(all_items, 1):
        item_full_path = os.path.join(local_dir, item)
        is_dir = os.path.isdir(item_full_path)
        suffix = "/" if is_dir else ""
        rec_str = ""
        if is_recommended_ignore(item):
            rec_str = f" {BOLD}{YELLOW}* [RECOMMENDED TO IGNORE]{RESET}"
            defaults_to_ignore.append(item)
        print(f"  [{idx}] {item}{suffix}{rec_str}")

    if defaults_to_ignore:
        print(f"\n- To ignore the recommended defaults ({', '.join(defaults_to_ignore)}), simply press {BOLD}Enter{RESET}.")
    else:
        print(f"\n- To accept defaults (no recommended items detected), press {BOLD}Enter{RESET}.")
    print(f"- To ignore custom items, enter their numbers separated by commas (e.g. {BOLD}1,3,5{RESET}) or type custom paths (e.g. {BOLD}logs/, *.tmp{RESET}).")
    print(f"- To ignore NOTHING (copy absolutely everything), type {BOLD}none{RESET}.")
    
    user_input = input("\nEnter choice: ").strip()
    
    if not user_input:
        if defaults_to_ignore:
            print(f"{GREEN}Using recommended defaults: {', '.join(defaults_to_ignore)}{RESET}")
        else:
            print(f"{GREEN}No recommended defaults; proceeding with no exclusions.{RESET}")
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
                ignores.append(part)
                print(f"{GREEN}Added custom exclusion: {part}{RESET}")

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

def parse_rsync_line(line):
    line = line.strip()
    if not line:
        return None
    parts = line.split(' ', 1)
    if len(parts) != 2:
        return None
    status, path = parts
    if len(status) < 2:
        return None
    file_type = status[1]
    return status, path, file_type

def build_rsync_cmd(connection_info, ignores, destination, dry_run=False, force_copy=False):
    local_dir = os.getcwd()
    host = connection_info['host']
    port = connection_info['port']
    username = connection_info['username']
    auth = connection_info['auth']
    
    if dry_run:
        cmd = ["rsync", "-az", "--dry-run", "--out-format=%i %n"]
    else:
        cmd = ["rsync", "-az", "--out-format=%i %n"]
        
    if force_copy:
        cmd.append("--ignore-times")
        
    for item in ignores:
        cmd.append(f"--exclude={item}")
        
    if auth['type'] == 'key':
        ssh_key_path = auth['key_path']
        cmd.extend([
            "-e", 
            f"ssh -p {port} -i {ssh_key_path} -o StrictHostKeyChecking=no", 
            f"{local_dir}/", 
            f"{username}@{host}:{destination}"
        ])
    elif auth['type'] == 'password':
        cmd.extend([
            "-e", 
            f"ssh -p {port} -o StrictHostKeyChecking=no", 
            f"{local_dir}/", 
            f"{username}@{host}:{destination}"
        ])
    return cmd

def run_rsync_operation(cmd, connection_info, show_output=True, dry_run=False):
    auth = connection_info['auth']
    output_lines = []
    success = False
    
    if auth['type'] == 'key':
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            for line in proc.stdout:
                output_lines.append(line)
                if show_output:
                    parsed = parse_rsync_line(line)
                    if parsed:
                        status, path, ftype = parsed
                        if path in ('.', './'):
                            continue
                        if dry_run:
                            if ftype == 'f':
                                print(f"  {YELLOW}→{RESET} {path}")
                            elif ftype == 'd':
                                print(f"  {BLUE}📁{RESET} {path}/")
                            elif ftype in ('L', 'l'):
                                print(f"  {YELLOW}🔗{RESET} {path}")
                        else:
                            if ftype == 'f':
                                print(f"  {GREEN}✓{RESET} {path}")
                            elif ftype == 'd':
                                print(f"  {BLUE}📁{RESET} {path}/")
                            elif ftype in ('L', 'l'):
                                print(f"  {GREEN}🔗{RESET} {path}")
            
            proc.wait()
            stderr_content = proc.stderr.read()
            if proc.returncode == 0:
                success = True
            else:
                if stderr_content.strip():
                    print(f"{RED}Error: {stderr_content.strip()}{RESET}")
                else:
                    for line in output_lines:
                        if not parse_rsync_line(line):
                            print(f"{RED}{line.strip()}{RESET}")
        except Exception as e:
            print(f"{RED}Error executing rsync: {e}{RESET}")
            
    elif auth['type'] == 'password':
        password = auth['password']
        escaped_cmd = shlex.join(cmd)
        env = os.environ.copy()
        env["SYNC_PASSWORD"] = password
        
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
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env
            )
            proc.stdin.write(expect_script)
            proc.stdin.close()
            
            for line in proc.stdout:
                output_lines.append(line)
                parsed = parse_rsync_line(line)
                if parsed:
                    status, path, ftype = parsed
                    if path in ('.', './'):
                        continue
                    if show_output:
                        if dry_run:
                            if ftype == 'f':
                                print(f"  {YELLOW}→{RESET} {path}")
                            elif ftype == 'd':
                                print(f"  {BLUE}📁{RESET} {path}/")
                            elif ftype in ('L', 'l'):
                                print(f"  {YELLOW}🔗{RESET} {path}")
                        else:
                            if ftype == 'f':
                                print(f"  {GREEN}✓{RESET} {path}")
                            elif ftype == 'd':
                                print(f"  {BLUE}📁{RESET} {path}/")
                            elif ftype in ('L', 'l'):
                                print(f"  {GREEN}🔗{RESET} {path}")
                else:
                    cleaned = line.strip()
                    if cleaned and show_output:
                        if "password:" in cleaned or "connecting (yes/no)" in cleaned:
                            pass
                        elif "spawn bash -c" in cleaned:
                            pass
                        else:
                            print(f"  {cleaned}")
            
            proc.wait()
            if proc.returncode == 0:
                success = True
                for line in output_lines:
                    if "rsync error:" in line or "Connection refused" in line or "Permission denied" in line:
                        success = False
            else:
                success = False
        except Exception as e:
            print(f"{RED}Error executing expect script: {e}{RESET}")
            
    return output_lines, success

def count_changes(output_lines):
    files = 0
    dirs = 0
    symlinks = 0
    for line in output_lines:
        parsed = parse_rsync_line(line)
        if parsed:
            status, path, ftype = parsed
            if path in ('.', './'):
                continue
            if ftype == 'f':
                files += 1
            elif ftype == 'd':
                dirs += 1
            elif ftype in ('L', 'l'):
                symlinks += 1
    return files, dirs, symlinks

def run_sync(connection_info, ignores, destination, force_copy=False):
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
    if force_copy:
        print(f"  Mode Override : {BOLD}{YELLOW}Force Copy All Files (Ignore Times){RESET}")
    
    # Pre-create the directory on the VPS recursively
    ensure_remote_dir(connection_info, destination)
    
    print_header("Detecting Changes")
    print("Scanning local directory and comparing with remote VPS...")
    
    # Run dry run silently first to detect changes and counts
    dry_run_cmd = build_rsync_cmd(connection_info, ignores, destination, dry_run=True, force_copy=force_copy)
    output_lines, success = run_rsync_operation(dry_run_cmd, connection_info, show_output=False, dry_run=True)
    
    if not success:
        print(f"\n{RED}Error: Failed to perform change detection.{RESET}")
        sys.exit(1)
        
    files, dirs, symlinks = count_changes(output_lines)
    
    if files == 0 and dirs == 0 and symlinks == 0:
        print(f"\n{GREEN}✓ Everything is up to date. No files to sync.{RESET}")
        return
        
    print(f"\n{BOLD}Changes detected:{RESET}")
    # Print the cached changes
    for line in output_lines:
        parsed = parse_rsync_line(line)
        if parsed:
            status, path, ftype = parsed
            if path in ('.', './'):
                continue
            if ftype == 'f':
                print(f"  {YELLOW}→{RESET} {path}")
            elif ftype == 'd':
                print(f"  {BLUE}📁{RESET} {path}/")
            elif ftype in ('L', 'l'):
                print(f"  {YELLOW}🔗{RESET} {path}")
                
    print_header("Sync Details")
    if files > 0:
        print(f"  - Files to sync         : {BOLD}{files}{RESET}")
    if dirs > 0:
        print(f"  - Directories to create : {BOLD}{dirs}{RESET}")
    if symlinks > 0:
        print(f"  - Symlinks to sync      : {BOLD}{symlinks}{RESET}")
        
    confirm = input(f"\nDo you want to proceed with the sync? (y/N): ").strip().lower()
    if confirm != 'y':
        print(f"\n{YELLOW}Sync cancelled by user.{RESET}")
        return
        
    print(f"\n{GREEN}--- STARTING RECURSIVE COPY TO VPS ---{RESET}\n")
    sync_cmd = build_rsync_cmd(connection_info, ignores, destination, dry_run=False, force_copy=force_copy)
    output_lines, success = run_rsync_operation(sync_cmd, connection_info, show_output=True, dry_run=False)
    
    if success:
        synced_files, synced_dirs, synced_symlinks = count_changes(output_lines)
        print_header("Sync Successful")
        if synced_files > 0:
            print(f"  {GREEN}✓{RESET} Files synced successfully: {BOLD}{synced_files}{RESET}")
        if synced_dirs > 0:
            print(f"  {GREEN}✓{RESET} Directories created/updated: {BOLD}{synced_dirs}{RESET}")
        if synced_symlinks > 0:
            print(f"  {GREEN}✓{RESET} Symlinks synced successfully: {BOLD}{synced_symlinks}{RESET}")
        if synced_files == 0 and synced_dirs == 0 and synced_symlinks == 0:
            print(f"  {GREEN}✓{RESET} Sync completed, but no changes were necessary.")
    else:
        print(f"\n{RED}Error: Sync command failed.{RESET}")
        sys.exit(1)

def main():
    try:
        init_config()
        local_dir = os.getcwd()
        
        while True:
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
                    print(f"  [m] Manage connection profiles (Edit/Delete)...")
                    print(f"  [q] Quit")
                    
                    choice = input(f"\nSelect choice (1-{new_target_idx}, m, q) [default: 1]: ").strip()
                    if not choice:
                        choice = "1"
                    
                    if choice.lower() == 'q':
                        print(f"{YELLOW}Operation cancelled by user.{RESET}")
                        sys.exit(0)
                        
                    if choice.lower() == 'm':
                        manage_connections_menu()
                        continue
                        
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
                            print(f"{RED}Invalid choice. Please try again.{RESET}")
                            continue
                    else:
                        print(f"{RED}Invalid choice. Please try again.{RESET}")
                        continue
            
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
            
            break
        
        # Prompt for copy mode
        print_header("Copy Mode")
        print(f"  [1] {BOLD}Smart Sync{RESET}       – Only copy new or modified files {GREEN}(recommended){RESET}")
        print(f"  [2] {BOLD}Force Copy All{RESET}   – Copy every file, regardless of changes {YELLOW}(slower){RESET}")
        
        mode_choice = ""
        while mode_choice not in ['1', '2']:
            mode_choice = input("\nSelect copy mode (1 or 2) [default: 1]: ").strip()
            if not mode_choice:
                mode_choice = "1"
                break
                
        force_copy = mode_choice == '2'
        if force_copy:
            print(f"{YELLOW}Force Copy All mode selected — all files will be synced.{RESET}")
        else:
            print(f"{GREEN}Smart Sync mode selected — only new/modified files will be synced.{RESET}")
            
        # Run copy operation
        run_sync(connection_info, ignores, destination, force_copy=force_copy)
        
    except KeyboardInterrupt:
        print(f"\n\n{YELLOW}Operation interrupted by user. Exiting gracefully...{RESET}")
        sys.exit(0)

if __name__ == "__main__":
    main()
