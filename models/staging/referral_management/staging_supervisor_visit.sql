{{ config(materialized='table') }}

-- models/staging/stg_supervisor_visit.sql
-- Staging model for supervisor follow-up visits
-- Source: Chatbot -> Frappe -> Airbyte -> Postgres (tabSupervisor_visit)

with source as (

    select * from {{ source('referral_management', 'tabSupervisor_Visit') }}
    where parent is not null
      and trim(parent) <> ''

),

cleaned as (

    select

        --referrance number
        trim(s.parent)::text                                        as reference_id,

        --visit date
        case
            when s.visit_date::text ~ '^\d{2}-\d{2}-\d{4}$'
                then to_date(s.visit_date::text, 'DD-MM-YYYY')
            else null
        end                                                                   as visit_date,

        
        nullif(trim(s.supervisor_name), '')::text                             as supervisor_name,
        nullif(trim(s.facility_visited), '')::text                            as facility_visited,
        nullif(trim(s.patient_health_status), '')::text                       as patient_health_status,

        --non-visit reason
        nullif(
            initcap(regexp_replace(trim(s.non_visit_reason_code), '\s+', ' ', 'g')),
            ''
        )::text                                                               as non_visit_reason

        from source s

)

select * from cleaned