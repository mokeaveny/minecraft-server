A production-grade, automated Minecraft deployment on Microsoft Azure, managed entirely via Infrastructure as Code (IaC). This project demonstrates a "Zero-Touch" deployment where the environment moves from code to a playable, DNS-secured state with Zero-Secret leakage.

To mirror enterprise-grade environments, this project implements a Layered Infrastructure Strategy. By decoupling the long-lived security components from the transient compute resources, we ensure a stable "Root of Trust" that survives application teardowns.

1. The Foundation Layer (/foundation)
This includes all of code to provision the "persistent" services used in the project. It is deployed once and rarely destroyed. Currently includes:
    - Azure Key Vault: Centralized, RBAC-protected storage for sensitive credentials.
    - Identity Management: Configures the security principals required for the workload to "reach" into the vault.
    - Lifecycle Guards: Implements prevent_destroy and purge_protection to safeguard secrets.

2. The Workload Layer (/workloads/minecraft)
This is the "Disposable Compute" layer. It contains the game server and its networking. Currently includes:
    - Dynamic Discovery: Utilizes terraform_remote_state to automatically find the Key Vault without manual variable injection.
    - Just-In-Time Secrets: Pulls Cloudflare API tokens and Zone IDs directly into memory during the apply phase.
    - Compute: An Ubuntu VM running Dockerized Minecraft with Azure Monitor Agent (AMA) integration and a sidecar backup service.

This stack follows a three-tier automation strategy:

1. Infrastructure Tier (Terraform): Provisions the Network, Security Groups, and the Ubuntu VM.
2. Provisioning Tier (Cloud-Init/init.sh): A custom shell script injected via Azure custom_data. It automates the installation of Docker, GPG keys, and system dependencies upon the first boot.
3. Orchestration Tier (Docker Compose): Defines the application lifecycle, managing the Minecraft container, environment variables, and persistent volume mounts for world data.

Key Features:

1. Automated Bootstrapping (init.sh)
To ensure an immutable and repeatable environment, I utilized the Azure custom_data attribute to execute a bootstrapping script at runtime. This script:
    - Updates system packages and installs the Docker engine.
    - Sets up the necessary directory structures for world persistence.
    - Clones the configuration repository and launches the stack.

2. Containerized Orchestration
Using docker-compose.yml, the server environment is fully decoupled from the host OS. This allows for:
    - Easy Version Upgrades: Simply changing the image tag for whichever version you want (currently set to LATEST)
    - Resource Limits: Defining memory and CPU constraints at the container level.
    - Environment Injection: Managing server properties (EULA, Op-permission, World Type) through secure environment variables.

3. Advanced Observability (AMA & KQL)
Guest-level performance counters are streamed via the Azure Monitor Agent (AMA). This allows for real-time monitoring of JVM memory pressure and CPU spikes directly within the Azure Portal.

4. Networking & DNS Abstraction
The server uses a Static Public IP linked to a Cloudflare CNAME. By aliasing minecraft.michaelkeaveny.com to the Azure FQDN, the connection remains stable even if the underlying hardware is migrated within the Azure backbone.

## Configuration

Before deploying, you must provide values for several required variables. These are defined in `variables.tf` and must be set in a `.tfvars` file. An example is provided in `example.tfvars`.

**Required variables:**

- `home_ip_address`: Your home IP address for NSG rule (e.g., `"203.0.113.1/32"`)
- `ssh_public_key_path`: Path to your SSH public key for VM access (e.g., `"/home/user/.ssh/id_rsa.pub"`)
- `admin_username`: Admin username for the VM
- `contact_email`: Email address to receive budget notifications

**Optional variables:**

- `minecraft_memory`: Amount of memory (in GB) to allocate to the Minecraft server (default: `3G`)

To configure, copy `example.tfvars` to a new file (e.g., `production.tfvars`) and fill in your values:

```sh
cp example.tfvars production.tfvars
# Edit production.tfvars with your details
```

Your `production.tfvars` should look like:

```hcl
home_ip_address      = "YOUR_HOME_IP/32"
ssh_public_key_path  = "/path/to/your/.ssh/id_rsa.pub"
admin_username       = "your_admin_username"
minecraft_memory     = "3G"
contact_email        = "your@email.com"
```

Deployment Guide:

Phase 1: Provision the Foundation
Build the security core first. This only needs to be done once.

```sh
cd foundation/
terraform init
terraform apply
```

Manual Step: Seed your secrets into the newly created Vault (note - this requires the Azure CLI being installed on your machine):
```sh
az keyvault secret set --vault-name <vault_name_from_output> --name "cloudflare-api-token" --value "your_token"
az keyvault secret set --vault-name <vault_name_from_output> --name "cloudflare-zone-id" --value "your_zone_id"
```

Phase 2: Provision the Workload
Deploy the server. This layer automatically "reaches back" to the foundation for its secrets.

```sh
cd ../workloads/minecraft/
terraform init
terraform apply -var-file="production.tfvars"
```

Monitoring & Health
Once the server is live, you can track the bootstrapping progress by SSHing into the VM:

```sh
tail -f /var/log/cloud-init-output.log
```

To monitor live RAM usage in the Azure Portal, use the following KQL Query:
```sh
Perf
| where CounterName == "Available MBytes"
| summarize avg(CounterValue) by bin(TimeGenerated, 1m)
| render timechart
```