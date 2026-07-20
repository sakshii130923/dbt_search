-- models/prod/prod_referral_management_chatbot.sql
-- Prod model for the Referral Management Chatbot dataset.
-- Sits on top of the staging model — staging handles cleaning, de-dup, and type casting.
-- This model is the final, dashboard-facing table: one validated row per referral.

{{
    config(
        materialized = 'table'
    )
}}

with staging as (

    select *
    from {{ ref('staging_referral_management_chatbot') }}

),

final as (

    select
        reference_id,
        referral_date,
        phc,
        referrer_department,
        referrer_name,
        patient_name,
        patient_age,
        patient_gender,
        patient_taluka,
        referred_to_department

    from staging
    -- final safety net: a referral with no date or no destination department
    -- isn't usable on the dashboard, so we drop it here rather than upstream
    where referral_date is not null
        and referred_to_department is not null

)

select * from final