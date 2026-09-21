#!/usr/bin/env bash
# ==============================================================================
# 🚀 Infra CLI - Complete Infrastructure Orchestrator for GCP, Vault & Kubernetes
# ==============================================================================
set -e

# Base directory setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_KEY="${SSH_KEY_PATH:-$HOME/.ssh/nan-laptop}"
VAULT_TF_DIR="$SCRIPT_DIR/terraform/environments/hc_vault"
K8S_TF_DIR="$SCRIPT_DIR/terraform/environments/gcp_dev"
CICD_TF_DIR="$SCRIPT_DIR/terraform/environments/cicd"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
KUBESPRAY_DIR="$SCRIPT_DIR/kubespray"
VAULT_INVENTORY="$ANSIBLE_DIR/inventory/hc_vault/inventory.ini"
K8S_INVENTORY="$KUBESPRAY_DIR/inventory/gcp_dev/inventory.ini"
CICD_INVENTORY="$ANSIBLE_DIR/inventory/cicd/inventory.ini"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper Functions
log_info()    { echo -e "${CYAN}ℹ [INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}✔ [SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠ [WARN]${NC} $1"; }
log_error()   { echo -e "${RED}✖ [ERROR]${NC} $1"; }
log_header()  { echo -e "\n${PURPLE}${BOLD}====================================================================${NC}\n${PURPLE}${BOLD} $1${NC}\n${PURPLE}${BOLD}====================================================================${NC}"; }

check_prereqs() {
    local missing=()
    for cmd in terraform ansible python3 ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required commands: ${missing[*]}"
        log_warn "Please install the missing tools and try again."
        exit 1
    fi
}

activate_venv() {
    if [ -f "$KUBESPRAY_DIR/venv/bin/activate" ]; then
        log_info "Activating Kubespray Python virtual environment..."
        source "$KUBESPRAY_DIR/venv/bin/activate"
    elif [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
        log_info "Activating Python virtual environment..."
        source "$SCRIPT_DIR/venv/bin/activate"
    else
        log_warn "No virtual environment found at $KUBESPRAY_DIR/venv. Using system Python context."
    fi
}

# ------------------------------------------------------------------------------
# Auto IP Synchronization from Terraform Outputs to Inventory files
# ------------------------------------------------------------------------------
sync_inventory_ips() {
    log_header "🔄 Synchronizing Terraform IP Outputs to Inventory Files"

    # 1. Sync Vault IP
    if [ -d "$VAULT_TF_DIR" ] && [ -f "$VAULT_TF_DIR/terraform.tfstate" ]; then
        log_info "Extracting Vault Terraform IP output..."
        VAULT_IP=$(cd "$VAULT_TF_DIR" && terraform output -raw vault_public_ip 2>/dev/null || true)
        if [ -n "$VAULT_IP" ] && [ "$VAULT_IP" != "No outputs found" ]; then
            log_info "Updating Vault inventory ($VAULT_INVENTORY) with IP: $VAULT_IP"
            mkdir -p "$(dirname "$VAULT_INVENTORY")"
            cat <<EOF > "$VAULT_INVENTORY"
[vault_hosts]
$VAULT_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY
EOF
            log_success "Vault inventory updated successfully."
        else
            log_warn "Vault Terraform state found, but vault_public_ip output was empty."
        fi
    else
        log_warn "Vault Terraform state not found at $VAULT_TF_DIR. Skipping Vault inventory update."
    fi

    # 2. Sync K8s Node IPs
    if [ -d "$K8S_TF_DIR" ] && [ -f "$K8S_TF_DIR/terraform.tfstate" ]; then
        log_info "Extracting K8s Cluster Terraform IP outputs..."
        TF_OUTPUT_JSON=$(cd "$K8S_TF_DIR" && terraform output -json node_ips 2>/dev/null || true)

        if [ -n "$TF_OUTPUT_JSON" ] && [ "$TF_OUTPUT_JSON" != "{}" ]; then
            log_info "Parsing Terraform node IPs and updating Kubespray inventory ($K8S_INVENTORY)..."
            python3 - "$TF_OUTPUT_JSON" "$K8S_INVENTORY" "$SSH_KEY" << 'PYEOF'
import sys, json, os

tf_json_raw = sys.argv[1]
inventory_path = sys.argv[2]
ssh_key = sys.argv[3]

try:
    data = json.loads(tf_json_raw)
    nodes = data.get("value", data)
    
    all_hosts = []
    control_planes = []
    kube_nodes = []
    
    for name, info in sorted(nodes.items()):
        pub_ip = info.get("public_ip")
        priv_ip = info.get("private_ip")
        host_entry = f"{name}-dev ansible_host={pub_ip} ip={priv_ip}"
        all_hosts.append(host_entry)
        
        if "master" in name:
            control_planes.append(f"{name}-dev")
        else:
            kube_nodes.append(f"{name}-dev")

    os.makedirs(os.path.dirname(inventory_path), exist_ok=True)
    with open(inventory_path, "w") as f:
        f.write("[all]\n")
        for h in all_hosts:
            f.write(f"{h}\n")
        f.write("\n[kube_control_plane]\n")
        for cp in control_planes:
            f.write(f"{cp}\n")
        f.write("\n[etcd]\n")
        for cp in control_planes:
            f.write(f"{cp}\n")
        f.write("\n[kube_node]\n")
        for kn in kube_nodes:
            f.write(f"{kn}\n")
        f.write("\n[k8s_cluster:children]\n")
        f.write("kube_control_plane\n")
        f.write("kube_node\n")
        f.write("\n[all:vars]\n")
        f.write("ansible_user=ubuntu\n")
        f.write(f"ansible_ssh_private_key_file={ssh_key}\n")
        f.write("ansible_become=true\n")
        f.write("ansible_become_method=sudo\n")
        f.write("ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n")

    print("SUCCESS")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
            if [ $? -eq 0 ]; then
                log_success "Kubespray inventory ($K8S_INVENTORY) updated successfully."
            else
                log_error "Failed to parse Terraform outputs for K8s inventory."
            fi
        else
            log_warn "K8s Terraform state found, but node_ips output was empty."
        fi
    else
        log_warn "K8s Terraform state not found at $K8S_TF_DIR. Skipping K8s inventory update."
    fi

    # 3. Sync CI/CD Server IP
    if [ -d "$CICD_TF_DIR" ] && [ -f "$CICD_TF_DIR/terraform.tfstate" ]; then
        log_info "Extracting CI/CD Terraform IP output..."
        CICD_IP=$(cd "$CICD_TF_DIR" && terraform output -raw cicd_public_ip 2>/dev/null || true)
        if [ -n "$CICD_IP" ] && [ "$CICD_IP" != "No outputs found" ]; then
            log_info "Updating CI/CD inventory ($CICD_INVENTORY) with IP: $CICD_IP"
            mkdir -p "$(dirname "$CICD_INVENTORY")"
            cat <<EOF > "$CICD_INVENTORY"
[cicd_hosts]
$CICD_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY
EOF
            log_success "CI/CD inventory updated successfully."
        else
            log_warn "CI/CD Terraform state found, but cicd_public_ip output was empty."
        fi
    else
        log_warn "CI/CD Terraform state not found at $CICD_TF_DIR. Skipping CI/CD inventory update."
    fi
}

# ------------------------------------------------------------------------------
# Vault Subcommands
# ------------------------------------------------------------------------------
vault_tf_apply() {
    log_header "🔐 Phase 1.1: Deploying Vault Infrastructure with Terraform"
    cd "$VAULT_TF_DIR"
    terraform init
    terraform apply -auto-approve
    log_success "Vault infrastructure applied."
    sync_inventory_ips
}

vault_ansible_setup() {
    log_header "🔐 Phase 1.2: Configuring Vault Server with Ansible"
    activate_venv
    if [ ! -f "$VAULT_INVENTORY" ]; then
        log_warn "Vault inventory file missing. Attempting IP sync first..."
        sync_inventory_ips
    fi
    cd "$ANSIBLE_DIR"
    ansible-playbook -i "$VAULT_INVENTORY" vault_site.yml
    log_success "Vault Ansible playbook completed."
}

vault_tf_destroy() {
    log_header "🧹 Destroying Vault Infrastructure"
    cd "$VAULT_TF_DIR"
    terraform destroy -auto-approve
    log_success "Vault infrastructure destroyed."
}

# ------------------------------------------------------------------------------
# CI/CD Server Subcommands (Jenkins, SonarQube, Nexus, Nginx)
# ------------------------------------------------------------------------------
cicd_tf_apply() {
    log_header "⚡ Phase 4.1: Deploying CI/CD Server Infrastructure with Terraform"
    cd "$CICD_TF_DIR"
    terraform init
    terraform apply -auto-approve
    log_success "CI/CD server infrastructure applied."
    sync_inventory_ips
}

cicd_ansible_setup() {
    log_header "⚡ Phase 4.2: Configuring CI/CD Server (Jenkins, SonarQube, Nexus, SSL) with Ansible"
    activate_venv
    if [ ! -f "$CICD_INVENTORY" ]; then
        log_warn "CI/CD inventory file missing. Attempting IP sync first..."
        sync_inventory_ips
    fi

    CF_TOKEN=""
    if [ -f "$CICD_TF_DIR/terraform.tfvars" ]; then
        CF_TOKEN=$(grep -E '^cloudflare_api_token' "$CICD_TF_DIR/terraform.tfvars" | cut -d '=' -f2 | tr -d ' "' || true)
    fi

    cd "$ANSIBLE_DIR"
    if [ -n "$CF_TOKEN" ]; then
        log_info "Cloudflare API token detected. Requesting Let's Encrypt SSL certificates via Certbot..."
        ansible-playbook -i "$CICD_INVENTORY" cicd_site.yml -e "cloudflare_api_token=$CF_TOKEN"
    else
        log_warn "Cloudflare API token not found. Falling back to self-signed SSL..."
        ansible-playbook -i "$CICD_INVENTORY" cicd_site.yml
    fi
    log_success "CI/CD Ansible playbook completed."
}

cicd_tf_destroy() {
    log_header "🧹 Destroying CI/CD Infrastructure"
    cd "$CICD_TF_DIR"
    terraform destroy -auto-approve
    log_success "CI/CD infrastructure destroyed."
}

# ------------------------------------------------------------------------------
# K8s Infrastructure & Kubespray Subcommands
# ------------------------------------------------------------------------------
k8s_tf_apply() {
    log_header "☸ Phase 2.1: Deploying Kubernetes VMs with Terraform"
    cd "$K8S_TF_DIR"
    terraform init
    terraform apply -auto-approve
    log_success "Kubernetes VMs deployed."
    sync_inventory_ips
}

k8s_deploy_cluster() {
    log_header "☸ Phase 2.2: Provisioning Kubernetes Cluster with Kubespray"
    activate_venv
    if [ ! -f "$K8S_INVENTORY" ]; then
        log_warn "Kubespray inventory file missing. Running IP sync..."
        sync_inventory_ips
    fi

    log_info "Testing SSH ping connectivity to nodes..."
    ansible -i "$K8S_INVENTORY" all -m ping -e "ansible_become=false"

    log_info "Executing Kubespray cluster playbook..."
    cd "$KUBESPRAY_DIR"
    ansible-playbook -i "$K8S_INVENTORY" cluster.yml -b --become-user=root
    log_success "Kubernetes cluster provisioned with Kubespray!"
}

k8s_setup_kubeconfig() {
    log_header "🔑 Phase 2.3: Fetching Kubeconfig & Launching SSH Tunnel"
    
    if [ ! -f "$K8S_INVENTORY" ]; then
        log_error "Inventory file $K8S_INVENTORY not found. Cannot determine master IP."
        exit 1
    fi

    MASTER_IP=$(grep -E 'k8s-master-1.*ansible_host=' "$K8S_INVENTORY" | sed -n 's/.*ansible_host=\([0-9\.]*\).*/\1/p' | head -n 1)

    if [ -z "$MASTER_IP" ]; then
        log_error "Could not find k8s-master public IP in $K8S_INVENTORY"
        exit 1
    fi

    log_info "Fetching kubeconfig from Master VM ($MASTER_IP)..."
    mkdir -p "$HOME/.kube"
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "ubuntu@$MASTER_IP" "sudo cat /etc/kubernetes/admin.conf" > "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"
    sed -i "s/$MASTER_IP/127.0.0.1/g" "$HOME/.kube/config"

    log_info "Setting up SSH Tunnel (Local port 6443 -> Master VM localhost:6443)..."
    pkill -f "6443:localhost:6443" || true
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -i "$SSH_KEY" -f -N -L 6443:localhost:6443 "ubuntu@$MASTER_IP"

    log_success "Kubeconfig updated and SSH tunnel established."
    log_info "Testing kubectl access..."
    kubectl get nodes -o wide || log_warn "kubectl call failed. Ensure master API server is running."
}

k8s_deploy_apps() {
    log_header "🔐 Phase 3: Platform, ESO & Application Deployment (Ansible)"
    activate_venv
    if [ ! -f "$K8S_INVENTORY" ]; then
        log_warn "Inventory file missing. Syncing IPs..."
        sync_inventory_ips
    fi
    cd "$ANSIBLE_DIR"
    ansible-playbook -i "$K8S_INVENTORY" site.yml
    log_success "Platform apps (ESO, Traefik, Longhorn, Postgres) deployed successfully!"
}

k8s_tf_destroy() {
    log_header "🧹 Destroying Kubernetes Infrastructure"
    cd "$K8S_TF_DIR"
    terraform destroy -auto-approve
    log_success "Kubernetes VMs destroyed."
}

get_argocd_password() {
    log_header "🔐 Fetching ArgoCD Initial Admin Credentials"
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl is not installed or not in PATH."
        return 1
    fi

    log_info "Retrieving initial admin password from Kubernetes secret 'argocd-initial-admin-secret'..."
    PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || true)

    if [ -n "$PASS" ]; then
        echo ""
        echo -e "${GREEN}${BOLD}====================================================================${NC}"
        echo -e "${GREEN}${BOLD} 🔐 ArgoCD Login Credentials:${NC}"
        echo -e "   • URL:      ${CYAN}https://argocd.dnan.tech${NC}"
        echo -e "   • Username: ${BOLD}admin${NC}"
        echo -e "   • Password: ${YELLOW}${BOLD}$PASS${NC}"
        echo -e "${GREEN}${BOLD}====================================================================${NC}"
        echo ""
    else
        log_warn "Could not retrieve password. Either ArgoCD is not deployed yet or the initial secret was changed."
        log_info "Manual Command: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
    fi
}

get_cicd_credentials() {
    log_header "🔐 Fetching CI/CD Platform Initial Admin Credentials"
    
    if [ ! -f "$CICD_INVENTORY" ]; then
        log_error "CI/CD inventory file missing. Run './infrastructure/infra.sh cicd apply' first."
        return 1
    fi

    CICD_IP=$(grep -E '^[0-9\.]+' "$CICD_INVENTORY" | awk '{print $1}' | head -n 1)

    if [ -z "$CICD_IP" ]; then
        log_error "Could not determine CI/CD server IP from inventory."
        return 1
    fi

    log_info "Connecting to CI/CD server ($CICD_IP) to fetch initial admin passwords..."
    
    JENKINS_PASS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$CICD_IP "sudo cat /opt/jenkins_home/secrets/initialAdminPassword 2>/dev/null" || echo "Installing / Pending...")
    NEXUS_PASS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$CICD_IP "sudo cat /opt/nexus-data/admin.password 2>/dev/null" || echo "Installing / Pending...")

    echo ""
    echo -e "${GREEN}${BOLD}====================================================================${NC}"
    echo -e "${GREEN}${BOLD} 🔐 CI/CD Platform Initial Admin Credentials:${NC}"
    echo -e "${GREEN}${BOLD}====================================================================${NC}"
    echo -e " ⚡ ${BOLD}Jenkins:${NC}"
    echo -e "    • URL:      ${CYAN}https://jenkins.dnan.tech${NC}"
    echo -e "    • Username: ${BOLD}admin${NC}"
    echo -e "    • Password: ${YELLOW}${BOLD}$JENKINS_PASS${NC}"
    echo ""
    echo -e " 🔍 ${BOLD}SonarQube:${NC}"
    echo -e "    • URL:      ${CYAN}https://sonar.dnan.tech${NC}"
    echo -e "    • Username: ${BOLD}admin${NC}"
    echo -e "    • Password: ${YELLOW}${BOLD}admin${NC} (Prompts for new password on 1st login)"
    echo ""
    echo -e " 📦 ${BOLD}Nexus Repository Manager:${NC}"
    echo -e "    • URL:      ${CYAN}https://nexus.dnan.tech${NC}"
    echo -e "    • Username: ${BOLD}admin${NC}"
    echo -e "    • Password: ${YELLOW}${BOLD}$NEXUS_PASS${NC}"
    echo -e "${GREEN}${BOLD}====================================================================${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# System Diagnostics / Status Check
# ------------------------------------------------------------------------------
status_check() {
    log_header "📊 System Diagnostics & Health Check"
    
    # 1. Vault TF State
    echo -n "• Vault Terraform State: "
    if [ -f "$VAULT_TF_DIR/terraform.tfstate" ]; then
        echo -e "${GREEN}Present${NC}"
    else
        echo -e "${YELLOW}Not Provisioned${NC}"
    fi

    # 2. K8s TF State
    echo -n "• K8s VMs Terraform State: "
    if [ -f "$K8S_TF_DIR/terraform.tfstate" ]; then
        echo -e "${GREEN}Present${NC}"
    else
        echo -e "${YELLOW}Not Provisioned${NC}"
    fi

    # 3. CI/CD TF State
    echo -n "• CI/CD VM Terraform State: "
    if [ -f "$CICD_TF_DIR/terraform.tfstate" ]; then
        echo -e "${GREEN}Present${NC}"
    else
        echo -e "${YELLOW}Not Provisioned${NC}"
    fi

    # 4. Inventory Files
    echo -n "• Vault Inventory: "
    if [ -f "$VAULT_INVENTORY" ]; then echo -e "${GREEN}Found${NC}"; else echo -e "${YELLOW}Missing${NC}"; fi

    echo -n "• K8s Inventory: "
    if [ -f "$K8S_INVENTORY" ]; then echo -e "${GREEN}Found${NC}"; else echo -e "${YELLOW}Missing${NC}"; fi

    echo -n "• CI/CD Inventory: "
    if [ -f "$CICD_INVENTORY" ]; then echo -e "${GREEN}Found${NC}"; else echo -e "${YELLOW}Missing${NC}"; fi

    # 5. SSH Ping Test
    if [ -f "$K8S_INVENTORY" ]; then
        echo -e "\n${BOLD}Testing Node Connectivity (Ansible Ping):${NC}"
        activate_venv
        ansible -i "$K8S_INVENTORY" all -m ping -e "ansible_become=false" --one-line 2>/dev/null || log_warn "Ping test failed or nodes unreachable."
    fi

    # 6. Kubectl Status
    echo -e "\n${BOLD}Kubernetes Cluster Status:${NC}"
    if command -v kubectl &>/dev/null && [ -f "$HOME/.kube/config" ]; then
        kubectl get nodes -o wide 2>/dev/null || log_warn "Cannot reach Kubernetes API server (Is SSH tunnel active?)."
    else
        log_warn "kubectl CLI or kubeconfig not configured."
    fi
}

destroy_all() {
    log_header "⚠️ TEARDOWN / DESTROY EVERYTHING ⚠️"
    echo -e "${RED}${BOLD}WARNING: This action will completely destroy Vault, K8s, and CI/CD infrastructure on GCP!${NC}"
    read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirm
    if [ "$confirm" == "yes" ]; then
        cicd_tf_destroy || true
        k8s_tf_destroy || true
        vault_tf_destroy || true
        pkill -f "6443:localhost:6443" || true
        log_success "All infrastructure has been destroyed."
    else
        log_info "Teardown aborted."
    fi
}

# ------------------------------------------------------------------------------
# Interactive Menu (TUI)
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        log_header "🛠 Infra Management CLI - Main Menu"
        echo -e "  ${BOLD}Vault Server:${NC}"
        echo -e "    1) Provision Vault Infra (Terraform Apply)"
        echo -e "    2) Configure Vault Server (Ansible Setup)"
        echo -e "    3) Destroy Vault Infra (Terraform Destroy)"
        echo ""
        echo -e "  ${BOLD}CI/CD Server (Jenkins, SonarQube, Nexus):${NC}"
        echo -e "    4) Provision CI/CD Infra (Terraform Apply)"
        echo -e "    5) Configure CI/CD Server (Ansible Setup)"
        echo -e "    6) Destroy CI/CD Infra (Terraform Destroy)"
        echo ""
        echo -e "  ${BOLD}Kubernetes Cluster & Apps:${NC}"
        echo -e "    7) Provision K8s Infra VMs (Terraform Apply)"
        echo -e "    8) Deploy K8s Cluster (Kubespray Playbook)"
        echo -e "    9) Fetch Kubeconfig & Start SSH Tunnel"
        echo -e "   10) Deploy Platform & Apps (Ansible site.yml)"
        echo -e "   11) Destroy K8s Infra VMs (Terraform Destroy)"
        echo ""
        echo -e "  ${BOLD}Utilities & Lifecycle:${NC}"
        echo -e "   12) 🔄 Sync Terraform IPs -> Ansible Inventories"
        echo -e "   13) 📊 Run Health Check & Diagnostics"
        echo -e "   14) 🔐 Fetch ArgoCD Initial Admin Password"
        echo -e "   15) 🚀 Full Deployment (Vault -> CI/CD -> K8s -> Apps)"
        echo -e "   16) 🧹 Teardown / Destroy Everything"
        echo -e "    0) Exit"
        echo ""
        read -p "Select an option [0-16]: " opt

        case $opt in
            1) vault_tf_apply ;;
            2) vault_ansible_setup ;;
            3) vault_tf_destroy ;;
            4) cicd_tf_apply ;;
            5) cicd_ansible_setup ;;
            6) cicd_tf_destroy ;;
            7) k8s_tf_apply ;;
            8) k8s_deploy_cluster ;;
            9) k8s_setup_kubeconfig ;;
            10) k8s_deploy_apps ;;
            11) k8s_tf_destroy ;;
            12) sync_inventory_ips ;;
            13) status_check ;;
            14) get_argocd_password ;;
            15)
                log_info "Starting full end-to-end deployment..."
                vault_tf_apply
                vault_ansible_setup
                cicd_tf_apply
                cicd_ansible_setup
                k8s_tf_apply
                k8s_deploy_cluster
                k8s_setup_kubeconfig
                k8s_deploy_apps
                log_success "Full deployment finished successfully!"
                ;;
            16) destroy_all ;;
            0) echo -e "\nGoodbye! 👋\n"; exit 0 ;;
            *) log_error "Invalid option '$opt'. Please choose 0-16." ;;
        esac

        echo ""
        read -p "Press Enter to return to the menu..."
    done
}

# ------------------------------------------------------------------------------
# Command Line Argument Routing
# ------------------------------------------------------------------------------
check_prereqs

case "$1" in
    vault)
        case "$2" in
            tf-apply|apply) vault_tf_apply ;;
            setup|ansible)  vault_ansible_setup ;;
            tf-destroy|destroy) vault_tf_destroy ;;
            *) log_error "Usage: $0 vault [apply|setup|destroy]" ;;
        esac
        ;;
    cicd)
        case "$2" in
            tf-apply|apply) cicd_tf_apply ;;
            setup|ansible)  cicd_ansible_setup ;;
            tf-destroy|destroy) cicd_tf_destroy ;;
            *) log_error "Usage: $0 cicd [apply|setup|destroy]" ;;
        esac
        ;;
    k8s)
        case "$2" in
            tf-apply|apply)     k8s_tf_apply ;;
            deploy-cluster|cluster|kubespray) k8s_deploy_cluster ;;
            kubeconfig|tunnel)  k8s_setup_kubeconfig ;;
            deploy-apps|apps)   k8s_deploy_apps ;;
            tf-destroy|destroy) k8s_tf_destroy ;;
            *) log_error "Usage: $0 k8s [apply|cluster|kubeconfig|apps|destroy]" ;;
        esac
        ;;
    argocd-pass|argocd|argocd-password)
        get_argocd_password
        ;;
    cicd-pass|cicd-credentials|cicd-password)
        get_cicd_credentials
        ;;
    sync-ip|sync)
        sync_inventory_ips
        ;;
    status|check)
        status_check
        ;;
    destroy-all)
        destroy_all
        ;;
    help|--help|-h)
        echo "Infra Management CLI"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)             Launch interactive menu"
        echo "  vault apply           Provision Vault VM (Terraform)"
        echo "  vault setup           Configure Vault server (Ansible)"
        echo "  vault destroy         Destroy Vault VM"
        echo "  cicd apply            Provision CI/CD VM (Terraform)"
        echo "  cicd setup            Configure CI/CD server stack (Ansible)"
        echo "  cicd destroy          Destroy CI/CD VM"
        echo "  k8s apply             Provision K8s VMs (Terraform)"
        echo "  k8s cluster           Provision K8s cluster (Kubespray)"
        echo "  k8s kubeconfig        Fetch kubeconfig & start SSH tunnel"
        echo "  k8s apps              Deploy platform & apps (Ansible)"
        echo "  k8s destroy           Destroy K8s VMs"
        echo "  argocd-pass           Fetch ArgoCD initial admin password"
        echo "  cicd-pass             Fetch CI/CD initial admin passwords (Jenkins, Sonar, Nexus)"
        echo "  sync-ip               Sync Terraform outputs to inventory.ini files"
        echo "  status                Run health checks and status diagnostics"
        echo "  destroy-all           Teardown all resources"
        ;;
    "")
        interactive_menu
        ;;
    *)
        log_error "Unknown command '$1'. Run '$0 help' for available subcommands."
        exit 1
        ;;
esac
