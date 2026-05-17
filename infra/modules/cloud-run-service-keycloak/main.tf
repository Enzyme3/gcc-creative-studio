# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# --- Service Account ---
resource "google_service_account" "run_sa" {
  account_id   = "${var.resource_prefix}-${var.environment}-run"
  display_name = "SA for ${var.service_name} (${var.environment}) Runtime"
}

# --- Core Resources ---
resource "google_cloud_run_v2_service" "this" {
  name                = var.service_name
  location            = var.gcp_region
  deletion_protection = false

  template {
    service_account = google_service_account.run_sa.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloud_sql_instance_connection_name]
      }
    }

    containers {
      image = "quay.io/keycloak/keycloak:24.0.1"
      args  = ["start", "--optimized"]

      resources {
        limits = {
          cpu    = "2000m"
          memory = "2048Mi"
        }
      }

      # Database configuration
      env {
        name  = "KC_DB"
        value = "postgres"
      }
      env {
        name  = "KC_DB_URL"
        value = "jdbc:postgresql:///keycloak?host=/cloudsql/${var.cloud_sql_instance_connection_name}"
      }
      env {
        name  = "KC_DB_USERNAME"
        value = var.db_user
      }
      env {
        name = "KC_DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_secret_id
            version = "latest"
          }
        }
      }

      # Hardcoded Admin credentials
      env {
        name  = "KEYCLOAK_ADMIN"
        value = "admin"
      }
      env {
        name  = "KEYCLOAK_ADMIN_PASSWORD"
        value = "admin"
      }

      # Proxy settings for GCLB
      env {
        name  = "KC_PROXY"
        value = "edge"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
}

# --- IAM Bindings ---

# Allow Keycloak to talk to Cloud SQL Auth Proxy
resource "google_project_iam_member" "cloudsql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

# Allow Keycloak to read the DB password secret
resource "google_secret_manager_secret_iam_member" "db_password_access" {
  secret_id = var.db_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

# Allow public access to Keycloak so users can load login screens
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
