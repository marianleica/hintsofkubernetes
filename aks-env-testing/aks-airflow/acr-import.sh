#!/bin/bash
MY_ACR_REGISTRY="mydnsrandomnamebdgfj"

az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:airflow-pgbouncer-2025.03.05-1.23.1 --image airflow:airflow-pgbouncer-2024.01.19-1.21.0
az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:airflow-pgbouncer-exporter-2025.03.05-0.18.0 --image airflow:airflow-pgbouncer-exporter-2025.03.05-0.17.0
az acr import --name $MY_ACR_REGISTRY --source docker.io/bitnamisecure/postgresql:latest --image postgresql:latest
az acr import --name $MY_ACR_REGISTRY --source quay.io/prometheus/statsd-exporter:v0.26.1 --image statsd-exporter:v0.26.1 
az acr import --name $MY_ACR_REGISTRY --source quay.io/prometheus/statsd-exporter:v0.27.1 --image statsd-exporter:v0.27.1 
az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:3.1.0 --image airflow:3.1.0
az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:3.0.0 --image airflow:3.0.0
az acr import --name $MY_ACR_REGISTRY --source registry.k8s.io/git-sync/git-sync:v4.1.0 --image git-sync:v4.1.0