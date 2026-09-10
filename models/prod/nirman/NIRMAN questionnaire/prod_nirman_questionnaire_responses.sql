{{ config(materialized='table') }}

-- Join unpivoted data with question lookup to get actual question text
-- This creates a long format table with readable question text

with resolved_responses as (
    select
        participant_id,
        participant_name,
        workshop_name,
        workshop_phase,
        batch,
        response_int,
        response_text,
        case question_code
            when 'question_65'  then 'question_23'
            when 'question_66'  then 'question_24'
            when 'question_67'  then 'question_25'
            when 'question_68'  then 'question_26'
            when 'question_69'  then 'question_27'
            when 'question_70'  then 'question_28'
            when 'question_71'  then 'question_29'
            when 'question_72'  then 'question_30'
            when 'question_73'  then 'question_31'
            when 'question_74'  then 'question_32'
            when 'question_75'  then 'question_34'
            when 'question_76'  then 'question_35'
            when 'question_77'  then 'question_36'
            when 'question_78'  then 'question_37'
            when 'question_79'  then 'question_38'
            when 'question_80'  then 'question_40'
            when 'question_87'  then 'question_55'
            when 'question_88'  then 'question_7'
            when 'question_91'  then 'question_42'
            when 'question_94'  then 'question_17'
            when 'question_101' then 'question_60'
            when 'question_102' then 'question_57'
            when 'question_103' then 'question_61'
            when 'question_104' then 'question_37'
            when 'question_117' then 'question_85'
            when 'question_119' then 'question_93'
            when 'question_122' then 'question_22'
            when 'question_126' then 'question_57'
            when 'question_128' then 'question_22'
            when 'question_130' then 'question_57'
            when 'question_131' then 'question_25'
            when 'question_133' then 'question_30'
            when 'question_139' then 'question_10'
            when 'question_140' then 'question_14'
            when 'question_141' then 'question_85'
            when 'question_142' then 'question_86'
            else question_code
        end as question_code
    from {{ ref('int_nirman_questionnaire') }}
),

deduplicated_responses as (
    select
        *,
        row_number() over (
            partition by participant_id, workshop_name, workshop_phase, question_code
            order by response_int desc, response_text desc
        ) as rn
    from resolved_responses
    where coalesce(cast(response_int as text), trim(response_text)) != ''
),

responses_with_questions as (
    select
        r.participant_id as response_id,
        r.participant_name,
        r.workshop_name,
        r.workshop_phase,
        r.question_code,
        r.batch as batch,
        case 
            when r.batch::numeric = floor(r.batch::numeric) then 0.1
            when round(r.batch::numeric - floor(r.batch::numeric), 1) = 0.2 then 0.2
            when round(r.batch::numeric - floor(r.batch::numeric), 1) = 0.3 then 0.3
        end as workshop_level,
        q.category,
        q.question_text as question,
        q.short_question_text as short_question,
        -- prefer integer response when available, otherwise use textual response
        coalesce(cast(r.response_int as text), r.response_text) as response
    from deduplicated_responses r
    left join {{ ref('staging_nirman_questions_lookup') }} q
        on r.question_code = q.question_code
    where r.rn = 1
)

select
    response_id,
    participant_name as participant,
    workshop_name as workshop,
    workshop_phase,
    batch,
    workshop_level,
    category,
    question_code,
    question,
    short_question,
    response
from responses_with_questions
order by 
    response_id, 
    case category
        when 'career' then 1
        when 'criteria' then 2
        when 'insecurities' then 3
        when 'social_contribution' then 4
        when 'questions' then 5
        when 'finance' then 6
    end,
    question_code