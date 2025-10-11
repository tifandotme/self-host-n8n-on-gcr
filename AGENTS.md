This repo is a fork of <https://github.com/datawranglerai/self-host-n8n-on-gcr> with my own modifications.

Always read these files at the start of conversation:

- terraform/main.tf
- terraform/variables.tf
- terraform/terraform.tfvars.example
- MAINTENANCE.md
- COSTS.md
- Dockerfile
- startup.sh
- mise.toml
- README.md

Never run terraform's `apply` or `destroy` commands, especially from mise `terraform:deploy` and `terraform:destroy` task.

Always run `mise run terraform:check` after you reconfigure terraform.
