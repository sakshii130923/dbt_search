-- models/staging/staging_referral_management_chatbot.sql
-- Staging model for the Referral Management Chatbot dataset (Frappe -> Airbyte -> Postgres raw)
-- Purpose: clean, dedupe, and cast only the columns required downstream.

with source as (

    select
        reference_number,
        referral_date,
        phc,
        referrer_department,
        referrer,
        referrer_name,
        patient_name,
        patient_age,
        patient_gender,
        patient_taluka,
        service_facility_type,
        other_facility_name,
        opd_departments           as referred_to_department,
        status as followup_status,
        opd_category,
        patient_village,
        referred_by_who,
        visit_date,
        visit_count,
        referred_doctor as referred_by_doctor,
        facility_visited,
        referral_recorded_date
    from {{ source('referral_management', 'tabPatient_Referral') }}
    where reference_number is not null
        and trim(reference_number) <> ''

),

cleaned as (

    select

        -- ============ IDENTIFIERS ============
        -- reference_id: unique, non-blank identifier
        trim(s.reference_number)::text                                        as reference_id,

        -- referrer_id: system-generated unique id, display and join use only
        trim(s.referrer)::text                                                as referrer_id,

        -- ============ DATES (source format DD-MM-YYYY) ============
        -- Anything that doesn't match the pattern becomes null instead of
        -- erroring the run.
        {{ validate_date('s.referral_date') }}                                 as referral_date,

        {{ validate_date('s.visit_date') }}                                    as visit_date,

        {{ validate_date('s.referral_recorded_date') }}                        as referral_recorded_date,

        -- patient_age: numeric, constrained to a realistic human range (0-120)
        case
            when trim(s.patient_age::text) ~ '^\d+(\.\d+)?$'
                and (trim(s.patient_age::text))::numeric between 0 and 120
                then (trim(s.patient_age::text))::numeric(5,2)
            else null
        end                                                                     as patient_age,
        -- visit_count: numeric only, no upper limit so extra visits aren't lost
        case
            when trim(s.visit_count::text) ~ '^\d+$'
                then (trim(s.visit_count::text))::int
            else null
        end                                                                   as followup_visit_count,

        -- ============ GENDER (only two valid values) ============
        case
            when upper(trim(s.patient_gender)) in ('MALE', 'M')   then 'Male'
            when upper(trim(s.patient_gender)) in ('FEMALE', 'F') then 'Female'
            else null
        end                                                                   as patient_gender,

    
        nullif(trim(s.phc), '')::text                                         as phc,
        nullif(trim(s.referrer_department), '')::text                         as referrer_department,
        nullif(trim(s.patient_taluka), '')::text                              as patient_taluka,
        nullif(trim(s.patient_village), '')::text                             as patient_village,
        nullif(trim(s.service_facility_type), '')::text                       as service_facility_type,
        nullif(trim(s.referred_to_department), '')::text                      as referred_to_department,
        nullif(trim(s.opd_category), '')::text                                as opd_category,
        nullif(trim(s.followup_status), '')::text                             as followup_status,
        nullif(trim(s.referred_by_who), '')::text                             as point_of_referral,
        nullif(trim(s.referred_by_doctor), '')::text                          as referred_by_doctor,
        nullif(trim(s.facility_visited), '')::text                            as facility_visited,
        nullif(trim(s.referrer_name), '')::text                                as referrer_name,

        -- patient_name: formatting cleanup only, no seed mapping
        nullif(
            initcap(regexp_replace(trim(s.patient_name), '\s+', ' ', 'g')),
            ''
        )::text                                                                as patient_name,

        -- other_facility_name: only meaningful when 'Other' was selected
        case
            when lower(trim(s.service_facility_type)) = 'other'
                then nullif(initcap(regexp_replace(trim(s.other_facility_name), '\s+', ' ', 'g')), '')
            else null
        end::text                                                              as other_facility_name

        from source s

)

select * from cleaned