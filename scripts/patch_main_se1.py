#!/usr/bin/env python3
"""SE1 wiring на Write Transaction в BreaksRecovery_Main.json."""

from __future__ import annotations

import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "workflows/BreaksRecovery_Main.json"
ERROR_HANDLER_ID = "ge4g0yigf0Ykn65R"


def uid() -> str:
    return str(uuid.uuid4())


def patch(wf: dict) -> None:
    nodes = wf["nodes"]
    by_name = {n["name"]: n for n in nodes}

    wt = by_name["Write Transaction"]
    wt["retryOnFail"] = True
    wt["maxTries"] = 3
    wt["waitBetweenTries"] = 1000
    wt["onError"] = "continueErrorOutput"
    wt["notes"] = "C7 / proc_07. SE1 при сбое RPA DB после 3 retries."

    if "Set Process SE1 Error" not in by_name:
        nodes.extend(
            [
                {
                    "parameters": {
                        "assignments": {
                            "assignments": [
                                {
                                    "id": uid(),
                                    "name": "error_type",
                                    "value": "System Error",
                                    "type": "string",
                                },
                                {
                                    "id": uid(),
                                    "name": "error_code",
                                    "value": "SE1",
                                    "type": "string",
                                },
                                {
                                    "id": uid(),
                                    "name": "error_message",
                                    "value": "={{ $workflow.name + ' / Write Transaction: RPA DB failure after 3 retries' }}",
                                    "type": "string",
                                },
                                {
                                    "id": uid(),
                                    "name": "success",
                                    "value": False,
                                    "type": "boolean",
                                },
                            ]
                        },
                        "options": {},
                    },
                    "id": uid(),
                    "name": "Set Process SE1 Error",
                    "type": "n8n-nodes-base.set",
                    "typeVersion": 3.4,
                    "position": [6944, 1150],
                    "notes": "Process loop: RPA DB UPDATE fail → SE1.",
                },
                {
                    "parameters": {
                        "workflowId": {
                            "__rl": True,
                            "value": ERROR_HANDLER_ID,
                            "mode": "list",
                            "cachedResultName": "BreaksRecovery_8.ErrorHandler",
                        },
                        "workflowInputs": {
                            "mappingMode": "defineBelow",
                            "value": {},
                            "matchingColumns": [],
                            "schema": [],
                            "attemptToConvertTypes": False,
                            "convertFieldsToString": True,
                        },
                        "options": {},
                    },
                    "id": uid(),
                    "name": "Execute Process ErrorHandler",
                    "type": "n8n-nodes-base.executeWorkflow",
                    "typeVersion": 1.2,
                    "position": [7184, 1150],
                },
                {
                    "parameters": {
                        "errorMessage": "={{ $json.error_message || 'Process Write Transaction failed' }}"
                    },
                    "id": uid(),
                    "name": "Stop Process On SE1",
                    "type": "n8n-nodes-base.stopAndError",
                    "typeVersion": 1,
                    "position": [7424, 1150],
                },
            ]
        )

    conn = wf["connections"]
    entry = conn.setdefault("Write Transaction", {"main": [[]]})
    if "error" not in entry:
        entry["error"] = [[]]
    targets = entry["error"][0]
    if not any(t.get("node") == "Set Process SE1 Error" for t in targets):
        targets.append({"node": "Set Process SE1 Error", "type": "main", "index": 0})

    conn["Set Process SE1 Error"] = {
        "main": [[{"node": "Execute Process ErrorHandler", "type": "main", "index": 0}]]
    }
    conn["Execute Process ErrorHandler"] = {
        "main": [[{"node": "Stop Process On SE1", "type": "main", "index": 0}]]
    }


def main() -> None:
    wf = json.loads(MAIN.read_text(encoding="utf-8"))
    patch(wf)
    MAIN.write_text(json.dumps(wf, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Patched SE1 on Write Transaction in Main.json")


if __name__ == "__main__":
    main()
