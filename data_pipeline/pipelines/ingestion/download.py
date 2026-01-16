import os
import sys
from datetime import datetime
from pathlib import Path

# Ajouter le répertoire racine au PYTHONPATH
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dateutil.relativedelta import relativedelta
from dotenv import load_dotenv
from loguru import logger

from utils.download_helper import (
    build_file_path,
    build_url_from_template,
    download_file_from_url,
    save_file_locally,
    upload_file_to_azure,
)

load_dotenv()


def generer_liste_mois(date_debut, date_fin=None):
    debut = datetime.strptime(date_debut, "%Y-%m")

    if not date_fin:
        fin = datetime.now()
    else:
        fin = datetime.strptime(date_fin, "%Y-%m")

    liste_mois = []
    date_courante = debut

    while date_courante <= fin:
        liste_mois.append((date_courante.year, date_courante.month))
        date_courante += relativedelta(months=1)

    return liste_mois


def telecharger_fichier(annee, mois):
    url_template = (
        "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{annee}-{mois:02d}.parquet"
    )

    url = build_url_from_template(url_template, annee=annee, mois=mois)

    return download_file_from_url(url, timeout=60)


def sauvegarder_local(contenu, annee, mois):
    nom_fichier = f"yellow_tripdata_{annee}-{mois:02d}.parquet"
    chemin = build_file_path("data/raw", nom_fichier)
    save_file_locally(contenu, chemin)


def uploader_vers_azure(contenu, annee, mois):
    container_name = os.getenv("AZURE_CONTAINER_NAME", "raw")
    blob_name = f"yellow_tripdata_{annee}-{mois:02d}.parquet"
    upload_file_to_azure(
        contenu, blob_name=blob_name, container_name=container_name, create_container=True
    )


def telecharger_donnees_taxi():
    date_debut = os.getenv("START_DATE")
    date_fin = os.getenv("END_DATE")

    if not date_debut:
        raise ValueError("START_DATE doit être défini dans .env")

    liste_mois = generer_liste_mois(date_debut, date_fin)

    logger.info(f"{len(liste_mois)} fichiers à télécharger\n")

    # USE_LOCAL=true force le stockage local même si AZURE_STORAGE_CONNECTION_STRING existe
    use_local = os.getenv("USE_LOCAL", "false").lower() == "true"
    has_azure_creds = os.getenv("AZURE_STORAGE_CONNECTION_STRING") is not None

    if use_local:
        logger.info("Mode local activé (USE_LOCAL=true) - Stockage sur disque local")
        storage_mode = "local"
    elif has_azure_creds:
        logger.info("Mode Azure activé - Stockage sur Azure Blob Storage")
        storage_mode = "azure"
    else:
        logger.info("Mode local activé (pas de credentials Azure)")
        storage_mode = "local"

    for annee, mois in liste_mois:
        contenu = telecharger_fichier(annee, mois)

        if contenu is None:
            logger.warning(f"Fichier {annee}-{mois:02d} non disponible, passage au suivant")
            continue

        if storage_mode == "azure":
            # Upload vers Azure ET sauvegarde locale (pour Pipeline 2)
            uploader_vers_azure(contenu, annee, mois)
            sauvegarder_local(contenu, annee, mois)
            logger.info(f"  → Aussi sauvegardé localement pour Pipeline 2")
        else:
            sauvegarder_local(contenu, annee, mois)

    logger.success("\nTéléchargement terminé")


if __name__ == "__main__":
    logger.info("Démarrage de la Pipeline 1 : Téléchargement des données\n")
    telecharger_donnees_taxi()
