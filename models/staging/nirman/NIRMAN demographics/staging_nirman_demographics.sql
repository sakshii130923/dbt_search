{{ config(materialized='table') }}

/*
  Location Normalisation — CASE-based lookup, no extensions required
  ──────────────────────────────────────────────────────────────────
  State  : CASE map with aliases + international detection + inferred-from-district
  District: CASE map (MH only) with aliases
  Tehsil  : CASE map scoped by resolved district; covers all 356 MH talukas
             plus common spelling variants, locality names, and renamed talukas

  To add a new alias: add a WHEN clause in the relevant district block in Step 3.
  No extensions, macros, or seeds required.

  Audit columns:
    state_match_status    → OK | Unmatched | International
    district_match_status → OK | Unmatched
    tehsil_match_method   → Resolved | Null Input | Skipped-No-District
*/

with source_data as (
    select
        id::text                                           as participant_id,
        full_name::text                                    as name,
        gender::text                                       as gender,
        batch::text                                        as batch,
        current_age::numeric                               as current_age,
        age_at_the_time_of_the_workshop::numeric           as age_at_workshop,
        workshop_details::text                             as workshop,
        nirman_krutee_nirman::text                         as workshop_type,
        workshops_attended                                 as workshops_attended,
        workshop_month_and_year::text                      as workshop_month_year,
        stream::text                                       as educational_stream,
        state::text                                        as native_state,
        district::text                                     as native_district,
        tehsiltown::text                                   as native_tehsiltown,
        point_2_workshop_name::text                        as point_2_workshop_name,
        point_2_workshop_invited::text                     as point_2_workshop_invited,
        point_2_workshop_attended::text                    as point_2_workshop_attended,
        point_3_workshop_name::text                        as point_3_workshop_name,
        point_3_workshop_invited::text                     as point_3_workshop_invited,
        point_3_workshop_attended::text                    as point_3_workshop_attended,
        case
            when trim(level_of_education) = ''              then null
            when upper(trim(level_of_education)) = 'NA'     then null
            when upper(trim(level_of_education)) = 'N/A'    then null
            when level_of_education is null                 then null
            else level_of_education::text
        end                                                as level_of_education,
        current_status_of_work::text                       as current_status_of_work,
        -- Field was float in Frappe (cast to numeric worked directly).
        -- Changed to data type (text) in Frappe — values are now strings,
        -- so we use a regex guard before casting to numeric.
        case
            when trim(person_years_of_social_action_as_on_31st_march_latest::text) = ''    then null
            when person_years_of_social_action_as_on_31st_march_latest is null        then null
            when upper(trim(person_years_of_social_action_as_on_31st_march_latest::text))
                 in ('NA', 'N/A')                                                     then null
            when trim(person_years_of_social_action_as_on_31st_march_latest::text)
                 !~ '^[0-9]+(\.[0-9]+)?$'                                             then null
            else round(
                trim(person_years_of_social_action_as_on_31st_march_latest::text)::numeric,
                1)
        end                                                as person_years_social_action
    from {{ source('nirman', 'demographics_raw') }}
),

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1 : basic cleaning + work/education categorisation (unchanged logic)
-- ─────────────────────────────────────────────────────────────────────────────
cleaned_data as (
    select
        participant_id,
        trim(name)                   as name,
        trim(upper(gender))          as gender,
        case
            when upper(trim(workshop_type)) = 'KRUTEE NIRMAN'
                then nullif(regexp_replace(trim(workshop), '[^0-9\\.]', '', 'g'), '')::numeric
            when trim(batch) = ''                             then null
            when upper(trim(batch)) in ('NA', 'N/A')         then null
            else nullif(regexp_replace(trim(batch), '[^0-9\\.]', '', 'g'), '')::numeric
        end                          as batch,

        -- ── Workshop ─────────────────────────────────────────────────────────
        -- For Krutee NIRMAN: one workshop per batch → always 'A'
        -- For all others: use workshop column as normal
        current_age,  -- Added: Include current_age from source_data
        age_at_workshop,  -- Added: Include age_at_workshop from source_data
        case
            when upper(trim(workshop_type)) = 'KRUTEE NIRMAN' then 'A'
            else trim(workshop)
        end                          as workshop,
        trim(workshop_type)          as workshop_type,
        case
            when workshop_month_year ~ '^\d{4}-\d{2}-\d{2}' then
                case substring(trim(workshop_month_year) from 6 for 2)
                    when '01' then substring(trim(workshop_month_year) from 3 for 2) || '-Jan'
                    when '02' then substring(trim(workshop_month_year) from 3 for 2) || '-Feb'
                    when '03' then substring(trim(workshop_month_year) from 3 for 2) || '-Mar'
                    when '04' then substring(trim(workshop_month_year) from 3 for 2) || '-Apr'
                    when '05' then substring(trim(workshop_month_year) from 3 for 2) || '-May'
                    when '06' then substring(trim(workshop_month_year) from 3 for 2) || '-Jun'
                    when '07' then substring(trim(workshop_month_year) from 3 for 2) || '-Jul'
                    when '08' then substring(trim(workshop_month_year) from 3 for 2) || '-Aug'
                    when '09' then substring(trim(workshop_month_year) from 3 for 2) || '-Sep'
                    when '10' then substring(trim(workshop_month_year) from 3 for 2) || '-Oct'
                    when '11' then substring(trim(workshop_month_year) from 3 for 2) || '-Nov'
                    when '12' then substring(trim(workshop_month_year) from 3 for 2) || '-Dec'
                end
            else trim(workshop_month_year)
        end                          as workshop_month_year,
        workshops_attended,
        case
            when trim(educational_stream) = 'Commerace' then 'Commerce'
            when trim(educational_stream) = 'Medical' then 'Medical / Public Health'
            else trim(educational_stream)
        end                          as educational_stream_raw,
        trim(level_of_education)     as level_of_education,
        trim(current_status_of_work) as current_status_of_work_raw,
        person_years_social_action,

        -- raw location fields preserved for audit
        trim(native_state)           as raw_state,
        trim(native_district)        as raw_district,
        trim(native_tehsiltown)      as raw_tehsil,

        point_2_workshop_name,
        point_2_workshop_invited,
        point_2_workshop_attended,
        point_3_workshop_name,
        point_3_workshop_invited,
        point_3_workshop_attended,

        -- ── Current Status of Work ──────────────────────────────────────────
        case
            when upper(trim(current_status_of_work)) = 'DT'
                then 'Different Trajectory'
            when upper(trim(current_status_of_work)) = 'EDB'
                then 'Educational Break'
            when upper(trim(current_status_of_work)) = 'OW'
                then 'Other Work'
            when upper(trim(current_status_of_work)) = 'NOT NOW'
                 or lower(trim(current_status_of_work)) ilike '%not now%'
                then 'Previously SIW'
            when upper(trim(current_status_of_work)) = 'SIW'
                 or lower(trim(current_status_of_work)) ilike 'social impact work'
                then 'Social Impact Work'
            when upper(trim(current_status_of_work)) = 'NOT SURE'
                then 'Not Sure'
            else trim(current_status_of_work)
        end as current_status_of_work,

        -- ── Educational Stream 1 ─────────────────────────────────────────────
        case
            when lower(trim(educational_stream)) ilike '%medical%'
                then 'Medical'
            when lower(trim(educational_stream)) ilike '%engineering%'
                then 'Engineering'
            when lower(trim(educational_stream)) ilike 'arts%'
                 or lower(trim(educational_stream)) ilike '%art%'
                 or lower(trim(educational_stream)) ilike '%commerce%'
                 or lower(trim(educational_stream)) ilike '%science%'
                 or lower(trim(educational_stream)) ilike '%pharmancy%'
                then 'Arts/Commerce/Science/Pharmacy'
            else 'Other'
        end as educational_stream_1,

        -- ── Education Status ─────────────────────────────────────────────────
        case
            when lower(trim(current_status_of_work)) ilike '%student%'
                then 'Student'
            when upper(trim(current_status_of_work)) = 'SIW'
                 or lower(trim(current_status_of_work)) ilike '%social impact work%'
                 or upper(trim(current_status_of_work)) = 'NOT NOW'
                 or lower(trim(current_status_of_work)) ilike '%not now%'
                 or lower(trim(current_status_of_work)) ilike '%prev siw%'
                 or upper(trim(current_status_of_work)) = 'OW'
                 or lower(trim(current_status_of_work)) ilike '%other work%'
                 or upper(trim(current_status_of_work)) = 'EDB'
                 or lower(trim(current_status_of_work)) ilike '%educational break%'
                 or upper(trim(current_status_of_work)) = 'DT'
                 or lower(trim(current_status_of_work)) ilike '%different trajectory%'
                then 'Graduate'
            when (current_status_of_work is null
                  or trim(current_status_of_work) = '')
                 and (
                     upper(trim(level_of_education)) = 'M'
                     or upper(trim(level_of_education)) = 'P'
                     or lower(trim(level_of_education)) ilike '%master%'
                     or lower(trim(level_of_education)) ilike '%phd%'
                 )
                then 'Graduate'
            else 'Not Known'
        end as education_status

    from source_data
),


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2 : location normalisation
--
--  A. STATE   — CASE lookup with aliases + international detection
--  B. DISTRICT — CASE lookup (MH only) with aliases
--  C. TEHSIL  — CASE lookup with aliases, district-scoped
--
--  No extensions required. No macros. No seeds.
--  To add new aliases: just add a WHEN clause.
-- ─────────────────────────────────────────────────────────────────────────────

location_normalized as (
    select
        *,

        -- ══════════════════════════════════════════════════════════════
        -- A. STATE
        -- ══════════════════════════════════════════════════════════════
        case
            -- International
            when lower(trim(raw_state)) in (
                'usa','us','united states','united states of america',
                'new york','california','texas','new jersey','florida',
                'uk','united kingdom','england','australia','canada',
                'germany','france','uae','dubai','singapore','japan',
                'netherlands','switzerland','new zealand','ireland','the gambia'
            ) then 'International'
            when lower(trim(raw_district)) ilike '%abroad%'
              or lower(trim(raw_district)) ilike '%international%'
                then 'International'

            -- Maharashtra + aliases
            when lower(trim(raw_state)) in ('maharashtra','mh','maha','m.h.')
                then 'Maharashtra'
            -- Raw state is actually a MH district name → Maharashtra
            when upper(trim(raw_state)) in (
                'AHMEDNAGAR','AKOLA','AMRAVATI','AURANGABAD','BEED','BHANDARA',
                'BULDHANA','CHANDRAPUR','DHULE','GADCHIROLI','GONDIA','HINGOLI',
                'JALGAON','JALNA','KOLHAPUR','LATUR','MUMBAI CITY','MUMBAI SUBURBAN',
                'MUMBAI','NAGPUR','NANDED','NANDURBAR','NASHIK','OSMANABAD',
                'PALGHAR','PARBHANI','PUNE','RAIGAD','RATNAGIRI','SANGLI',
                'SATARA','SINDHUDURG','SOLAPUR','THANE','WARDHA','WASHIM','YAVATMAL'
            ) then 'Maharashtra'

            -- Other Indian states
            when lower(trim(raw_state)) in ('delhi','new delhi','ncr','n.c.r.')
                then 'Delhi'
            when lower(trim(raw_state)) in ('up','uttar pradesh','u.p.')
                then 'Uttar Pradesh'
            when lower(trim(raw_state)) in ('mp','madhya pradesh','m.p.')
                then 'Madhya Pradesh'
            when lower(trim(raw_state)) in ('rajasthan','rj','rajsthan')
                then 'Rajasthan'
            when lower(trim(raw_state)) in ('gujarat','gj','gujrat')
                then 'Gujarat'
            when lower(trim(raw_state)) in ('karnataka','karnatak','ktk')
                then 'Karnataka'
            when lower(trim(raw_state)) in ('andhra pradesh','ap','andhra')
                then 'Andhra Pradesh'
            when lower(trim(raw_state)) in ('telangana','ts','telangna','telengana')
                then 'Telangana'
            when lower(trim(raw_state)) in ('tamil nadu','tamilnadu','tn','tamil naidu')
                then 'Tamil Nadu'
            when lower(trim(raw_state)) in ('kerala','kl')
                then 'Kerala'
            when lower(trim(raw_state)) in ('west bengal','wb','bengal')
                then 'West Bengal'
            when lower(trim(raw_state)) in ('bihar','br')
                then 'Bihar'
            when lower(trim(raw_state)) in ('jharkhand','jh')
                then 'Jharkhand'
            when lower(trim(raw_state)) in ('odisha','orissa','od')
                then 'Odisha'
            when lower(trim(raw_state)) in ('assam','as')
                then 'Assam'
            when lower(trim(raw_state)) in ('punjab','pb')
                then 'Punjab'
            when lower(trim(raw_state)) in ('haryana','hr')
                then 'Haryana'
            when lower(trim(raw_state)) in ('himachal pradesh','hp','himachal')
                then 'Himachal Pradesh'
            when lower(trim(raw_state)) in ('uttarakhand','uk','uttaranchal')
                then 'Uttarakhand'
            when lower(trim(raw_state)) in ('chhattisgarh','chattisgarh','cg','chhatisgarh')
                then 'Chhattisgarh'
            when lower(trim(raw_state)) in ('goa')
                then 'Goa'
            when lower(trim(raw_state)) in ('j&k','jammu & kashmir','jammu and kashmir','jk')
                then 'Jammu and Kashmir'
            when lower(trim(raw_state)) in ('chandigarh')
                then 'Chandigarh'
            when lower(trim(raw_state)) in ('puducherry','pondicherry','py')
                then 'Puducherry'

            -- State blank but district implies Maharashtra
            when (raw_state is null or trim(raw_state) = '')
                and upper(trim(raw_district)) in (
                    'AHMEDNAGAR','AKOLA','AMRAVATI','AURANGABAD','BEED','BHANDARA',
                    'BULDHANA','CHANDRAPUR','DHULE','GADCHIROLI','GONDIA','HINGOLI',
                    'JALGAON','JALNA','KOLHAPUR','LATUR','MUMBAI CITY','MUMBAI SUBURBAN',
                    'MUMBAI','NAGPUR','NANDED','NANDURBAR','NASHIK','OSMANABAD',
                    'PALGHAR','PARBHANI','PUNE','RAIGAD','RATNAGIRI','SANGLI',
                    'SATARA','SINDHUDURG','SOLAPUR','THANE','WARDHA','WASHIM','YAVATMAL'
                ) then 'Maharashtra'

            -- State blank but district contains another state name
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%karnataka%'      then 'Karnataka'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%gujarat%'         then 'Gujarat'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%telangana%'       then 'Telangana'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%andhra%'          then 'Andhra Pradesh'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%rajasthan%'       then 'Rajasthan'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%delhi%'           then 'Delhi'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%madhya pradesh%'  then 'Madhya Pradesh'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%uttar pradesh%'   then 'Uttar Pradesh'
            when (raw_state is null or trim(raw_state) = '')
                and lower(trim(raw_district)) ilike '%goa%'             then 'Goa'

            when raw_state is null or trim(raw_state) = ''              then null
            else initcap(trim(raw_state))
        end as state_normalized,

        -- ══════════════════════════════════════════════════════════════
        -- B. DISTRICT  (MH only)
        -- ══════════════════════════════════════════════════════════════
        case
            when lower(trim(raw_district)) ilike '%out of maharashtra%'   then null
            when lower(trim(raw_district)) ilike '%outside maharashtra%'   then null
            when lower(trim(raw_district)) ilike '%out of mh%'             then null
            when upper(trim(raw_district)) in (
                'MAHARASHTRA','KARNATAKA','GUJARAT','TELANGANA',
                'ANDHRA PRADESH','RAJASTHAN','DELHI','MADHYA PRADESH',
                'UTTAR PRADESH','GOA','KERALA','TAMIL NADU','BIHAR',
                'JHARKHAND','ODISHA','ASSAM','PUNJAB','HARYANA',
                'UTTARAKHAND','CHHATTISGARH','WEST BENGAL','HIMACHAL PRADESH'
            ) then null

            when upper(trim(raw_district)) in ('AHMEDNAGAR','AHMED NAGAR','AHMEDANAGAR','AHEMADNAGAR')
                then 'Ahmednagar'
            when upper(trim(raw_district)) in ('AKOLA')
                then 'Akola'
            when upper(trim(raw_district)) in ('AMRAVATI','AMARAVATI','AMRAWATI')
                then 'Amravati'
            when upper(trim(raw_district)) in ('AURANGABAD','CHHATRAPATI SAMBHAJINAGAR','CHHATRAPATI SAMBHAJINAGAR (AURANGABAD)')
                then 'Aurangabad'
            when upper(trim(raw_district)) in ('BEED','BID')
                then 'Beed'
            when upper(trim(raw_district)) in ('BHANDARA')
                then 'Bhandara'
            when upper(trim(raw_district)) in ('BULDHANA','BULDANA')
                then 'Buldhana'
            when upper(trim(raw_district)) in ('CHANDRAPUR','CHANDA')
                then 'Chandrapur'
            when upper(trim(raw_district)) in ('DHULE','DHULIA')
                then 'Dhule'
            when upper(trim(raw_district)) in ('GADCHIROLI')
                then 'Gadchiroli'
            when upper(trim(raw_district)) in ('GONDIA','GONDIYA')
                then 'Gondia'
            when upper(trim(raw_district)) in ('HINGOLI')
                then 'Hingoli'
            when upper(trim(raw_district)) in ('JALGAON')
                then 'Jalgaon'
            when upper(trim(raw_district)) in ('JALNA')
                then 'Jalna'
            when upper(trim(raw_district)) in ('KOLHAPUR')
                then 'Kolhapur'
            when upper(trim(raw_district)) in ('LATUR')
                then 'Latur'
            when upper(trim(raw_district)) in ('MUMBAI CITY','MUMBAI (CITY)','MUMBAI C')
                then 'Mumbai'
            when upper(trim(raw_district)) in ('MUMBAI SUBURBAN','MUMBAI (SUBURBAN)','MUMBAI SUB')
                then 'Mumbai'
            when upper(trim(raw_district)) in ('MUMBAI','BOMBAY')
                then 'Mumbai'
            when upper(trim(raw_district)) in ('NAGPUR')
                then 'Nagpur'
            when upper(trim(raw_district)) in ('NANDED','NANDED-WAGHALA')
                then 'Nanded'
            when upper(trim(raw_district)) in ('NANDURBAR')
                then 'Nandurbar'
            when upper(trim(raw_district)) in ('NASHIK','NASIK')
                then 'Nashik'
            when upper(trim(raw_district)) in ('OSMANABAD','DHARASHIV','DHARASIV')
                then 'Osmanabad'
            when upper(trim(raw_district)) in ('PALGHAR')
                then 'Palghar'
            when upper(trim(raw_district)) in ('PARBHANI')
                then 'Parbhani'
            when upper(trim(raw_district)) in ('PUNE','POONA')
                then 'Pune'
            when upper(trim(raw_district)) in ('RAIGAD','RAIGARH','KULABA')
                then 'Raigad'
            when upper(trim(raw_district)) in ('RATNAGIRI')
                then 'Ratnagiri'
            when upper(trim(raw_district)) in ('SANGLI')
                then 'Sangli'
            when upper(trim(raw_district)) in ('SATARA')
                then 'Satara'
            when upper(trim(raw_district)) in ('SINDHUDURG','SINDU DURG')
                then 'Sindhudurg'
            when upper(trim(raw_district)) in ('SOLAPUR','SHOLAPUR')
                then 'Solapur'
            when upper(trim(raw_district)) in ('THANE','THAN','THANA')
                then 'Thane'
            when upper(trim(raw_district)) in ('WARDHA')
                then 'Wardha'
            when upper(trim(raw_district)) in ('WASHIM','VASHIM')
                then 'Washim'
            when upper(trim(raw_district)) in ('YAVATMAL','YEOTMAL','YAWATMAL')
                then 'Yavatmal'

            when raw_district is null or trim(raw_district) = '' then null
            else null
        end as district_normalized

    from cleaned_data
),

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3 : tehsil normalisation
--
--  Resolution priority per row:
--   T1. Exact case-insensitive match against taluka master (within resolved district)
--   T2. Alias lookup (district-scoped CASE) — handles typos, locality names,
--       parenthetical variants, renamed talukas
--   T3. Exact match across all MH talukas regardless of district (last resort)
--   T4. NULL  — not a taluka name (city locality, 'Not Known', district name, etc.)
--
--  Logic lives in a single CASE; no extensions, seeds, or macros required.
-- ─────────────────────────────────────────────────────────────────────────────

tehsil_normalized_cte as (
    select
        ln.*,

        case

            -- ── Sentinel / null values → always NULL ───────────────────────
            when raw_tehsil is null or trim(raw_tehsil) = ''            then null
            when lower(trim(raw_tehsil)) in (
                'not known','n/a','na','unknown','none','-','--',
                'not applicable','nill','nil'
            )                                                            then null

            -- ── T1+T2: district-scoped lookup ──────────────────────────────
            -- Exact master matches + known aliases, all scoped to resolved district.
            -- Format: when district_normalized = 'X' and upper(trim(raw_tehsil)) in (...) then 'Y'

            -- ── Ahmednagar ─────────────────────────────────────────────────
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'AHMEDNAGAR','AHMED NAGAR','NAGAR') then 'Nagar'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'SHEVGAON','SHEVGAVON') then 'Shevgaon'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'PATHARDI') then 'Pathardi'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'PARNER') then 'Parner'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'SANGAMNER','SANGAMANER') then 'Sangamner'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'KOPARGAON') then 'Kopargaon'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'AKOLE') then 'Akole'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'SHRIRAMPUR','SRIRAMPUR','SHIRDI') then 'Shrirampur'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'NEVASA','NEWASA') then 'Nevasa'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'RAHATA') then 'Rahata'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'RAHURI') then 'Rahuri'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'SHRIGONDA') then 'Shrigonda'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'KARJAT') then 'Karjat'
            when district_normalized = 'Ahmednagar' and upper(trim(raw_tehsil)) in (
                'JAMKHED') then 'Jamkhed'

            -- ── Akola ──────────────────────────────────────────────────────
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'AKOLA') then 'Akola'
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'AKOT') then 'Akot'
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'TELHARA') then 'Telhara'
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'BALAPUR') then 'Balapur'
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'PATUR') then 'Patur'
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'MURTAJAPUR','MURTIZAPUR') then 'Murtajapur'
            when district_normalized = 'Akola' and upper(trim(raw_tehsil)) in (
                'BARSHITAKLI') then 'Barshitakli'

            -- ── Amravati ───────────────────────────────────────────────────
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'AMRAVATI','AMARAVATI','AMARAWATI','AMRAVATHI') then 'Amravati'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'ACHALPUR') then 'Achalpur'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'BHATKULI','BHATUKALI') then 'Bhatkuli'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'CHANDURBAZAR','CHANDUR BAZAR','CHANDUR BAZAAR','CHANDUR BAZZAR') then 'Chandurbazar'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'MORSHI') then 'Morshi'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'NANDGAON KHANDESHWAR','NANDGAON (KHANDESHWAR)','NANDGAON KHANDASHWAR') then 'Nandgaon Khandeshwar'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'DHARNI') then 'Dharni'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'DARYAPUR') then 'Daryapur'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'ANJANGAON SURJI','ANJANGAON-SURJI','ANJANGAON') then 'Anjangaon Surji'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'CHANDUR','CHANDUR RAILWAY') then 'Chandur'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'DHAMANGAON','DHAMANGAON RAILWAY') then 'Dhamangaon'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'TIOSA') then 'Tiosa'
            when district_normalized = 'Amravati' and upper(trim(raw_tehsil)) in (
                'WARUD') then 'Warud'

            -- ── Aurangabad ─────────────────────────────────────────────────
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'AURANGABAD','AURNAGBAD','AURANGBAD') then 'Aurangabad'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'KANNAD') then 'Kannad'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'SOEGAON') then 'Soegaon'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'SILLOD') then 'Sillod'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'PHULAMBRI','PHULAMBARI') then 'Phulambri'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'KHULDABAD','KHULTABAD') then 'Khuldabad'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'VAIJAPUR') then 'Vaijapur'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'PAITHAN') then 'Paithan'
            when district_normalized = 'Aurangabad' and upper(trim(raw_tehsil)) in (
                'GANGAPUR') then 'Gangapur'

            -- ── Beed ───────────────────────────────────────────────────────
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'BEED','BID') then 'Beed'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'ASHTI') then 'Ashti'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'PATODA') then 'Patoda'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'SHIRUR KASAR','SHIRUR (KASAR)','SHIRUR-KASAR') then 'Shirur Kasar'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'GEORAI','GEVRAI','DHARUR') then 'Georai'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'MAJALGAON') then 'Majalgaon'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'WADWANI') then 'Wadwani'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'KAIJ') then 'Kaij'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'PARLI','PARLI VAIJANATH','PADALI') then 'Parli'
            when district_normalized = 'Beed' and upper(trim(raw_tehsil)) in (
                'AMBAJOGAI','AMBEJOGAI') then 'Ambajogai'

            -- ── Bhandara ───────────────────────────────────────────────────
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'BHANDARA','BHANADARA') then 'Bhandara'
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'TUMSAR') then 'Tumsar'
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'PAUNI') then 'Pauni'
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'MOHADI') then 'Mohadi'
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'SAKOLI') then 'Sakoli'
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'LAKHNI','LAKHANI') then 'Lakhni'
            when district_normalized = 'Bhandara' and upper(trim(raw_tehsil)) in (
                'LAKHANDUR') then 'Lakhandur'

            -- ── Buldhana ───────────────────────────────────────────────────
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'BULDHANA','BULDANA') then 'Buldhana'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'CHIKHLI') then 'Chikhli'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'DEULGAON RAJA','DEULGAON-RAJA','DEULGOAN RAJA') then 'Deulgaon Raja'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'JALGAON JAMOD','JALGAON (JAMOD)','JALGAON') then 'Jalgaon Jamod'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'KHAMGAON','KHAMGAO') then 'Khamgaon'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'LONAR') then 'Lonar'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'MALKAPUR') then 'Malkapur'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'MEHKAR') then 'Mehkar'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'MOTALA') then 'Motala'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'NANDURA') then 'Nandura'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'SANGRAMPUR') then 'Sangrampur'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'SHEGAON') then 'Shegaon'
            when district_normalized = 'Buldhana' and upper(trim(raw_tehsil)) in (
                'SINDKHED RAJA','SINDKHED-RAJA','SINKHED RAJA','SHINDKHED RAJA') then 'Sindkhed Raja'

            -- ── Chandrapur ─────────────────────────────────────────────────
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'CHANDRAPUR','CHANDA') then 'Chandrapur'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'BALLARPUR','BALLARSHA','BALLHARSHA') then 'Ballarpur'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'WARORA','SAWALI') then 'Warora'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'BHADRAVATI','BHADRAWATI','POMBHURNA') then 'Bhadravati'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'BRAHMAPURI','BRAMHAPURI','BRAMHPURI','BRAHAMAPURI') then 'Brahmapuri'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'NAGBHID') then 'Nagbhid'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'SINDEWAHI') then 'Sindewahi'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'CHIMUR') then 'Chimur'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'MUL') then 'Mul'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'SAOLI') then 'Saoli'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'GONDPIMPRI','GONDPIPARI') then 'Gondpimpri'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'RAJURA') then 'Rajura'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'KORPANA') then 'Korpana'
            when district_normalized = 'Chandrapur' and upper(trim(raw_tehsil)) in (
                'JIVATI','JIWATI') then 'Jivati'

            -- ── Dhule ──────────────────────────────────────────────────────
            when district_normalized = 'Dhule' and upper(trim(raw_tehsil)) in (
                'DHULE','DHULIA') then 'Dhule'
            when district_normalized = 'Dhule' and upper(trim(raw_tehsil)) in (
                'SAKRI') then 'Sakri'
            when district_normalized = 'Dhule' and upper(trim(raw_tehsil)) in (
                'SHIRPUR') then 'Shirpur'
            when district_normalized = 'Dhule' and upper(trim(raw_tehsil)) in (
                'SHINDKHEDA','SINDKHEDA') then 'Shindkheda'

            -- ── Gadchiroli ─────────────────────────────────────────────────
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'GADCHIROLI') then 'Gadchiroli'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'DHANORA') then 'Dhanora'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'CHAMORSHI') then 'Chamorshi'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'MULCHERA') then 'Mulchera'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'DESAIGANJ','WADSA','WADASA','DESAIGANJ WADSA','DESAIGANJ (WADSA)') then 'Desaiganj'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'ARMORI') then 'Armori'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'KURKHEDA') then 'Kurkheda'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'KORCHI') then 'Korchi'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'AHERI','ETAPALLI') then 'Aheri'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'BHAMRAGAD','BHAMRAGARH') then 'Bhamragad'
            when district_normalized = 'Gadchiroli' and upper(trim(raw_tehsil)) in (
                'SIRONCHA') then 'Sironcha'

            -- ── Gondia ─────────────────────────────────────────────────────
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'GONDIA') then 'Gondia'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'TIRORA','TIRODA') then 'Tirora'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'GOREGAON') then 'Goregaon'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'ARJUNI MORGAON','ARJUNI MOR GAON','ARJUNI MOR.','ARJUNI MORGAO',
                'ARJUNI-MORGAON','ARJUNIMORGAON') then 'Arjuni Morgaon'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'AMGAON') then 'Amgaon'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'SALEKASA') then 'Salekasa'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'SADAK ARJUNI','SADAK-ARJUNI') then 'Sadak Arjuni'
            when district_normalized = 'Gondia' and upper(trim(raw_tehsil)) in (
                'DEORI') then 'Deori'

            -- ── Hingoli ────────────────────────────────────────────────────
            when district_normalized = 'Hingoli' and upper(trim(raw_tehsil)) in (
                'HINGOLI') then 'Hingoli'
            when district_normalized = 'Hingoli' and upper(trim(raw_tehsil)) in (
                'KALAMNURI') then 'Kalamnuri'
            when district_normalized = 'Hingoli' and upper(trim(raw_tehsil)) in (
                'SENGAON','SENGAO') then 'Sengaon'
            when district_normalized = 'Hingoli' and upper(trim(raw_tehsil)) in (
                'AUNDHA NAGNATH','AUNDHA','AUNDHA-NAGNATH') then 'Aundha Nagnath'
            when district_normalized = 'Hingoli' and upper(trim(raw_tehsil)) in (
                'BASMAT','BASMATH') then 'Basmat'

            -- ── Jalgaon ────────────────────────────────────────────────────
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'JALGAON') then 'Jalgaon'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'JAMNER') then 'Jamner'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'ERANDOL') then 'Erandol'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'DHARANGAON') then 'Dharangaon'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'BHUSAWAL','BHUSAWAD','BHUSAVAL') then 'Bhusawal'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'RAVER') then 'Raver'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'MUKTAINAGAR','MUKTAI NAGAR','MUKTAINAGAR (EDALABAD)') then 'Muktainagar'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'BODWAD') then 'Bodwad'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'YAWAL') then 'Yawal'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'AMALNER') then 'Amalner'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'CHOPDA') then 'Chopda'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'PAROLA') then 'Parola'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'PACHORA') then 'Pachora'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'BHADGAON','KASUDA') then 'Bhadgaon'
            when district_normalized = 'Jalgaon' and upper(trim(raw_tehsil)) in (
                'CHALISGAON') then 'Chalisgaon'

            -- ── Jalna ──────────────────────────────────────────────────────
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'JALNA') then 'Jalna'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'BHOKARDAN') then 'Bhokardan'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'JAFRABAD') then 'Jafrabad'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'AMBAD') then 'Ambad'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'GHANSAWANGI','GHANSAVANGI') then 'Ghansawangi'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'PARTUR') then 'Partur'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'MANTHA') then 'Mantha'
            when district_normalized = 'Jalna' and upper(trim(raw_tehsil)) in (
                'BADNAPUR') then 'Badnapur'

            -- ── Kolhapur ───────────────────────────────────────────────────
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'KARVIR','KARVEER','KOLHAPUR','KOLHAPUR CITY','KOLHAPUR (CITY)','KARVIR (KOLHAPUR)') then 'Karvir'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'PANHALA') then 'Panhala'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'SHAHUWADI') then 'Shahuwadi'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'HATKANANGALE','HATKANANGLE','HATKANANAGALE','HATKANANANGLE','ICHALKARANJI') then 'Hatkanangale'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'SHIROL') then 'Shirol'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'GAGANBAWADA','GAGANBAVADA','GAGAN BAWADA') then 'Gaganbawada'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'RADHANAGARI','RADHANAGRI') then 'Radhanagari'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'KAGAL') then 'Kagal'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'BHUDARGAD') then 'Bhudargad'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'AJARA','AJRA') then 'Ajara'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'GADHINGLAJ','GADHINGALAJ') then 'Gadhinglaj'
            when district_normalized = 'Kolhapur' and upper(trim(raw_tehsil)) in (
                'CHANDGAD') then 'Chandgad'

            -- ── Latur ──────────────────────────────────────────────────────
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'LATUR') then 'Latur'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'AUSA') then 'Ausa'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'NILANGA') then 'Nilanga'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'UDGIR') then 'Udgir'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'RENAPUR') then 'Renapur'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'AHMADPUR','AHMEDPUR','AHMEDAPUR','AHAMADPUR','AHEMADPUR') then 'Ahmadpur'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'JALKOT') then 'Jalkot'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'CHAKUR') then 'Chakur'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'DEONI') then 'Deoni'
            when district_normalized = 'Latur' and upper(trim(raw_tehsil)) in (
                'SHIRUR ANANTPAL','SHIRUR (ANANTPAL)','SHIRUR ANANTAPAL') then 'Shirur Anantpal'

            -- ── Mumbai City ────────────────────────────────────────────────
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'FORT','MUMBAI CITY','MUMBAI','MUMBAI (CITY)','MUMBAI C') then 'Fort'
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'BYCULLA') then 'Byculla'
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'KURLA','MUMBAI SUBURBAN') then 'Kurla'

            -- ── Mumbai Suburban ────────────────────────────────────────────
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'ANDHERI','MUMBAI SUBURBAN','MUMBAI','MUMBAI (SUBURBAN)','MUMBAI SUB') then 'Andheri'
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'BORIVALI') then 'Borivali'
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'KURLA','KURLA (MULUND)') then 'Kurla'
            when district_normalized = 'Mumbai' and upper(trim(raw_tehsil)) in (
                'AMBARNATH','AMBERNATH') then 'Ambarnath'

            -- ── Nagpur ─────────────────────────────────────────────────────
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'NAGPUR URBAN','NAGPUR','NAGPUR (URBAN)','NAGPUR CITY','NAGPUR U') then 'Nagpur Urban'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'NAGPUR RURAL','NAGPUR (RURAL)','NAGPUR R') then 'Nagpur Rural'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'KATOL') then 'Katol'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'KALMESHWAR','KALAMESHWAR') then 'Kalmeshwar'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'SAVNER','SAONER') then 'Savner'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'PARSEONI') then 'Parseoni'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'RAMTEK') then 'Ramtek'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'KAMPTEE') then 'Kamptee'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'UMRED') then 'Umred'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'KUHI','BHIWAPUR') then 'Kuhi'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'MAUDA','MOUDA') then 'Mauda'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'HINGNA') then 'Hingna'
            when district_normalized = 'Nagpur' and upper(trim(raw_tehsil)) in (
                'NARKHED') then 'Narkhed'

            -- ── Nanded ─────────────────────────────────────────────────────
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'NANDED') then 'Nanded'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'ARDHAPUR') then 'Ardhapur'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'MUDKHED') then 'Mudkhed'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'BHOKAR') then 'Bhokar'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'UMRI','UMARI') then 'Umri'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'DHARMABAD') then 'Dharmabad'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'BILOLI') then 'Biloli'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'NAIGAON','NAIGAON (KHAIRGAON)') then 'Naigaon'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'LOHA') then 'Loha'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'KANDHAR') then 'Kandhar'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'KINWAT','KINVAT') then 'Kinwat'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'HADGAON') then 'Hadgaon'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'DEGLUR','DEGLOOR') then 'Deglur'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'MAHUR') then 'Mahur'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'HIMAYATNAGAR','HIMAYAT NAGAR') then 'Himayatnagar'
            when district_normalized = 'Nanded' and upper(trim(raw_tehsil)) in (
                'MUKHED') then 'Mukhed'

            -- ── Nandurbar ──────────────────────────────────────────────────
            when district_normalized = 'Nandurbar' and upper(trim(raw_tehsil)) in (
                'NANDURBAR') then 'Nandurbar'
            when district_normalized = 'Nandurbar' and upper(trim(raw_tehsil)) in (
                'SHAHADA') then 'Shahada'
            when district_normalized = 'Nandurbar' and upper(trim(raw_tehsil)) in (
                'TALODA','TALODE') then 'Taloda'
            when district_normalized = 'Nandurbar' and upper(trim(raw_tehsil)) in (
                'NAVAPUR','NAWAPUR') then 'Navapur'
            when district_normalized = 'Nandurbar' and upper(trim(raw_tehsil)) in (
                'AKKALKUWA') then 'Akkalkuwa'
            when district_normalized = 'Nandurbar' and upper(trim(raw_tehsil)) in (
                'AKRANI') then 'Akrani'

            -- ── Nashik ─────────────────────────────────────────────────────
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'NASHIK','NASIK') then 'Nashik'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'IGATPURI','IGATPURU') then 'Igatpuri'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'TRIMBAKESHWAR','TRIMBAK','TRYAMBAKESHWAR','TRYAMBAK') then 'Trimbakeshwar'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'DINDORI') then 'Dindori'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'PETH') then 'Peth'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'KALWAN') then 'Kalwan'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'SURGANA','SATANA') then 'Surgana'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'CHANDWAD','CHANDVAD') then 'Chandwad'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'DEOLA') then 'Deola'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'BAGLAN','BAGLAN (SATANA)') then 'Baglan'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'MALEGAON','MALEGAON (N)','MALEGAON N') then 'Malegaon'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'NANDGAON') then 'Nandgaon'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'YEOLA','YEVLA') then 'Yeola'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'NIPHAD') then 'Niphad'
            when district_normalized = 'Nashik' and upper(trim(raw_tehsil)) in (
                'SINNAR') then 'Sinnar'

            -- ── Osmanabad ──────────────────────────────────────────────────
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'OSMANABAD','DHARASHIV','DHARASIV') then 'Osmanabad'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'TULJAPUR') then 'Tuljapur'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'KALAMB','KALLAMB') then 'Kalamb'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'UMARGA','OMERGA') then 'Umarga'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'LOHARA') then 'Lohara'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'PARANDA') then 'Paranda'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'BHUM') then 'Bhum'
            when district_normalized = 'Osmanabad' and upper(trim(raw_tehsil)) in (
                'WASHI') then 'Washi'

            -- ── Palghar ────────────────────────────────────────────────────
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'PALGHAR') then 'Palghar'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'VASAI','VASAI-VIRAR','WASAI') then 'Vasai'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'DAHANU') then 'Dahanu'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'TALASARI') then 'Talasari'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'JAWHAR') then 'Jawhar'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'MOKHADA') then 'Mokhada'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'VIKRAMGAD','VIKRAMGARH') then 'Vikramgad'
            when district_normalized = 'Palghar' and upper(trim(raw_tehsil)) in (
                'WADA','VADA') then 'Wada'

            -- ── Parbhani ───────────────────────────────────────────────────
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'PARBHANI') then 'Parbhani'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'GANGAKHED') then 'Gangakhed'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'PATHRI') then 'Pathri'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'MANWATH','MANVAT') then 'Manwath'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'JINTUR') then 'Jintur'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'SONPETH') then 'Sonpeth'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'PURNA') then 'Purna'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'PALAM') then 'Palam'
            when district_normalized = 'Parbhani' and upper(trim(raw_tehsil)) in (
                'SAILU','SELU') then 'Sailu'

            -- ── Pune ───────────────────────────────────────────────────────
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'PUNE CITY','PUNE','PUNE URBAN','PUNE MUNICIPAL','KOTHRUD','BHOSARI') then 'Pune City'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'HAVELI','HAVALI','HAVELI (PUNE)') then 'Haveli'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'KHED','KHED (RAJGURUNAGAR)','KHED (PUNE)','KHED PUNE') then 'Khed'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'JUNNAR') then 'Junnar'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'AMBEGAON','AMBEGAON (GHODEGAON)') then 'Ambegaon'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'MAVAL','MAWAL','MAVAL (VADGAON)') then 'Maval'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'MULSHI') then 'Mulshi'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'SHIRUR','SHIRUR (PUNE)','SHIRUR PUNE') then 'Shirur'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'PURANDAR','PURANDHAR','PURANDHAR (SASWAD)','PURANDAR (SASWAD)','PURANDHAR SASWAD') then 'Purandar'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'VELHE') then 'Velhe'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'BHOR') then 'Bhor'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'BARAMATI') then 'Baramati'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'INDAPUR') then 'Indapur'
            when district_normalized = 'Pune' and upper(trim(raw_tehsil)) in (
                'DAUND') then 'Daund'

            -- ── Raigad ─────────────────────────────────────────────────────
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'ALIBAG','RAIGAD') then 'Alibag'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'PANVEL','NAVI MUMBAI') then 'Panvel'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'URAN') then 'Uran'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'KARJAT') then 'Karjat'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'KHALAPUR') then 'Khalapur'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'PEN') then 'Pen'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'MANGAON') then 'Mangaon'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'ROHA') then 'Roha'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'SUDHAGAD','SUDHAGAD (PALI)','SUDHAGAD PALI') then 'Sudhagad'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'MAHAD') then 'Mahad'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'POLADPUR') then 'Poladpur'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'SHRIVARDHAN','SHRIVARDHAN (RAIGAD)') then 'Shrivardhan'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'MHASLA') then 'Mhasla'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'MURUD') then 'Murud'
            when district_normalized = 'Raigad' and upper(trim(raw_tehsil)) in (
                'TALA') then 'Tala'

            -- ── Ratnagiri ──────────────────────────────────────────────────
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'RATNAGIRI') then 'Ratnagiri'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'SANGAMESHWAR','SANGAMESWAR') then 'Sangameshwar'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'LANJA') then 'Lanja'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'RAJAPUR','RAMPUR') then 'Rajapur'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'CHIPLUN') then 'Chiplun'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'GUHAGAR') then 'Guhagar'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'DAPOLI') then 'Dapoli'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'MANDANGAD') then 'Mandangad'
            when district_normalized = 'Ratnagiri' and upper(trim(raw_tehsil)) in (
                'KHED','KHED (RATNAGIRI)','KHED RATNAGIRI') then 'Khed'

            -- ── Sangli ─────────────────────────────────────────────────────
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'MIRAJ','SANGLI','MIRAJ (SANGLI)') then 'Miraj'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'KAVATHE MAHANKAL','KAVATHE-MAHANKAL','KAVTHE MAHANKAL') then 'Kavathe Mahankal'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'TASGAON') then 'Tasgaon'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'JAT') then 'Jat'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'WALWA','WALWA (ISLAMPUR)') then 'Walwa'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'SHIRALA') then 'Shirala'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'KHANAPUR','KADEGAON','KADEGAO','KHANPUR-VITA') then 'Khanapur'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'ATPADI') then 'Atpadi'
            when district_normalized = 'Sangli' and upper(trim(raw_tehsil)) in (
                'PALUS') then 'Palus'

            -- ── Satara ─────────────────────────────────────────────────────
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'SATARA') then 'Satara'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'WAI') then 'Wai'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'KHANDALA') then 'Khandala'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'KOREGAON','KOREGAO') then 'Koregaon'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'PHALTAN') then 'Phaltan'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'MAN','MAAN (DAHIWADI)','MAAN','DAHIWADI') then 'Man'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'KHATAV','KHATAV (VADUJ)') then 'Khatav'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'PATAN') then 'Patan'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'KARAD') then 'Karad'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'JAOLI') then 'Jaoli'
            when district_normalized = 'Satara' and upper(trim(raw_tehsil)) in (
                'MAHABALESHWAR','MAHABALESWAR','MAHABLESHWAR') then 'Mahabaleshwar'

            -- ── Sindhudurg ─────────────────────────────────────────────────
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'KANKAVLI') then 'Kankavli'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'VAIBHAVWADI','VAIBHAV WADI','VAIBHAVAWADI') then 'Vaibhavwadi'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'DEVGAD') then 'Devgad'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'MALVAN','MALWAN') then 'Malvan'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'SAWANTWADI','SAVANTVADI','SAWANT WADI') then 'Sawantwadi'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'KUDAL') then 'Kudal'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'VENGURLA') then 'Vengurla'
            when district_normalized = 'Sindhudurg' and upper(trim(raw_tehsil)) in (
                'DODAMARG','DODA MARG') then 'Dodamarg'

            -- ── Solapur ────────────────────────────────────────────────────
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'SOLAPUR NORTH','NORTH SOLAPUR','SOLAPUR (NORTH)') then 'Solapur North'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'SOLAPUR SOUTH','SOUTH SOLAPUR','SOLAPUR (SOUTH)') then 'Solapur South'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'AKKALKOT') then 'Akkalkot'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'BARSHI') then 'Barshi'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'KARMALA') then 'Karmala'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'MADHA') then 'Madha'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'MALSHIRAS','MALSIRAS') then 'Malshiras'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'MANGALVEDHE','MANGALWEDHA') then 'Mangalvedhe'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'MOHOL','MHADA') then 'Mohol'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'PANDHARPUR') then 'Pandharpur'
            when district_normalized = 'Solapur' and upper(trim(raw_tehsil)) in (
                'SANGOLA','SANGOLE') then 'Sangola'

            -- ── Thane ──────────────────────────────────────────────────────
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'THANE','THAN','THANA','MUMBAI') then 'Thane'
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'KALYAN') then 'Kalyan'
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'BHIWANDI') then 'Bhiwandi'
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'SHAHAPUR') then 'Shahapur'
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'MURBAD','NAVI MUMBAI') then 'Murbad'
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'ULHASNAGAR') then 'Ulhasnagar'
            when district_normalized = 'Thane' and upper(trim(raw_tehsil)) in (
                'AMBARNATH','AMBERNATH') then 'Ambarnath'

            -- ── Wardha ─────────────────────────────────────────────────────
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'WARDHA') then 'Wardha'
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'ARVI') then 'Arvi'
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'ASHTI') then 'Ashti'
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'DEOLI') then 'Deoli'
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'HINGANGHAT','HINGANGHAAT') then 'Hinganghat'
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'SAMUDRAPUR','SAMUDRPUR') then 'Samudrapur'
            when district_normalized = 'Wardha' and upper(trim(raw_tehsil)) in (
                'SELOO') then 'Seloo'

            -- ── Washim ─────────────────────────────────────────────────────
            when district_normalized = 'Washim' and upper(trim(raw_tehsil)) in (
                'WASHIM','VASHIM') then 'Washim'
            when district_normalized = 'Washim' and upper(trim(raw_tehsil)) in (
                'MALEGAON','MALEGAON JAHANGIR') then 'Malegaon'
            when district_normalized = 'Washim' and upper(trim(raw_tehsil)) in (
                'MANGRULPIR','CHICHAMBA') then 'Mangrulpir'
            when district_normalized = 'Washim' and upper(trim(raw_tehsil)) in (
                'MANORA') then 'Manora'
            when district_normalized = 'Washim' and upper(trim(raw_tehsil)) in (
                'KARANJA','KARANJA LAD','KARANJA-LAD') then 'Karanja'
            when district_normalized = 'Washim' and upper(trim(raw_tehsil)) in (
                'RISOD') then 'Risod'

            -- ── Yavatmal ───────────────────────────────────────────────────
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'YAVATMAL') then 'Yavatmal'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'DARWHA') then 'Darwha'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'PUSAD') then 'Pusad'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'UMARKHED','UMERKHED') then 'Umarkhed'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'MAHAGAON') then 'Mahagaon'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'MAREGAON') then 'Maregaon'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'ARNI') then 'Arni'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'GHATANJI') then 'Ghatanji'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'KALAMB') then 'Kalamb'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'NER') then 'Ner'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'DIGRAS') then 'Digras'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'RALEGAON') then 'Ralegaon'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'BABHULGAON') then 'Babhulgaon'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'ZARI JAMANI','ZARI-JAMANI','ZARIJAMANI','JARI JAMANI','ZARI (JAMNI)') then 'Zari Jamani'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'WANI') then 'Wani'
            when district_normalized = 'Yavatmal' and upper(trim(raw_tehsil)) in (
                'KELAPUR','KELAPUR (PANDHARKAWADA)','PANDHARKAWADA','PANDHARKAWDA','PANDHARKWDA') then 'Kelapur'

            -- ── T3: unscoped fallback — catch exact names regardless of district ──
            -- Handles rare cases where district is wrong but tehsil name is correct
            when upper(trim(raw_tehsil)) = 'KINWAT'        then 'Kinwat'
            when upper(trim(raw_tehsil)) = 'PANDHARPUR'    then 'Pandharpur'
            when upper(trim(raw_tehsil)) = 'AKKALKOT'      then 'Akkalkot'

            else null

        end as tehsil_normalized,

        -- Match method audit flag
        case
            when raw_tehsil is null or trim(raw_tehsil) = ''            then 'Null Input'
            when lower(trim(raw_tehsil)) in (
                'not known','n/a','na','unknown','none','-','--',
                'not applicable','nill','nil'
            )                                                            then 'Null Input'
            when district_normalized is null
                 and (raw_tehsil is not null and trim(raw_tehsil) != '') then 'Skipped-No-District'
            else 'Resolved'
        end as tehsil_match_method,

        case
            when state_normalized is null
                 and (raw_state is not null and trim(raw_state) != '')   then 'Unmatched'
            when state_normalized = 'International'                      then 'International'
            else 'OK'
        end as state_match_status,

        case
            when district_normalized is null
                 and state_normalized = 'Maharashtra'
                 and (raw_district is not null and trim(raw_district) != '')
                 and lower(trim(raw_district)) not ilike '%out of maharashtra%'
                then 'Unmatched'
            else 'OK'
        end as district_match_status

    from location_normalized ln
),
-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4 : workshop month + financial year parsing
--
--  Input formats seen in the data:
--   "December 2019"   → full month name + 4-digit year
--   "Aug-25"          → 3-letter abbreviation + 2-digit year  (20xx assumed)
--   "April"           → month name only, no year
--   ""  / null        → unknown
--
--  Outputs:
--   workshop_month_num  → integer 1–12 (for sorting)
--   workshop_month      → "January" … "December"
--   workshop_year       → integer e.g. 2025  (null when year absent)
--   workshop_fy         → "FY 2024-25" style  (null when year absent)
--                         Indian FY: Apr–Mar
--                         Month Apr–Dec  → FY starts that calendar year
--                         Month Jan–Mar  → FY started previous calendar year
-- ─────────────────────────────────────────────────────────────────────────────
workshop_parsed as (
    select
        t.*,

        -- ── Normalised month name ──────────────────────────────────────────
        case
            -- Format: "August 2021" or "August"
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'january'   then 'January'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'february'  then 'February'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'march'     then 'March'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'april'     then 'April'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'may'       then 'May'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'june'      then 'June'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'july'      then 'July'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'august'    then 'August'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'september' then 'September'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'october'   then 'October'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'november'  then 'November'
            when lower(trim(split_part(workshop_month_year, ' ', 1))) = 'december'  then 'December'
            -- Format: "Aug-25" or "25-Aug" (3-letter abbreviation before or after the hyphen)
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'jan' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'jan'  then 'January'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'feb' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'feb'  then 'February'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'mar' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'mar'  then 'March'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'apr' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'apr'  then 'April'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'may' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'may'  then 'May'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'jun' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'jun'  then 'June'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'jul' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'jul'  then 'July'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'aug' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'aug'  then 'August'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'sep' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'sep'  then 'September'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'oct' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'oct'  then 'October'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'nov' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'nov'  then 'November'
            when lower(trim(split_part(workshop_month_year, '-', 1))) = 'dec' or lower(trim(split_part(workshop_month_year, '-', 2))) = 'dec'  then 'December'
            else null
        end as workshop_month,

        -- ── Month number (for sorting in charts) ──────────────────────────
        case
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('january')   or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'jan'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'jan'           then 1
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('february')  or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'feb'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'feb'           then 2
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('march')     or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'mar'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'mar'           then 3
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('april')     or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'apr'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'apr'           then 4
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('may')       or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'may'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'may'           then 5
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('june')      or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'jun'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'jun'           then 6
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('july')      or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'jul'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'jul'           then 7
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('august')    or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'aug'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'aug'           then 8
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('september') or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'sep'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'sep'           then 9
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('october')   or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'oct'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'oct'           then 10
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('november')  or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'nov'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'nov'           then 11
            when lower(trim(split_part(workshop_month_year, ' ', 1))) in ('december')  or
                 lower(trim(split_part(workshop_month_year, '-', 1))) = 'dec'          or
                 lower(trim(split_part(workshop_month_year, '-', 2))) = 'dec'           then 12
            else null
        end as workshop_month_num,

        -- ── Calendar year ─────────────────────────────────────────────────
        -- "December 2019" → 2019
        -- "Aug-25"        → 2025
        -- "April"         → null (no year)
        case
            -- Space-separated format: year is the second token, 4 digits
            when workshop_month_year ~ '^[A-Za-z]+ \d{4}$'
                then split_part(trim(workshop_month_year), ' ', 2)::integer
            -- Hyphen format (Mon-YY): year is the part after '-', 2 digits → prepend 20
            when workshop_month_year ~ '^[A-Za-z]+-\d{2}$'
                then (2000 + split_part(trim(workshop_month_year), '-', 2)::integer)
            -- Hyphen format (YY-Mon): year is the part before '-', 2 digits → prepend 20
            when workshop_month_year ~ '^\d{2}-[A-Za-z]+$'
                then (2000 + split_part(trim(workshop_month_year), '-', 1)::integer)
            else null
        end as workshop_year

    from tehsil_normalized_cte t
),

-- ── Financial year derived from month + year ───────────────────────────────
-- Indian FY runs April → March
-- Apr–Dec of year Y  → "FY Y-(Y+1 mod 100 zero-padded)"   e.g. Apr 2024 → "FY 2024-25"
-- Jan–Mar of year Y  → "FY (Y-1)-Y mod 100 zero-padded"   e.g. Jan 2025 → "FY 2024-25"
workshop_final as (
    select
        wp.*,
        case
            when workshop_year is null or workshop_month_num is null then null
            when workshop_month_num >= 4   -- Apr–Dec: FY starts this year
                then 'FY ' || workshop_year::text || '-'
                  || lpad(((workshop_year + 1) % 100)::text, 2, '0')
            else                           -- Jan–Mar: FY started previous year
                'FY ' || (workshop_year - 1)::text || '-'
                  || lpad((workshop_year % 100)::text, 2, '0')
        end as workshop_fy
    from workshop_parsed wp
)

-- ─────────────────────────────────────────────────────────────────────────────
-- FINAL SELECT
-- ─────────────────────────────────────────────────────────────────────────────
select
    participant_id,
    name,
    gender,
    case
        when batch < 10 then '0' || batch::text
        else batch::text
    end as batch,
    current_age,
    age_at_workshop,
    workshop,
    workshop_type,
    workshop_month_year,
    case
        when workshop_month = 'April'     then '01-April'
        when workshop_month = 'May'       then '02-May'
        when workshop_month = 'June'      then '03-June'
        when workshop_month = 'July'      then '04-July'
        when workshop_month = 'August'    then '05-August'
        when workshop_month = 'September' then '06-September'
        when workshop_month = 'October'   then '07-October'
        when workshop_month = 'November'  then '08-November'
        when workshop_month = 'December'  then '09-December'
        when workshop_month = 'January'   then '10-January'
        when workshop_month = 'February'  then '11-February'
        when workshop_month = 'March'     then '12-March'
        else workshop_month
    end as workshop_month,
    workshop_month_num,              -- e.g. 12  (use for chart sort order)
    workshop_fy,                     -- e.g. 'FY 2024-25'
    workshops_attended,
    educational_stream_raw          as educational_stream,
    educational_stream_1,
    current_status_of_work,
    person_years_social_action,
    education_status,

    state_normalized                as native_state,
    district_normalized             as native_district,
    tehsil_normalized               as native_tehsiltown,

    raw_state                       as raw_native_state,
    raw_district                    as raw_native_district,
    raw_tehsil                      as raw_native_tehsil,

    state_match_status,
    district_match_status,
    tehsil_match_method,

    point_2_workshop_name,
    point_2_workshop_invited,
    point_2_workshop_attended,
    point_3_workshop_name,
    point_3_workshop_invited,
    point_3_workshop_attended

from workshop_final
where participant_id is not null
order by participant_id