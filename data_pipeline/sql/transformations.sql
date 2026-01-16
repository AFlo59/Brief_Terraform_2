-- ========================================
-- Script de transformation OPTIMISÉ : Tables DIM et FACT
-- ========================================
-- Version optimisée pour ~187M lignes
-- Optimisations :
-- 1. Index créés APRÈS insertion (10x plus rapide)
-- 2. Pas de ROW_NUMBER() coûteux sur toute la table
-- 3. ANALYZE après chaque table
-- 4. Configuration PostgreSQL optimisée
-- ========================================

-- Configuration pour améliorer les performances
SET work_mem = '256MB';
SET maintenance_work_mem = '512MB';
SET temp_buffers = '128MB';

-- Supprimer les tables si elles existent déjà
DROP TABLE IF EXISTS fact_trips CASCADE;
DROP TABLE IF EXISTS dim_datetime CASCADE;
DROP TABLE IF EXISTS dim_location CASCADE;
DROP TABLE IF EXISTS dim_payment CASCADE;
DROP TABLE IF EXISTS dim_vendor CASCADE;
DROP TABLE IF EXISTS dim_rate_code CASCADE;
-- Alias pour compatibilité avec l'ancien nommage
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_payment_type CASCADE;

-- ========================================
-- 1. DIM_DATETIME : Dimension temporelle (Brief: dim_datetime)
-- ========================================
-- OPTIMISATION: CREATE TABLE puis INSERT (plus rapide que CREATE TABLE AS)
CREATE TABLE dim_datetime (
    datetime_key SERIAL PRIMARY KEY,
    date_complete DATE NOT NULL,
    annee INTEGER,
    mois INTEGER,
    nom_mois VARCHAR(20),
    jour INTEGER,
    jour_semaine_numero INTEGER,
    jour_semaine_nom VARCHAR(20),
    type_jour VARCHAR(10),
    heure INTEGER,
    periode_journee VARCHAR(15),
    trimestre INTEGER
);

-- Insertion optimisée
INSERT INTO dim_datetime (
    date_complete, annee, mois, nom_mois, jour,
    jour_semaine_numero, jour_semaine_nom, type_jour,
    heure, periode_journee, trimestre
)
SELECT DISTINCT
    DATE(tpep_pickup_datetime) AS date_complete,
    EXTRACT(YEAR FROM tpep_pickup_datetime)::INTEGER AS annee,
    EXTRACT(MONTH FROM tpep_pickup_datetime)::INTEGER AS mois,
    TO_CHAR(tpep_pickup_datetime, 'Month') AS nom_mois,
    EXTRACT(DAY FROM tpep_pickup_datetime)::INTEGER AS jour,
    EXTRACT(DOW FROM tpep_pickup_datetime)::INTEGER AS jour_semaine_numero,
    TO_CHAR(tpep_pickup_datetime, 'Day') AS jour_semaine_nom,
    CASE
        WHEN EXTRACT(DOW FROM tpep_pickup_datetime) IN (0, 6) THEN 'Week-end'
        ELSE 'Semaine'
    END AS type_jour,
    EXTRACT(HOUR FROM tpep_pickup_datetime)::INTEGER AS heure,
    CASE
        WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 6 AND 11 THEN 'Matin'
        WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 12 AND 17 THEN 'Après-midi'
        WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 18 AND 22 THEN 'Soir'
        ELSE 'Nuit'
    END AS periode_journee,
    EXTRACT(QUARTER FROM tpep_pickup_datetime)::INTEGER AS trimestre
FROM staging_taxi_trips
WHERE tpep_pickup_datetime IS NOT NULL
ORDER BY date_complete;

-- Index créé APRÈS l'insertion (beaucoup plus rapide)
CREATE INDEX idx_dim_datetime_date ON dim_datetime(date_complete);

-- Mise à jour des statistiques
ANALYZE dim_datetime;

-- ========================================
-- 2. DIM_LOCATION : Dimension géographique
-- ========================================
CREATE TABLE dim_location (
    location_key SERIAL PRIMARY KEY,
    location_id BIGINT NOT NULL,
    zone_description VARCHAR(50)
);

-- Insertion optimisée avec UNION
INSERT INTO dim_location (location_id, zone_description)
SELECT DISTINCT location_id, 'Zone NYC'
FROM (
    SELECT DISTINCT pu_location_id AS location_id
    FROM staging_taxi_trips
    WHERE pu_location_id IS NOT NULL
    UNION
    SELECT DISTINCT do_location_id AS location_id
    FROM staging_taxi_trips
    WHERE do_location_id IS NOT NULL
) AS all_locations
ORDER BY location_id;

-- Index créé APRÈS
CREATE INDEX idx_dim_location_id ON dim_location(location_id);

-- Mise à jour des statistiques
ANALYZE dim_location;

-- ========================================
-- 3. DIM_PAYMENT : Dimension type de paiement (Brief: dim_payment)
-- ========================================
CREATE TABLE dim_payment (
    payment_key SERIAL PRIMARY KEY,
    payment_type_id BIGINT NOT NULL,
    payment_description VARCHAR(50)
);

INSERT INTO dim_payment (payment_type_id, payment_description)
SELECT DISTINCT
    payment_type AS payment_type_id,
    CASE payment_type
        WHEN 1 THEN 'Carte de crédit'
        WHEN 2 THEN 'Espèces'
        WHEN 3 THEN 'Sans frais'
        WHEN 4 THEN 'Dispute'
        WHEN 5 THEN 'Inconnu'
        WHEN 6 THEN 'Voyage annulé'
        ELSE 'Autre'
    END AS payment_description
FROM staging_taxi_trips
WHERE payment_type IS NOT NULL
ORDER BY payment_type;

-- Index pour les jointures
CREATE INDEX idx_dim_payment_type_id ON dim_payment(payment_type_id);

-- Mise à jour des statistiques
ANALYZE dim_payment;

-- ========================================
-- 4. DIM_VENDOR : Dimension fournisseur (Brief: dim_vendor)
-- ========================================
CREATE TABLE dim_vendor (
    vendor_key SERIAL PRIMARY KEY,
    vendor_id BIGINT NOT NULL,
    vendor_name VARCHAR(50)
);

INSERT INTO dim_vendor (vendor_id, vendor_name)
SELECT DISTINCT
    vendor_id,
    CASE vendor_id
        WHEN 1 THEN 'Creative Mobile Technologies'
        WHEN 2 THEN 'VeriFone Inc.'
        ELSE 'Autre'
    END AS vendor_name
FROM staging_taxi_trips
WHERE vendor_id IS NOT NULL
ORDER BY vendor_id;

-- Index pour les jointures
CREATE INDEX idx_dim_vendor_id ON dim_vendor(vendor_id);

-- Mise à jour des statistiques
ANALYZE dim_vendor;

-- ========================================
-- 5. DIM_RATE_CODE : Dimension code de tarification (bonus)
-- ========================================
CREATE TABLE dim_rate_code (
    rate_code_key SERIAL PRIMARY KEY,
    rate_code_id BIGINT NOT NULL,
    rate_code_description VARCHAR(50)
);

INSERT INTO dim_rate_code (rate_code_id, rate_code_description)
SELECT DISTINCT
    ratecode_id AS rate_code_id,
    CASE ratecode_id
        WHEN 1 THEN 'Tarif standard'
        WHEN 2 THEN 'JFK'
        WHEN 3 THEN 'Newark'
        WHEN 4 THEN 'Nassau ou Westchester'
        WHEN 5 THEN 'Tarif négocié'
        WHEN 6 THEN 'Trajet de groupe'
        ELSE 'Autre'
    END AS rate_code_description
FROM staging_taxi_trips
WHERE ratecode_id IS NOT NULL
ORDER BY ratecode_id;

-- Index pour les jointures
CREATE INDEX idx_dim_rate_code_id ON dim_rate_code(rate_code_id);

-- Mise à jour des statistiques
ANALYZE dim_rate_code;

-- ========================================
-- 6. FACT_TRIPS : Table de faits (métriques)
-- ========================================
-- OPTIMISATION: Création de la table d'abord, insertion ensuite
CREATE TABLE fact_trips (
    trip_id BIGINT PRIMARY KEY,
    -- Clés étrangères vers les dimensions
    pickup_datetime_key DATE,
    pickup_location_key BIGINT,
    dropoff_location_key BIGINT,
    vendor_key BIGINT,
    payment_key BIGINT,
    rate_code_key BIGINT,
    -- Timestamps originaux
    tpep_pickup_datetime TIMESTAMP,
    tpep_dropoff_datetime TIMESTAMP,
    -- Métriques
    distance_miles DOUBLE PRECISION,
    duree_minutes DOUBLE PRECISION,
    nombre_passagers BIGINT,
    montant_course DOUBLE PRECISION,
    frais_supplementaires DOUBLE PRECISION,
    taxe_mta DOUBLE PRECISION,
    montant_pourboire DOUBLE PRECISION,
    peages DOUBLE PRECISION,
    frais_amelioration DOUBLE PRECISION,
    montant_total DOUBLE PRECISION,
    -- Métriques calculées
    prix_par_mile DOUBLE PRECISION,
    prix_par_minute DOUBLE PRECISION,
    pourcentage_pourboire DOUBLE PRECISION,
    vitesse_moyenne_mph DOUBLE PRECISION
);

-- Insertion en masse (plus rapide sans les contraintes)
INSERT INTO fact_trips
SELECT
    trip_id,
    -- Clés étrangères
    DATE(tpep_pickup_datetime) AS pickup_datetime_key,
    pu_location_id AS pickup_location_key,
    do_location_id AS dropoff_location_key,
    vendor_id AS vendor_key,
    payment_type AS payment_key,
    ratecode_id AS rate_code_key,
    -- Timestamps
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    -- Métriques
    trip_distance AS distance_miles,
    trip_duration_minutes AS duree_minutes,
    passenger_count AS nombre_passagers,
    fare_amount AS montant_course,
    extra AS frais_supplementaires,
    mta_tax AS taxe_mta,
    tip_amount AS montant_pourboire,
    tolls_amount AS peages,
    improvement_surcharge AS frais_amelioration,
    total_amount AS montant_total,
    -- Métriques calculées
    CASE
        WHEN trip_distance > 0 THEN total_amount / trip_distance
        ELSE 0
    END AS prix_par_mile,
    CASE
        WHEN trip_duration_minutes > 0 THEN total_amount / trip_duration_minutes
        ELSE 0
    END AS prix_par_minute,
    CASE
        WHEN total_amount > 0 THEN (tip_amount / total_amount) * 100
        ELSE 0
    END AS pourcentage_pourboire,
    CASE
        WHEN trip_duration_minutes > 0 THEN trip_distance / (trip_duration_minutes / 60)
        ELSE 0
    END AS vitesse_moyenne_mph
FROM staging_taxi_trips;

-- Index créés APRÈS l'insertion (BEAUCOUP plus rapide)
CREATE INDEX idx_fact_trips_datetime ON fact_trips(pickup_datetime_key);
CREATE INDEX idx_fact_trips_pickup_location ON fact_trips(pickup_location_key);
CREATE INDEX idx_fact_trips_dropoff_location ON fact_trips(dropoff_location_key);
CREATE INDEX idx_fact_trips_vendor ON fact_trips(vendor_key);
CREATE INDEX idx_fact_trips_payment ON fact_trips(payment_key);
CREATE INDEX idx_fact_trips_rate_code ON fact_trips(rate_code_key);

-- Mise à jour des statistiques
ANALYZE fact_trips;

-- ========================================
-- Statistiques finales (vérification)
-- ========================================
SELECT 'staging_taxi_trips' AS table_name, COUNT(*) AS nombre_lignes FROM staging_taxi_trips
UNION ALL
SELECT 'dim_datetime', COUNT(*) FROM dim_datetime
UNION ALL
SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL
SELECT 'dim_payment', COUNT(*) FROM dim_payment
UNION ALL
SELECT 'dim_vendor', COUNT(*) FROM dim_vendor
UNION ALL
SELECT 'dim_rate_code', COUNT(*) FROM dim_rate_code
UNION ALL
SELECT 'fact_trips', COUNT(*) FROM fact_trips;
