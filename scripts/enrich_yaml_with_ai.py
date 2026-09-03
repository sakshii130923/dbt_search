import json
import os
import yaml
from pathlib import Path
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

TARGET_DIR = Path("target")
MODELS_DIR = Path("models")


def load_json(path):
    with open(path) as f:
        return json.load(f)


def strip_empty_config(schema):
    """Remove config blocks that are empty/default (meta: {}, tags: [])."""
    for section_key in ("models", "seeds", "sources"):
        for item in schema.get(section_key, []):
            cfg = item.get("config", {})
            if cfg is None or cfg == {} or cfg == {"meta": {}, "tags": []}:
                item.pop("config", None)
            for col in item.get("columns", []):
                col_cfg = col.get("config", {})
                if col_cfg is None or col_cfg == {} or col_cfg == {"meta": {}, "tags": []}:
                    col.pop("config", None)
            for table in item.get("tables", []):
                tbl_cfg = table.get("config", {})
                if tbl_cfg is None or tbl_cfg == {} or tbl_cfg == {"meta": {}, "tags": []}:
                    table.pop("config", None)
                for col in table.get("columns", []):
                    col_cfg = col.get("config", {})
                    if col_cfg is None or col_cfg == {} or col_cfg == {"meta": {}, "tags": []}:
                        col.pop("config", None)
    return schema


def build_prompt(model_name, compiled_sql, columns, upstream_models):
    col_list = "\n".join(f"- {c}" for c in columns)
    upstream = ", ".join(upstream_models) or "none"
    return f"""You are a dbt documentation expert. Write concise, accurate column descriptions for a dbt model.

Model: {model_name}
Upstream sources: {upstream}

Compiled SQL:
{compiled_sql[:3000]}

Columns to document:
{col_list}

Return ONLY a YAML mapping of column name to description. Example format:
patient_id: Unique identifier for the patient record.
visit_date: Date of the patient visit in YYYY-MM-DD format.

Do not include any explanation, just the YAML mapping."""


def get_catalog_columns(model_name, catalog_nodes):
    for key, node in catalog_nodes.items():
        if key.endswith(f".{model_name}"):
            return list(node.get("columns", {}).keys())
    return []


def enrich_schema_file(schema_path, manifest_nodes, catalog_nodes):
    with open(schema_path) as f:
        original = f.read()

    schema = yaml.safe_load(original)
    if not schema:
        return

    changed = False

    for section_key in ("models", "seeds"):
        for model in schema.get(section_key, []):
            node_type = "model" if section_key == "models" else "seed"
            node_key = f"{node_type}.dbt_search.{model['name']}"
            node = manifest_nodes.get(node_key)
            if not node:
                print(f"  ⚠ {model['name']} not found in manifest, skipping")
                continue

            # get existing columns in YAML
            existing_cols = {col["name"] for col in model.get("columns", [])}

            # try manifest columns first, fall back to catalog
            manifest_cols = list(node.get("columns", {}).keys())
            catalog_cols = get_catalog_columns(model["name"], catalog_nodes)
            all_cols = manifest_cols or catalog_cols

            if not all_cols:
                print(f"  ⚠ {model['name']} — no columns found in manifest or catalog, skipping")
                continue

            # add missing columns to YAML
            for col_name in all_cols:
                if col_name not in existing_cols:
                    model.setdefault("columns", []).append({"name": col_name})
                    changed = True

            # collect undocumented columns
            undocumented = [
                col["name"]
                for col in model.get("columns", [])
                if not col.get("description")
            ]

            if not undocumented:
                print(f"  ✓ {model['name']} — all columns documented, skipping")
                continue

            compiled_sql = node.get("compiled_code") or node.get("compiled_sql", "")
            upstream = [
                d.split(".")[-1]
                for d in node.get("depends_on", {}).get("nodes", [])
            ]

            print(f"  → Calling OpenAI for {model['name']} ({len(undocumented)} columns)...")
            prompt = build_prompt(model["name"], compiled_sql, undocumented, upstream)

            try:
                response = client.chat.completions.create(
                    model="gpt-4o",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.2,
                )
                raw = response.choices[0].message.content.strip()
                if raw.startswith("```"):
                    raw = "\n".join(raw.split("\n")[1:])
                if raw.endswith("```"):
                    raw = "\n".join(raw.split("\n")[:-1])
                descriptions = yaml.safe_load(raw)
            except Exception as e:
                print(f"  ⚠ Error for {model['name']}: {e}")
                continue

            if not isinstance(descriptions, dict):
                print(f"  ⚠ Unexpected response for {model['name']}, skipping")
                continue

            for col in model.get("columns", []):
                if col["name"] in descriptions and not col.get("description"):
                    col["description"] = str(descriptions[col["name"]])
                    changed = True

    # always apply cleanup and write if anything changed
    schema = strip_empty_config(schema)
    cleaned = yaml.dump(schema, allow_unicode=True, sort_keys=False, default_flow_style=False)

    if changed or cleaned != original:
        with open(schema_path, "w") as f:
            f.write(cleaned)
        print(f"  ✓ Saved {schema_path}")
    else:
        print(f"  — No changes for {schema_path}")


def main():
    print("Loading manifest and catalog...")
    manifest = load_json(TARGET_DIR / "manifest.json")
    catalog = load_json(TARGET_DIR / "catalog.json")

    nodes = {**manifest["nodes"], **manifest.get("sources", {})}
    catalog_nodes = {**catalog.get("nodes", {}), **catalog.get("sources", {})}

    schema_files = list(MODELS_DIR.rglob("*.yml")) + list(Path("seeds").rglob("*.yml"))

    if not schema_files:
        print("No YAML files found. Run dbt-osmosis refactor first.")
        return

    for schema_path in schema_files:
        print(f"\nProcessing {schema_path}...")
        enrich_schema_file(schema_path, nodes, catalog_nodes)

    print("\nDone!")


if __name__ == "__main__":
    main()