# SPDX-License-Identifier: Apache-2.0
# Source-of-truth: reait.gitlab.atm.svcs.io/repositories/healthcheck (internal mirror, commit ddd199fbb)
# This is the same tool used on internal CloudLinux mirrors. Migrated under PF-600.

import argparse
import json
from datetime import datetime
from pathlib import Path
import os
import sys
from dotenv import load_dotenv

load_dotenv(dotenv_path="/opt/healthcheck/.env")

def format_now():
    return datetime.now().strftime("%Y/%m/%d %H:%M:%S")

def update_json(json_path, service=None, field=None, value=None, status=None, config_update=False):
    time = format_now()
    data = {}
    if json_path.exists() and json_path.stat().st_size > 0:
        try:
            with open(json_path) as f:
                data = json.load(f)
        except json.JSONDecodeError:
            data = {}

    data["healthcheck_update"] = time

    if config_update:
        data["config_update"] = time

    if service and status:
        block_name = f"{service}_status"
        block = data.setdefault(block_name, [])

        if field and value:
            block = [entry for entry in block if entry.get(field) != value]
            block.append({field: value, "status": status, "time": time})
        else:
            block = [entry for entry in block if list(entry.keys()) != ["status", "time"]]
            block.append({"status": status, "time": time})

        data[block_name] = block

    with open(json_path, "w") as f:
        json.dump(data, f, indent=2)

def render_html(json_path, html_path):
    if not json_path.exists() or json_path.stat().st_size == 0:
        return

    try:
        with open(json_path) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        return

    lines = ["<html><body>\n"]
    lines.append(f"<strong>Last config update:</strong> {data.get('config_update', '')}<br />\n")
    lines.append(f"<strong>Last healthcheck update:</strong> {data.get('healthcheck_update', '')}<br /><br />\n")

    for key, entries in data.items():
        if key in ("config_update", "healthcheck_update"):
            continue

        title = key.replace("_", " ").capitalize()
        lines.append(f"<h3>{title}</h3>\n")
        for entry in entries:
            value_field = next((k for k in entry if k not in ("status", "time")), None)
            value = entry.get(value_field, "Last launch") if value_field else "Last launch"
            status = entry.get("status", "")
            time = entry.get("time", "")
            lines.append(f"{value} | Status: {status} | {time} <br />\n")
        lines.append("<hr>\n")

    lines.append("</body></html>\n")

    temp_path = html_path.with_suffix('.html.tmp')
    with open(temp_path, "w") as f:
        f.writelines(lines)

    os.replace(temp_path, html_path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--service", help="Name of the service (e.g. rsync, snapshot)")
    parser.add_argument("--field", help="Field name (e.g. repo, domain)")
    parser.add_argument("--value", help="Value of the field")
    parser.add_argument("--status", help="Status string (e.g. OK, FAIL)")
    parser.add_argument("--json", help="Path to JSON file")
    parser.add_argument("--html", help="Path to HTML file")
    parser.add_argument("--config-update", action="store_true", help="Flag to update config_update timestamp")

    args = parser.parse_args()

    if not any([args.service, args.status, args.config_update]):
        print("Error: Must provide at least --service and --status or --config-update")
        sys.exit(1)

    json_env = os.getenv("HEALTHCHECK_JSON")
    html_env = os.getenv("HEALTHCHECK_HTML")

    if not (args.json or json_env):
        print("Error: JSON path is not defined (via --json or HEALTHCHECK_JSON)")
        sys.exit(1)

    if not (args.html or html_env):
        print("Error: HTML path is not defined (via --html or HEALTHCHECK_HTML)")
        sys.exit(1)

    json_path = Path(args.json or json_env)
    html_path = Path(args.html or html_env)

    update_json(json_path, args.service, args.field, args.value, args.status, args.config_update)
    render_html(json_path, html_path)

if __name__ == "__main__":
    main()
