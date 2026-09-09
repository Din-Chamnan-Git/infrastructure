# 🛠️ Ansible Infrastructure & Secrets Management

This directory follows standard production Ansible directory practices with **Roles** and **Group Variables**.

---

## 📁 Directory Structure

```text
ansible/
├── group_vars/
│   └── all/
│       ├── vars.yml           # Non-sensitive global configuration
│       └── vault.yml          # Encrypted sensitive credentials (Ansible Vault)
├── roles/
│   └── k8s_secrets/
│       ├── defaults/
│       │   └── main.yml       # Default role variables
│       └── tasks/
│           ├── main.yml       # Role task entrypoint
│           ├── cloudflare.yml # Task to deploy cloudflare-tls Secret
│           └── postgres.yml   # Task to deploy postgres-secret Secret
├── site.yml                   # Primary master playbook
└── deploy_secrets.yml         # Entrypoint playbook wrapper
```

---

## 🚀 How to Run

### 1. Encrypt Vault
```bash
ansible-vault encrypt group_vars/all/vault.yml
```

### 2. Run Playbook
```bash
ansible-playbook site.yml --ask-vault-pass
```
*(or using `deploy_secrets.yml`)*
```bash
ansible-playbook deploy_secrets.yml --ask-vault-pass
```
