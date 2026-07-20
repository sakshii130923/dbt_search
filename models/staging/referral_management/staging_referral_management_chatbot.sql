-- models/staging/staging_referral_management_chatbot.sql
-- Staging model for the Referral Management Chatbot dataset (Frappe -> Airbyte -> Postgres raw)
-- Purpose: clean, dedupe, and cast only the columns required downstream.

with source as (

    select
        reference_number,
        referral_date,
        phc,
        referrer_department,
        referrer_name,
        patient_name,
        patient_age,
        patient_gender,
        patient_taluka,
        opd_departments           as referred_to_department,
        modified                  as _modified_at   -- used only for de-dup ordering, dropped later
    from {{ source('referral_management', 'tabPatient_Referral') }}
    where reference_number is not null
        and trim(reference_number) <> ''

),

deduped as (

    -- Frappe/Airbyte syncs can re-land the same record on every run.
    -- Keep the most recently modified row per reference_number.
    select
        *,
        row_number() over (
            partition by reference_number
            order by _modified_at desc
        ) as rn
    from source

),

cleaned as (

    select
        -- reference_id: unique, non-blank identifier
        trim(reference_number)::text                                          as reference_id,

        -- referral_date: cast to date, drop anything that doesn't parse
        case
            when referral_date is not null
                and referral_date::text ~ '^\d{4}-\d{2}-\d{2}'
            then referral_date::date
            else null
        end                                                                   as referral_date,

        -- phc: plain text, trimmed
        trim(phc)::text                                                       as phc,

        -- referrer_department: plain text, trimmed
        trim(referrer_department)::text                                       as referrer_department,

        -- referrer_name: plain text, trimmed
        trim(referrer_name)::text                                             as referrer_name,

        -- patient_name: plain text, trimmed
        trim(patient_name)::text                                              as patient_name,

        -- patient_age: numeric, constrained to a realistic human range (0-120)
        case
            when patient_age::text ~ '^\d+$'
                and patient_age::numeric between 0 and 120
            then patient_age::numeric
            else null
        end                                                                   as patient_age,

        -- patient_gender: normalised to Male / Female / Other only
        case
            when lower(trim(patient_gender)) = 'male'   then 'Male'
            when lower(trim(patient_gender)) = 'female'  then 'Female'
            when lower(trim(patient_gender)) = 'other'   then 'Other'
            else null
        end                                                                   as patient_gender,
         -- patient_taluka: plain text, trimmed
        trim(patient_taluka)::text                                            as patient_taluka,
        -- referred_to_department: plain text, trimmed
        trim(referred_to_department)::text                                    as referred_to_department

    from deduped
    where rn = 1

)

select * from cleaned