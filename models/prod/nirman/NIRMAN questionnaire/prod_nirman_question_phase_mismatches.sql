{{ config(materialized='table') }}

with phase_counts as (
    select
        r.batch,
        r.question_code,
        r.question,
        count(case when r.workshop_phase = 'Pre' and r.response is not null and r.response not in ('None', '', '0') then 1 end) as pre_responses,
        count(case when r.workshop_phase = 'Post' and r.response is not null and r.response not in ('None', '', '0') then 1 end) as post_responses
    from {{ ref('prod_nirman_questionnaire_responses') }} r
    left join {{ ref('prod_nirman_demographics') }} d
        on r.response_id = d."Participant ID"
    where r.category = 'questions'
      and r.workshop_level = 0.1
      and d."Workshop Type" = 'NIRMAN'
    group by r.batch, r.question_code, r.question
)

select
    batch,
    question_code,
    question,
    pre_responses,
    post_responses,
    case
        when pre_responses = 0 and post_responses > 0 then 'Missing in Pre'
        when post_responses = 0 and pre_responses > 0 then 'Missing in Post'
    end as mismatch_type,
    (pre_responses = 0 and post_responses > 0) as is_missing_in_pre,
    (post_responses = 0 and pre_responses > 0) as is_missing_in_post
from phase_counts
-- We use > 0 instead of > 5 as requested by the nature of the requirement, 
-- but we filter out cases where both are zero or both are > 0.
where (pre_responses = 0 and post_responses > 0)
   or (post_responses = 0 and pre_responses > 0)
order by batch, question_code
