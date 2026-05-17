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

variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for the Cloud Run service."
}

variable "environment" {
  type        = string
  description = "The deployment environment (e.g., 'dev')."
}

variable "service_name" {
  type        = string
  description = "The name of the Keycloak Cloud Run service."
}

variable "resource_prefix" {
  type        = string
  description = "A short prefix for resource names."
}

variable "cloud_sql_instance_connection_name" {
  type        = string
  description = "The connection name of the Cloud SQL instance."
}

variable "db_user" {
  type        = string
  description = "The username for database connectivity."
}

variable "db_secret_id" {
  type        = string
  description = "The Secret Manager secret ID holding the database password."
}
