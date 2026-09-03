{{ config(materialized='table') }}

with source as (

    select * from {{ source('mental_health', 'tabMH_Chatbot_Consultation_Glific') }}

),

cleaned as (

    select

        -- Identifier
        case
            when patient_identification_number::text ~ '^-?\d+(\.\d+)?$'
                then (patient_identification_number::text)::bigint
            else null
        end as patient_registration_id,

        -- Date
        cast(creation as date) as creation_date,
        cast(modified as timestamp) as modified_at,

        -- Text fields
        trim(counselor_name) as counselor_name,
        trim(patient_name) as patient_name,

        -- Gender standardisation
        case
            when upper(trim(patient_gender)) in ('MALE', 'M') then 'Male'
            when upper(trim(patient_gender)) in ('FEMALE', 'F') then 'Female'
            else null
        end as patient_gender,

        -- Age: valid number AND between 1-120
        case
            when patient_age::text ~ '^-?\d+(\.\d+)?$'
                and (patient_age::text)::numeric between 1 and 120
                then (patient_age::text)::int
            else null
        end as patient_age,

        trim(patient_taluka) as patient_taluka,
        trim(patient_district) as patient_district,

        -- PHQ-2 (just check valid number, no range restriction)
        case when phq2_1::text ~ '^-?\d+(\.\d+)?$'
            then (phq2_1::text)::int else null end as phq2_1,
        case when phq2_2_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq2_2_score::text)::int else null end as phq2_2,

        -- PHQ-9 (just check valid number, no range restriction)
        case when phq9_1_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_1_score::text)::int else null end as phq9_1_score,
        case when phq9_2_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_2_score::text)::int else null end as phq9_2_score,
        case when phq9_3_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_3_score::text)::int else null end as phq9_3_score,
        case when phq9_4_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_4_score::text)::int else null end as phq9_4_score,
        case when phq9_5_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_5_score::text)::int else null end as phq9_5_score,
        case when phq9_7_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_7_score::text)::int else null end as phq9_7_score,
        case when phq9_8_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_8_score::text)::int else null end as phq9_8_score,
        case when phq9_9_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_9_score::text)::int else null end as phq9_9_score,
        case when phq9_10_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_10_score::text)::int else null end as phq9_10_score,
        case when phq9_11_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq9_11_score::text)::int else null end as phq9_11_score,

        case when phq_overall_score::text ~ '^-?\d+(\.\d+)?$'
            then (phq_overall_score::text)::int else null end as phq_overall_score,

        -- GAD-2 (just check valid number, no range restriction)
        case when gad2_1_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad2_1_score::text)::int else null end as gad2_1_score,
        case when gad2_2_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad2_2_score::text)::int else null end as gad2_2_score,

        -- GAD-7 (just check valid number, no range restriction)
        case when gad7_1_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_1_score::text)::int else null end as gad7_1_score,
        case when gad7_2_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_2_score::text)::int else null end as gad7_2_score,
        case when gad7_3_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_3_score::text)::int else null end as gad7_3_score,
        case when gad7_4_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_4_score::text)::int else null end as gad7_4_score,
        case when gad7_5_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_5_score::text)::int else null end as gad7_5_score,
        case when gad7_6_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_6_score::text)::int else null end as gad7_6_score,
        case when gad7_7_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad7_7_score::text)::int else null end as gad7_7_score,

        case when gad_overall_score::text ~ '^-?\d+(\.\d+)?$'
            then (gad_overall_score::text)::int else null end as gad_overall_score,

        -- PADIS (just check valid number, no range restriction)
        case when padis1_score::text ~ '^-?\d+(\.\d+)?$'
            then (padis1_score::text)::int else null end as padis1_score,
        case when padis2_score::text ~ '^-?\d+(\.\d+)?$'
            then (padis2_score::text)::int else null end as padis2_score,
        case when padis3_score::text ~ '^-?\d+(\.\d+)?$'
            then (padis3_score::text)::int else null end as padis3_score,
        case when padis4_score::text ~ '^-?\d+(\.\d+)?$'
            then (padis4_score::text)::int else null end as padis4_score,

        case when padis_overall_score::text ~ '^-?\d+(\.\d+)?$'
            then (padis_overall_score::text)::int else null end as padis_overall_score,

        -- Similarity scores (keep 2 decimal places, do not round to int)
        case when pharmacotherapy_similarity_score::text ~ '^-?\d+(\.\d+)?$'
            then (pharmacotherapy_similarity_score::text)::numeric(10,2) else null end as pharmacotherapy_similarity_score,
        case when diagnosis_similarity_score::text ~ '^-?\d+(\.\d+)?$'
            then (diagnosis_similarity_score::text)::numeric(10,2) else null end as psycoeducation_similarity_score,
        case when human_diagnosis_similarity_score::text ~ '^-?\d+(\.\d+)?$'
            then (human_diagnosis_similarity_score::text)::numeric(10,2) else null end as human_psycoeducation_similarity_score,
        case when human_pharmacotherapy_similarity_score::text ~ '^-?\d+(\.\d+)?$'
            then (human_pharmacotherapy_similarity_score::text)::numeric(10,2) else null end as human_pharmacotherapy_similarity_score

    from source

)

select * from cleaned