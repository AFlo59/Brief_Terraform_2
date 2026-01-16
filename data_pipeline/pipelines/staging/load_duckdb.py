import os
from pathlib import Path

from dotenv import load_dotenv
from loguru import logger

from utils.database import (
    execute_sql_file_duckdb,
    execute_sql_file_postgresql,
    get_database_duckdb,
)

load_dotenv()


def get_data_path() -> Path:
    """
    Détermine le chemin des données selon le mode d'exécution.
    - Mode local (USE_LOCAL=true ou pas de creds Azure) : data/raw
    - Mode Azure : Les fichiers doivent être téléchargés localement d'abord
    """
    use_local = os.getenv("USE_LOCAL", "false").lower() == "true"
    has_azure_creds = os.getenv("AZURE_STORAGE_CONNECTION_STRING") is not None
    
    # En mode Docker avec volume, les données sont dans /app/data/raw
    # En mode local direct, elles sont dans ./data/raw
    data_path = Path("data/raw")
    
    if use_local:
        logger.info(f"Mode local - Lecture depuis : {data_path.absolute()}")
    elif has_azure_creds:
        logger.info("Mode Azure détecté")
        logger.info("Note: DuckDB lit les fichiers Parquet locaux.")
        logger.info("Les fichiers doivent avoir été téléchargés par le pipeline 1 (download)")
        logger.info(f"Chemin de lecture : {data_path.absolute()}")
    
    return data_path


def charger_avec_duckdb():
    """
    Charge les fichiers Parquet dans PostgreSQL via DuckDB.
    Utilise le pattern glob pour charger tous les fichiers en une seule requête.
    """
    data_path = get_data_path()
    
    # Vérifier que le dossier existe
    if not data_path.exists():
        logger.warning(f"Dossier {data_path} n'existe pas. Création...")
        data_path.mkdir(parents=True, exist_ok=True)
    
    # Lister les fichiers
    fichiers = list(data_path.glob("*.parquet"))

    if not fichiers:
        logger.warning(f"Aucun fichier Parquet trouvé dans {data_path}")
        logger.info("Vérifiez que le pipeline 1 (download) a bien été exécuté")
        return

    logger.info(f"{len(fichiers)} fichiers Parquet détectés:")
    for f in fichiers[:5]:  # Afficher les 5 premiers
        logger.info(f"  - {f.name}")
    if len(fichiers) > 5:
        logger.info(f"  ... et {len(fichiers) - 5} autres")

    try:
        glob_pattern = str(data_path / "*.parquet")
        logger.info(f"Chargement optimisé de TOUS les fichiers : {glob_pattern}")
        execute_sql_file_duckdb("sql/insert_to.sql", params={"glob_pattern": glob_pattern})
        logger.success("Données chargées avec succès dans PostgreSQL")
    except Exception as e:
        logger.error(f"Erreur lors du chargement : {e}")
        raise


if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Pipeline 2 : Chargement des données (DuckDB → PostgreSQL)")
    logger.info("=" * 60)
    
    logger.info("Étape 1/3 : Création de la table staging...")
    execute_sql_file_postgresql("sql/create_staging_table.sql")
    
    logger.info("Étape 2/3 : Nettoyage de la table (TRUNCATE)...")
    execute_sql_file_postgresql("sql/truncate.sql")
    
    logger.info("Étape 3/3 : Chargement des données...")
    charger_avec_duckdb()
    
    logger.success("Pipeline 2 terminé")
