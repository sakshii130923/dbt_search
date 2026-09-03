{{ config(materialized='table') }}

-- Lookup table mapping question codes to human-readable text.
-- ─────────────────────────────────────────────────────────────
-- ALIAS CODES (exact text duplicates from Frappe server script)
-- are intentionally excluded from this table. They are merged
-- in the prod model via question_code IN (...) groupings.
--
-- Alias → Canonical mapping (for reference / documentation):
--   question_65  → question_23   question_66  → question_24
--   question_67  → question_25   question_68  → question_26   question_131 → question_25
--   question_69  → question_27   question_70  → question_28
--   question_71  → question_29   question_72  → question_30   question_133 → question_30
--   question_73  → question_31   question_74  → question_32
--   question_75  → question_34   question_76  → question_35
--   question_77  → question_36   question_78  → question_37   question_104 → question_37
--   question_79  → question_38   question_80  → question_40
--   question_87  → question_55   question_91  → question_42
--   question_101 → question_60   question_103 → question_61
--   question_128 → question_22   question_122 → question_22
--   question_130 → question_57   question_126 → question_57   question_102 → question_57
--   question_139 → question_10   question_140 → question_14
--   question_141 → question_85   question_142 → question_86   question_117 → question_85
--   question_88  → question_7    question_94  → question_17   question_119 → question_93
--
-- When new questions are added, append a row with a NEW canonical
-- code. If the same question is reused under a new code, add the
-- alias → canonical mapping to the prod model's IN (...) clause.
-- ─────────────────────────────────────────────────────────────

with question_mapping as (

    -- ── Career ────────────────────────────────────────────────
    select 'carrer_1' as question_code, 'career' as category, 'Goverment Service' as question_text, null as short_question_text
    union all select 'carrer_2', 'career', 'Job in Private Industry', null
    union all select 'carrer_3', 'career', 'Own Buisness', null
    union all select 'carrer_4', 'career', 'Social Entrepreneurship/Own NGO', null
    union all select 'carrer_5', 'career', 'Working in NGO', null
    union all select 'carrer_6', 'career', 'Academic (College/University)', null
    union all select 'carrer_7', 'career', 'Confused / Not Decided', null
    union all select 'carrer_8', 'career', 'Other', null

    -- ── Criteria ──────────────────────────────────────────────
    union all select 'criteria_1', 'criteria', 'Geographical Location', null
    union all select 'criteria_2', 'criteria', 'Financial Security', null
    union all select 'criteria_3', 'criteria', 'Work Satisfaction', null
    union all select 'criteria_4', 'criteria', 'Cause of My work', null
    union all select 'criteria_5', 'criteria', 'Carrer progress/growth', null
    union all select 'criteria_6', 'criteria', 'Work Life Balance', null
    union all select 'criteria_7', 'criteria', 'Financial Prosperity', null
    union all select 'criteria_8', 'criteria', 'Fame / Recognition', null
    union all select 'criteria_9', 'criteria', 'Job Security', null

    -- ── Insecurities ──────────────────────────────────────────
    union all select 'insecurities_1',  'insecurities', 'Social Acceptability', null
    union all select 'insecurities_2',  'insecurities', 'Monetary Compensation', null
    union all select 'insecurities_3',  'insecurities', 'Response of Parents', null
    union all select 'insecurities_4',  'insecurities', 'Difficulty in finding the sutaible life partner', null
    union all select 'insecurities_5',  'insecurities', 'Underutilisation of my talent and skills', null
    union all select 'insecurities_6',  'insecurities', 'Less comfertable lifestyle as compared to my usual peers', null
    union all select 'insecurities_7',  'insecurities', 'Not being Able to create any visible impact', null
    union all select 'insecurities_8',  'insecurities', 'Feeling professionaly leftout', null
    union all select 'insecurities_9',  'insecurities', 'Lack of satisfaction at the end of life', null
    union all select 'insecurities_10', 'insecurities', 'Will my life be less Comfortable than it currently is', null

    -- ── Social Contribution ───────────────────────────────────
    union all select 'social_contribution', 'social_contribution', 'During my productive lifetime I plan to engage in social contribution', null

    -- ── Self-Assessment Questions (Batch .1/.2) ───────────────
    union all select 'question_1',  'questions', 'I feel happy about myself. I like who I am.', 'I feel happy about myself. I like who I am.'
    union all select 'question_2',  'questions', 'I have a good understanding about various social issues around me and their severity', 'I understand social issues around me'
    union all select 'question_3',  'questions', 'I believe that there is a purpose to my life', 'Believe that there is a purpose to my life'
    union all select 'question_4',  'questions', 'I clearly know which sector I will be working in the long term', 'Know which sector I will be working in the long term'
    union all select 'question_5',  'questions', 'I know what my values are', 'I know what my values are'
    union all select 'question_6',  'questions', 'I have mentor / facilitators I can talk to regarding myself, my confusions, my future plans', 'I have mentors / facilitators I can talk to'
    union all select 'question_7',  'questions', 'I can take a specific stand about various social issues around me and in my vicinity', 'Can take a specific stand about issues around me'
    union all select 'question_8',  'questions', 'I have the courage of going against the flow of conventional career options', 'Have courgae to go against conventional careers'
    union all select 'question_9',  'questions', 'I am aware of various ways / approaches of solving social problems', 'Aware of approaches of social problem solving'
    union all select 'question_10', 'questions', 'I do serious readinng to build my moral and political philosophy', 'Do serious reading to build moral /  political philosophy'
    -- question_139 is an alias of question_10 — excluded
    union all select 'question_11', 'questions', 'I usually act on my intentions to work towards social issues', 'I act  on my intention to work towards social issues'
    union all select 'question_12', 'questions', 'I know what is my ''Swa-dharma''', 'I know what is my ''Swa-dharma'''
    union all select 'question_13', 'questions', 'I feel secure about my financial future', 'I feel secure about my financial future'
    union all select 'question_14', 'questions', 'I am a person who believes that it''s my responsibility to take action for social change', 'Believe in responsibility to take action for social change'
    -- question_140 is an alias of question_14 — excluded
    union all select 'question_15', 'questions', 'I have many likeminded friends who also believe in taking action for social change', 'Have likeminded friends believing in taking social action'
    union all select 'question_16', 'questions', 'I have found a purpose for my life', 'I have found a purpose for my life'
    union all select 'question_17', 'questions', 'I know quite clearly what are my personal drives, motivations for social action', 'Know my personal drives for social action'
    union all select 'question_18', 'questions', 'I find connection between my personal career and social work & expect to contribute accordingly', 'I find connection between my career and social work'
    union all select 'question_19', 'questions', 'I am actively involved in the process of meaning-making for my life', 'Involved in meaning-making for my life'
    union all select 'question_20', 'questions', 'I have a larger social dream that I can relate to', 'I have a larger social dream that I can relate to'
    union all select 'question_21', 'questions', 'I feel that I belong to a diverse and caring community', 'I feel that I belong to a diverse community'
    union all select 'question_22', 'questions', 'I understand the difference between social work activities and the social problem solving approach', 'Understanding difference - social work activities & social problem solving'
    union all select 'question_23', 'questions', 'I know that even if I fail, there are people out there to support me', 'Know that people are there to support me'
    -- question_65 is an alias of question_23 — excluded
    union all select 'question_24', 'questions', 'I find social problem solving intellectually exciting', 'I find social problem solving intellectually exciting'
    -- question_66 is an alias of question_24 — excluded
    union all select 'question_25', 'questions', 'I can imagine myself as an impactful social change-maker', 'Imagine myself as impactful social change-maker'
    -- question_67 is an alias of question_25 — excluded
    union all select 'question_26', 'questions', 'I believe engaging with society is crucial for me to live a meaningful life', 'Engagement with society is crucial for meaningful life'
    -- question_68 is an alias of question_26 — excluded
    union all select 'question_27', 'questions', 'There are inspiring role models in the social field that I can look up to', 'I have inspiring role models to look up to'
    -- question_69 is an alias of question_27 — excluded
    union all select 'question_28', 'questions', 'I feel confident about my potential to bring about positive social change', 'I feel confident of bringing about positive social change'
    -- question_70 is an alias of question_28 — excluded
    union all select 'question_29', 'questions', 'I understand the difference between happiness and meaning', 'Understand the difference between happiness & meaning'
    -- question_71 is an alias of question_29 — excluded
    union all select 'question_30', 'questions', 'I feel I am an emotionally mature adult', 'I feel I am an emotionally mature adult'
    -- question_72 is an alias of question_30 — excluded
    union all select 'question_31', 'questions', 'I think I am quite privileged in being who I am today', 'I am privileged in being who I am today'
    -- question_73 is an alias of question_31 — excluded
    union all select 'question_32', 'questions', 'I clearly know the differences between my needs and my wants', 'Know the difference between my needs and wants'
    -- question_74 is an alias of question_32 — excluded
    union all select 'question_33', 'questions', '15 years from now I see myself as an example that will encourage other youth to engage in social action', 'Myself as an example to encourage youth for social action'
    union all select 'question_34', 'questions', 'I have a guiding life philosophy or moral framework to steer me through life decisions', 'I have a guiding philosophy for decision making'
    -- question_75 is an alias of question_34 — excluded
    union all select 'question_35', 'questions', 'I am confident in experimenting with my life', 'Confident of experimenting with my life'
    -- question_76 is an alias of question_35 — excluded
    union all select 'question_36', 'questions', 'I get plenty of opportunities to reflect on what is it that I really want to do', 'I get opportunities to refelct on what I want to do'
    -- question_77 is an alias of question_36 — excluded
    union all select 'question_37', 'questions', 'All things considered, I am satisfied with my life as a whole these days', 'I am satisfied with my life as a whole'
    -- question_78 is an alias of question_37 — excluded
    union all select 'question_38', 'questions', 'I think there are definite rights and wrongs, morals are not relative', 'Morals are not relative'
    -- question_79 is an alias of question_38 — excluded
    union all select 'question_39', 'questions', 'I am comfortable in expressing my feelings', 'Comfortable in expressing my feelings'
    union all select 'question_40', 'questions', 'I believe that engaging in a path of pro-social purpose will have a positive effect on my well-being', 'Pro-social purpose positively affects well-being'
    -- question_80 is an alias of question_40 — excluded
    union all select 'question_41', 'questions', 'I know what it means to be a flourishing youth', 'I know what it means to be a flourishing youth'
    union all select 'question_42', 'questions', 'I understand the scientific definition of ''purpose''', 'Understand the scientific definition of purpose'
    -- question_91 is an alias of question_42 — excluded
    union all select 'question_43', 'questions', 'Multiple life possibilities of my 20s fill me with excitement', 'Life possibilities of 20s excite me'
    union all select 'question_44', 'questions', 'Finding my purpose in life is the most urgent priority for me', 'Purpose finding is an urgent priority'
    union all select 'question_45', 'questions', 'I understand the difference between leading a ''happy life'' and a ''meaningful life''', 'Understand the difference between happy life & meaningful life'
    union all select 'question_46', 'questions', 'I understand the difference between goal and purpose', 'Understand the difference between goal & purpose'
    union all select 'question_47', 'questions', 'The more money one earns, the more happy they are', 'The more money one earns, the more happy they are'
    union all select 'question_48', 'questions', 'I understand how to apply ''categorical moral framework'' while making important life decisions', 'Know the application of categorical moral framework'
    union all select 'question_49', 'questions', 'The process of finding / working on my purpose fills me with excitement', 'Process of finding / pursuing purpose excites me'
    union all select 'question_50', 'questions', 'The question of ''how much money would I earn in life'' does not bother me', 'How much money would I earn doesn''t bother me'
    union all select 'question_51', 'questions', 'From those to whom much is given, much is expected', 'From those to whom much is given, much is expected'
    union all select 'question_52', 'questions', 'I value the ''freedom to work on my chosen challenge'' more than other opportunities with even higher financial gains', 'Valuing freedom to work on social challenge than financial gain'
    union all select 'question_53', 'questions', 'I understand the importance of purpose and the various advantages associated with it', 'Understand importance of purpose and its advantages'
    union all select 'question_54', 'questions', 'Leading a life of ''social contribution'' is one of my deepest quests', 'Life of social contribution is one of my deepest quests'
    union all select 'question_55', 'questions', 'I know how an ''impactful social organisation'' functions', 'Know how impactful organization functions'
    -- question_87 is an alias of question_55 — excluded
    union all select 'question_56', 'questions', 'There are many ''social change makers'' that I know of and feel inspired by', 'I know & feel inspired by many social change-makers'
    union all select 'question_57', 'questions', 'I can visualise possible ways in which I can contribute in the social sector', 'Visualizing possible ways to contribute to social sector'
    union all select 'question_58', 'questions', 'I know the difference between my ''minimum threshold income for financial security'' and my ''aspirational income''', 'Know difference - minimum threshold & aspirational income'
    union all select 'question_59', 'questions', 'I think it''s safe to drink alcohol if consumed within limits', 'Safe to drink alcohol in limits'
    union all select 'question_60', 'questions', 'I have identified specific books to read in the coming year', 'Identified specific books to read'
    -- question_101 is an alias of question_60 — excluded
    union all select 'question_61', 'questions', 'I plan to proactively engage in actions to reduce my ''carbon footprint''', 'Plan of actions to reduce my carbon footprint'
    -- question_103 is an alias of question_61 — excluded
    union all select 'question_62', 'questions', 'I have identified specific actions to work upon in the next 6 months regarding my own flourishing', 'Identified actions for flourishing'
    union all select 'question_63', 'questions', 'I know some specific actions to do in the next 6 months as part of my social contribution', 'Know actions for social change'
    union all select 'question_64', 'questions', 'I have identified few specific actions to pursue my purpose journey', 'Identified actions to pursue my purpose journey'

    -- ── Second survey version (question_81–109) ───────────────
    -- Genuinely new questions, not aliases.
    union all select 'question_81', 'questions', 'I know how to become a ''flourishing youth''', 'Know how to become a flourishing youth'
    union all select 'question_82', 'questions', 'I can visualize at least 5 different career paths for myself', 'Can visualise 5 different career paths'
    union all select 'question_83', 'questions', 'I productively spend my day in meaningful pursuits', 'Spend my day in meaningful pursuits'
    union all select 'question_84', 'questions', 'I am committed to bringing about social change', 'Committed to bringing about social change'
    union all select 'question_85', 'questions', 'I have a mentor(s) with whom I can discuss important life matters', 'I have a mentor(s) to discuss important life matters'
    -- question_141 is an alias of question_85 — excluded
    union all select 'question_86', 'questions', 'I have a ''guiding philosophy'' to steer me through life', 'I have a guiding philosophy to steer me through life'
    -- question_142 is an alias of question_86 — excluded
    -- question_88 is an alias of question_7 — excluded
    union all select 'question_89', 'questions', 'I know how to understand and analyse a social change intervention', 'Can understand and analyze a social change intervention'
    union all select 'question_90', 'questions', 'I feel anxious about fulfilling financial aspirations / ambitions of my life', 'I feel anxious about financial aspirations'
    -- question_91 → alias of question_42, excluded above
    union all select 'question_92', 'questions', 'I know the building blocks of effective social problem-solving', 'Know the building blocks for social problem solving'
    union all select 'question_93', 'questions', 'I am clear about the process of finding and pursuing my purpose in life', 'Clarity in finding and pursuing my purpose'
    -- question_94 is an alias of question_17 — excluded
    union all select 'question_95', 'questions', 'I can stay firm on my values even if they are against conventional norms', 'Can stay firm on my values even against conventional norms'
    union all select 'question_96', 'questions', 'I understand different approaches / methods of bringing about social change', 'Understand approaches to bring social change'
    union all select 'question_97', 'questions', 'I understand the importance and urgency of identifying my purpose in life', 'Understand urgency of identifying life purpose'
    union all select 'question_98', 'questions', 'I have a ''set of values'' that help me in making important life decisions', 'I have a set of values for decision making'
    union all select 'question_99', 'questions', 'I have a fair idea about what to do with my life', 'I have a fair idea about what to do with my life'
    union all select 'question_100', 'questions', 'I have carefully identified a set of moral resolutions to follow in my daily living', 'I have identified moral resolutions for daily living'
    -- question_102 is an alias of question_57 — excluded
    -- question_103 → alias of question_61, excluded above
    -- question_104 is an alias of question_37 — excluded
    union all select 'question_105', 'questions', 'I have identified specific actions to do in the next 1 year to pursue my purpose journey', 'Identified actions to pursue my purpose journey'
    union all select 'question_106', 'questions', 'I clearly know which sector I will be working in for most of my professional life', 'Know which sector I will be working in'
    union all select 'question_107', 'questions', 'I have planned specific actions to do in the next 1 year as part of my social change-making journey', 'Planned actions for social change-making journey'
    union all select 'question_108', 'questions', 'I am empowered to enact my responsibilities as an ''Active Citizen'' while dealing with the state', 'Enact responsibilites as an Active Citizen'
    union all select 'question_109', 'questions', 'I have a clear sense of purpose in my life', 'I have a clear sense of purpose in my life'

    -- ── Extended questionnaire (question_110–126) ──────────────
    -- All genuinely new questions; no aliases in this range.
    union all select 'question_110', 'questions', 'I can think of at least 5 different life possibilities based on the decisions I make in my youth', 'Can think of 5 different life possibilties'
    union all select 'question_111', 'questions', 'There is more to life than continuous consumption of exotic experiences and materialistic pleasures', 'There''s more to life than exotice experiences / materialistic pleasures'
    union all select 'question_112', 'questions', 'I feel anxious about how I will find / pursue my purpose in life', 'I feel anxious about finding / pursuing my life purpose'
    union all select 'question_113', 'questions', 'I am solely responsible for the success I have achieved in my life', 'I am solely responsible for my success'
    union all select 'question_114', 'questions', 'Large number youth pursuing a career in the social sector is an important need of our today''s society', 'Youth in social sector is an important need today'
    union all select 'question_115', 'questions', 'I know my values / morals and I can take a firm stand about them even in the face of opposition', 'Know my values and can take a stand'
    union all select 'question_116', 'questions', 'I have decided a few moral lifestyle resolutions that I follow', 'I have moral lifestyle resolutions that I follow'
    -- question_117 is an alias of question_85 — excluded
    union all select 'question_118', 'questions', 'I know how a life of meaningfulness looks different from a life of pleasure-seeking, & I have the clarity to choose among them', 'Distinguishing meaningfulness from pleasure'
    -- question_119 is an alias of question_93 — excluded
    union all select 'question_120', 'questions', 'I understand the need, importance and unique roles of the social sector in society', 'Know need and unique roles of social sector'
    union all select 'question_121', 'questions', 'I exhibit the courage to live authentically with my values and beliefs even if they are against conventional norms', 'Exhibit the courgae to live authentically with my values'
    -- question_122 is an alias of question_22 — excluded
    -- question_128 is an alias of question_122 — excluded
    union all select 'question_123', 'questions', 'I have given a careful thought to what I want to do in my life', 'I have thought what I want to do in my life'
    union all select 'question_124', 'questions', 'My choice of what I want to do in my life is not majorly influenced by the norms followed by my peers, seniors, society', 'What I want to do in my life is not influenced by peers, seniors'
    union all select 'question_125', 'questions', 'I know the difference between my ''financial needs'' and my ''aspirational income''', 'Can differentiate between financial needs & aspirational income'
    -- question_126 is an alias of question_57 — excluded
    -- question_130 is an alias of question_126 — excluded

    -- ── Batch .3 questions (question_127+) ─────────────────────
    -- New questions added for .3 level batches.
    -- q128, q130, q139, q140, q141, q142 are exact-text aliases
    -- and are excluded (see alias map at top of file).
    union all select 'question_127', 'questions', 'Although most people wish to join pvt. or govt. sector, I can visualize myself pursuing a career in the social sector', 'Visualize my career in social sector'
    union all select 'question_129', 'questions', 'The elevation I feel when I see or read about other people devoting their lives for a social mission, strongly motivates me to act for social change', 'Elevation I feel motivates me for social change'
    -- question_131 is an alias of question_25 — excluded
    union all select 'question_132', 'questions', 'My self actualisation is intemently linked with the others in the society', 'My self-actualization is linked with others in society'
    -- question_133 is an alias of question_30 — excluded
    union all select 'question_134', 'questions', 'I don''t have a lear understanding between my needs and my wants', 'Don''t clearly understand my needs and wants'
    union all select 'question_135', 'questions', 'My undrstanding of the broader social economic issues is very poor', 'Understanding of social / economic issues is poor'
    union all select 'question_136', 'questions', 'I don''t get opportunity to reflect on what it is that I really want to do', 'Don''t get opportunity to reflect on what I want to do'
    union all select 'question_137', 'questions', 'I think morals are relative, there are no definite rights and wrongs for everybody', 'Morals are relative'
    union all select 'question_138', 'questions', 'I doubt that engaging in a path of social purpose might affect my well-being adversely', 'Social purpose might adversely affect my well-being'
    union all select 'question_143', 'questions', 'Parental agreement is a mandatory requirement for me to take any decision on my life & career', 'Mandatory parental agreement for making important life decisions'
    union all select 'question_144', 'questions', 'I will prefer a path that ensures my safety and security needs of life', 'Will prefer a path that ensures safety and security'
    union all select 'question_145', 'questions', 'I do experiment / change in my lifestyle to make it environment friendly', 'Experiment / change my lifestyle to make it environment friendly'
    union all select 'question_146', 'questions', 'I Think It is my responsibility to give back to society', 'It is my responsibility to give back to society'
    union all select 'question_147', 'questions', 'My efforts have contributed more to who I am today than when, where and to whom I was born', 'My efforts have contributed more to who I am than time / place of birth'
    union all select 'question_148', 'questions', 'Since you live only once, I believe that one should have as many materialistic pleasures and experiences as possible', 'One should have as many materialistic pleasures as possible'
    union all select 'question_149', 'questions', 'Being who I am today is a privilege I enjoy which thereby makes me want to contribute to society', 'Being privileged makes me want to contribute to society'
    union all select 'question_150', 'questions', 'I know various possible ways by which I can help those in need', 'Know various ways to help those in need'
    union all select 'question_151', 'questions', 'The compassion I feel when I see people living in extreme poverty, strongly motivates me to act for social change', 'Compassion on seeing poor people motivates me to act for social change'
    union all select 'question_152', 'questions', 'I apply ''value-based criteria'' while making important life decisions', 'Apply value-based criteria for making important life decisions'
    union all select 'question_153', 'questions', 'The righteous anger I feel when I see injustice in the society, strongly motivates me to act for social change', 'Righteous anger on seeing injustice motivates me to act for social change'
    union all select 'question_154', 'questions', 'I understand the importance & unique roles of a vibrant social sector in addition to the government & private sectors', 'Understand unique roles of social sector'
    union all select 'question_155', 'questions', 'I take a firm stand on my values even when others around me are behaving differently', 'Take a firm stand on values irrespective of others'
    union all select 'question_156', 'questions', 'Who I am today is determined more by the chance elements of life than my own efforts', 'Who I am today is determined by chance elements'
    union all select 'question_157', 'questions', 'Since I have received a lot from society, I want to give back through social contribution', 'I want to give back to society since I have received a lot'
    union all select 'question_158', 'questions', 'I take important life decisions by applying test of values / morals', 'Take important life decisions by applying morals / values'
    union all select 'question_159', 'questions', 'I am confident of earning sufficient money in future', 'Confident of earning sufficient money in future'
    union all select 'question_160', 'questions', 'I can visualize myself pursuing a career in the social sector', 'Visualize myself pursuing a career in social sector'
    union all select 'question_161', 'questions', 'Agreement with parents is a mandatory condition for me for making important life decisions', 'Agreement with parents is mandatory for important life decisions'
    union all select 'question_162', 'questions', 'Living in harmony with nature is an important part in my life', 'Living in harmony with nature is important'
    union all select 'question_163', 'questions', 'I feel inspired to bring about social impact', 'Feel inspired to bring social impact'
    union all select 'question_164', 'questions', 'I feel excited with the prospect of discovering / pursuing my life purpose', 'Feel excite to pursue / discover life purpose'
    union all select 'question_165', 'questions', 'I am committed to be part of a social change movement', 'Committed to be part of social change movement'
    union all select 'question_166', 'questions', 'I believe my purpose is to make a meaningful difference in the society', 'My purpose is to make meaningful difference in society'
    union all select 'question_167', 'questions', 'I am committed to be part of a youth community working for social change', 'Committed to be part of a youth community working for social change'
    union all select 'question_168', 'questions', 'In the existing representative democracy, I can enact my responsibilities as an ''Active Citizen''', 'I can enact my duty as an Active Citizen'
    union all select 'question_169', 'questions', 'The safety and security needs of life occupy a major part of my thoughts and mental world', 'Safety and security needs occupy a major part of my mental world'
    union all select 'question_170', 'questions', 'My approach to leading life is to complete a bucket list to maximise my happiness', 'Complete bucket list to maximise happiness'
    union all select 'question_171', 'questions', 'I usually spend my every day intentionally, engaging in activities linked to my long-term purpose', 'Spend day intentionally linked to purpose'
    union all select 'question_172', 'questions', 'I feel an urgency to act on the issue of climate change', 'Urgency to act on climate change'
    union all select 'question_173', 'questions', 'While contemplating about social change, I often feel lonely', 'Often feel lonely contemplating social change'
    union all select 'question_174', 'questions', 'Income inequality in the world is justified as talented people are bound to earn more', 'Income inequality is justified'
    union all select 'question_175', 'questions', 'I am proactively taking steps to become an independent & responsible adult', 'Steps to become independent & responsible adult'
    union all select 'question_176', 'questions', 'I carefully consider my needs before making any purchases', 'Consider needs before purchases'
    union all select 'question_177', 'questions', 'I realize the importance of having mentors (non-family elders) whom I can ask for continued growth input.', 'Realize importance of growth mentors'
    union all select 'question_178', 'questions', 'I am actively cultivating relationship with mentor(s)', 'Actively cultivating relationship with mentor'
    -- ── Finance ───────────────────────────────────────────────
    union all select 'finance_1', 'finance', 'Quote a figure of the monthly income (INR) that you think will make you feel financially secure At the age of 25 years', null
    union all select 'finance_2', 'finance', 'Quote a figure of the monthly income (INR) that you think will make you feel financially secure At the age of 30 years', null
    union all select 'finance_3', 'finance', 'Quote a figure of the monthly income (INR) that you think will make you feel financially secure as per Financial sheet', null
    union all select 'finance_4', 'finance', 'Quote a figure of the monthly income (INR) that you think will make you feel financially secure Divided by 2', null
    union all select 'finance_5', 'finance', 'I will be financially independent in the next ….years', null

)

select
    question_code,
    category,
    question_text,
    short_question_text
from question_mapping
order by
    case category
        when 'career'              then 1
        when 'criteria'            then 2
        when 'insecurities'        then 3
        when 'social_contribution' then 4
        when 'questions'           then 5
        when 'finance'             then 6
    end,
    question_code
