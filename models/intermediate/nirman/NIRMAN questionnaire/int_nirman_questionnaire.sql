{{ config(materialized='table') }}

-- Unpivot all questionnaire response columns into a long format.
-- The unpivot_questionnaire_columns macro handles:
--   - generating UNION ALL for each numbered column
--   - splitting response into response_int (numeric) and response_text
--   - filtering out NULL responses

{% set categories = [
    ('carrer', 1, 8),
    ('criteria', 1, 9),
    ('insecurities', 1, 10),
    ('question', 1, 178),
    ('finance', 1, 5)
] %}

with all_unpivoted as (
    {% for prefix, start_val, end_val in categories %}
    {{ unpivot_questionnaire_columns(ref('staging_nirman_questionnaire'), prefix, start_val, end_val) }}
    {% if not loop.last %}
    union all
    {% endif %}
    {% endfor %}

    union all

    -- social_contribution is a single non-numbered column, handled separately
    select 
        participant_id,
        participant_name,
        workshop_name,
        workshop_phase,
        batch,
        'social_contribution' as question_code,
        null::int as response_int,
        cast(social_contribution as text) as response_text
    from {{ ref('staging_nirman_questionnaire') }}
    where social_contribution is not null
)

select
    participant_id,
    participant_name,
    workshop_name,
    workshop_phase,
    batch,
    question_code,
    response_int,
    response_text
from all_unpivoted