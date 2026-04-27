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

Lessons Learned

1. Infrastructure Layering & State Persistence
    - The Challenge: Realized that keeping the Resource Group in the workload folder caused the pipeline to "de-authorize" itself when the workload was destroyed.
    - The Lesson: I learned the importance of separating lifecycle boundaries. By refactoring the Resource Group into a long-lived foundation/ layer, I ensured that security roles and networking remained intact while allowing the workload/ compute to be fully ephemeral and disposable.

2. Identity-Driven Security (OIDC)
    - The Challenge: Handling static Service Principal secrets in GitHub was a security risk and required manual rotation.
    - The Lesson: I transitioned to GitHub OIDC (OpenID Connect). I learned how to establish a passwordless trust relationship via Federated Credentials, which taught me that the most secure secret is the one that doesn't exist.

3. Azure RBAC & Scopes
    - The Challenge: Encountered a 403 Forbidden error because the app registration setup via Federated Credentials had the 'Contributor' role but lacked the permission to manage role assignments. This resulted in the pipeline failing as the terraform apply or destroy command would fail due to lack of permissions.
    - The Lesson: This taught me the Principle of Least Privilege in a practical way. I learned to assign the 'User Access Administrator' role specifically at the Resource Group scope allowing the pipeline to manage the Managed Identity roles it created without granting it 'Owner' status over the subscription (which would be too many permissions).

4. Defensive CI/CD Programming
    - The Challenge: The pipeline crashed on standard git push triggers because the manual input variables (workflow_dispatch) where null.
    - The Lesson: I learned to implement Event-Driven Fallbacks in YAML. By using shell expansion logic (${{ github.event.inputs.action || 'apply' }}), I ensured the pipeline was resilient enough to handle both automated branch updates and manual UI instructions.

5. Passing Sensitive Data Through Variable Injection
    - The Challenge: Passing sensitive data like Cloudflare tokens and SSH keys without commiting them to version control.
    - The Lesson: I mastered Terraform Variable Precedence. I learned to map GitHub secrets to the TF_VAR_ environment variable prefix, allowing the runner to ingest data dynamically. This also taught me how to refactor code to use Remote State Outputs instead of local file dependencies (like .pub files).

6. Cost Governance and Resource Resiliency
    - The Challenge: Managing the financial risk of public cloud resources and the technical risk of data loss.
    - The Lesson: I learned that operations are as important as code. By implementing Azure Budget Alerts and a 7-day retention sidecar backup policy, I ensured the project was economically sustainable and protected against accidental world corruption.

7. Identity Resolution (App vs Service Principal)
    - The Challenge: Faced PrincipalTypeNotSupported errors when trying to assign roles via Terraform.
    - The Lesson: I gained a deep understanding of Entra ID (formerly Azure AD). I learned that while the "App Registration" is the definition, the "Enterprise Application/Service Principal" is the actual identity used for RBAC, each with its own distinct Object ID.
