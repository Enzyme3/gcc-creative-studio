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

# --- Static Global IP Address ---
resource "google_compute_global_address" "default" {
  name = "${var.resource_prefix}-${var.environment}-ip"
}

# --- Google-Managed SSL Certificate ---
resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.resource_prefix}-${var.environment}-cert"

  managed {
    domains = [var.custom_domain]
  }
}

# --- Serverless Network Endpoint Groups (NEGs) ---
resource "google_compute_region_network_endpoint_group" "frontend" {
  name                  = "${var.resource_prefix}-${var.environment}-fe-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  cloud_run {
    service = var.frontend_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "backend" {
  name                  = "${var.resource_prefix}-${var.environment}-be-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  cloud_run {
    service = var.backend_service_name
  }
}

# --- Compute Backend Services with Native IAP ---
resource "google_compute_backend_service" "frontend" {
  name                  = "${var.resource_prefix}-${var.environment}-fe-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.frontend.id
  }

  iap {
    enabled              = true
    oauth2_client_id     = var.iap_oauth2_client_id
    oauth2_client_secret = var.iap_oauth2_client_secret
  }
}

resource "google_compute_backend_service" "backend" {
  name                  = "${var.resource_prefix}-${var.environment}-be-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }

  iap {
    enabled              = true
    oauth2_client_id     = var.iap_oauth2_client_id
    oauth2_client_secret = var.iap_oauth2_client_secret
  }
}

# --- URL Map for Path-Based Routing ---
resource "google_compute_url_map" "default" {
  name            = "${var.resource_prefix}-${var.environment}-url-map"
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = [var.custom_domain]
    path_matcher = "all-paths"
  }

  path_matcher {
    name            = "all-paths"
    default_service = google_compute_backend_service.frontend.id

    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.backend.id
    }
  }
}

# --- Target HTTPS Proxy ---
resource "google_compute_target_https_proxy" "default" {
  name             = "${var.resource_prefix}-${var.environment}-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

# --- Global Forwarding Rule ---
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "${var.resource_prefix}-${var.environment}-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.id
  ip_address            = google_compute_global_address.default.id
}
