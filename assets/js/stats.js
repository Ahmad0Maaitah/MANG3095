/* MANG2074 shared statistics library (no dependencies).
   Everything lives under the global object `ST`. */
(function (global) {
  'use strict';
  var ST = {};

  /* ---------- RNG: deterministic mulberry32 + Box-Muller normals ---------- */
  ST.rng = function (seed) {
    var a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };
  ST.randn = function (rand) {
    var u = 0, v = 0;
    while (u === 0) u = rand();
    while (v === 0) v = rand();
    return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
  };

  /* ---------- basic moments ---------- */
  ST.mean = function (x) {
    var s = 0; for (var i = 0; i < x.length; i++) s += x[i];
    return s / x.length;
  };
  ST.variance = function (x, ddof) {
    ddof = ddof === undefined ? 1 : ddof;
    var m = ST.mean(x), s = 0;
    for (var i = 0; i < x.length; i++) s += (x[i] - m) * (x[i] - m);
    return s / (x.length - ddof);
  };
  ST.sd = function (x, ddof) { return Math.sqrt(ST.variance(x, ddof)); };
  ST.cov = function (x, y) {
    var mx = ST.mean(x), my = ST.mean(y), s = 0;
    for (var i = 0; i < x.length; i++) s += (x[i] - mx) * (y[i] - my);
    return s / (x.length - 1);
  };
  ST.corr = function (x, y) { return ST.cov(x, y) / (ST.sd(x) * ST.sd(y)); };
  ST.skewness = function (x) {
    var m = ST.mean(x), s = ST.sd(x, 0), n = x.length, a = 0;
    for (var i = 0; i < n; i++) a += Math.pow((x[i] - m) / s, 3);
    return a / n;
  };
  ST.kurtosis = function (x) { // raw kurtosis (normal = 3)
    var m = ST.mean(x), s = ST.sd(x, 0), n = x.length, a = 0;
    for (var i = 0; i < n; i++) a += Math.pow((x[i] - m) / s, 4);
    return a / n;
  };
  ST.min = function (x) { return Math.min.apply(null, x); };
  ST.max = function (x) { return Math.max.apply(null, x); };
  ST.quantile = function (x, p) {
    var s = x.slice().sort(function (a, b) { return a - b; });
    var h = (s.length - 1) * p, lo = Math.floor(h), hi = Math.ceil(h);
    return s[lo] + (h - lo) * (s[hi] - s[lo]);
  };

  /* ---------- distributions ---------- */
  ST.normPdf = function (z) { return Math.exp(-0.5 * z * z) / Math.sqrt(2 * Math.PI); };
  function erf(x) { // Abramowitz-Stegun 7.1.26
    var sign = x < 0 ? -1 : 1;
    x = Math.abs(x);
    var t = 1 / (1 + 0.3275911 * x);
    var y = 1 - (((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t) * Math.exp(-x * x);
    return sign * y;
  }
  ST.normCdf = function (z) { return 0.5 * (1 + erf(z / Math.SQRT2)); };

  // log-gamma (Lanczos)
  function gammaln(x) {
    var c = [76.18009172947146, -86.50532032941677, 24.01409824083091,
             -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5];
    var y = x, tmp = x + 5.5;
    tmp -= (x + 0.5) * Math.log(tmp);
    var ser = 1.000000000190015;
    for (var j = 0; j < 6; j++) ser += c[j] / ++y;
    return -tmp + Math.log(2.5066282746310005 * ser / x);
  }
  // regularized incomplete beta via continued fraction
  function betacf(a, b, x) {
    var MAXIT = 200, EPS = 3e-12, FPMIN = 1e-300;
    var qab = a + b, qap = a + 1, qam = a - 1;
    var c = 1, d = 1 - qab * x / qap;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    d = 1 / d;
    var h = d;
    for (var m = 1; m <= MAXIT; m++) {
      var m2 = 2 * m;
      var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1 + aa * d; if (Math.abs(d) < FPMIN) d = FPMIN;
      c = 1 + aa / c; if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d; h *= d * c;
      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1 + aa * d; if (Math.abs(d) < FPMIN) d = FPMIN;
      c = 1 + aa / c; if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d;
      var del = d * c; h *= del;
      if (Math.abs(del - 1) < EPS) break;
    }
    return h;
  }
  function ibeta(a, b, x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    var bt = Math.exp(gammaln(a + b) - gammaln(a) - gammaln(b) + a * Math.log(x) + b * Math.log(1 - x));
    if (x < (a + 1) / (a + b + 2)) return bt * betacf(a, b, x) / a;
    return 1 - bt * betacf(b, a, 1 - x) / b;
  }
  // lower regularized incomplete gamma
  function gammainc(s, x) {
    if (x <= 0) return 0;
    if (x < s + 1) { // series
      var sum = 1 / s, term = sum;
      for (var n = 1; n < 300; n++) {
        term *= x / (s + n); sum += term;
        if (Math.abs(term) < Math.abs(sum) * 1e-13) break;
      }
      return sum * Math.exp(-x + s * Math.log(x) - gammaln(s));
    }
    // continued fraction for upper, complement
    var FPMIN = 1e-300, b = x + 1 - s, c = 1 / FPMIN, d = 1 / b, h = d;
    for (var i = 1; i < 300; i++) {
      var an = -i * (i - s);
      b += 2; d = an * d + b; if (Math.abs(d) < FPMIN) d = FPMIN;
      c = b + an / c; if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d;
      var del = d * c; h *= del;
      if (Math.abs(del - 1) < 1e-13) break;
    }
    return 1 - Math.exp(-x + s * Math.log(x) - gammaln(s)) * h;
  }
  ST.tCdf = function (t, df) {
    var x = df / (df + t * t);
    var p = 0.5 * ibeta(df / 2, 0.5, x);
    return t > 0 ? 1 - p : p;
  };
  ST.tPdf = function (t, df) {
    return Math.exp(gammaln((df + 1) / 2) - gammaln(df / 2)) /
      Math.sqrt(df * Math.PI) * Math.pow(1 + t * t / df, -(df + 1) / 2);
  };
  ST.tInv = function (p, df) { // bisection on tCdf
    var lo = -60, hi = 60;
    for (var i = 0; i < 120; i++) {
      var mid = (lo + hi) / 2;
      if (ST.tCdf(mid, df) < p) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2;
  };
  ST.chi2Cdf = function (x, k) { return gammainc(k / 2, x / 2); };
  ST.fCdf = function (f, d1, d2) {
    if (f <= 0) return 0;
    return ibeta(d1 / 2, d2 / 2, d1 * f / (d1 * f + d2));
  };

  /* ---------- OLS ---------- */
  // simple bivariate OLS with classic SEs
  ST.ols = function (x, y) {
    var n = x.length;
    var mx = ST.mean(x), my = ST.mean(y);
    var sxx = 0, sxy = 0;
    for (var i = 0; i < n; i++) { sxx += (x[i] - mx) * (x[i] - mx); sxy += (x[i] - mx) * (y[i] - my); }
    var beta = sxy / sxx, alpha = my - beta * mx;
    var fitted = new Array(n), resid = new Array(n), rss = 0, tss = 0;
    for (i = 0; i < n; i++) {
      fitted[i] = alpha + beta * x[i];
      resid[i] = y[i] - fitted[i];
      rss += resid[i] * resid[i];
      tss += (y[i] - my) * (y[i] - my);
    }
    var s2 = rss / (n - 2);
    var seBeta = Math.sqrt(s2 / sxx);
    var seAlpha = Math.sqrt(s2 * (1 / n + mx * mx / sxx));
    var tb = beta / seBeta, ta = alpha / seAlpha;
    return {
      n: n, alpha: alpha, beta: beta, seAlpha: seAlpha, seBeta: seBeta,
      tAlpha: ta, tBeta: tb,
      pAlpha: 2 * (1 - ST.tCdf(Math.abs(ta), n - 2)),
      pBeta: 2 * (1 - ST.tCdf(Math.abs(tb), n - 2)),
      r2: 1 - rss / tss, rss: rss, tss: tss, s2: s2,
      fitted: fitted, resid: resid
    };
  };

  // multiple OLS: y on columns of X (constant added automatically)
  // X = array of regressor arrays; returns beta (incl. intercept first), se, t, r2, resid, fitted
  ST.olsMulti = function (y, X) {
    var n = y.length, k = X.length + 1;
    // design matrix rows
    var rows = new Array(n);
    for (var i = 0; i < n; i++) {
      rows[i] = [1];
      for (var j = 0; j < X.length; j++) rows[i].push(X[j][i]);
    }
    // X'X and X'y
    var XtX = [], Xty = [];
    for (var a = 0; a < k; a++) {
      XtX.push(new Array(k).fill(0)); Xty.push(0);
      for (i = 0; i < n; i++) Xty[a] += rows[i][a] * y[i];
      for (var b = 0; b < k; b++)
        for (i = 0; i < n; i++) XtX[a][b] += rows[i][a] * rows[i][b];
    }
    // invert XtX by Gauss-Jordan (k is small)
    var inv = [];
    for (a = 0; a < k; a++) {
      inv.push(new Array(k).fill(0)); inv[a][a] = 1;
    }
    var M = XtX.map(function (r) { return r.slice(); });
    for (var col = 0; col < k; col++) {
      var piv = col;
      for (a = col + 1; a < k; a++) if (Math.abs(M[a][col]) > Math.abs(M[piv][col])) piv = a;
      var tmp = M[col]; M[col] = M[piv]; M[piv] = tmp;
      tmp = inv[col]; inv[col] = inv[piv]; inv[piv] = tmp;
      var d = M[col][col];
      if (Math.abs(d) < 1e-12) d = 1e-12;
      for (b = 0; b < k; b++) { M[col][b] /= d; inv[col][b] /= d; }
      for (a = 0; a < k; a++) {
        if (a === col) continue;
        var f = M[a][col];
        for (b = 0; b < k; b++) { M[a][b] -= f * M[col][b]; inv[a][b] -= f * inv[col][b]; }
      }
    }
    var beta = new Array(k).fill(0);
    for (a = 0; a < k; a++) for (b = 0; b < k; b++) beta[a] += inv[a][b] * Xty[b];
    var fitted = new Array(n), resid = new Array(n), rss = 0, tss = 0;
    var my = ST.mean(y);
    for (i = 0; i < n; i++) {
      var f2 = 0;
      for (a = 0; a < k; a++) f2 += rows[i][a] * beta[a];
      fitted[i] = f2; resid[i] = y[i] - f2;
      rss += resid[i] * resid[i]; tss += (y[i] - my) * (y[i] - my);
    }
    var s2 = rss / (n - k);
    var se = [], t = [];
    for (a = 0; a < k; a++) {
      se.push(Math.sqrt(s2 * inv[a][a]));
      t.push(beta[a] / se[a]);
    }
    return { n: n, k: k, beta: beta, se: se, t: t, r2: 1 - rss / tss, rss: rss, s2: s2, fitted: fitted, resid: resid };
  };

  /* ---------- regression diagnostic tests (LM form, chi-2) ---------- */
  // White (1980) heteroscedasticity test, single regressor: e^2 on x, x^2
  ST.whiteTest = function (resid, x) {
    var e2 = resid.map(function (e) { return e * e; });
    var x2 = x.map(function (v) { return v * v; });
    var aux = ST.olsMulti(e2, [x, x2]);
    var lm = resid.length * aux.r2;
    return { stat: lm, df: 2, p: 1 - ST.chi2Cdf(lm, 2) };
  };
  // Breusch-Godfrey autocorrelation test of order p: e_t on x and e_{t-1..t-p}
  ST.bgTest = function (resid, x, p) {
    p = p || 1;
    var n = resid.length;
    var y = resid.slice(p);
    var regs = [x.slice(p)];
    for (var j = 1; j <= p; j++) regs.push(resid.slice(p - j, n - j));
    var aux = ST.olsMulti(y, regs);
    var lm = (n - p) * aux.r2;
    return { stat: lm, df: p, p: 1 - ST.chi2Cdf(lm, p) };
  };
  // Ramsey RESET functional-form test: y on x, yhat^2 (LM version)
  ST.resetTest = function (y, x, fitted) {
    var f2 = fitted.map(function (v) { return v * v; });
    var aux = ST.olsMulti(y, [x, f2]);
    var base = ST.ols(x, y);
    // F-stat for adding yhat^2
    var f = (base.rss - aux.rss) / 1 / (aux.rss / (y.length - 3));
    return { stat: f, df1: 1, df2: y.length - 3, p: 1 - ST.fCdf(f, 1, y.length - 3) };
  };

  /* ---------- time-series tools ---------- */
  ST.acf = function (x, maxLag) {
    var n = x.length, m = ST.mean(x), out = [];
    var c0 = 0;
    for (var i = 0; i < n; i++) c0 += (x[i] - m) * (x[i] - m);
    for (var k = 1; k <= maxLag; k++) {
      var ck = 0;
      for (i = k; i < n; i++) ck += (x[i] - m) * (x[i - k] - m);
      out.push(ck / c0);
    }
    return out;
  };
  ST.pacf = function (x, maxLag) { // Durbin-Levinson
    var rho = ST.acf(x, maxLag);
    var phi = [], prev = [], out = [];
    for (var k = 1; k <= maxLag; k++) {
      if (k === 1) { phi = [rho[0]]; }
      else {
        var num = rho[k - 1], den = 1;
        for (var j = 0; j < k - 1; j++) { num -= prev[j] * rho[k - 2 - j]; den -= prev[j] * rho[j]; }
        var pk = num / den;
        phi = [];
        for (j = 0; j < k - 1; j++) phi.push(prev[j] - pk * prev[k - 2 - j]);
        phi.push(pk);
      }
      out.push(phi[k - 1]);
      prev = phi.slice();
    }
    return out;
  };
  // ARMA(p,q) simulation with N(0, sigma^2) shocks and burn-in
  ST.simARMA = function (phi, theta, n, sigma, rand) {
    phi = phi || []; theta = theta || []; sigma = sigma || 1;
    var burn = 100, N = n + burn;
    var e = new Array(N), y = new Array(N);
    for (var t = 0; t < N; t++) {
      e[t] = ST.randn(rand) * sigma;
      var v = e[t];
      for (var i = 0; i < phi.length; i++) v += phi[i] * (t - 1 - i >= 0 ? y[t - 1 - i] : 0);
      for (var j = 0; j < theta.length; j++) v += theta[j] * (t - 1 - j >= 0 ? e[t - 1 - j] : 0);
      y[t] = v;
    }
    return y.slice(burn);
  };
  // GARCH(1,1) simulation; returns {r, sigma} conditional sd path
  ST.simGARCH = function (omega, alpha, beta, n, rand) {
    var burn = 100, N = n + burn;
    var uncond = omega / Math.max(1e-8, 1 - alpha - beta);
    if (uncond <= 0 || !isFinite(uncond)) uncond = omega;
    var h = uncond, r = new Array(N), s = new Array(N);
    for (var t = 0; t < N; t++) {
      s[t] = Math.sqrt(h);
      r[t] = s[t] * ST.randn(rand);
      h = omega + alpha * r[t] * r[t] + beta * h;
    }
    return { r: r.slice(burn), sigma: s.slice(burn) };
  };
  ST.ewma = function (x2, lambda) { // variance filter on squared returns
    var out = new Array(x2.length), v = ST.mean(x2);
    for (var t = 0; t < x2.length; t++) {
      out[t] = Math.sqrt(v);
      v = lambda * v + (1 - lambda) * x2[t];
    }
    return out;
  };

  /* ---------- diagnostics ---------- */
  ST.jarqueBera = function (x) {
    var n = x.length, S = ST.skewness(x), K = ST.kurtosis(x);
    var jb = n / 6 * (S * S + Math.pow(K - 3, 2) / 4);
    return { stat: jb, p: 1 - ST.chi2Cdf(jb, 2), skew: S, kurt: K };
  };
  ST.durbinWatson = function (resid) {
    var num = 0, den = 0;
    for (var i = 0; i < resid.length; i++) {
      den += resid[i] * resid[i];
      if (i > 0) num += Math.pow(resid[i] - resid[i - 1], 2);
    }
    return num / den;
  };

  /* ---------- small matrix helpers (2x2 VAR) ---------- */
  ST.eig2 = function (A) { // eigenvalues of [[a,b],[c,d]]; returns moduli
    var a = A[0][0], b = A[0][1], c = A[1][0], d = A[1][1];
    var tr = a + d, det = a * d - b * c;
    var disc = tr * tr / 4 - det;
    if (disc >= 0) {
      var s = Math.sqrt(disc);
      return [{ re: tr / 2 + s, im: 0 }, { re: tr / 2 - s, im: 0 }];
    }
    var im = Math.sqrt(-disc);
    return [{ re: tr / 2, im: im }, { re: tr / 2, im: -im }];
  };
  ST.irf2 = function (A, shock, horizon) { // IRF path for 2-var VAR(1), unit shock vector
    var out = [shock.slice()];
    for (var h = 1; h <= horizon; h++) {
      var prev = out[h - 1];
      out.push([
        A[0][0] * prev[0] + A[0][1] * prev[1],
        A[1][0] * prev[0] + A[1][1] * prev[1]
      ]);
    }
    return out;
  };

  /* ---------- misc helpers ---------- */
  ST.logReturns = function (prices) {
    var out = [];
    for (var i = 1; i < prices.length; i++) out.push(Math.log(prices[i] / prices[i - 1]));
    return out;
  };
  ST.simpleReturns = function (prices) {
    var out = [];
    for (var i = 1; i < prices.length; i++) out.push(prices[i] / prices[i - 1] - 1);
    return out;
  };
  ST.fmt = function (x, d) {
    if (!isFinite(x)) return ' - ';
    return x.toFixed(d === undefined ? 3 : d);
  };

  global.ST = ST;
})(typeof window !== 'undefined' ? window : this);
