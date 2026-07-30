#!/usr/bin/env python3
"""Fetch SF city job postings from the SmartRecruiters API and flatten them
to local JSON that dbt reads with read_json_auto().

SmartRecruiters caps postings at 100/page (confirmed: a totalFound of 148
still returns only 100 rows for limit=1000), so pagination has to happen
here in Python rather than in a single SQL call like the Socrata-backed
sources use.

Run before `dbt run`:  python scripts/fetch_city_jobs.py
"""
import json
import ssl
import sys
import urllib.request
from pathlib import Path

import certifi

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "sources" / "city_jobs.json"

API_URL = "https://api.smartrecruiters.com/v1/companies/CityAndCountyOfSanFrancisco1/postings"
JOB_URL_BASE = "https://jobs.smartrecruiters.com/CityAndCountyOfSanFrancisco1"
PAGE_SIZE = 100

SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())


def get_custom_field(custom_fields: list[dict], label: str) -> str:
    for f in custom_fields:
        if f.get("fieldLabel") == label:
            return f.get("valueLabel", "")
    return ""


def parse_job(raw: dict) -> dict:
    custom_fields = raw.get("customField", [])
    class_label = get_custom_field(custom_fields, "Job Code and Title")
    class_code = class_label.split("-")[0].strip() if class_label else ""
    department = get_custom_field(custom_fields, "Department") or raw.get("department", {}).get("label", "")
    job_id = str(raw.get("id", ""))

    return {
        "id": job_id,
        "title": raw.get("name", ""),
        "url": f"{JOB_URL_BASE}/{job_id}",
        "class_code": class_code,
        "class_label": class_label,
        "employment_type": get_custom_field(custom_fields, "Fill Type"),
        "department": department,
        "ref_num": raw.get("refNumber", ""),
        "released_date": raw.get("releasedDate", ""),
    }


def fetch_all_jobs() -> list[dict]:
    all_jobs = []
    offset = 0
    while True:
        url = f"{API_URL}?limit={PAGE_SIZE}&offset={offset}"
        req = urllib.request.Request(url, headers={"User-Agent": "data-pipelines/fetch_city_jobs.py"})
        with urllib.request.urlopen(req, context=SSL_CONTEXT) as resp:
            data = json.loads(resp.read())
        content = data.get("content", [])
        if not content:
            break
        all_jobs.extend(parse_job(r) for r in content)
        offset += len(content)
        if offset >= data.get("totalFound", 0):
            break
    return all_jobs


def main() -> int:
    jobs = fetch_all_jobs()
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(jobs))
    print(f"[fetch] city_jobs: {len(jobs)} postings -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
