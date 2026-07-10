/* MANG2074 shared simulation/plotting library (no dependencies).
   Canvas plotting primitives + small UI helpers, under global `SIM`.
   Colours follow the arcade theme in assets/css/theme.css. */
(function (global) {
  'use strict';
  var SIM = {};

  SIM.colors = {
    bg: '#0b1220', grid: '#1e293b', axis: '#475569', text: '#94a3b8',
    accent: '#38bdf8', accent2: '#fbbf24', good: '#34d399', bad: '#f87171',
    line: '#e2e8f0', dim: 'rgba(148,163,184,0.5)'
  };

  /* ---------- Plot: a canvas with data coordinates ---------- */
  // new SIM.Plot(canvas, {xmin,xmax,ymin,ymax, xlabel, ylabel, title, margin})
  function Plot(canvas, opts) {
    this.canvas = typeof canvas === 'string' ? document.getElementById(canvas) : canvas;
    this.opts = opts || {};
    this.m = this.opts.margin || { l: 52, r: 14, t: this.opts.title ? 26 : 12, b: 34 };
    this._setupPixels();
    this.setLimits(this.opts.xmin, this.opts.xmax, this.opts.ymin, this.opts.ymax);
  }
  Plot.prototype._setupPixels = function () {
    var c = this.canvas;
    var dpr = global.devicePixelRatio || 1;
    // CSS size comes from width/height attributes or style; keep attribute size as logical px
    this.W = c.width; this.H = c.height;
    if (!c._dprApplied) {
      var cssW = c.width, cssH = c.height;
      c.style.width = '100%';
      c.style.maxWidth = cssW + 'px';
      c.width = Math.round(cssW * dpr);
      c.height = Math.round(cssH * dpr);
      c._dprApplied = true;
      this.dpr = dpr;
    } else {
      this.dpr = dpr;
    }
    this.W = c.width / this.dpr;
    this.H = c.height / this.dpr;
    this.ctx = c.getContext('2d');
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
  };
  Plot.prototype.setLimits = function (xmin, xmax, ymin, ymax) {
    this.xmin = xmin; this.xmax = xmax; this.ymin = ymin; this.ymax = ymax;
  };
  Plot.prototype.xpix = function (x) {
    return this.m.l + (x - this.xmin) / (this.xmax - this.xmin) * (this.W - this.m.l - this.m.r);
  };
  Plot.prototype.ypix = function (y) {
    return this.H - this.m.b - (y - this.ymin) / (this.ymax - this.ymin) * (this.H - this.m.t - this.m.b);
  };
  Plot.prototype.xdata = function (px) {
    return this.xmin + (px - this.m.l) / (this.W - this.m.l - this.m.r) * (this.xmax - this.xmin);
  };
  Plot.prototype.ydata = function (py) {
    return this.ymin + (this.H - this.m.b - py) / (this.H - this.m.t - this.m.b) * (this.ymax - this.ymin);
  };
  Plot.prototype.clear = function () {
    var ctx = this.ctx;
    ctx.fillStyle = SIM.colors.bg;
    ctx.fillRect(0, 0, this.W, this.H);
  };
  function niceTicks(lo, hi, n) {
    n = n || 5;
    var span = hi - lo;
    if (span <= 0 || !isFinite(span)) return [];
    var step = Math.pow(10, Math.floor(Math.log10(span / n)));
    var err = span / n / step;
    if (err >= 7.5) step *= 10; else if (err >= 3.5) step *= 5; else if (err >= 1.5) step *= 2;
    var t = [], v = Math.ceil(lo / step) * step;
    for (; v <= hi + step * 1e-6; v += step) t.push(Math.abs(v) < step * 1e-6 ? 0 : v);
    return t;
  }
  function fmtTick(v) {
    if (v === 0) return '0';
    var a = Math.abs(v);
    if (a >= 10000 || a < 0.001) return v.toExponential(0);
    if (a >= 100) return v.toFixed(0);
    if (a >= 1) return (Math.round(v * 100) / 100).toString();
    return (Math.round(v * 1000) / 1000).toString();
  }
  Plot.prototype.axes = function (opts) {
    opts = opts || {};
    var ctx = this.ctx, self = this;
    var xt = opts.xticks || niceTicks(this.xmin, this.xmax);
    var yt = opts.yticks || niceTicks(this.ymin, this.ymax);
    ctx.strokeStyle = SIM.colors.grid; ctx.lineWidth = 1;
    ctx.fillStyle = SIM.colors.text; ctx.font = '11px system-ui, sans-serif';
    // gridlines + tick labels
    xt.forEach(function (v) {
      var px = self.xpix(v);
      ctx.beginPath(); ctx.moveTo(px, self.m.t); ctx.lineTo(px, self.H - self.m.b); ctx.stroke();
      ctx.textAlign = 'center'; ctx.textBaseline = 'top';
      ctx.fillText(opts.xfmt ? opts.xfmt(v) : fmtTick(v), px, self.H - self.m.b + 5);
    });
    yt.forEach(function (v) {
      var py = self.ypix(v);
      ctx.beginPath(); ctx.moveTo(self.m.l, py); ctx.lineTo(self.W - self.m.r, py); ctx.stroke();
      ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
      ctx.fillText(opts.yfmt ? opts.yfmt(v) : fmtTick(v), self.m.l - 6, py);
    });
    // frame
    ctx.strokeStyle = SIM.colors.axis;
    ctx.strokeRect(this.m.l, this.m.t, this.W - this.m.l - this.m.r, this.H - this.m.t - this.m.b);
    // labels + title
    ctx.fillStyle = SIM.colors.text;
    if (this.opts.xlabel) {
      ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
      ctx.fillText(this.opts.xlabel, (this.m.l + this.W - this.m.r) / 2, this.H - 2);
    }
    if (this.opts.ylabel) {
      ctx.save();
      ctx.translate(12, (this.m.t + this.H - this.m.b) / 2);
      ctx.rotate(-Math.PI / 2);
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(this.opts.ylabel, 0, 0);
      ctx.restore();
    }
    if (this.opts.title) {
      ctx.fillStyle = SIM.colors.accent2; ctx.font = '600 12px system-ui, sans-serif';
      ctx.textAlign = 'left'; ctx.textBaseline = 'top';
      ctx.fillText(this.opts.title, this.m.l, 6);
    }
  };
  Plot.prototype._clip = function (fn) {
    var ctx = this.ctx;
    ctx.save();
    ctx.beginPath();
    ctx.rect(this.m.l, this.m.t, this.W - this.m.l - this.m.r, this.H - this.m.t - this.m.b);
    ctx.clip();
    fn();
    ctx.restore();
  };
  Plot.prototype.line = function (xs, ys, opts) {
    opts = opts || {};
    var ctx = this.ctx, self = this;
    this._clip(function () {
      ctx.strokeStyle = opts.color || SIM.colors.accent;
      ctx.lineWidth = opts.width || 1.6;
      if (opts.dash) ctx.setLineDash(opts.dash);
      ctx.beginPath();
      for (var i = 0; i < xs.length; i++) {
        var px = self.xpix(xs[i]), py = self.ypix(ys[i]);
        if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.stroke();
      ctx.setLineDash([]);
    });
  };
  Plot.prototype.series = function (ys, opts) { // convenience: x = 0..n-1
    var xs = ys.map(function (_, i) { return i; });
    this.line(xs, ys, opts);
  };
  Plot.prototype.scatter = function (xs, ys, opts) {
    opts = opts || {};
    var ctx = this.ctx, self = this;
    this._clip(function () {
      ctx.fillStyle = opts.color || SIM.colors.accent;
      for (var i = 0; i < xs.length; i++) {
        ctx.beginPath();
        ctx.arc(self.xpix(xs[i]), self.ypix(ys[i]), opts.r || 3.5, 0, 2 * Math.PI);
        ctx.fill();
        if (opts.stroke) { ctx.strokeStyle = opts.stroke; ctx.stroke(); }
      }
    });
  };
  Plot.prototype.stems = function (values, opts) { // ACF-style stem plot, x = 1..k
    opts = opts || {};
    var ctx = this.ctx, self = this;
    this._clip(function () {
      ctx.strokeStyle = opts.color || SIM.colors.accent;
      ctx.lineWidth = opts.width || 4;
      var y0 = self.ypix(0);
      values.forEach(function (v, i) {
        var px = self.xpix(opts.x0 !== undefined ? opts.x0 + i : i + 1);
        ctx.beginPath(); ctx.moveTo(px, y0); ctx.lineTo(px, self.ypix(v)); ctx.stroke();
      });
    });
  };
  Plot.prototype.bars = function (xs, heights, opts) {
    opts = opts || {};
    var ctx = this.ctx, self = this;
    var wpix = opts.barWidth || Math.max(2, (this.W - this.m.l - this.m.r) / xs.length * 0.8);
    this._clip(function () {
      ctx.fillStyle = opts.color || SIM.colors.accent;
      var y0 = self.ypix(Math.max(self.ymin, 0));
      xs.forEach(function (x, i) {
        var px = self.xpix(x), py = self.ypix(heights[i]);
        ctx.fillRect(px - wpix / 2, Math.min(py, y0), wpix, Math.abs(y0 - py));
      });
    });
  };
  Plot.prototype.hist = function (data, bins, opts) {
    opts = opts || {};
    var lo = opts.lo !== undefined ? opts.lo : Math.min.apply(null, data);
    var hi = opts.hi !== undefined ? opts.hi : Math.max.apply(null, data);
    if (lo === hi) { lo -= 1; hi += 1; }
    var counts = new Array(bins).fill(0), w = (hi - lo) / bins;
    data.forEach(function (v) {
      var b = Math.floor((v - lo) / w);
      if (b >= 0 && b < bins) counts[b]++;
      else if (b === bins) counts[bins - 1]++;
    });
    var dens = counts.map(function (c) { return c / (data.length * w); }); // density scale
    var centers = counts.map(function (_, i) { return lo + (i + 0.5) * w; });
    this.bars(centers, opts.density === false ? counts : dens,
      { color: opts.color || 'rgba(56,189,248,0.55)', barWidth: (this.xpix(lo + w) - this.xpix(lo)) * 0.92 });
    return { centers: centers, counts: counts, density: dens, width: w };
  };
  Plot.prototype.hline = function (y, opts) {
    opts = opts || {};
    this.line([this.xmin, this.xmax], [y, y], { color: opts.color || SIM.colors.dim, width: opts.width || 1, dash: opts.dash || [5, 4] });
  };
  Plot.prototype.vline = function (x, opts) {
    opts = opts || {};
    this.line([x, x], [this.ymin, this.ymax], { color: opts.color || SIM.colors.dim, width: opts.width || 1, dash: opts.dash || [5, 4] });
  };
  Plot.prototype.shade = function (x0, x1, opts) { // vertical band
    opts = opts || {};
    var ctx = this.ctx, self = this;
    this._clip(function () {
      ctx.fillStyle = opts.color || 'rgba(248,113,113,0.18)';
      ctx.fillRect(self.xpix(x0), self.m.t, self.xpix(x1) - self.xpix(x0), self.H - self.m.t - self.m.b);
    });
  };
  Plot.prototype.shadeUnder = function (xs, ys, opts) { // area under a curve to y=0
    opts = opts || {};
    var ctx = this.ctx, self = this;
    this._clip(function () {
      ctx.fillStyle = opts.color || 'rgba(248,113,113,0.28)';
      ctx.beginPath();
      ctx.moveTo(self.xpix(xs[0]), self.ypix(0));
      for (var i = 0; i < xs.length; i++) ctx.lineTo(self.xpix(xs[i]), self.ypix(ys[i]));
      ctx.lineTo(self.xpix(xs[xs.length - 1]), self.ypix(0));
      ctx.closePath(); ctx.fill();
    });
  };
  Plot.prototype.label = function (x, y, text, opts) {
    opts = opts || {};
    var ctx = this.ctx;
    ctx.fillStyle = opts.color || SIM.colors.text;
    ctx.font = (opts.bold ? '600 ' : '') + (opts.size || 12) + 'px system-ui, sans-serif';
    ctx.textAlign = opts.align || 'left';
    ctx.textBaseline = opts.baseline || 'bottom';
    ctx.fillText(text, this.xpix(x), this.ypix(y));
  };
  Plot.prototype.legend = function (items) { // [{label, color}]
    var ctx = this.ctx, x = this.m.l + 10, y = this.m.t + 10;
    ctx.font = '11px system-ui, sans-serif';
    ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
    items.forEach(function (it, i) {
      ctx.fillStyle = it.color;
      ctx.fillRect(x, y + i * 17 - 4, 14, 8);
      ctx.fillStyle = SIM.colors.text;
      ctx.fillText(it.label, x + 20, y + i * 17);
    });
  };
  SIM.Plot = Plot;

  /* ---------- UI helpers ---------- */
  // SIM.slider(containerEl, {label, min, max, step, value, fmt}, onChange) -> {get, set, output}
  SIM.slider = function (container, cfg, onChange) {
    if (typeof container === 'string') container = document.getElementById(container);
    var wrap = document.createElement('div');
    wrap.className = 'ctl';
    var lab = document.createElement('label');
    lab.textContent = cfg.label;
    var inp = document.createElement('input');
    inp.type = 'range'; inp.min = cfg.min; inp.max = cfg.max;
    inp.step = cfg.step || 'any'; inp.value = cfg.value;
    var out = document.createElement('output');
    var fmt = cfg.fmt || function (v) { return (+v).toFixed(2); };
    out.textContent = fmt(cfg.value);
    inp.addEventListener('input', function () {
      out.textContent = fmt(+inp.value);
      if (onChange) onChange(+inp.value);
    });
    wrap.appendChild(lab); wrap.appendChild(inp); wrap.appendChild(out);
    container.appendChild(wrap);
    return {
      get: function () { return +inp.value; },
      set: function (v) { inp.value = v; out.textContent = fmt(v); },
      input: inp, output: out
    };
  };
  SIM.button = function (container, label, onClick, ghost) {
    if (typeof container === 'string') container = document.getElementById(container);
    var b = document.createElement('button');
    b.type = 'button'; b.textContent = label;
    if (ghost) b.className = 'ghost';
    b.addEventListener('click', onClick);
    container.appendChild(b);
    return b;
  };
  // drag interaction on a Plot; cb(dataX, dataY, phase) phase in {down,move,up}
  SIM.drag = function (plot, cb) {
    var c = plot.canvas, active = false;
    function pos(ev) {
      var r = c.getBoundingClientRect();
      var cx = (ev.touches ? ev.touches[0].clientX : ev.clientX) - r.left;
      var cy = (ev.touches ? ev.touches[0].clientY : ev.clientY) - r.top;
      // canvas may be CSS-scaled: map to logical px
      var sx = plot.W / r.width, sy = plot.H / r.height;
      return { x: plot.xdata(cx * sx), y: plot.ydata(cy * sy), px: cx * sx, py: cy * sy };
    }
    function down(ev) { active = true; var p = pos(ev); cb(p, 'down'); ev.preventDefault(); }
    function move(ev) { if (!active) return; var p = pos(ev); cb(p, 'move'); ev.preventDefault(); }
    function up(ev) { if (!active) return; active = false; cb(null, 'up'); }
    c.addEventListener('mousedown', down);
    c.addEventListener('mousemove', move);
    global.addEventListener('mouseup', up);
    c.addEventListener('touchstart', down, { passive: false });
    c.addEventListener('touchmove', move, { passive: false });
    c.addEventListener('touchend', up);
  };

  /* ---------- language tabs (lab guides) ---------- */
  SIM.initTabs = function (root) {
    (root || document).querySelectorAll('.codetabs').forEach(function (ct) {
      var btns = ct.querySelectorAll('.tabbar button');
      var panes = ct.querySelectorAll('.tabpane');
      btns.forEach(function (b, i) {
        b.addEventListener('click', function () {
          btns.forEach(function (x) { x.classList.remove('active'); });
          panes.forEach(function (x) { x.classList.remove('active'); });
          b.classList.add('active');
          panes[i].classList.add('active');
        });
      });
      if (btns.length && !ct.querySelector('.tabbar button.active')) {
        btns[0].classList.add('active');
        panes[0].classList.add('active');
      }
    });
  };

  /* ---------- quiz helper ---------- */
  // markup: .quiz > .q, .opt[data-ok], .explain
  SIM.initQuiz = function (root) {
    (root || document).querySelectorAll('.quiz .opt').forEach(function (opt) {
      opt.addEventListener('click', function () {
        var quiz = opt.closest('.quiz');
        quiz.querySelectorAll('.opt').forEach(function (o) { o.classList.remove('correct', 'wrong'); });
        opt.classList.add(opt.hasAttribute('data-ok') ? 'correct' : 'wrong');
        var ok = quiz.querySelector('.opt[data-ok]');
        if (ok && opt !== ok) ok.classList.add('correct');
        var ex = quiz.querySelector('.explain');
        if (ex) ex.classList.add('show');
      });
    });
  };

  /* ---------- academic year + copyright ---------- */
  // UK academic year, switching on 1 July: from July 2026 to June 2027 this returns "2026/2027"
  SIM.academicYear = function () {
    var d = new Date();
    var y = d.getMonth() >= 6 ? d.getFullYear() : d.getFullYear() - 1;
    return y + '/' + (y + 1);
  };
  function stampYearAndCopyright() {
    var year = SIM.academicYear();
    document.querySelectorAll('.acyear').forEach(function (el) { el.textContent = year; });
    if (document.querySelector('.site-copyright')) return;
    var bar = document.createElement('div');
    bar.className = 'site-copyright';
    bar.textContent = '© ' + year + ' Dr. Ahmad Maaitah, University of Southampton';
    if (document.querySelector('.reveal')) {
      document.body.appendChild(bar);           // fixed strip under the slides
    } else {
      var f = document.querySelector('footer');
      if (f) { bar.classList.add('inline'); f.appendChild(bar); }
      else document.body.appendChild(bar);
    }
  }
  function autoInit() {
    stampYearAndCopyright();
    SIM.initTabs();   // idempotent: wires any .codetabs on the page (decks and labs alike)
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', autoInit);
  } else {
    autoInit();
  }

  global.SIM = SIM;
})(typeof window !== 'undefined' ? window : this);
