terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  backend "gcs" {
    bucket = "n8n-terraform-state-bucket"
    prefix = "n8n"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Data source to get the project number
data "google_project" "project" {
  project_id = var.gcp_project_id
}

# --- Services --- #
resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "cloudscheduler" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = true
}

# --- Artifact Registry (Optional - only for custom image) --- #
resource "google_artifact_registry_repository" "n8n_repo" {
  count         = var.use_custom_image ? 1 : 0
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = var.artifact_repo_name
  description   = "Repository for n8n workflow images"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifactregistry]
}

# --- Secret Manager --- #
resource "google_secret_manager_secret" "actual_password_secret" {
  secret_id = "n8n-actual-password"
  project   = var.gcp_project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "actual_password_secret_version" {
  secret      = google_secret_manager_secret.actual_password_secret.id
  secret_data = var.actual_password
}

resource "google_secret_manager_secret" "db_password_secret" {
  secret_id = "n8n-db-password"
  project   = var.gcp_project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password_secret.id
  secret_data = var.db_password
}

resource "random_password" "n8n_encryption_key" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "encryption_key_secret" {
  secret_id = "${var.cloud_run_service_name}-encryption-key"
  project   = var.gcp_project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "encryption_key_secret_version" {
  secret      = google_secret_manager_secret.encryption_key_secret.id
  secret_data = random_password.n8n_encryption_key.result
}

resource "google_secret_manager_secret" "license_activation_key_secret" {
  secret_id = "n8n-license-activation-key"
  project   = var.gcp_project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "license_activation_key_secret_version" {
  secret      = google_secret_manager_secret.license_activation_key_secret.id
  secret_data = var.license_activation_key
}

# --- IAM Service Account & Permissions --- #
resource "google_service_account" "n8n_sa" {
  account_id   = var.service_account_name
  display_name = "n8n Service Account for Cloud Run"
  project      = var.gcp_project_id
}

resource "google_secret_manager_secret_iam_member" "actual_password_secret_accessor" {
  project   = google_secret_manager_secret.actual_password_secret.project
  secret_id = google_secret_manager_secret.actual_password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "db_password_secret_accessor" {
  project   = google_secret_manager_secret.db_password_secret.project
  secret_id = google_secret_manager_secret.db_password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "encryption_key_secret_accessor" {
  project   = google_secret_manager_secret.encryption_key_secret.project
  secret_id = google_secret_manager_secret.encryption_key_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "license_activation_key_secret_accessor" {
  project   = google_secret_manager_secret.license_activation_key_secret.project
  secret_id = google_secret_manager_secret.license_activation_key_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"
}

# --- Cloud Run Service --- #
locals {
  # Use official image or custom image based on variable
  n8n_image = var.use_custom_image ? "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${var.artifact_repo_name}/${var.cloud_run_service_name}:latest" : "docker.io/n8nio/n8n:latest"

  # Port configuration differs between options
  n8n_port = var.use_custom_image ? "443" : "5678"

  # User folder differs between options
  n8n_user_folder = var.use_custom_image ? "/home/node" : "/home/node/.n8n"
}

resource "google_cloud_run_v2_service" "n8n" {
  name     = var.cloud_run_service_name
  location = var.gcp_region
  project  = var.gcp_project_id

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.n8n_sa.email
    scaling {
      max_instance_count = var.cloud_run_max_instances
      min_instance_count = 0
    }
    containers {
      image = local.n8n_image

      # Set command and args for official image (Option A)
      command = var.use_custom_image ? null : ["/bin/sh"]
      args    = var.use_custom_image ? null : ["-c", "sleep 5; n8n start"]

      ports {
        container_port = var.cloud_run_container_port
      }
      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
        startup_cpu_boost = true
        cpu_idle          = false # This is --no-cpu-throttling
      }

      # Only set N8N_PATH for custom image
      dynamic "env" {
        for_each = var.use_custom_image ? [1] : []
        content {
          name  = "N8N_PATH"
          value = "/"
        }
      }

      env {
        name  = "N8N_PORT"
        value = local.n8n_port
      }
      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = var.db_name
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = var.db_user
      }
      env {
        name  = "DB_POSTGRESDB_HOST"
        value = var.db_host
      }
      env {
        name  = "DB_POSTGRESDB_PORT"
        value = var.db_port
      }
      env {
        name  = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name  = "DB_POSTGRESDB_SSL"
        value = "require"
      }
      env {
        name  = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED"
        value = "false"
      }
      env {
        name  = "N8N_USER_FOLDER"
        value = local.n8n_user_folder
      }
      env {
        name  = "GENERIC_TIMEZONE"
        value = var.generic_timezone
      }
      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }
      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_key_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "N8N_LICENSE_ACTIVATION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.license_activation_key_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "N8N_HIDE_USAGE_PAGE"
        value = "true"
      }
      env {
        name  = "N8N_HOST"
        value = var.custom_domain
      }
      env {
        name  = "WEBHOOK_URL"
        value = "https://${var.custom_domain}"
      }
      env {
        name  = "N8N_EDITOR_BASE_URL"
        value = "https://${var.custom_domain}"
      }
      env {
        name  = "N8N_RUNNERS_ENABLED"
        value = "true"
      }
      env {
        name  = "N8N_PROXY_HOPS"
        value = "1"
      }
      env {
        name  = "NODE_FUNCTION_ALLOW_EXTERNAL"
        value = "@actual-app/api"
      }
      env {
        # Enabled insecure mode if using ALLOW_EXTERNAL, else Code executions hangs
        name  = "N8N_RUNNERS_INSECURE_MODE"
        value = "true"
      }
      env {
        name  = "N8N_RUNNERS_ALLOW_PROTOTYPE_MUTATION"
        value = "true"
      }
      env {
        name  = "NODE_FUNCTION_ALLOW_BUILTIN"
        value = "*"
      }

      // Actual
      env {
        name  = "ACTUAL_SERVER_URL"
        value = "https://${var.actual_server_url}"
      }
      env {
        name  = "ACTUAL_SYNC_ID"
        value = var.actual_sync_id
      }
      env {
        name = "ACTUAL_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.actual_password_secret.secret_id
            version = "latest"
          }
        }
      }

      # Disable diagnostics
      env {
        name  = "N8N_DIAGNOSTICS_ENABLED"
        value = "false"
      }
      env {
        name  = "N8N_VERSION_NOTIFICATIONS_ENABLED"
        value = "false"
      }
      env {
        name  = "EXTERNAL_FRONTEND_HOOKS_URLS"
        value = ""
      }
      env {
        name  = "N8N_DIAGNOSTICS_CONFIG_FRONTEND"
        value = ""
      }
      env {
        name  = "N8N_DIAGNOSTICS_CONFIG_BACKEND"
        value = ""
      }

      # Security
      env {
        name  = "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS"
        value = "true"
      }
      env {
        name  = "N8N_BLOCK_ENV_ACCESS_IN_NODE	"
        value = "false" # default is true
      }
      env {
        name  = "N8N_GIT_NODE_DISABLE_BARE_REPOS	"
        value = "true"
      }

      env {
        # https://docs.n8n.io/hosting/configuration/environment-variables/endpoints/
        # The interval (in seconds) at which the insights data should be flushed to the database.
        # Defaults to 30 seconds, which triggers the runtime
        name  = "N8N_INSIGHTS_FLUSH_INTERVAL_SECONDS"
        value = "1800"
      }
      env {
        # https://docs.n8n.io/hosting/configuration/environment-variables/logs/#n8n-logs
        # Output logs without ANSI colors
        name  = "NO_COLOR"
        value = "true"
      }

      startup_probe {
        initial_delay_seconds = 30
        timeout_seconds       = 240
        period_seconds        = 240
        failure_threshold     = 3
        http_get {
          path = "/healthz/readiness"
          port = var.cloud_run_container_port
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.run,
    google_secret_manager_secret_iam_member.actual_password_secret_accessor,
    google_secret_manager_secret_iam_member.db_password_secret_accessor,
    google_secret_manager_secret_iam_member.encryption_key_secret_accessor,
    google_secret_manager_secret_iam_member.license_activation_key_secret_accessor
  ]
}

resource "google_cloud_run_v2_service_iam_member" "n8n_public_invoker" {
  project  = google_cloud_run_v2_service.n8n.project
  location = google_cloud_run_v2_service.n8n.location
  name     = google_cloud_run_v2_service.n8n.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Domain mapping for custom domain
resource "google_cloud_run_domain_mapping" "n8n_domain" {
  count    = 1
  name     = var.custom_domain
  location = var.gcp_region
  metadata {
    namespace = var.gcp_project_id
  }
  spec {
    route_name = google_cloud_run_v2_service.n8n.name
  }
}

# Cloud Scheduler jobs to wake up n8n at specified times
resource "google_cloud_scheduler_job" "n8n_wake_up" {
  for_each = { for idx, time in var.scheduler_times : idx => time }

  description = "Wake up n8n at specified times"
  name        = "n8n-wake-up-${each.key}"
  schedule    = each.value
  time_zone   = var.generic_timezone

  http_target {
    uri         = "https://${var.custom_domain}"
    http_method = "GET"
  }

  retry_config {
    retry_count = 3
  }

  depends_on = [google_project_service.cloudscheduler]
}
