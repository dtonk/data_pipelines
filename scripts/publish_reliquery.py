#!/usr/bin/env python3
"""Publish every dbt model tagged `reliquery` to reliquery.net via its REST API.

Discovery is tag-driven: add `{{ config(tags=['reliquery']) }}` to a mart and
it gets published here automatically — no change to this script.

The first publish creates the dataset and records its id in
reliquery_datasets.json (tracked in git, alongside this script). Later runs
PUT to that id, which replaces the dataset's contents in place.

Run after `dbt run`:  python scripts/publish_reliquery.py
Publish only specific models (e.g. from a narrower, more frequent workflow
that only built a subset):  python scripts/publish_reliquery.py city_jobs
"""
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import certifi
import duckdb

SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "target" / "manifest.json"
REGISTRY = ROOT / "reliquery_datasets.json"
DUCKDB_PATH = os.environ.get("DUCKDB_PATH", str(ROOT / "warehouse.duckdb"))
API_BASE = "https://danalytics.reliquery.net/api/v1/datasets"


def load_env(path: Path) -> None:
    """Lightweight .env loader (no dependency). Existing env vars win."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def load_registry() -> dict:
    if REGISTRY.exists():
        return json.loads(REGISTRY.read_text())
    return {}


def save_registry(registry: dict) -> None:
    REGISTRY.write_text(json.dumps(registry, indent=2, sort_keys=True) + "\n")


def reliquery_models() -> list[dict]:
    if not MANIFEST.exists():
        sys.exit("[reliquery] target/manifest.json not found — run `dbt run` first.")
    manifest = json.loads(MANIFEST.read_text())
    return [
        n for n in manifest["nodes"].values()
        if n["resource_type"] == "model" and "reliquery" in n.get("tags", [])
    ]


def export_csv(con: duckdb.DuckDBPyConnection, n: dict) -> bytes:
    rel = f'"{n["schema"]}"."{n["name"]}"'
    tmp = ROOT / "out" / f'{n["name"]}.reliquery.csv'
    tmp.parent.mkdir(exist_ok=True)
    con.execute(f"COPY (SELECT * FROM {rel}) TO '{tmp}' (FORMAT CSV, HEADER true)")
    data = tmp.read_bytes()
    tmp.unlink()
    return data


def api_request(method: str, url: str, token: str, body: bytes) -> dict:
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "text/csv")
    req.add_header("User-Agent", "data-pipelines/publish_reliquery.py")
    try:
        with urllib.request.urlopen(req, context=SSL_CONTEXT) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"[reliquery] {method} {url} -> {e.code}: {e.read().decode(errors='replace')}")


def publish(n: dict, token: str, registry: dict) -> None:
    name = n["name"]
    con = duckdb.connect(DUCKDB_PATH, read_only=True)
    try:
        csv_bytes = export_csv(con, n)
    finally:
        con.close()

    entry = registry.get(name)
    if entry:
        api_request("PUT", f'{API_BASE}/{entry["id"]}/data', token, csv_bytes)
        print(f"[reliquery] {name}: refreshed dataset {entry['id']} ({len(csv_bytes)} bytes)")
    else:
        display_name = name.replace("_", " ").title()
        params = {"name": display_name}
        primary_key = n.get("meta", {}).get("reliquery_primary_key")
        if primary_key:
            params["primary_key"] = primary_key
        url = f"{API_BASE}?{urllib.parse.urlencode(params)}"
        result = api_request("POST", url, token, csv_bytes)
        registry[name] = {"id": result["id"], "slug": result.get("slug")}
        save_registry(registry)
        print(f"[reliquery] {name}: created dataset {result['id']} (slug={result.get('slug')})")


def main() -> int:
    load_env(ROOT / ".env")
    token = os.environ.get("DSP_TOKEN")
    if not token:
        sys.exit("[reliquery] DSP_TOKEN not set — see .env.example.")

    models = reliquery_models()
    requested = set(sys.argv[1:])
    if requested:
        models = [n for n in models if n["name"] in requested]
        missing = requested - {n["name"] for n in models}
        if missing:
            sys.exit(f"[reliquery] not tagged 'reliquery' or not found: {', '.join(sorted(missing))}")
    if not models:
        print("[reliquery] no models tagged 'reliquery' — nothing to do.")
        return 0

    registry = load_registry()
    for n in models:
        publish(n, token, registry)
    return 0


if __name__ == "__main__":
    sys.exit(main())
