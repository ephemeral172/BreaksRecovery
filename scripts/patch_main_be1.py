#!/usr/bin/env python3
"""BE1 + SKIP_TZ wiring в BreaksRecovery_Main.json."""

from __future__ import annotations

import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "workflows/BreaksRecovery_Main.json"

WFM_BE1_NODES = [
    "Get Container Scheme",
    "Get Agent Skills",
    "Get History 7d",
    "Get Shift Fact",
    "Get Shift Plan",
]

MERGE_SKILLS_JS = """const { mergeAgentSkills } = require('../workflows/js/phase_c_logic.js');
const payload = $('Merge WFM Container').first().json;
const rows = $input.all().map((item) => item.json);
return [{ json: mergeAgentSkills(payload, rows) }];
"""

# n8n Code node cannot require() — inline copy from phase_c_logic
MERGE_SKILLS_JS_INLINE = """const payload = $('Merge WFM Container').first().json;
const rows = $input.all().map((item) => item.json).filter((r) => r.skill_name);
const MOSCOW_TZ = 'Europe/Moscow';
const agent_skills = rows.map((r) => r.skill_name);
const badTz = rows.find((r) => r.skill_time_zone && r.skill_time_zone !== MOSCOW_TZ);
if (badTz) {
  return [{
    json: {
      ...payload,
      agent_skills,
      error_code: 'SKIP_TZ',
      processing_comment: `Agent excluded: skill ${badTz.skill_name} time_zone=${badTz.skill_time_zone} (v1 scope)`,
      wfms_lines: [],
      activities_to_restore: [],
      activities_restored: 0,
    },
  }];
}
return [{ json: { ...payload, agent_skills } }];
"""

STASH_AGENT_JS = """const staticData = $getWorkflowStaticData('global');
staticData.currentAgentPayload = $input.first().json;
return $input.all();
"""

MERGE_CONTAINER_JS = """const payload = $getWorkflowStaticData('global').currentAgentPayload ?? {};
const rows = $input.all().map((item) => item.json).filter((row) => row.schedule_scheme_name || row.schedule_variant_name);
const wfm = rows[0] || {};
return [{ json: { ...payload, ...wfm } }];
"""

HANDLE_BE1_JS = """const payload = $getWorkflowStaticData('global').currentAgentPayload ?? {};
const nodeName = $prevNode?.name || 'WFM DB';
return [{
  json: {
    ...payload,
    error_code: 'BE1',
    processing_comment: `${$workflow.name} / ${nodeName}: WFM DB failure after 3 retries`,
    wfms_lines: [],
    activities_to_restore: [],
    activities_restored: 0,
  },
}];
"""

SKIP_TZ_IF = {
    "conditions": {
        "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "strict", "version": 2},
        "conditions": [
            {
                "id": str(uuid.uuid4()),
                "leftValue": "={{ $json.error_code }}",
                "rightValue": "",
                "operator": {"type": "string", "operation": "notEmpty", "singleValue": True},
            }
        ],
        "combinator": "and",
    },
    "options": {},
}


def uid() -> str:
    return str(uuid.uuid4())


def patch(wf: dict) -> None:
    nodes = wf["nodes"]
    by_name = {n["name"]: n for n in nodes}

    # proc_02 params
    by_name["Get Agent Skills"]["parameters"]["options"]["queryReplacement"] = (
        "={{ [$json.wfm_user_id, $json.shift_date] }}"
    )

    # Stash loop payload before WFM SQL (error output ломает paired item в n8n)
    if "Stash Agent Payload" not in by_name:
        nodes.append(
            {
                "parameters": {"jsCode": STASH_AGENT_JS},
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [2808, 944],
                "id": uid(),
                "name": "Stash Agent Payload",
                "notes": "Сохраняет payload итерации loop в staticData (BE1 error branch).",
            }
        )
    else:
        by_name["Stash Agent Payload"]["parameters"]["jsCode"] = STASH_AGENT_JS

    # Merge WFM Container + Merge Agent Skills
    by_name["Merge WFM Container"]["parameters"]["jsCode"] = MERGE_CONTAINER_JS

    # Merge Agent Skills — TZ v1
    by_name["Merge Agent Skills"]["parameters"]["jsCode"] = MERGE_SKILLS_JS_INLINE
    by_name["Merge Agent Skills"]["notes"] = (
        "C2 / proc_02 + SKIP_TZ if skill.time_zone != Europe/Moscow."
    )

    # WFM nodes: retry + error output
    for name in WFM_BE1_NODES:
        node = by_name[name]
        node["retryOnFail"] = True
        node["maxTries"] = 3
        node["waitBetweenTries"] = 1000
        node["onError"] = "continueErrorOutput"

    # New nodes
    handle_be1_id = uid()
    skip_tz_id = uid()

    if "Handle Process BE1" not in by_name:
        nodes.append(
            {
                "parameters": {"jsCode": HANDLE_BE1_JS},
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [3400, 1150],
                "id": handle_be1_id,
                "name": "Handle Process BE1",
                "notes": "A.1–A.4 WFM fail after 3 retries → BE1, next agent.",
            }
        )
    else:
        by_name["Handle Process BE1"]["parameters"]["jsCode"] = HANDLE_BE1_JS

    if "Skip Agent Error" not in by_name:
        nodes.append(
            {
                "parameters": SKIP_TZ_IF,
                "type": "n8n-nodes-base.if",
                "typeVersion": 2.2,
                "position": [3900, 944],
                "id": skip_tz_id,
                "name": "Skip Agent Error",
                "notes": "SKIP_TZ / error_code после skills → Write Transaction.",
            }
        )

    conn = wf["connections"]

    # WFM error outputs → Handle Process BE1
    # onError: "continueErrorOutput" → error-ветка = main[1], НЕ ключ "error"
    for name in WFM_BE1_NODES:
        entry = conn.setdefault(name, {"main": [[]]})
        # Убираем BE1 из main[0], если попал туда как fan-out (ошибка ручного подключения)
        if entry["main"] and entry["main"][0]:
            entry["main"][0] = [
                t for t in entry["main"][0]
                if t.get("node") != "Handle Process BE1"
            ]
        # Ставим BE1 в main[1] = error-ветка onError: continueErrorOutput
        while len(entry["main"]) < 2:
            entry["main"].append([])
        entry["main"][1] = [{"node": "Handle Process BE1", "type": "main", "index": 0}]
        # Удаляем устаревший ключ "error" если есть
        entry.pop("error", None)

    conn["Handle Process BE1"] = {
        "main": [[{"node": "Write Transaction", "type": "main", "index": 0}]]
    }

    # Merge Agent Skills → Skip Agent Error (not direct to Get History)
    conn["Merge Agent Skills"] = {
        "main": [[{"node": "Skip Agent Error", "type": "main", "index": 0}]]
    }
    conn["Skip Agent Error"] = {
        "main": [
            [{"node": "Write Transaction", "type": "main", "index": 0}],
            [{"node": "Get History 7d", "type": "main", "index": 0}],
        ]
    }

    # Process loop → Stash → Get Container Scheme
    conn["Process Each Agent"]["main"][1] = [
        {"node": "Stash Agent Payload", "type": "main", "index": 0}
    ]
    conn["Stash Agent Payload"] = {
        "main": [[{"node": "Get Container Scheme", "type": "main", "index": 0}]]
    }

    # Write Transaction → Loop Continue → Process Each Agent
    # (NOT direct Write Transaction → Process Each Agent — двойная линковка = лишние итерации)
    if "Loop Continue" not in by_name:
        nodes.append(
            {
                "parameters": {"jsCode": "return $input.all();"},
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [7216, 944],
                "id": uid(),
                "name": "Loop Continue",
                "notes": "Передаёт сигнал в Split In Batches. Прямое соединение Write → Process Each Agent удалено.",
            }
        )
    else:
        by_name["Loop Continue"]["parameters"]["jsCode"] = "return $input.all();"

    # Меняем только main[0] (success) → Loop Continue; main[1] (SE1 error) не трогаем
    wt_main = conn["Write Transaction"]["main"]
    wt_main[0] = [{"node": "Loop Continue", "type": "main", "index": 0}]
    # Убеждаемся что main[1] → Set Process SE1 Error существует
    if len(wt_main) < 2:
        wt_main.append([{"node": "Set Process SE1 Error", "type": "main", "index": 0}])
    conn["Loop Continue"] = {
        "main": [[{"node": "Process Each Agent", "type": "main", "index": 0}]]
    }


def main() -> None:
    wf = json.loads(MAIN.read_text(encoding="utf-8"))
    patch(wf)
    MAIN.write_text(json.dumps(wf, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Patched BE1 + SKIP_TZ in Main.json")


if __name__ == "__main__":
    main()
