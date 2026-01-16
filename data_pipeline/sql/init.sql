-- ========================================
-- Script d'initialisation PostgreSQL
-- ========================================
-- Exécuté automatiquement au démarrage du container

-- Créer le schéma public s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS public;

-- Message de bienvenue
DO $$ BEGIN RAISE NOTICE 'Base de données NYC Taxi initialisée avec succès !';

RAISE NOTICE 'Prêt à recevoir les données des pipelines';

END $$;
