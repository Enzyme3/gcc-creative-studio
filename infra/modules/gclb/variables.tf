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
  description = "The GCP region for the Serverless NEGs."
}

variable "environment" {
  type        = string
  description = "The deployment environment name (e.g., 'dev')."
}

variable "resource_prefix" {
  type        = string
  description = "A short prefix for resource names."
}

variable "custom_domain" {
  type        = string
  description = "The custom domain name for the HTTPS Load Balancer (e.g. studio.example.com)."
}

variable "frontend_service_name" {
  type        = string
  description = "The name of the frontend Cloud Run service."
}

variable "backend_service_name" {
  type        = string
  description = "The name of the backend Cloud Run service."
}

variable "iap_oauth2_client_id" {
  type        = string
  description = "OAuth2 Client ID for Identity-Aware Proxy."
}

variable "iap_oauth2_client_secret" {
  type        = string
  description = "OAuth2 Client Secret for Identity-Aware Proxy."
  sensitive   = true
}
