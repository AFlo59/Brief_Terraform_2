import os
from pathlib import Path
from typing import List, Tuple

from dotenv import load_dotenv
from loguru import logger

load_dotenv()


def list_parquet_files() -> List[Tuple[str, str]]:
    use_azure = os.getenv("AZURE_STORAGE_CONNECTION_STRING") is not None
    fichiers = []

    if use_azure:
        fichiers = _list_parquet_files_azure()
    else:
        fichiers = _list_parquet_files_local()

    logger.info(f"Fichiers parquet trouvés : {len(fichiers)}")
    return fichiers


def _list_parquet_files_azure() -> List[Tuple[str, str]]:
    logger.info("Récupération des fichiers depuis Azure Blob Storage...")

    try:
        from azure.storage.blob import BlobServiceClient

        connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        container_name = os.getenv("AZURE_CONTAINER_NAME", "raw")

        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        container_client = blob_service_client.get_container_client(container_name)

        fichiers = []
        blobs = container_client.list_blobs()
        for blob in blobs:
            if blob.name.endswith(".parquet"):
                fichiers.append(("azure", blob.name))

        logger.success(f"Trouvé {len(fichiers)} fichiers dans Azure ({container_name})")
        return fichiers

    except Exception as e:
        logger.error(f"Erreur lors de la récupération depuis Azure: {e}")
        raise


def _list_parquet_files_local() -> List[Tuple[str, str]]:
    logger.info("Récupération des fichiers depuis local...")

    dossier = Path("data/raw")

    if not dossier.exists():
        logger.warning(f"Dossier {dossier} n'existe pas")
        return []

    fichiers = []
    for fichier in dossier.glob("*.parquet"):
        fichiers.append(("local", str(fichier)))

    logger.success(f"Trouvé {len(fichiers)} fichiers dans {dossier}")
    return fichiers


def load_parquet_from_azure(blob_name: str):
    from azure.storage.blob import BlobServiceClient

    connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
    container_name = os.getenv("AZURE_CONTAINER_NAME", "raw")

    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    blob_client = blob_service_client.get_blob_client(container=container_name, blob=blob_name)

    blob_data = blob_client.download_blob().readall()
    return blob_data


def is_using_azure() -> bool:
    return os.getenv("AZURE_STORAGE_CONNECTION_STRING") is not None
