import sys
import runpy
from loguru import logger


def main():
    """
    Pipeline principal NYC Taxi - Exécute les 3 étapes en séquence :
    1. Download : Télécharge les fichiers Parquet depuis NYC TLC
    2. Load : Charge les données dans PostgreSQL via DuckDB
    3. Transform : Crée le modèle en étoile (star schema)
    """
    try:
        logger.info("=" * 70)
        logger.info("🚀 NYC TAXI DATA PIPELINE")
        logger.info("=" * 70)
        
        # Pipeline 1 : Téléchargement
        logger.info("")
        logger.info("📥 PIPELINE 1/3 : Téléchargement des données")
        logger.info("-" * 50)
        runpy.run_path("pipelines/ingestion/download.py", run_name="__main__")
        
        # Pipeline 2 : Chargement
        logger.info("")
        logger.info("📦 PIPELINE 2/3 : Chargement dans PostgreSQL")
        logger.info("-" * 50)
        runpy.run_path("pipelines/staging/load_duckdb.py", run_name="__main__")
        
        # Pipeline 3 : Transformation
        logger.info("")
        logger.info("🔄 PIPELINE 3/3 : Transformation (Star Schema)")
        logger.info("-" * 50)
        runpy.run_path("pipelines/transformation/transform.py", run_name="__main__")
        
        logger.info("")
        logger.info("=" * 70)
        logger.success("✅ PIPELINE TERMINÉ AVEC SUCCÈS")
        logger.info("=" * 70)
        return 0
        
    except Exception as e:
        logger.error(f"❌ Erreur dans le pipeline : {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
