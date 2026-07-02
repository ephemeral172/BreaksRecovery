/**
 * Phase C Process logic — источник для Code-нод BreaksRecovery_Main.
 * ТЗ §4.5 шаги 8–12 · TDR §7.2
 */

const NEWS_ACTIVITY = 'Обучение (Новости)';
const MAX_NEWS_MIN = 60;
const BONUS_DEFAULT = 10;
const BONUS_EXCEPTION = 15;
const LUNCH_MIN = 30;
const BREAK_MIN = 10;
const BREAK_LONG_MIN = 15;
const MIN_SLOT_MIN = 60;
const MSK_OFFSET = '+03:00';

function toMskDateKey(val) {
  if (!val) return null;
  const s = String(val);
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  const msk = new Date(d.getTime() + 3 * 3600000);
  return msk.toISOString().slice(0, 10);
}

function weekdayCode(dateStr) {
  const d = new Date(`${dateStr}T12:00:00${MSK_OFFSET}`);
  return ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][d.getUTCDay()];
}

function resolveNewsPattern(scheme, newsRules) {
  if (!scheme) return null;
  const patterns = [...new Set((newsRules || []).map((r) => r.schedule_pattern))];
  if (patterns.includes(scheme)) return scheme;

  const t2 = scheme.match(/2\s*\/\s*2\s*тип\s*(\d)/i);
  if (t2) {
    const candidate = `2/2 тип ${t2[1]}`;
    if (patterns.includes(candidate)) return candidate;
  }

  const t52 = scheme.match(/5\s*\/\s*2\s*вых\s*[А-Яа-я]{2}-[А-Яа-я]{2}/i);
  if (t52) {
    const normalized = t52[0].replace(/\s+/g, ' ');
    const match = patterns.find((p) => p.toLowerCase() === normalized.toLowerCase());
    if (match) return match;
  }

  return patterns.find((p) => scheme.includes(p)) || null;
}

function resolveNewsPatternForNode(item) {
  const newsRules = item.mappings?.news_reading || [];
  const scheme = item.schedule_scheme_name || '';
  return resolveNewsPattern(scheme, newsRules);
}

function shiftPlanHasFixedBreaks(shiftPlan) {
  return (shiftPlan || []).some(
    (r) => r.is_fixed === true || r.is_fixed === 't' || r.is_fixed === 'true',
  );
}

function getBreakBudget(item) {
  const fromPlanFixed = shiftPlanHasFixedBreaks(item.shift_plan);
  const containers = item.mappings?.container || [];
  const ns = containers.find((c) => c.container_name === item.container_name);
  if (ns) {
    return {
      total_break_min: ns.break_duration_min,
      has_fixed_breaks: !!ns.has_fixed_breaks || fromPlanFixed,
    };
  }
  if (item.container_type === 'standard_9hrs') {
    return { total_break_min: 60, has_fixed_breaks: fromPlanFixed };
  }
  if (item.container_type === 'standard_12hrs') {
    return { total_break_min: 75, has_fixed_breaks: fromPlanFixed };
  }
  if (item.container_type === 'standard_pattern') {
    return { total_break_min: 60, has_fixed_breaks: fromPlanFixed };
  }
  return null;
}

function buildBreakDurations(containerType, remaining) {
  if (containerType === 'standard_12hrs' && remaining === 45) {
    return [BREAK_MIN, BREAK_MIN, BREAK_MIN, BREAK_LONG_MIN];
  }
  if (containerType === 'standard_9hrs' && remaining === 30) {
    return [BREAK_MIN, BREAK_MIN, BREAK_MIN];
  }
  const breaks = [];
  let left = remaining;
  while (left >= BREAK_MIN) {
    breaks.push(BREAK_MIN);
    left -= BREAK_MIN;
  }
  if (left > 0 && left < BREAK_MIN) {
    breaks.push(roundUp5(left));
  }
  return breaks;
}

function collectBreakDurations(shiftFact) {
  return (shiftFact || [])
    .filter((r) => r.activity_name === 'Перерыв' && (r.duration_min || 0) >= BREAK_MIN)
    .map((r) => roundUp5(r.duration_min));
}

function missingBreakActivities(requiredBreaks, factBreaks) {
  const pool = [...factBreaks];
  const missing = [];
  for (const need of requiredBreaks) {
    const exactIdx = pool.indexOf(need);
    if (exactIdx >= 0) {
      pool.splice(exactIdx, 1);
      continue;
    }
    const flexIdx = pool.findIndex((d) => d >= need);
    if (flexIdx >= 0) {
      pool.splice(flexIdx, 1);
      continue;
    }
    missing.push({ activity_name: 'Перерыв', duration_min: need });
  }
  return missing;
}

function roundUp5(min) {
  return Math.ceil(min / 5) * 5;
}

function formatMskIso(date) {
  const d = date instanceof Date ? date : new Date(date);
  const pad = (n) => String(n).padStart(2, '0');
  const y = d.getUTCFullYear();
  const mo = pad(d.getUTCMonth() + 1);
  const da = pad(d.getUTCDate());
  const h = pad(d.getUTCHours());
  const mi = pad(d.getUTCMinutes());
  const se = pad(d.getUTCSeconds());
  return `${y}-${mo}-${da}T${h}:${mi}:${se}${MSK_OFFSET}`;
}

function parseMskDateTime(str) {
  if (!str) return null;
  const s = String(str);
  if (s.includes('T')) {
    return new Date(s.endsWith('Z') ? s : `${s}${s.includes('+') ? '' : MSK_OFFSET}`);
  }
  return new Date(`${s}${MSK_OFFSET}`);
}

function canPlaceBreak(activityName, mappings) {
  const row = (mappings?.activity || []).find((a) => a.activity_name === activityName);
  const flag = row?.can_place_break;
  return flag === 'yes' || flag === 'no_but_movable';
}

function segmentAllowsPlacement(seg, mappings) {
  if (seg.not_erasable) return false;
  return canPlaceBreak(seg.activity_name, mappings);
}

const MOSCOW_TZ = 'Europe/Moscow';

function mergeAgentSkills(payload, skillRows) {
  const rows = (skillRows || []).filter((r) => r && r.skill_name);
  const agent_skills = rows.map((r) => r.skill_name);
  const badTz = rows.find(
    (r) => r.skill_time_zone && r.skill_time_zone !== MOSCOW_TZ,
  );
  if (badTz) {
    return {
      ...payload,
      agent_skills,
      error_code: 'SKIP_TZ',
      processing_comment: `Agent excluded: skill ${badTz.skill_name} time_zone=${badTz.skill_time_zone} (v1 scope)`,
      wfms_lines: [],
      activities_to_restore: [],
      activities_restored: 0,
    };
  }
  return { ...payload, agent_skills };
}

function determineContainerRules(item) {
  const scheme = item.schedule_scheme_name || '';
  const variant = item.schedule_variant_name || '';
  const containerName = variant || scheme;
  const containers = item.mappings?.container || [];

  const nsMatch = containers.find((c) => c.container_name === containerName);
  let containerType = null;
  let errorCode = item.error_code || null;
  let processingComment = item.processing_comment || null;

  if (!errorCode) {
    if (nsMatch) {
      containerType = 'non_standard';
    } else if (/\b9\s*hrs\b|\b9hrs\b/i.test(containerName) || /\b9\s*hrs\b/i.test(scheme)) {
      containerType = 'standard_9hrs';
    } else if (/\b12\s*hrs\b|\b12hrs\b/i.test(containerName) || /\b12\s*hrs\b/i.test(scheme)) {
      containerType = 'standard_12hrs';
    } else if (/\b5\s*\/\s*2\b|\b2\s*\/\s*2\b/i.test(scheme)) {
      containerType = 'standard_pattern';
    } else if (!containerName) {
      errorCode = 'BE2';
      processingComment = 'Container/scheme not found in WFM (proc_01 empty)';
    } else {
      errorCode = 'BE2';
      processingComment = `Unrecognized container: ${containerName}`;
    }
  }

  const newsPattern = resolveNewsPattern(scheme, item.mappings?.news_reading || []);

  return {
    ...item,
    schedule_scheme_name: scheme,
    schedule_variant_name: variant,
    container_name: containerName,
    container_type: containerType,
    schedule_pattern: newsPattern || scheme,
    news_pattern_resolved: newsPattern,
    error_code: errorCode,
    processing_comment: processingComment,
  };
}

function calculateNewsDuration(item) {
  if (item.error_code) {
    return { ...item, news_minutes: item.news_minutes ?? null };
  }

  const newsRules = item.mappings?.news_reading || [];
  const exceptionSkills = new Set(
    (item.mappings?.news_exception_skills || []).map((s) => s.skill_name),
  );
  const hasException = (item.agent_skills || []).some((sk) => exceptionSkills.has(sk));
  const pattern = resolveNewsPattern(item.schedule_scheme_name || '', newsRules);

  if (!pattern) {
    return {
      ...item,
      schedule_pattern: item.schedule_pattern || item.schedule_scheme_name || '',
      news_minutes: 0,
      news_pattern_resolved: null,
    };
  }

  const shiftDate = toMskDateKey(item.shift_date);
  const todayRule = newsRules.find(
    (r) => r.schedule_pattern === pattern && r.weekday === weekdayCode(shiftDate),
  );

  let baseToday = 0;
  if (todayRule && !todayRule.is_weekend) {
    const base = hasException ? todayRule.minutes_exception : todayRule.minutes_default;
    baseToday = Number(base) || 0;
  }

  const historyByDate = new Map();
  for (const row of item.history_7d || []) {
    const key = toMskDateKey(row.activity_date);
    if (!key) continue;
    if (!historyByDate.has(key)) historyByDate.set(key, []);
    historyByDate.get(key).push(row);
  }

  let missedDays = 0;
  const shiftDt = new Date(`${shiftDate}T12:00:00${MSK_OFFSET}`);
  for (let i = 7; i >= 1; i -= 1) {
    const d = new Date(shiftDt.getTime() - i * 86400000);
    const key = d.toISOString().slice(0, 10);
    const wd = weekdayCode(key);
    const rule = newsRules.find((r) => r.schedule_pattern === pattern && r.weekday === wd);
    if (!rule || rule.is_weekend) continue;

    const expected = hasException ? rule.minutes_exception : rule.minutes_default;
    if (!expected || expected <= 0) continue;

    const dayRows = historyByDate.get(key) || [];
    const workRows = dayRows.filter((r) => !r.is_absence);
    if (workRows.length === 0) continue;

    const newsRows = workRows.filter((r) => r.activity_name === NEWS_ACTIVITY);
    const newsMin = newsRows.reduce((sum, r) => sum + (r.duration_min || 0), 0);
    if (newsMin <= 0) missedDays += 1;
  }

  const bonusPerDay = hasException ? BONUS_EXCEPTION : BONUS_DEFAULT;
  const newsMinutes = Math.min(MAX_NEWS_MIN, baseToday + missedDays * bonusPerDay);

  return {
    ...item,
    schedule_pattern: pattern,
    news_pattern_resolved: pattern,
    news_minutes: newsMinutes,
    news_missed_days: missedDays,
  };
}

function buildRequiredActivities(item) {
  const required = [];
  const newsMin = item.news_minutes || 0;
  if (newsMin > 0) {
    required.push({ activity_name: NEWS_ACTIVITY, duration_min: newsMin });
  }

  const budget = getBreakBudget(item);
  if (!budget) {
    return { required, skip_slots: true, skip_reason: 'no_break_budget' };
  }
  if (budget.has_fixed_breaks) {
    return { required, skip_slots: true, skip_reason: 'fixed_breaks' };
  }

  let remaining = budget.total_break_min || 0;
  if (remaining >= LUNCH_MIN) {
    required.push({ activity_name: 'Обед', duration_min: LUNCH_MIN });
    remaining -= LUNCH_MIN;
  }
  for (const durationMin of buildBreakDurations(item.container_type, remaining)) {
    required.push({ activity_name: 'Перерыв', duration_min: durationMin });
  }

  return { required, skip_slots: false };
}

function findMissingActivities(item) {
  if (item.error_code) {
    return {
      ...item,
      activities_to_restore: [],
      activities_restored: 0,
    };
  }

  const { required, skip_slots, skip_reason } = buildRequiredActivities(item);
  const shiftFact = item.shift_fact || [];

  const factByName = {};
  for (const row of shiftFact) {
    factByName[row.activity_name] = (factByName[row.activity_name] || 0) + (row.duration_min || 0);
  }

  const requiredBreaks = required
    .filter((r) => r.activity_name === 'Перерыв')
    .map((r) => r.duration_min);
  const factBreaks = collectBreakDurations(shiftFact);

  const missing = [];
  for (const req of required) {
    if (req.activity_name === 'Перерыв') continue;
    const have = factByName[req.activity_name] || 0;
    const deficit = req.duration_min - have;
    if (deficit > 0) {
      missing.push({ activity_name: req.activity_name, duration_min: deficit });
    }
  }

  missing.push(...missingBreakActivities(requiredBreaks, factBreaks));

  return {
    ...item,
    activities_to_restore: missing,
    activities_restored: missing.length,
    skip_slots,
    skip_reason: skip_reason || null,
    shift_plan_count: (item.shift_plan || []).length,
  };
}

function buildSlots(segments, mappings) {
  const slots = [];
  const sorted = [...segments]
    .filter((s) => s.start_msk && s.end_msk)
    .sort((a, b) => parseMskDateTime(a.start_msk) - parseMskDateTime(b.start_msk));

  for (const seg of sorted) {
    if (!segmentAllowsPlacement(seg, mappings)) continue;
    if ((seg.duration_min || 0) < MIN_SLOT_MIN) continue;
    const start = parseMskDateTime(seg.start_msk);
    const end = parseMskDateTime(seg.end_msk);
    if (!start || !end) continue;
    slots.push({
      start_msk: start,
      end_msk: end,
      duration_min: seg.duration_min,
      kind: 'inline',
    });
  }

  for (let i = 0; i < sorted.length - 1; i += 1) {
    const left = sorted[i];
    const right = sorted[i + 1];
    if (!segmentAllowsPlacement(left, mappings) || !segmentAllowsPlacement(right, mappings)) {
      continue;
    }
    const gapStart = parseMskDateTime(left.end_msk);
    const gapEnd = parseMskDateTime(right.start_msk);
    if (!gapStart || !gapEnd) continue;
    const gapMin = (gapEnd - gapStart) / 60000;
    if (gapMin >= BREAK_MIN) {
      slots.push({
        start_msk: gapStart,
        end_msk: gapEnd,
        duration_min: gapMin,
        kind: 'gap',
      });
    }
  }

  return slots.sort((a, b) => b.duration_min - a.duration_min);
}

function calculateSlots(item) {
  if (item.error_code) {
    return { ...item, wfms_lines: [], placement_slots: [] };
  }

  if (item.skip_slots) {
    return {
      ...item,
      wfms_lines: [],
      placement_slots: [],
      processing_comment: item.processing_comment || `Skip slots: ${item.skip_reason || 'n/a'}`,
    };
  }

  const toRestore = item.activities_to_restore || [];
  if (toRestore.length === 0) {
    return { ...item, wfms_lines: [], placement_slots: [] };
  }

  const slots = buildSlots(item.shift_fact || [], item.mappings);
  const wfmsLines = [];
  const usedSlots = new Set();

  for (const act of toRestore) {
    const needMin = roundUp5(act.duration_min);
    const slotIdx = slots.findIndex((s, idx) => !usedSlots.has(idx) && s.duration_min >= needMin);
    if (slotIdx < 0) {
      return {
        ...item,
        wfms_lines: [],
        placement_slots: slots,
        error_code: 'BE3',
        processing_comment: `No slot for ${act.activity_name} (${needMin} min)`,
      };
    }
    usedSlots.add(slotIdx);
    const slot = slots[slotIdx];
    const start = slot.start_msk;
    const end = new Date(start.getTime() + needMin * 60000);
    wfmsLines.push({
      login: item.agent_login,
      activity: act.activity_name,
      start: formatMskIso(start),
      end: formatMskIso(end),
      timeZone: 'Europe/Moscow',
    });
  }

  return {
    ...item,
    wfms_lines: wfmsLines,
    placement_slots: slots,
    activities_restored: wfmsLines.length,
  };
}

function addToBatch(item) {
  const staticData = $getWorkflowStaticData('global');
  if (!staticData.wfmsBatch) {
    staticData.wfmsBatch = { lines: [], agents: 0 };
  }

  const lines = item.wfms_lines || [];
  if (lines.length > 0) {
    staticData.wfmsBatch.lines.push(...lines);
    staticData.wfmsBatch.agents += 1;
  }

  const maxAgents = item.mappings?.runtime?.batch_size_max_agents ?? 200;
  const maxBytes = item.mappings?.runtime?.batch_size_max_bytes ?? 262144;
  const batchBytes = Buffer.byteLength(JSON.stringify(staticData.wfmsBatch.lines), 'utf8');

  return [{
    json: {
      ...item,
      batch_line_count: staticData.wfmsBatch.lines.length,
      batch_agent_count: staticData.wfmsBatch.agents,
      batch_bytes: batchBytes,
      batch_limits: { maxAgents, maxBytes },
    },
  }];
}

module.exports = {
  determineContainerRules,
  calculateNewsDuration,
  findMissingActivities,
  calculateSlots,
  addToBatch,
  resolveNewsPattern,
  getBreakBudget,
  buildRequiredActivities,
  segmentAllowsPlacement,
  mergeAgentSkills,
};
