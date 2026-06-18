#!/usr/bin/env python3
"""Export every dbt model tagged `ltm_feed` to a JSON array and (optionally)
upload it to Cloudflare R2 for Low Tech Maps to pull.

Discovery is tag-driven: add a new model with `{{ config(tags=['ltm_feed']) }}`
and it gets exported here automatically — no change to this script.

Run after `dbt run`:  python scripts/export_feeds.py
"""
import json
import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "target" / "manifest.json"
OUT_DIR = ROOT / "out"
DUCKDB_PATH = os.environ.get("DUCKDB_PATH", str(ROOT / "warehouse.duckdb"))


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


def feed_models() -> list[dict]:
    if not MANIFEST.exists():
        sys.exit("[export] target/manifest.json not found — run `dbt run` first.")
    manifest = json.loads(MANIFEST.read_text())
    return [
        n for n in manifest["nodes"].values()
        if n["resource_type"] == "model" and "ltm_feed" in n.get("tags", [])
    ]


def export(models: list[dict]) -> list[Path]:
    OUT_DIR.mkdir(exist_ok=True)
    con = duckdb.connect(DUCKDB_PATH, read_only=True)
    paths: list[Path] = []
    try:
        for n in models:
            rel = f'"{n["schema"]}"."{n["name"]}"'
            out = OUT_DIR / f'{n["name"]}.json'
            # FORMAT JSON + ARRAY true → a single top-level JSON array, which is
            # exactly what the Low Tech Maps feed importer expects.
            con.execute(f"COPY (SELECT * FROM {rel}) TO '{out}' (FORMAT JSON, ARRAY true)")
            rows = con.execute(f"SELECT count(*) FROM {rel}").fetchone()[0]
            print(f"[export] {n['name']}: {rows} rows -> {out}")
            paths.append(out)
    finally:
        con.close()
    return paths


def upload_r2(paths: list[Path]) -> None:
    required = ["R2_ENDPOINT_URL", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET_NAME"]
    if not all(os.environ.get(k) for k in required):
        print("[export] R2 env not set — wrote local files only.")
        return
    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3",
        endpoint_url=os.environ["R2_ENDPOINT_URL"],
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        config=Config(signature_version="s3v4"),
    )
    bucket = os.environ["R2_BUCKET_NAME"]
    base = os.environ.get("R2_PUBLIC_BASE_URL", "").rstrip("/")
    for p in paths:
        key = f"feeds/{p.name}"
        client.upload_file(
            str(p), bucket, key, ExtraArgs={"ContentType": "application/json"}
        )
        url = f"{base}/{key}" if base else f"(bucket {bucket}) {key}"
        print(f"[export] uploaded -> {url}")


def main() -> int:
    load_env(ROOT / ".env")
    models = feed_models()
    if not models:
        print("[export] no models tagged 'ltm_feed' — nothing to do.")
        return 0
    paths = export(models)
    upload_r2(paths)
    return 0


if __name__ == "__main__":
    sys.exit(main())
