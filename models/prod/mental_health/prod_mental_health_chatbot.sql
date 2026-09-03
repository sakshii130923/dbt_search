{{ config(materialized='table') }}

with staging as (

    select * from {{ ref('staging_mental_health_chatbot') }}

),

-- Step 1: remove exact full-row duplicates
deduped as (

    select distinct *
    from staging

),

-- Step 2: enforce required fields are not null
required_fields_ok as (

    select *
    from deduped
    where patient_registration_id is not null
      and patient_name is not null

),

-- Step 3: if the same patient_registration_id still appears more than once
-- (same id, different data), keep only the oldest row (earliest modified_at)
ranked as (

    select
        *,
        row_number() over (
            partition by patient_registration_id
            order by modified_at asc
        ) as row_rank

    from required_fields_ok

)

select
    patient_registration_id,
    creation_date,
    modified_at,
    counselor_name,
    patient_name,
    patient_gender,
    patient_age,
    patient_taluka,
    patient_district,
    phq2_1,
    phq2_2,
    phq9_1_score,
    phq9_2_score,
    phq9_3_score,
    phq9_4_score,
    phq9_5_score,
    phq9_7_score,
    phq9_8_score,
    phq9_9_score,
    phq9_10_score,
    phq9_11_score,
    phq_overall_score,
    gad2_1_score,
    gad2_2_score,
    gad7_1_score,
    gad7_2_score,
    gad7_3_score,
    gad7_4_score,
    gad7_5_score,
    gad7_6_score,
    gad7_7_score,
    gad_overall_score,
    padis1_score,
    padis2_score,
    padis3_score,
    padis4_score,
    padis_overall_score,
    pharmacotherapy_similarity_score,
    psycoeducation_similarity_score,
    human_psycoeducation_similarity_score,
    human_pharmacotherapy_similarity_score
from ranked
where row_rank = 1