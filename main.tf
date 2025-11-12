terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# ============================
# REQUIRED: EDIT THESE VALUES
# ============================

# 1) Your GCP project ID
# 2) Your Flask Docker image in a registry (Docker Hub / Artifact Registry)
#    Example: "docker.io/YOUR_DOCKERHUB_NAME/allen-flask:latest"

provider "google" {
  project = "lofty-inn-259017"
  region  = "northamerica-northeast1"
  zone    = "northamerica-northeast1-b"
  credentials = file("lofty-inn-259017-758dfca62881.json")
}

# ============================
# VPC & SUBNETS
# ============================

resource "google_compute_network" "allen_vpc" {
  name                    = "allen-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "allen_public_subnet" {
  name          = "allen-public-subnet"
  region        = "northamerica-northeast1"
  network       = google_compute_network.allen_vpc.id
  ip_cidr_range = "10.0.1.0/24"
}

resource "google_compute_subnetwork" "allen_private_subnet" {
  name          = "allen-private-subnet"
  region        = "northamerica-northeast1"
  network       = google_compute_network.allen_vpc.id
  ip_cidr_range = "10.0.2.0/24"
}

# ============================
# FIREWALL (SSH + Flask port)
# ============================

resource "google_compute_firewall" "allen_allow_ssh_http" {
  name    = "allen-allow-ssh-http"
  network = google_compute_network.allen_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "5000"]
  }

  # For assignment/demo only. In real life, lock this down.
  source_ranges = ["0.0.0.0/0"]

  target_tags = ["allen-flask"]
}

# ============================
# STATIC PUBLIC IP
# ============================

resource "google_compute_address" "allen_flask_ip" {
  name   = "allen-flask-ip"
  region = "northamerica-northeast1"
}

# ============================
# BASE IMAGE FOR VM
# ============================

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

# ============================
# COMPUTE ENGINE INSTANCE
# Runs your Dockerized Flask app
# ============================

resource "google_compute_instance" "allen_flask_vm" {
  name         = "allen-flask-vm"
  machine_type = "e2-micro"
  zone         = "northamerica-northeast1-b"
  tags         = ["allen-flask"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.allen_public_subnet.self_link

    access_config {
      nat_ip = google_compute_address.allen_flask_ip.address
    }
  }

  # Container is part of the instance via startup script
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io -y

    systemctl enable docker
    systemctl start docker

    docker rm -f flask || true

    # Pull and run your Flask Docker image
    docker pull docker.io/daniel082198/allen-flask:latest

    docker run -d --name flask -p 5000:5000 docker.io/daniel082198/allen-flask:latest
  EOF
}
