from loguru import logger

from utils.database import execute_sql_file_postgresql


def transformer_donnees():
    try:
        execute_sql_file_postgresql("sql/transformations.sql")

        return {
            "transformation": "dim_fact_creation",
            "script": "transformations.sql",
            "status": "success",
        }

    finally:
        logger.info("Connexion fermée")


if __name__ == "__main__":
    logger.info("Démarrage de la Pipeline : Transformation des données")
    result = transformer_donnees()
    logger.success(f"Pipeline terminée : {result['status']}")
