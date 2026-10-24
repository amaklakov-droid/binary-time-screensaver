/* Binary Time — reference prototype (vanilla JS, no build step).
 * Reads window.BT_DATA = { i18n, catalog } from data.js (generated from ../data/*.json).
 * This is a behavioural reference for the real screensaver, not production code.
 */
(function () {
  'use strict';
  const I18N = window.BT_DATA.i18n;
  const CATALOG = window.BT_DATA.catalog;
  const LANGS = I18N.languages;
  const CALS = ['auto', 'gregory', 'islamic', 'hebrew', 'buddhist'];
  const DEFAULTS = { lang: 'auto', theme: 'dark', hourFormat: '24', calendar: 'auto', location: 'auto', bitShape: 'dot', showControls: true };
  const STORE_KEY = 'binary-time-settings-v1';

  // ── Settings: defaults ← localStorage ← URL params (?lang=ar&theme=light&hourFormat=12&calendar=hebrew&location=vpn&bitShape=square&showControls=0)
  const settings = Object.assign({}, DEFAULTS);
  try { Object.assign(settings, JSON.parse(localStorage.getItem(STORE_KEY) || '{}')); } catch (e) {}
  try {
    const q = new URLSearchParams(location.search);
    Object.keys(DEFAULTS).forEach((k) => { if (q.has(k)) settings[k] = k === 'showControls' ? q.get(k) !== '0' : q.get(k); });
  } catch (e) {}
  const save = () => { try { localStorage.setItem(STORE_KEY, JSON.stringify(settings)); } catch (e) {} };

  const runtime = { geo: null, spaceIdx: Math.floor(Math.random() * CATALOG.objects.length), structKey: '' };

  // ── Helpers
  const pad = (n) => (n < 10 ? '0' : '') + n;
  const fmtCache = {};
  const dtf = (key, locale, opts) => {
    if (!fmtCache[key]) {
      try { fmtCache[key] = new Intl.DateTimeFormat(locale, opts); } catch (e) { fmtCache[key] = new Intl.DateTimeFormat('en', opts); }
    }
    return fmtCache[key];
  };
  const calId = (cal) => (cal === 'islamic' ? 'islamic-umalqura' : cal);
  const digits = (str, lang) => {
    const set = I18N.digitSets[I18N.meta[lang].digits];
    if (!set || set === I18N.digitSets.latn) return String(str);
    return String(str).replace(/[0-9]/g, (ch) => set[+ch]);
  };
  const intlLang = (lang) => I18N.meta[lang].intlFallback || lang;

  function autoLang() {
    let list = [];
    try { list = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || 'en']; } catch (e) {}
    for (const l of list) {
      const code = String(l || '').toLowerCase().split('-')[0];
      if (code === 'iw') return 'he';
      if (LANGS.includes(code)) return code;
    }
    return I18N.fallback;
  }

  function systemTz() {
    try { return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'; } catch (e) { return 'UTC'; }
  }

  // Calendar by time zone (heuristic — see SPEC §4.2)
  function calForTz(tz) {
    if (tz === 'Asia/Riyadh') return 'islamic';
    if (tz === 'Asia/Jerusalem' || tz === 'Asia/Tel_Aviv') return 'hebrew';
    if (tz === 'Asia/Bangkok') return 'buddhist';
    return 'gregory';
  }

  const CITY_REGION = { Moscow: 'RU', Kaliningrad: 'RU', Samara: 'RU', Yekaterinburg: 'RU', Novosibirsk: 'RU', Krasnoyarsk: 'RU', Irkutsk: 'RU', Vladivostok: 'RU', London: 'GB', Paris: 'FR', Berlin: 'DE', Madrid: 'ES', Rome: 'IT', Lisbon: 'PT', Amsterdam: 'NL', Warsaw: 'PL', Prague: 'CZ', Belgrade: 'RS', Istanbul: 'TR', Kyiv: 'UA', Kiev: 'UA', Minsk: 'BY', Tbilisi: 'GE', Yerevan: 'AM', Baku: 'AZ', Almaty: 'KZ', Tashkent: 'UZ', Dubai: 'AE', Riyadh: 'SA', Jerusalem: 'IL', Tel_Aviv: 'IL', Bangkok: 'TH', Singapore: 'SG', Shanghai: 'CN', Hong_Kong: 'HK', Tokyo: 'JP', Seoul: 'KR', Kolkata: 'IN', Thimphu: 'BT', Kathmandu: 'NP', Sydney: 'AU', New_York: 'US', Chicago: 'US', Denver: 'US', Los_Angeles: 'US', Toronto: 'CA', Sao_Paulo: 'BR', Buenos_Aires: 'AR', Mexico_City: 'MX', Cairo: 'EG' };
  function regionName(code, lang) {
    if (!code) return '';
    try { return new Intl.DisplayNames([intlLang(lang)], { type: 'region' }).of(code) || ''; } catch (e) { return ''; }
  }

  // Numeric Y/M/D in the chosen calendar
  function dateParts(cal, d) {
    const id = calId(cal);
    let y = d.getFullYear(), mo = d.getMonth() + 1, da = d.getDate(), gotMonth = false;
    try {
      dtf('n-' + id, 'en-u-ca-' + id, { year: 'numeric', month: 'numeric', day: 'numeric' }).formatToParts(d).forEach((pt) => {
        const v = parseInt(pt.value, 10);
        if (isNaN(v)) return;
        if (pt.type === 'year') y = v;
        else if (pt.type === 'month') { mo = v; gotMonth = true; }
        else if (pt.type === 'day') da = v;
      });
    } catch (e) {}
    if (!gotMonth && cal === 'hebrew') {
      const order = ['Tishri', 'Heshvan', 'Kislev', 'Tevet', 'Shevat', 'Adar I', 'Adar', 'Nisan', 'Iyar', 'Sivan', 'Tamuz', 'Av', 'Elul'];
      const nm = dtf('m-' + id, 'en-u-ca-' + id, { month: 'long' }).format(d);
      const i = order.indexOf(nm === 'Adar II' ? 'Adar' : nm);
      if (i >= 0) mo = i + 1;
    }
    return { y, mo, da };
  }

  function dateLine(cal, lang, d, dp, t) {
    if (t.dateLine) return digits(t.dateLine.replace('{y}', dp.y).replace('{m}', dp.mo).replace('{d}', dp.da).replace('{wd}', t.weekdays[d.getDay()]), lang);
    const id = calId(cal);
    return digits(dtf('dl-' + lang + id, lang + '-u-ca-' + id + '-nu-latn', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(d), lang);
  }
  const weekday = (lang, d, t) => (t.weekdays ? t.weekdays[d.getDay()] : dtf('wd-' + lang, lang, { weekday: 'short' }).format(d));
  function dayPeriod(lang, d, t) {
    const pm = d.getHours() >= 12;
    if (t.dayPeriods) return t.dayPeriods[pm ? 1 : 0];
    try {
      const p = dtf('dp-' + lang, lang + '-u-nu-latn', { hour: 'numeric', hour12: true }).formatToParts(d).find((x) => x.type === 'dayPeriod');
      if (p) return p.value;
    } catch (e) {}
    return pm ? 'PM' : 'AM';
  }

  // ── Location model
  function locationModel(lang, t, tz) {
    if (settings.location === 'vpn') {
      const o = CATALOG.objects[runtime.spaceIdx % CATALOG.objects.length];
      const kinds = t.kinds || I18N.strings[I18N.fallback].kinds;
      let l3 = kinds[o.kind];
      if (o.designation) l3 += ' · ' + o.designation;
      if (o.distanceLy != null) {
        const num = new Intl.NumberFormat(intlLang(lang) + '-u-nu-latn', { maximumFractionDigits: 2 }).format(o.distanceLy);
        l3 += ' · ' + (o.approx ? '≈' : '') + digits(num, lang) + ' ' + t.ly;
      }
      const l2 = o.coords ? 'RA ' + o.coords.ra + ' · Dec ' + o.coords.dec : o.surface.lat + ' · ' + o.surface.lon;
      return { tag: t.vpn, l1: o.names[lang] || o.names[I18N.fallback], l2, l3 };
    }
    const parts = tz.split('/');
    const cityKey = parts.length > 1 ? parts[parts.length - 1] : '';
    const city = cityKey.replace(/_/g, ' ');
    const country = regionName(CITY_REGION[cityKey], lang);
    const g = runtime.geo;
    const coords = g ? Math.abs(g.lat).toFixed(4) + '° ' + (g.lat >= 0 ? 'N' : 'S') + ' · ' + Math.abs(g.lon).toFixed(4) + '° ' + (g.lon >= 0 ? 'E' : 'W') : '';
    let m;
    if (city) m = { l1: city + (country ? ' · ' + country : ''), l2: coords || tz, l3: coords ? tz : '' };
    else if (coords) m = { l1: coords, l2: tz, l3: '' };
    else m = { l1: t.unknown, l2: tz, l3: '' };
    m.tag = g ? t.geo : t.tz;
    return m;
  }

  // ── DOM
  const $ = (sel, el) => (el || document).querySelector(sel);
  const root = $('.bt-root');
  const el = {
    title: $('[data-k="title"]'), cal: $('[data-k="cal"]'), dateLine: $('[data-k="dateLine"]'),
    locTag: $('[data-k="locTag"]'), l1: $('[data-k="l1"]'), l2: $('[data-k="l2"]'), l3: $('[data-k="l3"]'),
    main: $('.bt-main'), head: $('.bt-head .bt-bits'), date: $('.bt-date'), time: $('.bt-time'), sep: $('.bt-sep span'),
    readout: $('[data-k="readout"]'), ampm: $('[data-k="ampm"]'), offset: $('[data-k="offset"]'),
    controls: $('.bt-controls'), bLang: $('[data-a="lang"]'), bLangText: $('[data-a="lang"] span'), bHF: $('[data-a="hf"]'), bCal: $('[data-a="cal"]'), bLoc: $('[data-a="loc"]'), bInv: $('[data-a="invert"]')
  };
  const setText = (node, v) => { if (node && node.textContent !== v) node.textContent = v; };
  const setAttr = (node, a, v) => { if (node && node.getAttribute(a) !== v) node.setAttribute(a, v); };
  let rowEls = [];

  function buildRows(W) {
    el.head.textContent = '';
    for (let i = W - 1; i >= 0; i--) {
      const s = document.createElement('span'); s.className = 'bt-place'; el.head.appendChild(s);
    }
    el.date.textContent = ''; el.time.textContent = '';
    rowEls = [];
    for (let r = 0; r < 7; r++) {
      const row = document.createElement('div'); row.className = 'bt-row' + (r === 6 ? ' fast' : '');
      const label = document.createElement('div'); label.className = 'bt-label';
      const lt = document.createElement('span'); const sub = document.createElement('span'); sub.className = 'bt-sub';
      label.append(lt, sub);
      const bits = document.createElement('div'); bits.className = 'bt-bits'; bits.setAttribute('role', 'img');
      const cells = [];
      for (let i = 0; i < W; i++) { const c = document.createElement('span'); c.className = 'c void'; bits.appendChild(c); cells.push(c); }
      const dec = document.createElement('div'); dec.className = 'bt-dec';
      row.append(label, bits, dec);
      (r < 3 ? el.date : el.time).appendChild(row);
      rowEls.push({ lt, sub, bits, cells, dec });
    }
  }

  function frame() {
    const lang = settings.lang === 'auto' || !LANGS.includes(settings.lang) ? autoLang() : settings.lang;
    const t = I18N.strings[lang];
    const meta = I18N.meta[lang];
    const dig = (x) => digits(x, lang);
    const tz = systemTz();
    const cal = settings.calendar === 'auto' ? calForTz(tz) : settings.calendar;
    const hf = String(settings.hourFormat);
    const d = new Date();
    const dp = dateParts(cal, d);

    const h24 = d.getHours();
    const h = hf === '12' ? (h24 % 12 || 12) : h24;
    const ampm = hf === '12' ? dayPeriod(lang, d, t) : '';
    const mi = d.getMinutes(), se = d.getSeconds(), cs = Math.floor(d.getMilliseconds() / 10);

    const yearBits = dp.y.toString(2).length;
    const W = Math.min(14, Math.max(7, yearBits));

    // root
    const cls = 'bt-root ' + (settings.theme === 'light' ? 't-light' : 't-dark') + ' ' + (meta.caps ? 's-caps' : 's-free') + (lang === 'bo' ? ' s-tibt' : '') + (settings.bitShape === 'square' ? ' sq' : '');
    if (root.className !== cls) root.className = cls;
    setAttr(root, 'dir', meta.dir); setAttr(root, 'lang', lang);
    document.documentElement.lang = lang;

    const key = W + '|' + lang;
    if (runtime.structKey !== key) {
      buildRows(W); runtime.structKey = key;
      el.main.style.setProperty('--w', W);
      for (let i = W - 1, j = 0; i >= 0; i--, j++) el.head.children[j].textContent = dig(Math.pow(2, i));
    }

    // header
    setText(el.title, t.title);
    setText(el.cal, t.cal[cal] + (settings.calendar === 'auto' ? ' · ' + t.auto : ''));
    setText(el.dateLine, dateLine(cal, lang, d, dp, t));
    const loc = locationModel(lang, t, tz);
    setText(el.locTag, loc.tag); setText(el.l1, loc.l1); setText(el.l2, loc.l2); setText(el.l3, loc.l3);
    el.l3.hidden = !loc.l3;

    // rows
    const L = t.labels;
    const spec = [
      [L[0], t.era[cal], dp.y, yearBits, String(dp.y)],
      [L[1], t.monthOf.replace('{n}', cal === 'hebrew' ? '13' : '12'), dp.mo, 4, pad(dp.mo)],
      [L[2], weekday(lang, d, t), dp.da, 5, pad(dp.da)],
      [L[3], hf === '12' ? ampm : t.h24.replace('{n}', '24'), h, hf === '12' ? 4 : 5, pad(h)],
      [L[4], t.range, mi, 6, pad(mi)],
      [L[5], t.range, se, 6, pad(se)],
      [L[6], t.hund, cs, 7, pad(cs)]
    ];
    spec.forEach((s, r) => {
      const R = rowEls[r];
      setText(R.lt, s[0]); setText(R.sub, dig(s[1])); setText(R.dec, dig(s[4]));
      setAttr(R.bits, 'aria-label', s[0] + ' ' + dig(s[4]) + ' — ' + s[2].toString(2));
      for (let i = W - 1, j = 0; i >= 0; i--, j++) {
        const c = i >= s[3] ? 'c void' : (Math.floor(s[2] / Math.pow(2, i)) % 2 ? 'c on' : 'c off');
        if (R.cells[j].className !== c) R.cells[j].className = c;
      }
    });
    setText(el.sep, t.sep);
    setAttr(el.date, 'aria-label', t.date); setAttr(el.time, 'aria-label', t.sep);

    // footer
    // LRM around separators keeps Arabic-Indic / Tibetan digit groups in LTR order (Unicode bidi rule N1)
    const S = meta.digits === 'latn' ? '·' : (meta.digits === 'arab' ? '\u200E/\u200E' : '\u200E·\u200E') /* Arabic zero ٠ looks like a middle dot */, SP = meta.digits === 'latn' ? '  ' : '\u200E  \u200E';
    setText(el.readout, dig(dp.y + S + pad(dp.mo) + S + pad(dp.da) + SP + pad(h) + ':' + pad(mi) + ':' + pad(se) + '.' + pad(cs)));
    setText(el.ampm, ampm);
    const off = -d.getTimezoneOffset();
    setText(el.offset, 'UTC' + (off >= 0 ? '+' : '−') + pad(Math.floor(Math.abs(off) / 60)) + ':' + pad(Math.abs(off) % 60));

    el.controls.hidden = !settings.showControls;
    setAttr(el.controls, 'aria-label', t.controls);
    setText(el.bLangText, meta.native); setAttr(el.bLang, 'aria-label', t.language + ': ' + meta.native);
    setText(el.bHF, dig(t.fmt[hf]));
    setText(el.bCal, t.calendar + ': ' + (settings.calendar === 'auto' ? t.auto : t.cal[cal].split(' · ')[0]));
    setText(el.bLoc, t.location + ': ' + (settings.location === 'vpn' ? 'VPN' : t.auto));
    setText(el.bInv, t.invert);
  }

  // ── Actions
  const actions = {
    lang: () => {
      const cur = settings.lang === 'auto' ? autoLang() : settings.lang;
      settings.lang = LANGS[(LANGS.indexOf(cur) + 1) % LANGS.length];
    },
    hf: () => { settings.hourFormat = String(settings.hourFormat) === '12' ? '24' : '12'; },
    cal: () => { settings.calendar = CALS[(CALS.indexOf(settings.calendar) + 1) % CALS.length]; },
    loc: () => { settings.location = settings.location === 'vpn' ? 'auto' : 'vpn'; runtime.spaceIdx++; },
    invert: () => { settings.theme = settings.theme === 'light' ? 'dark' : 'light'; }
  };
  document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (!b) return;
    actions[b.getAttribute('data-a')](); save();
  });
  // Prototype-only shortcuts: L language · H 12/24 · C calendar · V location · I invert · S show/hide controls
  document.addEventListener('keydown', (e) => {
    const map = { l: 'lang', h: 'hf', c: 'cal', v: 'loc', i: 'invert' };
    const k = e.key.toLowerCase();
    if (map[k]) { actions[map[k]](); save(); }
    else if (k === 's') { settings.showControls = !settings.showControls; save(); }
  });
  // Show cursor on mouse move, hide after 2 s
  let cursorTimer;
  document.addEventListener('mousemove', () => {
    document.body.classList.add('show-cursor');
    clearTimeout(cursorTimer);
    cursorTimer = setTimeout(() => document.body.classList.remove('show-cursor'), 2000);
  });

  // ── Loops
  let lastCs = -1;
  (function tick() {
    const cs = Math.floor(Date.now() / 10);
    if (cs !== lastCs) { lastCs = cs; frame(); }
    requestAnimationFrame(tick);
  })();
  setInterval(() => { runtime.spaceIdx++; }, CATALOG.rotateEverySeconds * 1000);
  try {
    navigator.geolocation && navigator.geolocation.getCurrentPosition(
      (p) => { runtime.geo = { lat: p.coords.latitude, lon: p.coords.longitude }; },
      () => {}, { timeout: 8000, maximumAge: 600000 }
    );
  } catch (e) {}
})();
