{{ config(materialized='table') }}

-- ─────────────────────────────────────────────────────────────────────────────
-- PROD NIRMAN DEMOGRAPHICS & QUESTIONNAIRE WIDE
-- ─────────────────────────────────────────────────────────────────────────────
-- Combines each participant's full demographic profile with all questionnaire
-- responses across Level 0.1 (Pre & Post), Level 0.2 (Post), and Level 0.3 (Post)
-- into a single consolidated row per Participant ID.
-- ─────────────────────────────────────────────────────────────────────────────

{% set excluded_cols = [
    'participant_id',
    'participant_name',
    'workshop_name',
    'batch',
    'workshop_level',
    'workshop_phase'
] %}

{% set phases = [
    ('0.1 Pre', 'q01_pre'),
    ('0.1 Post', 'q01_post'),
    ('0.2 Post', 'q02_post'),
    ('0.3 Post', 'q03_post')
] %}

{% if execute %}
    {% set q_relation = ref('prod_nirman_questionnaire') %}
    {% set all_cols = adapter.get_columns_in_relation(q_relation) %}
    {% set question_cols = [] %}
    {% for col in all_cols %}
        {% if col.name not in excluded_cols %}
            {% do question_cols.append(col.name) %}
        {% endif %}
    {% endfor %}
{% else %}
    {% set question_cols = [] %}
{% endif %}

with demographics as (
    select * from {{ ref('prod_nirman_demographics') }}
),

q01_pre as (
    select * from {{ ref('prod_nirman_questionnaire') }}
    where workshop_level = 0.1 and workshop_phase = 'Pre'
),

q01_post as (
    select * from {{ ref('prod_nirman_questionnaire') }}
    where workshop_level = 0.1 and workshop_phase = 'Post'
),

q02_post as (
    select * from {{ ref('prod_nirman_questionnaire') }}
    where workshop_level = 0.2 and workshop_phase = 'Post'
),

q03_post as (
    select * from {{ ref('prod_nirman_questionnaire') }}
    where workshop_level = 0.3 and workshop_phase = 'Post'
)

select
    -- ── Participant Demographics ──────────────────────────────────────────────
    d.*

    -- ── Multi-Phase Questionnaire Responses ──────────────────────────────────
    {% for phase_prefix, phase_alias in phases %}
    {% for col_name in question_cols %}
    , {{ phase_alias }}."{{ col_name }}" as "{{ phase_prefix }} - {{ col_name }}"
    {% endfor %}
    {% endfor %}

from demographics d
left join q01_pre  on d."Participant ID" = q01_pre.participant_id
left join q01_post on d."Participant ID" = q01_post.participant_id
left join q02_post on d."Participant ID" = q02_post.participant_id
left join q03_post on d."Participant ID" = q03_post.participant_id
order by d."Participant ID"
