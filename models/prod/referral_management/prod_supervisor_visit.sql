{{
    config(
        materialized = 'table'
    )
}}

with staging as (

    select *
    from {{ ref('staging_supervisor_visit') }}

),

final as (
    select
        reference_id,
        visit_date as supervisor_visit_date,
        supervisor_name,
        facility_visited,
        patient_health_status,
        non_visit_reason

    from staging
)

select * from final