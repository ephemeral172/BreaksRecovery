/**
 * RPA-1834 DoD — unit-тесты Process (ТЗ §4.5 шаги 8–11)
 * Эталон: workflows/js/phase_c_logic.js
 */
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  determineContainerRules,
  calculateNewsDuration,
  findMissingActivities,
  calculateSlots,
  getBreakBudget,
  mergeAgentSkills,
} = require('../workflows/js/phase_c_logic');

const mappingsDir = path.join(__dirname, '..', 'mappings');

function loadMappings() {
  const read = (name) => JSON.parse(fs.readFileSync(path.join(mappingsDir, name), 'utf8'));
  return {
    activity: read('activity.json'),
    container: read('container.json'),
    news_reading: read('news_reading.json'),
    news_exception_skills: read('news_exception_skills.json'),
  };
}

const MSK_OFFSET = '+03:00';

function weekdayCode(dateStr) {
  const d = new Date(`${dateStr}T12:00:00${MSK_OFFSET}`);
  return ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][d.getUTCDay()];
}

/** История с новостями на все будни lookback — без ложных «пропусков». */
function historyWithNews(shiftDate, pattern, newsRules) {
  const shiftDt = new Date(`${shiftDate}T12:00:00${MSK_OFFSET}`);
  const rows = [];
  for (let i = 7; i >= 1; i -= 1) {
    const d = new Date(shiftDt.getTime() - i * 86400000);
    const key = d.toISOString().slice(0, 10);
    const wd = weekdayCode(key);
    const rule = newsRules.find((r) => r.schedule_pattern === pattern && r.weekday === wd);
    if (!rule || rule.is_weekend) continue;
    const mins = rule.minutes_default || rule.minutes_exception;
    if (!mins || mins <= 0) continue;
    rows.push({
      activity_date: key,
      activity_name: 'Обучение (Новости)',
      duration_min: mins,
      is_absence: false,
    });
  }
  return rows;
}

function baseItem(overrides = {}) {
  const mappings = overrides.mappings || loadMappings();
  const shiftDate = overrides.shift_date || '2026-07-02';
  const pattern = overrides.schedule_scheme_name || '5/2 вых ПН-ВТ';
  const history = overrides.history_7d ?? historyWithNews(shiftDate, pattern, mappings.news_reading);

  return {
    transaction_id: 1,
    agent_id: 100,
    agent_login: 'test_agent',
    shift_date: shiftDate,
    is_night_shift: false,
    shift_start_msk: `${shiftDate}T09:00:00+03:00`,
    mappings,
    shift_fact: [],
    shift_plan: [],
    history_7d: history,
    agent_skills: [],
    ...overrides,
    history_7d: overrides.history_7d !== undefined ? overrides.history_7d : history,
  };
}

function runProcess(item) {
  let ctx = determineContainerRules(item);
  ctx = calculateNewsDuration(ctx);
  ctx = findMissingActivities(ctx);
  ctx = calculateSlots(ctx);
  return ctx;
}

function runThroughMissing(item) {
  let ctx = determineContainerRules(item);
  ctx = calculateNewsDuration(ctx);
  return findMissingActivities(ctx);
}

function sumByName(list, name) {
  return list
    .filter((r) => r.activity_name === name)
    .reduce((s, r) => s + r.duration_min, 0);
}

function countByName(list, name) {
  return list.filter((r) => r.activity_name === name).length;
}

describe('RPA-1834 Process — phase_c_logic', () => {
  describe('T1 standard_9hrs: обед 30 + 3×10 + новости', () => {
    it('бюджет перерывов и дефicit при пустом факте', () => {
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
      });
      const ctx = runThroughMissing(item);

      assert.equal(ctx.container_type, 'standard_9hrs');
      assert.equal(ctx.error_code, null);
      assert.equal(ctx.news_minutes, 10);

      const budget = getBreakBudget(ctx);
      assert.deepEqual(budget, { total_break_min: 60, has_fixed_breaks: false });

      const missing = ctx.activities_to_restore;
      assert.equal(sumByName(missing, 'Обучение (Новости)'), 10);
      assert.equal(sumByName(missing, 'Обед'), 30);
      assert.equal(countByName(missing, 'Перерыв'), 3);
      assert.equal(
        sumByName(missing, 'Обед') + sumByName(missing, 'Перерыв'),
        60,
      );
    });

    it('слот подобран для одного перерыва в movable-сегменте', () => {
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        activities_to_restore: [{ activity_name: 'Перерыв', duration_min: 10 }],
        skip_slots: false,
        shift_fact: [
          {
            activity_name: 'Autohub 1st',
            start_msk: '2026-07-02T09:00:00+03:00',
            end_msk: '2026-07-02T11:00:00+03:00',
            duration_min: 120,
            not_erasable: false,
          },
        ],
      });
      const ctx = calculateSlots(item);

      assert.ok(!ctx.error_code);
      assert.equal(ctx.wfms_lines.length, 1);
      assert.equal(ctx.wfms_lines[0].activity, 'Перерыв');
    });
  });

  describe('T2 standard_12hrs: обед 30 + 3×10 + 1×15 + новости', () => {
    it('бюджет 75 мин, паттерн 2/2, перерывы 10+10+10+15', () => {
      const item = baseItem({
        schedule_scheme_name: '2/2 тип 1',
        schedule_variant_name: 'Night line 12hrs shift',
        shift_date: '2026-07-01',
      });
      const ctx = runThroughMissing(item);

      assert.equal(ctx.container_type, 'standard_12hrs');
      assert.equal(ctx.schedule_pattern, '2/2 тип 1');
      assert.ok(ctx.news_minutes >= 20);

      const budget = getBreakBudget(ctx);
      assert.deepEqual(budget, { total_break_min: 75, has_fixed_breaks: false });

      const missing = ctx.activities_to_restore;
      assert.equal(sumByName(missing, 'Обед'), 30);
      const breaks = missing.filter((r) => r.activity_name === 'Перерыв').map((r) => r.duration_min);
      assert.deepEqual(breaks.sort((a, b) => a - b), [10, 10, 10, 15]);
      assert.equal(
        sumByName(missing, 'Обед') + sumByName(missing, 'Перерыв'),
        75,
      );
    });
  });

  describe('T3 non-standard fixed breaks', () => {
    it('Night 1st line 22:00 ПН 5hrs — skip_slots, без wfms_lines', () => {
      const item = baseItem({
        schedule_scheme_name: 'Night Written Pro',
        schedule_variant_name: 'Night 1st line 22:00 ПН 5hrs',
      });
      const ctx = runProcess(item);

      assert.equal(ctx.container_type, 'non_standard');
      assert.equal(ctx.skip_slots, true);
      assert.equal(ctx.skip_reason, 'fixed_breaks');
      assert.deepEqual(ctx.wfms_lines, []);
    });

    it('is_fixed в shift_plan (WFM template) → skip_slots', () => {
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Some Floating Container',
        shift_plan: [
          {
            activity_name: 'Обед',
            start_msk: '2026-07-02T13:00:00+03:00',
            end_msk: '2026-07-02T13:30:00+03:00',
            duration_min: 30,
            plan_source: 'template',
            is_fixed: true,
          },
        ],
      });
      const ctx = runThroughMissing(item);

      assert.equal(ctx.skip_slots, true);
      assert.equal(ctx.skip_reason, 'fixed_breaks');
    });
  });

  describe('T4 news_exception +15', () => {
    it('навык DE Claim — minutes_exception 20 вместо 10', () => {
      const mappings = loadMappings();
      const history = historyWithNews('2026-07-02', '5/2 вых ПН-ВТ', mappings.news_reading);
      const base = {
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        mappings,
        history_7d: history,
      };
      const withSkill = calculateNewsDuration(
        determineContainerRules(baseItem({ ...base, agent_skills: ['DE Письмо - Claim'] })),
      );
      const withoutSkill = calculateNewsDuration(
        determineContainerRules(baseItem({ ...base, agent_skills: [] })),
      );

      assert.equal(withoutSkill.news_minutes, 10);
      assert.equal(withSkill.news_minutes, 20);
    });

    it('бонус +15 за пропущенный будний день (exception skill)', () => {
      const mappings = loadMappings();
      const history = historyWithNews('2026-07-02', '5/2 вых ПН-ВТ', mappings.news_reading)
        .filter((r) => r.activity_date !== '2026-06-25')
        .concat([
          {
            activity_date: '2026-06-25',
            activity_name: 'CSI',
            duration_min: 480,
            is_absence: false,
          },
        ]);
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        agent_skills: ['DE Письмо - Billing'],
        mappings,
        history_7d: history,
      });
      const afterNews = calculateNewsDuration(determineContainerRules(item));

      assert.equal(afterNews.news_minutes, 35);
    });

    it('день только с absence — не считается пропуском новостей', () => {
      const mappings = loadMappings();
      const history = historyWithNews('2026-07-02', '5/2 вых ПН-ВТ', mappings.news_reading)
        .filter((r) => r.activity_date !== '2026-06-25')
        .concat([
          {
            activity_date: '2026-06-25',
            activity_name: 'Больничный',
            duration_min: 480,
            is_absence: true,
          },
        ]);
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        mappings,
        history_7d: history,
      });
      const afterNews = calculateNewsDuration(determineContainerRules(item));

      assert.equal(afterNews.news_missed_days, 0);
      assert.equal(afterNews.news_minutes, 10);
    });
  });

  describe('T5 BE2 — контейнер не распознан', () => {
    it('error_code BE2 и пустой wfms batch', () => {
      const item = baseItem({
        schedule_scheme_name: 'Totally Unknown Scheme',
        schedule_variant_name: 'Unknown Container XYZ',
      });
      const ctx = runProcess(item);

      assert.equal(ctx.error_code, 'BE2');
      assert.equal(ctx.container_type, null);
      assert.deepEqual(ctx.wfms_lines, []);
      assert.equal(ctx.activities_restored, 0);
    });
  });

  describe('T6 BE3 — нет валидного слота', () => {
    it('error_code BE3 при недостаточных слотах', () => {
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        shift_fact: [
          {
            activity_name: 'CSI',
            start_msk: '2026-07-02T09:00:00+03:00',
            end_msk: '2026-07-02T18:00:00+03:00',
            duration_min: 540,
            not_erasable: false,
          },
        ],
      });
      const ctx = runProcess(item);

      assert.equal(ctx.error_code, 'BE3');
      assert.deepEqual(ctx.wfms_lines, []);
    });
  });

  describe('T7 not_erasable — не ставить поверх', () => {
    it('защищённый сегмент не даёт inline-слот → BE3', () => {
      const item = baseItem({
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        shift_fact: [
          {
            activity_name: 'Autohub 1st',
            start_msk: '2026-07-02T09:00:00+03:00',
            end_msk: '2026-07-02T13:00:00+03:00',
            duration_min: 240,
            not_erasable: true,
          },
        ],
      });
      const ctx = runProcess(item);

      assert.equal(ctx.error_code, 'BE3');
      assert.deepEqual(ctx.wfms_lines, []);
    });

    it('перерыв ставится в movable-сегмент, не в not_erasable', () => {
      const item = baseItem({
        activities_to_restore: [{ activity_name: 'Перерыв', duration_min: 10 }],
        skip_slots: false,
        shift_fact: [
          {
            activity_name: 'Autohub 1st',
            start_msk: '2026-07-02T09:00:00+03:00',
            end_msk: '2026-07-02T11:00:00+03:00',
            duration_min: 120,
            not_erasable: true,
          },
          {
            activity_name: 'Autohub 1st',
            start_msk: '2026-07-02T11:00:00+03:00',
            end_msk: '2026-07-02T13:00:00+03:00',
            duration_min: 120,
            not_erasable: false,
          },
        ],
      });
      const ctx = calculateSlots(item);

      assert.ok(!ctx.error_code);
      assert.equal(ctx.wfms_lines.length, 1);
      assert.equal(ctx.wfms_lines[0].activity, 'Перерыв');
    });
  });

  describe('A.3 mergeAgentSkills — Europe/Moscow', () => {
    it('SKIP_TZ при non-Moscow time_zone', () => {
      const out = mergeAgentSkills(
        { transaction_id: 1, agent_login: 'x' },
        [{ skill_name: 'DE Voice', skill_time_zone: 'Europe/Berlin' }],
      );
      assert.equal(out.error_code, 'SKIP_TZ');
      assert.deepEqual(out.agent_skills, ['DE Voice']);
    });

    it('ok при Europe/Moscow или пустом TZ', () => {
      const out = mergeAgentSkills(
        { transaction_id: 1 },
        [
          { skill_name: 'RU Skill', skill_time_zone: 'Europe/Moscow' },
          { skill_name: 'Legacy', skill_time_zone: null },
        ],
      );
      assert.equal(out.error_code, undefined);
      assert.deepEqual(out.agent_skills, ['RU Skill', 'Legacy']);
    });
  });

  describe('T8 FTE coverage не влияет на расчёт', () => {
    it('результат идентичен с fte_coverage и без', () => {
      const base = {
        schedule_scheme_name: '5/2 вых ПН-ВТ',
        schedule_variant_name: 'Written Pro 9hrs 10 мин',
        shift_fact: [
          {
            activity_name: 'Autohub 1st',
            start_msk: '2026-07-02T09:00:00+03:00',
            end_msk: '2026-07-02T18:00:00+03:00',
            duration_min: 540,
            not_erasable: false,
          },
        ],
      };
      const withoutFte = runProcess(baseItem(base));
      const withFte = runProcess(baseItem({ ...base, fte_coverage: 0.5 }));

      assert.deepEqual(
        {
          container_type: withoutFte.container_type,
          news_minutes: withoutFte.news_minutes,
          activities_to_restore: withoutFte.activities_to_restore,
          error_code: withoutFte.error_code,
          wfms_lines: withoutFte.wfms_lines,
        },
        {
          container_type: withFte.container_type,
          news_minutes: withFte.news_minutes,
          activities_to_restore: withFte.activities_to_restore,
          error_code: withFte.error_code,
          wfms_lines: withFte.wfms_lines,
        },
      );
    });
  });
});
