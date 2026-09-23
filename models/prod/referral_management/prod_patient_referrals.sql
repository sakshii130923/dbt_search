-- models/prod/prod_patient_referrals.sql
-- Prod model for the Referral Management dataset.
-- Sits on top of the staging model — staging handles cleaning, de-dup, and type casting.
-- This model is the final, dashboard-facing table: one validated row per referral.

{{
    config(
        materialized = 'table'
    )
}}

with staging as (

    select *
    from {{ ref('staging_patient_referrals') }}

),

final as (

    select
        reference_id,
        patient_name,
        patient_age,
        patient_gender,
        patient_taluka,
        phc,
        patient_village,
        service_facility_type,
        other_facility_name,
        opd_category,
        referred_to_department,
        referral_date,
        referral_recorded_date,
        referrer_name,
        referrer_id,
        referrer_department,
        point_of_referral,
        referred_by_doctor,
        followup_visit_count, 
        followup_status,
        visit_date              as facility_visit_date,
        facility_visited 

    from staging

    where referral_date is not null
        and reference_id is not null

)

select * from final