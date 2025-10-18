variable "gcp_project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "gcp_region" {
  description = "Google Cloud region for deployment."
  type        = string
}

variable "use_custom_image" {
  description = "Set to true to use custom Docker image (Option B), false to use official n8n image (Option A - recommended)."
  type        = bool
  default     = false
}

variable "db_host" {
  description = "External database host."
  type        = string
}

variable "db_name" {
  description = "External database name."
  type        = string
  default     = "neondb"
}

variable "db_user" {
  description = "External database user."
  type        = string
  default     = "neondb_owner"
}

variable "db_password" {
  description = "External database password."
  type        = string
  sensitive   = true
}


variable "db_port" {
  description = "External database port."
  type        = string
  default     = "5432"
}


variable "artifact_repo_name" {
  description = "Name for the Artifact Registry repository (only used if use_custom_image is true)."
  type        = string
  default     = "n8n-repo"
}

variable "cloud_run_service_name" {
  description = "Name for the Cloud Run service."
  type        = string
  default     = "n8n"
}

variable "service_account_name" {
  description = "Name for the IAM service account."
  type        = string
  default     = "n8n-service-account"
}

variable "cloud_run_cpu" {
  description = "CPU allocation for Cloud Run service."
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory allocation for Cloud Run service."
  type        = string
  default     = "2Gi"
}

variable "cloud_run_max_instances" {
  description = "Maximum number of instances for Cloud Run service."
  type        = number
  default     = 1
}

variable "cloud_run_container_port" {
  description = "Internal port the n8n container listens on."
  type        = number
  default     = 5678
}

variable "generic_timezone" {
  description = "Timezone for n8n."
  type        = string
  default     = "UTC"
}

variable "actual_server_url" {
  description = "Domain of the Actual Budget server."
  type        = string
}

variable "actual_password" {
  description = "Password for the Actual Budget server."
  type        = string
  sensitive   = true
}

variable "actual_sync_id" {
  description = "Sync ID of the Actual Budget."
  type        = string
}

variable "scheduler_times" {
  description = "List of cron schedules in the local time of generic_timezone for waking up n8n Cloud Run service."
  type        = list(string)
}

variable "custom_domain" {
  description = "Custom domain to map to the n8n service."
  type        = string
}

variable "license_activation_key" {
  description = "Activation key for n8n license."
  type        = string
  sensitive   = true
}
