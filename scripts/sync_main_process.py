#!/usr/bin/env python3
"""Синхронизация Process SQL и Code-нод Main.json из workflows/."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "workflows/BreaksRecovery_Main.json"
LOGIC = ROOT / "workflows/js/phase_c_logic.js"

SQL_NODES = {
    "Get Container Scheme": "proc_01_get_container_scheme.sql",
    "Get Agent Skills": "proc_02_get_agent_skills.sql",
    "Get History 7d": "proc_03_get_history_7d.sql",
    "Get Shift Plan": "proc_04_get_shift_plan.sql",
    "Get Shift Fact": "proc_05_get_shift_fact.sql",
    "Write Transaction": "proc_07_update_transaction.sql",
}

CODE_NODES = {
    "Determine Container Rules": (
        "// ТЗ §4.5 шаг 8: тип контейнера\n",
        "const item = $input.first().json;\n"
        "return [{ json: determineContainerRules(item) }];",
    ),
    "Calculate News Duration": (
        "// ТЗ §4.5 шаг 9: минуты новостей\n",
        "return [{ json: calculateNewsDuration($input.first().json) }];",
    ),
    "Find Missing Activities": (
        "// ТЗ §4.5 шаг 10: положенное vs факт\n",
        "return [{ json: findMissingActivities($input.first().json) }];",
    ),
    "Calculate Slots": (
        "// ТЗ §4.5 шаг 11: слоты; нет слота -> BE3\n",
        "return [{ json: calculateSlots($input.first().json) }];",
    ),
}


def load_logic_helpers() -> str:
    text = LOGIC.read_text(encoding="utf-8")
    text = re.sub(r"\nfunction addToBatch[\s\S]*", "\n", text)
    text = re.sub(r"\nmodule\.exports[\s\S]*", "\n", text)
    return text.strip() + "\n\n"


def sync_sql(wf: dict) -> list[str]:
    updated = []
    for node in wf["nodes"]:
        name = node.get("name")
        if name not in SQL_NODES:
            continue
        sql_path = ROOT / "workflows/sql" / SQL_NODES[name]
        node["parameters"]["query"] = sql_path.read_text(encoding="utf-8").strip()
        updated.append(name)
    return updated


def sync_code(wf: dict) -> list[str]:
    helpers = load_logic_helpers()
    updated = []
    for node in wf["nodes"]:
        name = node.get("name")
        if name not in CODE_NODES:
            continue
        comment, tail = CODE_NODES[name]
        node["parameters"]["jsCode"] = helpers + comment + tail
        updated.append(name)
    return updated


def main() -> None:
    wf = json.loads(MAIN.read_text(encoding="utf-8"))
    sql_ok = sync_sql(wf)
    code_ok = sync_code(wf)
    MAIN.write_text(json.dumps(wf, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("SQL:", ", ".join(sql_ok))
    print("Code:", ", ".join(code_ok))


if __name__ == "__main__":
    main()
