-- Clean and standardize DOB NOW job filings
-- One row per job_filing_number (raw had 350 duplicate filings)

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        -- Pass through everything not transformed below.
        -- Date columns are already TIMESTAMP in raw, and the
        -- filing_representative_* fields are already STRING, so they keep their names.
        * EXCEPT (
            job_filing_number,
            borough,
            postcode,
            zip,
            council_district,
            commmunity_board,
            latitude,
            longitude
        ),

        -- Identifier
        CAST(job_filing_number AS STRING) AS job_filing_number,

        -- Location: named to conform with stg_nyc_311_dot (borough, zip, council_district)
        CAST(borough AS STRING) AS borough,
        CAST(postcode AS STRING) AS zip,
        CAST(council_district AS STRING) AS council_district,

        -- Raw column name has a typo (three m's), so fix it here
        CAST(commmunity_board AS STRING) AS community_board,

        -- Raw coordinates are STRING; SAFE_CAST returns NULL on bad values instead of failing
        SAFE_CAST(latitude AS FLOAT64) AS latitude,
        SAFE_CAST(longitude AS FLOAT64) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE job_filing_number IS NOT NULL

    -- Deduplicate: one row per filing; bin as a second key so reruns pick the same row
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY job_filing_number
        ORDER BY current_status_date DESC, bin
    ) = 1
)

SELECT * FROM cleaned