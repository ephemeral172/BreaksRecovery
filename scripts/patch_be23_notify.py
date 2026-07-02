#!/usr/bin/env python3
"""
Patch: добавляет ноду BE2/BE3 WARN MM-уведомление и маскировку логина.

Изменения:
  1. Новая нода «Notify Process BE2/BE3» (httpRequest) между BE2/BE3 Check и Write Transaction.
  2. Перемонтирует связь: BE2/BE3 Check main[0] → Notify → Write Transaction.
  3. Обновляет «Send MM Notification» — в stub добавляет маскировку agent_login.
"""

import json
import sys
from pathlib import Path

WF_PATH = Path('workflows/BreaksRecovery_Main.json')

# ---------- helper ----------------------------------------------------------

def mask_login_expr():
    """JS-выражение для маскировки логина в n8n-expression."""
    return (
        "=(()=>{"
        "const l=$json.agent_login||'';"
        "return l.length<=2?'***':l[0]+'*'.repeat(Math.max(l.length-2,1))+l[l.length-1];"
        "})()"
    )

# ---------- new node --------------------------------------------------------

NOTIFY_JS = """// Notify Process BE2/BE3 — WARN в RPA_BN_BreaksRecovery
// Code-нода: HTTP POST в try/catch, всегда возвращает исходный item агента.
// httpRequest с continueOnFail теряет входящий payload — поэтому Code.

const item = $input.item.json;

const login = item.agent_login || '';
const masked = login.length <= 2
  ? (login || '—')
  : login[0] + '*'.repeat(Math.max(login.length - 2, 1)) + login[login.length - 1];

const cfg = $('Execute LoadMappings').first().json;
const baseUrl = cfg.Mattermost1CChannelBaseURL || '';
const channel = cfg.MMCBotAlertChannel || '';
const url = `${baseUrl}/${channel}`;

const opsCh = item.mappings?.runtime?.mattermost?.channels?.ops || 'RPA_BN_BreaksRecovery';

const message = [
  `⚠️ WARN [${$workflow.name}] Агент пропущен (${item.error_code})`,
  `• login: ${masked}`,
  `• container: ${item.container_name || '—'}`,
  `• shift_date: ${item.shift_date}`,
  `• причина: ${item.processing_comment || '—'}`,
].join('\\n');

try {
  await $helpers.httpRequest({
    method: 'POST',
    url,
    body: JSON.stringify({ channel: opsCh, message }),
    headers: { 'Content-Type': 'application/json' },
  });
} catch (err) {
  console.warn(`[Notify BE2/BE3] MM error (ignored): ${err.message}`);
}

return [{ json: item }];
""".strip()

NOTIFY_NODE = {
    "id": "notify-be23-warn-001",
    "name": "Notify Process BE2/BE3",
    "type": "n8n-nodes-base.code",
    "typeVersion": 2,
    "position": [5760, 616],
    "parameters": {
        "mode": "runOnceForEachItem",
        "language": "javaScript",
        "jsCode": NOTIFY_JS,
    },
    "notes": (
        "BE2/BE3 WARN → RPA_BN_BreaksRecovery. "
        "Code-нода: HTTP POST в try/catch, всегда возвращает исходный item агента."
    ),
}

# ---------- main ------------------------------------------------------------

def patch():
    with open(WF_PATH, encoding='utf-8') as f:
        wf = json.load(f)

    nodes = wf['nodes']
    conns = wf['connections']
    names = {n['name'] for n in nodes}

    # 1. Добавить ноду (идемпотентно)
    if NOTIFY_NODE['name'] not in names:
        nodes.append(NOTIFY_NODE)
        print(f"[+] Added node: {NOTIFY_NODE['name']}")
    else:
        print(f"[=] Node already exists: {NOTIFY_NODE['name']}")

    # 2. Перемонтировать BE2/BE3 Check main[0]: Write Transaction → Notify
    be_check_conns = conns.setdefault('BE2/BE3 Check', {'main': [[], []]})
    main0 = be_check_conns['main'][0]
    replaced = False
    for i, c in enumerate(main0):
        if c.get('node') == 'Write Transaction':
            main0[i] = {'node': NOTIFY_NODE['name'], 'type': 'main', 'index': 0}
            replaced = True
            print("[~] BE2/BE3 Check main[0]: Write Transaction → Notify Process BE2/BE3")
    if not replaced:
        # Если уже Notify — ничего не делать
        already = any(c.get('node') == NOTIFY_NODE['name'] for c in main0)
        if not already:
            main0.append({'node': NOTIFY_NODE['name'], 'type': 'main', 'index': 0})
            print("[+] BE2/BE3 Check main[0]: added → Notify Process BE2/BE3")
        else:
            print("[=] BE2/BE3 Check main[0]: already wired to Notify")

    # 3. Добавить связь Notify → Write Transaction
    notify_conns = conns.setdefault(NOTIFY_NODE['name'], {'main': [[]]})
    existing_targets = [c.get('node') for c in notify_conns['main'][0]]
    if 'Write Transaction' not in existing_targets:
        notify_conns['main'][0].append({'node': 'Write Transaction', 'type': 'main', 'index': 0})
        print(f"[+] {NOTIFY_NODE['name']} main[0] → Write Transaction")
    else:
        print(f"[=] {NOTIFY_NODE['name']} main[0] already → Write Transaction")

    # 4. Обновить Send MM Notification — добавить маскировку логина в сообщение
    for node in nodes:
        if node['name'] == 'Send MM Notification':
            node['parameters']['jsonBody'] = (
                "={{ (() => {"
                "  const login = ($('Init WFMS Batch').first()?.json?.agent_login) || '';"
                "  const masked = login.length <= 2"
                "    ? (login || '\u2014')"
                "    : login[0] + '*'.repeat(Math.max(login.length - 2, 1)) + login[login.length - 1];"
                "  return JSON.stringify({"
                "    message: `BreaksRecovery WF-1 \u0437\u0430\u0432\u0435\u0440\u0448\u0451\u043d (\u0437\u0430\u0433\u043b\u0443\u0448\u043a\u0430 MM) | last agent: ${masked}`"
                "  });"
                "})() }}"
            )
            print("[~] Send MM Notification: updated jsonBody with masked login")
            break

    with open(WF_PATH, 'w', encoding='utf-8') as f:
        json.dump(wf, f, ensure_ascii=False, indent=2)

    print("\n✅ Patch applied →", WF_PATH)


if __name__ == '__main__':
    patch()
