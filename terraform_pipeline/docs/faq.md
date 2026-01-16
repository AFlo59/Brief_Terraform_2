# ❓ FAQ - Questions Fréquentes

## Général

### Pourquoi utiliser Docker pour Terraform ?

**Avantages** :
- 🔒 Environnement isolé et reproductible
- 📦 Pas besoin d'installer Terraform localement
- 🔄 Même version pour toute l'équipe
- 🔑 Credentials Azure isolés dans le conteneur

### Puis-je utiliser Terraform sans Docker ?

Oui, installez Terraform directement :
1. [Téléchargez Terraform](https://www.terraform.io/downloads)
2. Ajoutez-le au PATH
3. Utilisez les mêmes commandes sans le conteneur

### Combien de temps prend le déploiement ?

| Ressource | Temps estimé |
|-----------|--------------|
| Resource Group | ~10 secondes |
| Storage Account | ~30 secondes |
| Container Registry | ~1 minute |
| **Cosmos DB PostgreSQL** | **5-10 minutes** |
| Log Analytics | ~30 secondes |
| Container Apps | ~2 minutes |
| **Total (première fois)** | **~10-15 minutes** |

> Note: Cosmos DB PostgreSQL est la ressource la plus longue à provisionner.

---

## Azure

### Quelle région utiliser ?

Le brief impose **francecentral**. C'est la région la plus proche et la plus adaptée pour la France.

### Puis-je utiliser Azure gratuit ?

Oui, mais attention :
- Crédit gratuit initial : ~170€
- Cosmos DB consomme rapidement le crédit (~50-70€/mois)
- Faites `terraform destroy` en fin de journée !

### Comment voir mes coûts Azure ?

1. Portail Azure → Cost Management + Billing
2. Cost Analysis → Sélectionnez votre Resource Group
3. Configurez des alertes budget !

### Dois-je créer un compte Azure spécifique ?

Non, votre compte personnel ou étudiant suffit. Vérifiez vos crédits disponibles.

---

## Terraform

### Quelle est la différence entre `plan` et `apply` ?

| Commande | Action |
|----------|--------|
| `terraform plan` | Prévisualise les changements sans les appliquer |
| `terraform apply` | Applique réellement les changements |

**Toujours** faire `plan` avant `apply` !

### Puis-je modifier une ressource existante ?

Oui, modifiez le fichier `.tf` ou `.tfvars` puis :
```bash
terraform plan   # Voir les changements
terraform apply  # Appliquer
```

Terraform détecte automatiquement les différences.

### Comment voir l'état actuel de l'infrastructure ?

```bash
# Liste des ressources
terraform state list

# Détails d'une ressource
terraform state show azurerm_storage_account.main

# État complet
terraform show
```

### Puis-je supprimer une seule ressource ?

```bash
terraform destroy \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars \
  -target=azurerm_container_app.pipeline
```

### Que se passe-t-il si je modifie une ressource dans Azure Portal ?

Terraform détectera la différence au prochain `plan`. Vous pouvez :
- Réappliquer avec Terraform (écrase les modifications manuelles)
- Importer l'état avec `terraform refresh`

---

## Secrets

### Où mettre mon mot de passe PostgreSQL ?

Dans `terraform/environments/secrets.tfvars` :
```hcl
postgres_admin_password = "VotreMotDePasse123!"
```

### Le fichier secrets.tfvars est-il versionné ?

**NON !** Il est dans `.gitignore`. Ne le commitez jamais.

### Puis-je utiliser des variables d'environnement ?

Oui, préfixez avec `TF_VAR_` :
```bash
export TF_VAR_postgres_admin_password="MonMotDePasse123!"
terraform apply -var-file=environments/dev.tfvars
```

---

## Docker

### Comment reconstruire l'image après modification ?

```powershell
.\scripts\windows\docker\update.ps1
# ou
.\scripts\windows\docker\build.ps1 -NoCache
```

### Les modifications Terraform sont-elles persistées ?

Oui ! Le dossier `terraform/` est monté comme volume. Vos fichiers `.tf`, `.tfvars` et le state sont persistés.

### Comment exécuter une commande sans mode interactif ?

```powershell
.\scripts\windows\docker\run.ps1 -Cmd "terraform plan"
```

---

## Environnements

### Puis-je déployer plusieurs environnements en même temps ?

Oui ! Chaque environnement est isolé :
```bash
# Terminal 1 - Dev
terraform apply -var-file=environments/dev.tfvars ...

# Terminal 2 - Rec (autre fenêtre)
terraform apply -var-file=environments/rec.tfvars ...
```

### Comment passer de dev à prod ?

Changez simplement le fichier de variables :
```bash
# Dev
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# Prod
terraform apply -var-file=environments/prod.tfvars -var-file=environments/secrets.tfvars
```

---

## Problèmes courants

### Mon Container App ne démarre pas

1. Vérifiez que l'image est dans ACR :
```bash
az acr repository list --name <acr-name>
```

2. Si non, pushhez-la d'abord (voir [Getting Started](./getting-started.md))

### J'ai une erreur "SKU not available"

Certains SKU ne sont pas disponibles dans toutes les régions. Utilisez :
- `BurstableMemoryOptimized` pour Cosmos DB avec 1 vCore
- `Basic` pour ACR en dev

### terraform apply échoue au milieu

```bash
# Réessayez simplement
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# Terraform reprend là où il s'est arrêté
```

### Comment économiser sur les coûts ?

1. **Destroy en fin de journée** :
```bash
terraform destroy -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

2. **Min replicas à 0** (déjà configuré par défaut)

3. **Utilisez dev, pas prod** pour les tests

---

## Ressources

### Où trouver plus d'aide ?

- [Documentation Terraform Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Cosmos DB PostgreSQL](https://learn.microsoft.com/en-us/azure/cosmos-db/postgresql/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/terraform+azure)

### Comment signaler un bug ?

1. Vérifiez le [Troubleshooting](./troubleshooting.md)
2. Consultez cette FAQ
3. Recherchez sur Stack Overflow
4. Documentez votre erreur avec les logs complets
