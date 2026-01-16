# =============================================================================
# NYC Taxi Data Pipeline - Docker Image
# =============================================================================
# Image pour exécuter le pipeline de données localement ou sur Azure
# Utilise uv pour la gestion des dépendances Python
# =============================================================================

# Stage 1: Builder (avec uv)
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder

WORKDIR /app

# Copie des fichiers de dépendances
COPY pyproject.toml uv.lock ./

# Installation des dépendances avec uv
RUN uv sync --frozen --no-dev --compile-bytecode

# Copie du code source
COPY pipelines ./pipelines
COPY utils ./utils
COPY sql ./sql
COPY main.py ./

# Stage 2: Runtime
FROM python:3.11-slim-bookworm

# Installation des dépendances système (libpq pour psycopg2)
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copie l'environnement virtuel depuis le builder
COPY --from=builder /app/.venv /app/.venv

# Copie le code source depuis le builder
COPY --from=builder /app/pipelines ./pipelines
COPY --from=builder /app/utils ./utils
COPY --from=builder /app/sql ./sql
COPY --from=builder /app/main.py ./

# Variables d'environnement
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Script d'entrée
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Point d'entrée
ENTRYPOINT ["/entrypoint.sh"]

# Commande par défaut
CMD ["python", "main.py"]
