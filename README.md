# 🚀 End-to-End Crypto Streaming Platform (Infrastructure)

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4.svg?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Oracle Cloud](https://img.shields.io/badge/OCI-Always%20Free-F80000.svg?style=for-the-badge&logo=oracle)](https://cloud.oracle.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg?style=for-the-badge&logo=docker)](https://www.docker.com/)

> **Author:** Jonas
> **Status:** Phase 1 (Infrastructure as Code Deployed)

## 📖 Overview
This repository contains the foundational **Infrastructure as Code (IaC)** for an automated cryptocurrency quantitative analysis and trading platform. 

The architecture is entirely cloud-native, strictly governed by **FinOps** principles to run efficiently on the Oracle Cloud Infrastructure (OCI) Always Free tier. It provisions a robust, Zero-Trust network environment designed to host high-throughput streaming systems (Redpanda/Kafka) and stateful stream processing engines (Apache Flink).

Detailed architectural design, data flows, and state management strategies can be found in the [Architecture Documentation](./docs/architecture.md).

## 🛠 Tech Stack
* **Cloud Provider:** Oracle Cloud Infrastructure (OCI)
* **IaC Tool:** HashiCorp Terraform
* **Compute:** OCI Ampere A1 (ARM, 4 ECPUs, 24GB RAM)
* **Database (Warm Data):** Autonomous Data Warehouse (ADW)
* **Storage (Cold Data):** OCI Object Storage
* **Containerization:** Docker & OCI Container Registry (OCIR)

## 📁 Repository Structure
The Terraform codebase is modularized by domain to ensure maintainability and scalability:

```text
crypto-streaming-iac/
├── docs/                     
│   └── architecture.md       # Technical design and data flow diagrams
├── templates/                
│   └── cloud-init.tftpl      # VM bootstrapping script (Docker, Swap, OS configs)
├── compute.tf                # ARM VM provisioning and storage attachment
├── database.tf               # Autonomous Data Warehouse (ADW) setup
├── iam.tf                    # Dynamic groups & Resource Principal policies
├── network.tf                # VCN, Subnets, Gateways, and Security Lists (ACLs)
├── storage.tf                # Object Storage buckets
├── monitoring.tf             # FinOps budgets and usage alerts
├── main.tf                   # Dynamic IP resolution and OCIR configurations
├── variables.tf              # Input variables definitions
└── terraform.tfvars.example  # Template for sensitive credentials