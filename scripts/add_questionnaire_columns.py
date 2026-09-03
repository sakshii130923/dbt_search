"""
Appends all prod_nirman_questionnaire column entries (career, criteria,
insecurities, statements, finance) to the questionnaire schema YAML.
Run from the repo root: python scripts/add_questionnaire_columns.py
"""
import yaml
from pathlib import Path

SCHEMA_PATH = Path("models/prod/NIRMAN/NIRMAN questionnaire/prod_schema_nirman.yml")

# ── column definitions ────────────────────────────────────────────────────────
SCALE_CAREER    = "Career preference rank (1 = most preferred, 8 = least preferred)."
SCALE_CRITERIA  = "Life criteria rank (1 = most important, 9 = least important)."
SCALE_INSEC     = "Insecurity score 1–10 (1 = least insecure, 10 = very insecure)."
SCALE_STMT      = "Self-assessment applicability 1–5 (1 = least applicable, 5 = most applicable)."
SCALE_FINANCE   = "Monthly income expectation in INR as stated by the participant."

def col(name, desc):
    return {"name": name, "description": desc}

CAREER_COLS = [
    col("Goverment Service",              f"Career option: Government Service. {SCALE_CAREER}"),
    col("Job in Private Industry",        f"Career option: Job in Private Industry. {SCALE_CAREER}"),
    col("Own Buisness",                   f"Career option: Own Business. {SCALE_CAREER}"),
    col("Social Entrepreneurship/Own NGO",f"Career option: Social Entrepreneurship / Own NGO. {SCALE_CAREER}"),
    col("Working in NGO",                 f"Career option: Working in NGO. {SCALE_CAREER}"),
    col("Academic (College/University)",  f"Career option: Academic (College/University). {SCALE_CAREER}"),
    col("Confused / Not Decided",         f"Career option: Confused / Not Decided. {SCALE_CAREER}"),
    col("Other",                          f"Career option: Other. {SCALE_CAREER}"),
]

CRITERIA_COLS = [
    col("Geographical Location",  f"Criteria: Geographical Location. {SCALE_CRITERIA}"),
    col("Financial Security",     f"Criteria: Financial Security. {SCALE_CRITERIA}"),
    col("Work Satisfaction",      f"Criteria: Work Satisfaction. {SCALE_CRITERIA}"),
    col("Cause of My work",       f"Criteria: Cause of My Work. {SCALE_CRITERIA}"),
    col("Carrer progress/growth", f"Criteria: Career Progress / Growth. {SCALE_CRITERIA}"),
    col("Work Life Balance",      f"Criteria: Work Life Balance. {SCALE_CRITERIA}"),
    col("Financial Prosperity",   f"Criteria: Financial Prosperity. {SCALE_CRITERIA}"),
    col("Fame / Recognition",     f"Criteria: Fame / Recognition. {SCALE_CRITERIA}"),
    col("Job Security",           f"Criteria: Job Security. {SCALE_CRITERIA}"),
]

INSECURITY_COLS = [
    col("Social Acceptability",                                    f"Insecurity: Social Acceptability. {SCALE_INSEC}"),
    col("Monetary Compensation",                                   f"Insecurity: Monetary Compensation. {SCALE_INSEC}"),
    col("Response of Parents",                                     f"Insecurity: Response of Parents. {SCALE_INSEC}"),
    col("Difficulty in finding the sutaible life partner",         f"Insecurity: Difficulty in finding a suitable life partner. {SCALE_INSEC}"),
    col("Underutilisation of my talent and skills",                f"Insecurity: Underutilisation of talent and skills. {SCALE_INSEC}"),
    col("Less comfertable lifestyle as compared to my usual peers",f"Insecurity: Less comfortable lifestyle compared to peers. {SCALE_INSEC}"),
    col("Not being Able to create any visible impact",             f"Insecurity: Not being able to create visible impact. {SCALE_INSEC}"),
    col("Feeling professionaly leftout",                           f"Insecurity: Feeling professionally left out. {SCALE_INSEC}"),
    col("Lack of satisfaction at the end of life",                 f"Insecurity: Lack of satisfaction at the end of life. {SCALE_INSEC}"),
    col("Will my life be less Comfortable than it currently is",   f"Insecurity: Life being less comfortable than currently. {SCALE_INSEC}"),
]

STATEMENT_COLS = [
    col("I feel happy about myself. I like who I am.",                                                              SCALE_STMT),
    col("I have a good understanding about various social issues around me and their severity",                      SCALE_STMT),
    col("I believe that there is a purpose to my life",                                                             SCALE_STMT),
    col("I clearly know which sector I will be working in the long term",                                           SCALE_STMT),
    col("I know what my values are",                                                                                SCALE_STMT),
    col("I have mentor / facilitators I can talk to regarding myself, my confusions, my future plans",              SCALE_STMT),
    col("I can take a specific stand about various social issues around me and in my vicinity",                     SCALE_STMT),
    col("I have the courage of going against the flow of conventional career options",                              SCALE_STMT),
    col("I am aware of various ways / approaches of solving social problems",                                       SCALE_STMT),
    col("I do serious readinng to build my moral and political philosophy",                                         SCALE_STMT),
    col("I usually act on my intentions to work towards social issues",                                             SCALE_STMT),
    col("I know what is my 'Swa-dharma'",                                                                          SCALE_STMT),
    col("I feel secure about my financial future",                                                                  SCALE_STMT),
    col("I am a person who believes that it's my responsibility to take action for social change",                  SCALE_STMT),
    col("I have many likeminded friends who also believe in taking action for social change",                       SCALE_STMT),
    col("I have found a purpose for my life",                                                                       SCALE_STMT),
    col("I know quite clearly what are my personal drives, motivations for social action",                          SCALE_STMT),
    col("I find connection between my personal career and social work & expect to contribute accordingly",          SCALE_STMT),
    col("I am actively involved in the process of meaning-making for my life",                                      SCALE_STMT),
    col("I have a larger social dream that I can relate to",                                                        SCALE_STMT),
    col("I feel that I belong to a diverse and caring community",                                                   SCALE_STMT),
    col("I understand the difference between social work activities and the social problem solving approach",        SCALE_STMT),
    col("I know that even if I fail, there are people out there to support me",                                     SCALE_STMT),
    col("I find social problem solving intellectually exciting",                                                     SCALE_STMT),
    col("I can imagine myself as an impactful social change-maker",                                                 SCALE_STMT),
    col("I believe engaging with society is crucial for me to live a meaningful life",                              SCALE_STMT),
    col("There are inspiring role models in the social field that I can look up to",                                SCALE_STMT),
    col("I feel confident about my potential to bring about positive social change",                                SCALE_STMT),
    col("I understand the difference between happiness and meaning",                                                SCALE_STMT),
    col("I feel I am an emotionally mature adult",                                                                  SCALE_STMT),
    col("I think I am quite privileged in being who I am today",                                                    SCALE_STMT),
    col("I clearly know the differences between my needs and my wants",                                             SCALE_STMT),
    col("15 years from now I see myself as an example that will encourage other youth to engage in social action",  SCALE_STMT),
    col("I have a guiding life philosophy or moral framework to steer me through life decisions",                   SCALE_STMT),
    col("I am confident in experimenting with my life",                                                             SCALE_STMT),
    col("I get plenty of opportunities to reflect on what is it that I really want to do",                         SCALE_STMT),
    col("All things considered, I am satisfied with my life as a whole these days",                                 SCALE_STMT),
    col("I think there are definite rights and wrongs, morals are not relative",                                    SCALE_STMT),
    col("I am comfortable in expressing my feelings",                                                               SCALE_STMT),
    col("I believe that engaging in a path of pro-social purpose will have a positive effect on my well-being",    SCALE_STMT),
    col("I know what it means to be a flourishing youth",                                                           SCALE_STMT),
    col("I understand the scientific definition of 'purpose'",                                                      SCALE_STMT),
    col("Multiple life possibilities of my 20s fill me with excitement",                                            SCALE_STMT),
    col("Finding my purpose in life is the most urgent priority for me",                                            SCALE_STMT),
    col("I understand the difference between leading a 'happy life' and a 'meaningful life'",                       SCALE_STMT),
    col("I understand the difference between goal and purpose",                                                     SCALE_STMT),
    col("The more money one earns, the more happy they are",                                                        SCALE_STMT),
    col("I understand how to apply 'categorical moral framework' while making important life decisions",             SCALE_STMT),
    col("The process of finding / working on my purpose fills me with excitement",                                  SCALE_STMT),
    col("The question of 'how much money would I earn in life' does not bother me",                                 SCALE_STMT),
    col("From those to whom much is given, much is expected",                                                       SCALE_STMT),
    col("I value the 'freedom to work on my chosen challenge' more than other opportunities with even higher financial gains", SCALE_STMT),
    col("I understand the importance of purpose and the various advantages associated with it",                     SCALE_STMT),
    col("Leading a life of 'social contribution' is one of my deepest quests",                                     SCALE_STMT),
    col("I know how an 'impactful social organisation' functions",                                                  SCALE_STMT),
    col("There are many 'social change makers' that I know of and feel inspired by",                                SCALE_STMT),
    col("I can visualise possible ways in which I can contribute in the social sector",                             SCALE_STMT),
    col("I know the difference between my 'minimum threshold income for financial security' and my 'aspirational income'", SCALE_STMT),
    col("I think it's safe to drink alcohol if consumed within limits",                                             SCALE_STMT),
    col("I have identified specific books to read in the coming year",                                              SCALE_STMT),
    col("I plan to proactively engage in actions to reduce my 'carbon footprint'",                                  SCALE_STMT),
    col("I have identified specific actions to work upon in the next 6 months regarding my own flourishing",        SCALE_STMT),
    col("I know some specific actions to do in the next 6 months as part of my social contribution",               SCALE_STMT),
    col("I have identified few specific actions to pursue my purpose journey",                                      SCALE_STMT),
    col("I know how to become a 'flourishing youth'",                                                               SCALE_STMT),
    col("I can visualize at least 5 different career paths for myself",                                             SCALE_STMT),
    col("I productively spend my day in meaningful pursuits",                                                       SCALE_STMT),
    col("I am committed to bringing about social change",                                                           SCALE_STMT),
    col("I have a mentor(s) with whom I can discuss important life matters",                                        SCALE_STMT),
    col("I have a 'guiding philosophy' to steer me through life",                                                   SCALE_STMT),
    col("I can take a stand about various social issues around me",                                                  SCALE_STMT),
    col("I know how to understand and analyse a social change intervention",                                        SCALE_STMT),
    col("I feel anxious about fulfilling financial aspirations / ambitions of my life",                             SCALE_STMT),
    col("I know the building blocks of effective social problem-solving",                                           SCALE_STMT),
    col("I am clear about the process of finding and pursuing my purpose in life",                                  SCALE_STMT),
    col("I know clearly my personal drives and motivations for social action",                                      SCALE_STMT),
    col("I can stay firm on my values even if they are against conventional norms",                                 SCALE_STMT),
    col("I understand different approaches / methods of bringing about social change",                              SCALE_STMT),
    col("I understand the importance and urgency of identifying my purpose in life",                                SCALE_STMT),
    col("I have a 'set of values' that help me in making important life decisions",                                 SCALE_STMT),
    col("I have a fair idea about what to do with my life",                                                         SCALE_STMT),
    col("I have carefully identified a set of moral resolutions to follow in my daily living",                      SCALE_STMT),
    col("I can visualize various possible ways in which I can contribute to the social sector",                     SCALE_STMT),
    col("All things considered, I am satisfied with my life as a whole",                                            SCALE_STMT),
    col("I have identified specific actions to do in the next 1 year to pursue my purpose journey",                SCALE_STMT),
    col("I clearly know which sector I will be working in for most of my professional life",                        SCALE_STMT),
    col("I have planned specific actions to do in the next 1 year as part of my social change-making journey",     SCALE_STMT),
    col("I am empowered to enact my responsibilities as an 'Active Citizen' while dealing with the state",         SCALE_STMT),
    col("I have a clear sense of purpose in my life",                                                               SCALE_STMT),
    col("I can think of at least 5 different life possibilities based on the decisions I make in my youth",        SCALE_STMT),
    col("There is more to life than continuous consumption of exotic experiences and materialistic pleasures",      SCALE_STMT),
    col("I feel anxious about how I will find / pursue my purpose in life",                                         SCALE_STMT),
    col("I am solely responsible for the success I have achieved in my life",                                       SCALE_STMT),
    col("Large number youth pursuing a career in the social sector is an important need of our today's society",   SCALE_STMT),
    col("I know my values / morals and I can take a firm stand about them even in the face of opposition",         SCALE_STMT),
    col("I have decided a few moral lifestyle resolutions that I follow",                                           SCALE_STMT),
    col("I have a solid relationship with a mentor with whom I can discuss important life matters",                 SCALE_STMT),
    col("I know how a life of meaningfulness looks different from a life of pleasure-seeking, & I have the clarity to choose among them", SCALE_STMT),
    col("I am clear about the process of finding / pursuing my purpose in life",                                    SCALE_STMT),
    col("I understand the need, importance and unique roles of the social sector in society",                       SCALE_STMT),
    col("I exhibit the courage to live authentically with my values and beliefs even if they are against conventional norms", SCALE_STMT),
    col("I understand the difference between 'social work activities' and 'social problem-solving approach'",       SCALE_STMT),
    col("I have given a careful thought to what I want to do in my life",                                           SCALE_STMT),
    col("My choice of what I want to do in my life is not majorly influenced by the norms followed by my peers, seniors, society", SCALE_STMT),
    col("I know the difference between my 'financial needs' and my 'aspirational income'",                         SCALE_STMT),
    col("I can visualise various possible ways in which I can contribute in the social sector (v2)",               SCALE_STMT),
    col("Although most people wish to join pvt. or govt. sector, I can visualize myself pursuing a career in the social sector", SCALE_STMT),
    col("The elevation I feel when I see or read about other people devoting their lives for a social mission, strongly motivates me to act for social change", SCALE_STMT),
    col("I can imagine myself as impactful social changemaker",                                                     SCALE_STMT),
    col("My self actualisation is intemently linked with the others in the society",                                SCALE_STMT),
    col("I feel I am an emotionally matured adult",                                                                 SCALE_STMT),
    col("I don't have a lear understanding between my needs and my wants",                                          SCALE_STMT),
    col("My undrstanding of the broader social economic issues is very poor",                                       SCALE_STMT),
    col("I don't get opportunity to reflect on what it is that I really want to do",                               SCALE_STMT),
    col("I think morals are relative, there are no definite rights and wrongs for everybody",                       SCALE_STMT),
    col("I doubt that engaging in a path of social purpose might affect my well-being adversely",                   SCALE_STMT),
]

FINANCE_COLS = [
    col("Monthly income at age 25",              f"Finance: Expected monthly income at age 25 (INR). {SCALE_FINANCE}"),
    col("Monthly income at age 30",              f"Finance: Expected monthly income at age 30 (INR). {SCALE_FINANCE}"),
    col("Monthly income as per Financial sheet", f"Finance: Monthly income figure from the financial planning sheet (INR). {SCALE_FINANCE}"),
    col("Monthly income Divided by 2",           f"Finance: Half of the financial-sheet income figure (INR). {SCALE_FINANCE}"),
    col("Financially independent in next N years",f"Finance: Number of years within which the participant expects to be financially independent."),
]

ALL_NEW_COLS = CAREER_COLS + CRITERIA_COLS + INSECURITY_COLS + STATEMENT_COLS + FINANCE_COLS

# ── load, patch, write ────────────────────────────────────────────────────────
schema = yaml.safe_load(SCHEMA_PATH.read_text())

for model in schema.get("models", []):
    if model["name"] == "prod_nirman_questionnaire":
        existing_names = {c["name"] for c in model.get("columns", [])}
        for c in ALL_NEW_COLS:
            if c["name"] not in existing_names:
                model.setdefault("columns", []).append(c)
        print(f"✓ Added {len([c for c in ALL_NEW_COLS if c['name'] not in existing_names])} new columns.")
        break

SCHEMA_PATH.write_text(
    yaml.dump(schema, allow_unicode=True, sort_keys=False, default_flow_style=False)
)
print(f"✓ Saved {SCHEMA_PATH}")
