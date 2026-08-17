#!/usr/bin/env python3
"""Fetch SF Ethics Commission Statement of Economic Interests (Form 700)
disclosure line items from the public NetFile portal and flatten them to
local JSON that dbt reads with read_json_auto().

NetFile's public site (https://netfile.com/public/SFO/sei) is a SPA backed by
an undocumented JSON API — there's no public API doc, this was reverse
engineered from the site's JS bundle. `api/searchtransactions` returns one row
per disclosed schedule item (a stock holding, a piece of real property, a
gift, etc.), which is the itemized "holdings" data the transactions tab shows
(as opposed to `api/searchfilings`, which only lists the cover-page metadata
of each filed Form 700, not what's on it).

Schedules vary in shape (a stock holding and a gift share almost no fields),
so `content` is kept as the raw JSON string from the API rather than flattened
here — the mart picks out the fields worth normalizing per schedule.

Run before `dbt run`:  python scripts/fetch_netfile_sei.py
"""
import json
import ssl
import sys
import urllib.request
from pathlib import Path

import certifi

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "sources" / "netfile_sei_transactions.json"

API_URL = "https://netfile.com/api/public/sites/api/searchtransactions"
AGENCY_ID = "SFO"  # San Francisco Ethics Commission
PAGE_SIZE = 500
# All schedule types the public UI selects by default (A1/A2 investments,
# B real property, C income & loans, D gifts, E travel payments).
SCHEDULES = ["A1", "A2", "B", "C", "D", "E", "Comment"]

SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())


def fetch_page(page: int) -> dict:
    body = json.dumps({
        "aid": AGENCY_ID,
        "getArchived": False,
        "search": "",
        "searchSchedules": SCHEDULES,
        "searchFilerName": "",
        "searchDepartment": "",
        "searchDepartmentId": "",
        "searchPosition": "",
        "searchFilerType": "SuccessfulFilers",
        "searchStatementType": None,
        "afterFilingDate": None,
        "beforeFilingDate": None,
        "startPeriodDate": None,
        "endPeriodDate": None,
        "searchStatus": "all",
        "sort": "filingDateDesc",
        "currentPage": page,
        "pageSize": PAGE_SIZE,
    }).encode()
    req = urllib.request.Request(
        API_URL, data=body, method="POST",
        headers={"Content-Type": "application/json", "User-Agent": "data-pipelines/fetch_netfile_sei.py"},
    )
    with urllib.request.urlopen(req, context=SSL_CONTEXT) as resp:
        return json.loads(resp.read())


def fetch_all() -> list[dict]:
    items: list[dict] = []
    page = 1
    while True:
        data = fetch_page(page)
        items.extend(data["items"])
        if not data.get("hasNextPage"):
            break
        page += 1
    return items


def main() -> int:
    items = fetch_all()
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(items))
    print(f"[fetch] netfile_sei: {len(items)} disclosure items -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
