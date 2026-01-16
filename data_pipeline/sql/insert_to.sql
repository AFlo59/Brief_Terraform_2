INSERT INTO
    postgres_db.staging_taxi_trips
SELECT
    ROW_NUMBER() OVER () - 1 AS trip_id,
    VendorID AS vendor_id,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    RatecodeID AS ratecode_id,
    PULocationID AS pu_location_id,
    DOLocationID AS do_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    EXTRACT(
        EPOCH
        FROM (
                tpep_dropoff_datetime - tpep_pickup_datetime
            )
    ) / 60.0 AS trip_duration_minutes
FROM '{glob_pattern}'
WHERE
    tpep_pickup_datetime IS NOT NULL
    AND tpep_dropoff_datetime IS NOT NULL
    AND tpep_dropoff_datetime > tpep_pickup_datetime
    AND fare_amount >= 0
    AND total_amount >= 0
    AND tip_amount >= 0
    AND tolls_amount >= 0
    AND trip_distance >= 0
    AND trip_distance <= 500
    AND EXTRACT(
        EPOCH
        FROM (
                tpep_dropoff_datetime - tpep_pickup_datetime
            )
    ) / 60.0 > 0
    AND EXTRACT(
        EPOCH
        FROM (
                tpep_dropoff_datetime - tpep_pickup_datetime
            )
    ) / 60.0 <= 1440
    AND passenger_count >= 1
    AND passenger_count <= 9
