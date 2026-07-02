# AWS Application Infrastructure — Terraform

Provisions a VPC, public/private subnets across two AZs, a NAT gateway, three EC2 instances accessed via SSM, an internet-facing Application Load Balancer with access logs shipped to S3, and all associated IAM and security group resources — all in `us-east-1`.

---

## Architecture overview

```
Internet
   │
   ▼
Application Load Balancer  (public subnets: us-east-1a / us-east-1b)
   │  port 80 → forward
   ▼
Target Group  (port 8080, health check GET /health)
   ├── web   t2.micro  us-east-1a  private subnet
   └── web2  t2.micro  us-east-1b  private subnet

db  t2.micro  us-east-1a  private subnet  (NOT attached to ALB)

Outbound internet (private subnets) → NAT Gateway (us-east-1a public subnet)
Instance access → AWS SSM Session Manager (no SSH / no bastion)
ALB access logs → S3 bucket (yusufwaili-hcp-testing-bucket-<account-id>)
```

---

## Prerequisites

| Requirement | Detail |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | exactly `1.15.7` (see [`terraform.tf`](terraform.tf)) |
| AWS provider | `~> 6.49.0` — resolved automatically by `terraform init` |
| AWS credentials | configured via `aws configure`, environment variables, or an IAM role |
| AWS CLI v2 + [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) | required to connect to instances via SSM |

---

## File structure

| File | Contents |
|---|---|
| [`terraform.tf`](terraform.tf) | Terraform version pin and provider requirements |
| [`providers.tf`](providers.tf) | AWS provider — region `us-east-1` |
| [`variables.tf`](variables.tf) | Input variables (subnet CIDR maps) |
| [`locals.tf`](locals.tf) | Instance definitions (name → type + AZ) |
| [`network.tf`](network.tf) | VPC, subnets, IGW, NAT gateway, route tables |
| [`security_groups.tf`](security_groups.tf) | Security groups and ingress/egress rules |
| [`main.tf`](main.tf) | IAM/SSM profile, EC2 instances, S3 bucket, ALB |
| [`outputs.tf`](outputs.tf) | Values printed after `apply` |

---

## Variables

| Name | Default | Description |
|---|---|---|
| `public_subnet_cidrs` | `{ us-east-1a = "10.0.1.0/24", us-east-1b = "10.0.2.0/24" }` | CIDR block per AZ for public subnets |
| `private_subnet_cidrs` | `{ us-east-1a = "10.0.10.0/24", us-east-1b = "10.0.11.0/24" }` | CIDR block per AZ for private subnets |

Instances are defined in [`locals.tf`](locals.tf). To add, remove, or resize an instance edit the `instances` map — the key becomes the `Name` tag. Any instance whose key is `db` is automatically excluded from the ALB target group.

---

## Usage

```bash
# Download the AWS provider plugin
terraform init

# Preview changes
terraform plan

# Create all resources (~3–5 min, NAT gateway takes longest)
terraform apply
```

### Destroy

```bash
terraform destroy
```

> **Before destroying:** the ALB has `enable_deletion_protection = true`. Set it to `false` (edit [`main.tf`](main.tf) and run `terraform apply`) before `terraform destroy` will succeed.

---

## Outputs

| Output | Description |
|---|---|
| `alb_dns_name` | Public DNS of the load balancer — use with `curl` to test |
| `instance_ids` | Map of instance name → instance ID (for SSM sessions) |
| `instance_ips` | Map of instance name → public IP |
| `target_group_arn` | ARN of the app target group (for `describe-target-health`) |
| `bucket_name` | Name of the S3 bucket storing ALB access logs |
| `vpc_id` | ID of the created VPC |

### Connect to an instance

```bash
aws ssm start-session --target $(terraform output -json instance_ids | jq -r '.web')
```

### Test the load balancer

```bash
curl http://$(terraform output -raw alb_dns_name)
```

The ALB health check polls `GET /health` on port 8080 every 30 s (3 consecutive passes/failures to change state).

---

## Security group rules

### ALB — `test-lb-sg`

| Direction | Protocol | Port | Source/Dest |
|---|---|---|---|
| Ingress | TCP | 80 | `0.0.0.0/0` |
| Ingress | TCP | 443 | `0.0.0.0/0` |
| Egress | all | — | `0.0.0.0/0` |

### App instances — `test-app-sg`

| Direction | Protocol | Port | Source/Dest |
|---|---|---|---|
| Ingress | TCP | 8080 | `test-lb-sg` (security group reference) |
| Egress | all | — | `0.0.0.0/0` |

---

## Notes

- **`db` is not an ALB target.** The [`aws_lb_target_group_attachment`](main.tf) resource explicitly skips any instance named `db`.
- **Stopped-instance check.** A Terraform `check` block in [`main.tf`](main.tf) asserts that no instances in the account/region are in a `stopped` state. A failure surfaces as a warning — it does not block `apply`.
- **Hardcoded AMI.** Instances use `ami-0f9f41a981329c67b` (valid in `us-east-1` only). A dynamic `aws_ami` data source for HashiCorp base Ubuntu 24.04 is declared in [`main.tf`](main.tf) but not yet wired to the instances.
- **Single NAT gateway.** Placed in `us-east-1a` only. An outage in that AZ removes outbound internet for private instances in both AZs.
