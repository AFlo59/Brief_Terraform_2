# 🏗️ Architecture

## Vue d'ensemble

Le projet déploie une infrastructure Azure complète pour analyser les données des taxis de New York.

## Diagramme d'architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AZURE - francecentral                         │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Resource Group: rg-nyctaxi-{env}                                 │  │
│  │                                                                   │  │
│  │  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │  │
│  │  │  Storage Account │  │ Container       │  │  Log Analytics   │  │  │
│  │  │  st-nyctaxi-xxx  │  │ Registry (ACR)  │  │  Workspace       │  │  │
│  │  │                  │  │ acr-nyctaxi-xxx │  │                  │  │  │
│  │  │  📁 raw 📁      │  │                 │  │  📊 Logs 📊     │  │  │
│  │  │  📁 processed 📁│  │  🐳 Images 🐳  │  │  📈 Metrics 📈  │  │  │
│  │  └──────────────────┘  └─────────────────┘  └──────────────────┘  │  │
│  │           │                    │                    │             │  │
│  │           ▼                    ▼                    ▼             │  │
│  │  ┌────────────────────────────────────────────────────────────┐   │  │
│  │  │  Container Apps Environment: cae-nyctaxi-{env}             │   │  │
│  │  │                                                            │   │  │
│  │  │  ┌──────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  Container App: ca-nyctaxi-pipeline-{env}            │  │   │  │
│  │  │  │                                                      │  │   │  │
│  │  │  │  🔄 Pipeline 1: Download NYC Taxi Data 🔄           │  │   │  │
│  │  │  │  🔄 Pipeline 2: Load to PostgreSQL 🔄               │  │   │  │
│  │  │  │  🔄 Pipeline 3: Transform (Star Schema) 🔄          │  │   │  │
│  │  │  └──────────────────────────────────────────────────────┘  │   │  │
│  │  └────────────────────────────────────────────────────────────┘   │  │
│  │                              │                                    │  │
│  │                              ▼                                    │  │
│  │  ┌────────────────────────────────────────────────────────────┐   │  │
│  │  │  Cosmos DB for PostgreSQL (Citus): cosmos-nyctaxi-{env}    │   │  │
│  │  │                                                            │   │  │
│  │  │  📋 staging_taxi_trips    📋 dim_datetime                 │   │  │
│  │  │  📋 dim_location          📋 dim_payment                  │   │  │
│  │  │  📋 dim_vendor            📋 fact_trips                   │   │  │
│  │  └────────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Composants

### 1. Resource Group
- **Nom**: `rg-nyctaxi-{environment}`
- **Région**: francecentral
- Conteneur logique pour toutes les ressources

### 2. Storage Account
- **Nom**: `st{project}{random}` (globalement unique)
- **Type**: General Purpose v2
- **Réplication**: LRS (dev) / GRS (prod)
- **Containers**:
  - `raw`: Fichiers Parquet bruts téléchargés
  - `processed`: Fichiers transformés (optionnel)

### 3. Container Registry (ACR)
- **Nom**: `acr{project}{random}` (globalement unique)
- **SKU**: Basic (dev) / Standard (rec) / Premium (prod)
- Stocke l'image Docker du pipeline

### 4. Cosmos DB for PostgreSQL
- **Nom**: `cosmos-nyctaxi-{environment}`
- **Edition**: BurstableMemoryOptimized (1 vCore)
- **Stockage**: 32 GB (dev) à 128 GB (prod)
- Base de données distribuée compatible PostgreSQL (Citus)

### 5. Log Analytics Workspace
- **Nom**: `log-nyctaxi-{environment}`
- **Rétention**: 30-90 jours selon environnement
- Centralise tous les logs et métriques

### 6. Container Apps Environment
- **Nom**: `cae-nyctaxi-{environment}`
- Environnement serverless pour les containers

### 7. Container App
- **Nom**: `ca-nyctaxi-pipeline-{environment}`
- Exécute le pipeline de données
- Scale to zero quand inactif

## Flux de données

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  NYC TLC     │     │   Storage    │     │  Container   │     │  Cosmos DB   │
│  (Source)    │────▶│   Account    │────▶│    App       │────▶│  PostgreSQL  │
│              │     │   (raw/)     │     │  (DuckDB)    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
    Internet            Blob Storage         Processing          Data Warehouse
```

## Sécurité

- **TLS 1.2** minimum sur Storage Account
- **SSL requis** pour PostgreSQL
- **Secrets** gérés via Container App secrets
- **Firewall** PostgreSQL: uniquement services Azure (0.0.0.0)
- **Private containers** dans Storage Account

## Coûts estimés

| Environnement | Coût mensuel (24/7) |
|---------------|---------------------|
| Dev           | ~60-80€             |
| Rec           | ~100-150€           |
| Prod          | ~200-300€           |

> 💡 **Conseil**: Utilisez `terraform destroy` en fin de journée pour économiser.
