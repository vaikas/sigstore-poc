resource "google_container_registry" "registry" {
  project  = var.PROJECT_ID
  location = "US"
}

resource "google_service_account" "gke_user" {
  account_id   = "gke-user-${var.workspace_id}"
  display_name = "GKE Service Account"
  project      = var.PROJECT_ID
}

resource "google_project_iam_member" "gcr_member" {
  project = var.PROJECT_ID
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_user.email}"
}

resource "google_service_account" "gke_workload" {
  account_id   = "${var.workspace_id}-user-workload"
  display_name = "GKE Service Account Workload user"
  project      = var.PROJECT_ID
}

resource "google_service_account_iam_member" "workload_account_iam" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[default/gke-user]"
  service_account_id = google_service_account.gke_workload.name
  depends_on         = [google_service_account.gke_workload]
}

resource "google_project_iam_member" "storage_admin_member" {
  project    = var.PROJECT_ID
  role       = "roles/storage.admin"
  member     = "serviceAccount:${google_service_account.gke_workload.email}"
  depends_on = [google_service_account.gke_workload]
}

resource "google_project_iam_member" "private_ca_member" {
  project    = var.PROJECT_ID
  role       = "roles/privateca.admin"
  member     = "serviceAccount:${google_service_account.gke_workload.email}"
  depends_on = [google_service_account.gke_workload]
}

resource "kubernetes_service_account" "gcr" {
  metadata {
    name = "gke-user"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gke_workload.email
    }
  }
}

resource "google_container_cluster" "primary" {
  name               = "chainguard-dev-${var.workspace_id}"
  location           = var.CLUSTER_LOCATION != "" ? var.CLUSTER_LOCATION : var.DEFAULT_LOCATION
  project            = var.PROJECT_ID
  initial_node_count = 2
  node_config {
    machine_type = "n1-standard-4"
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_user.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  timeouts {
    create = "30m"
    update = "40m"
  }
  workload_identity_config {
    workload_pool = "${var.PROJECT_ID}.svc.id.goog"
  }
}


