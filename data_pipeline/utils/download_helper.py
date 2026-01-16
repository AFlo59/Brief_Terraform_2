import os
from pathlib import Path
from typing import Optional

import requests
from loguru import logger


def download_file_from_url(url: str, timeout: int = 60) -> Optional[bytes]:
    logger.info(f"Téléchargement de {url}...")

    try:
        response = requests.get(url, timeout=timeout)

        if response.status_code == 200:
            size_mb = len(response.content) / 1024 / 1024
            logger.success(f"Fichier téléchargé avec succès ({size_mb:.2f} MB)")
            return response.content
        elif response.status_code == 404:
            logger.warning("Fichier non trouvé (404)")
            return None
        else:
            logger.error(f"Erreur HTTP {response.status_code}")
            return None

    except requests.exceptions.Timeout:
        logger.error(f"Timeout après {timeout} secondes")
        return None
    except Exception as e:
        logger.error(f"Erreur lors du téléchargement: {e}")
        return None


def save_file_locally(content: bytes, file_path: Path) -> bool:
    try:
        # Créer les dossiers parents si nécessaire
        file_path = Path(file_path)
        file_path.parent.mkdir(parents=True, exist_ok=True)

        # Écrire le fichier
        with open(file_path, "wb") as f:
            f.write(content)

        logger.success(f"Fichier sauvegardé : {file_path}")
        return True

    except Exception as e:
        logger.error(f"Erreur lors de la sauvegarde : {e}")
        return False


def upload_file_to_azure(
    content: bytes,
    blob_name: str,
    connection_string: Optional[str] = None,
    container_name: str = "raw",
    create_container: bool = True,
) -> bool:
    try:
        from azure.storage.blob import BlobServiceClient

        # Utiliser la connection string fournie ou celle de .env
        conn_str = connection_string or os.getenv("AZURE_STORAGE_CONNECTION_STRING")

        if not conn_str:
            logger.error("AZURE_STORAGE_CONNECTION_STRING non défini")
            return False

        # Créer le client Azure
        blob_service_client = BlobServiceClient.from_connection_string(conn_str)
        container_client = blob_service_client.get_container_client(container_name)

        # Créer le container si nécessaire
        if create_container:
            try:
                container_client.create_container()
                logger.info(f"Container '{container_name}' créé")
            except Exception:
                pass  # Le container existe déjà

        # Upload le fichier
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(content, overwrite=True)

        logger.success(f"Fichier uploadé vers Azure : {container_name}/{blob_name}")
        return True

    except Exception as e:
        logger.error(f"Erreur lors de l'upload Azure : {e}")
        return False


def build_url_from_template(template: str, **kwargs) -> str:
    return template.format(**kwargs)


def build_file_path(
    base_dir: Path | str, filename: str, subdirs: Optional[list[str]] = None
) -> Path:
    path = Path(base_dir)

    if subdirs:
        for subdir in subdirs:
            path = path / str(subdir)

    return path / filename
