import os
from contextlib import contextmanager
from typing import Any, Generator, Optional

import duckdb
import psycopg2
from dotenv import load_dotenv
from loguru import logger

load_dotenv()


@contextmanager
def get_database_postgresql() -> Generator[psycopg2.extensions.connection, None, None]:
    logger.info("Connexion à la base de données PostgreSQL...")

    connection = None
    try:
        connection = psycopg2.connect(
            host=os.getenv("POSTGRES_HOST"),
            port=int(os.getenv("POSTGRES_PORT", 5432)),
            database=os.getenv("POSTGRES_DB"),
            user=os.getenv("POSTGRES_USER"),
            password=os.getenv("POSTGRES_PASSWORD"),
            sslmode=os.getenv("POSTGRES_SSL_MODE", "require"),
        )

        logger.success("Connexion à la base de données OK")
        yield connection

    except Exception as e:
        logger.error(f"Erreur de connexion à la base de données: {e}")
        raise
    finally:
        if connection:
            connection.close()
            logger.info("Connexion fermée")


@contextmanager
def get_database_duckdb() -> Generator["duckdb.DuckDBPyConnection", None, None]:
    logger.info("Connexion à la base de données DuckDB...")
    import multiprocessing

    nb_threads = multiprocessing.cpu_count()
    logger.info(f"Configuration DuckDB : {nb_threads} threads")
    pg_connection = f"postgresql://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@{os.getenv('POSTGRES_HOST')}:{os.getenv('POSTGRES_PORT', 5432)}/{os.getenv('POSTGRES_DB')}"
    connection = None
    try:
        connection = duckdb.connect(database=":memory:")
        connection.execute(f"""
            SET threads TO {nb_threads};
            SET memory_limit = '8GB';
            SET preserve_insertion_order = false;
            INSTALL postgres;
            LOAD postgres;
            ATTACH '{pg_connection}' AS postgres_db (TYPE POSTGRES);
        """)

        logger.success("Connexion à la base de données OK")
        yield connection

    except Exception as e:
        logger.error(f"Erreur de connexion à la base de données: {e}")
        raise
    finally:
        if connection:
            connection.close()
            logger.info("Connexion fermée")


def execute_sql_file_postgresql(sql_file_path: str) -> bool:
    """Exécute un fichier SQL et retourne True si succès"""
    try:
        with get_database_postgresql() as conn:
            conn.cursor().execute(open(sql_file_path, encoding="utf-8").read())
            conn.commit()
            logger.success(f"Fichier {sql_file_path} exécuté avec succès")
        return True
    except Exception as e:
        logger.error(f"Erreur lors de l'exécution de {sql_file_path}: {e}")
        return False


def execute_sql_file_duckdb(sql_file_path: str, params: Optional[dict[str, Any]] = None) -> bool:
    try:
        with open(sql_file_path, encoding="utf-8") as f:
            sql_content = f.read()

        if not sql_content.strip():
            logger.warning(f"Fichier SQL vide : {sql_file_path}")
            return False

        if params:
            for key, value in params.items():
                placeholder = f"{{{key}}}"
                sql_content = sql_content.replace(placeholder, str(value))
                logger.debug(f"Paramètre remplacé : {placeholder} -> {value}")

        with get_database_duckdb() as conn:
            logger.info(f"Exécution de {sql_file_path}...")
            conn.execute(sql_content)
            logger.success(f"✓ {sql_file_path} exécuté avec succès")

        return True

    except FileNotFoundError:
        logger.error(f"Fichier SQL introuvable : {sql_file_path}")
        return False

    except UnicodeDecodeError as e:
        logger.error(f"Erreur d'encodage dans {sql_file_path} : {e}")
        return False

    except Exception as e:
        logger.error(f"Erreur lors de l'exécution de {sql_file_path} : {e}")
        return False
