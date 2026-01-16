# =============================================================================
# Terraform + Azure CLI Docker Image
# =============================================================================
# Cette image fournit un environnement Terraform avec Azure CLI pré-installé
# pour gérer l'infrastructure du projet NYC Taxi Pipeline
# =============================================================================

FROM hashicorp/terraform:1.7.0

# Métadonnées de l'image
LABEL maintainer="NYC Taxi Pipeline Project"
LABEL description="Terraform workspace with Azure CLI for infrastructure management"
LABEL version="1.0"

# Installation des dépendances et Azure CLI
RUN apk add --no-cache \
    bash \
    curl \
    python3 \
    py3-pip \
    jq \
    git \
    openssh-client \
    && pip3 install --no-cache-dir --break-system-packages azure-cli

# Création du répertoire de travail
WORKDIR /workspace

# Variables d'environnement pour Azure CLI
ENV AZURE_CONFIG_DIR=/workspace/.azure
ENV TF_LOG_PATH=/workspace/logs/terraform.log

# Script d'entrée pour le login Azure
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Volume pour persister l'état Terraform et les configs Azure
VOLUME ["/workspace"]

# Point d'entrée personnalisé
ENTRYPOINT ["/entrypoint.sh"]

# Commande par défaut : shell interactif
CMD ["bash"]
