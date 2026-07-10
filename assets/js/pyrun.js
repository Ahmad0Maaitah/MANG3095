/* MANG2074 in-browser Python runner (Pyodide).
   Turns any <div class="pyrun"> block into an editable, executable code cell:

     <div class="pyrun">
       <textarea class="pyrun-code" spellcheck="false">print("hello")</textarea>
     </div>

   PYRUN.init() wires every block on the page: adds a toolbar (Run / Reset),
   an output pane and a figure strip. Pyodide (~15 MB) is fetched from the
   jsDelivr CDN on the first Run click only, then cached by the browser.
   pandas/numpy/statsmodels/scipy/matplotlib load on demand from imports.

   Data: a `load("name")` helper is injected that reads /data/csv/name.csv
   from this site, so the same datasets used in the labs work in the browser.
*/
(function (global) {
  'use strict';
  var PYRUN = {};
  var pyodide = null;
  var loading = null;
  var PYODIDE_URL = 'https://cdn.jsdelivr.net/pyodide/v0.26.4/full/pyodide.js';
  var PYODIDE_INDEX = 'https://cdn.jsdelivr.net/pyodide/v0.26.4/full/';

  function dataBase() {
    // absolute URL of data/csv/, derived from this script's own src
    var s = document.querySelector('script[src*="pyrun.js"]');
    var u = new URL(s.getAttribute('src'), global.location.href);
    return new URL('../../', u).href + 'data/csv/';
  }

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var el = document.createElement('script');
      el.src = src;
      el.onload = resolve;
      el.onerror = function () { reject(new Error('Could not download the Python runtime. Check your internet connection.')); };
      document.head.appendChild(el);
    });
  }

  function ensurePyodide(status) {
    if (pyodide) return Promise.resolve(pyodide);
    if (!loading) {
      loading = loadScript(PYODIDE_URL).then(function () {
        status('Starting Python (first run only, ~15 MB download)...');
        return global.loadPyodide({ indexURL: PYODIDE_INDEX });
      }).then(function (py) {
        pyodide = py;
        // helper: load("ukhp") -> DataFrame from this site's data/csv/
        py.globals.set('_PYRUN_DATA_BASE', dataBase());
        return py.runPythonAsync(
          'def load(name):\n' +
          '    import pandas as pd\n' +
          '    from pyodide.http import open_url\n' +
          '    return pd.read_csv(open_url(_PYRUN_DATA_BASE + name + ".csv"))\n'
        ).then(function () { return py; });
      });
    }
    return loading;
  }

  var FIG_HARVEST =
    'import base64 as _b64, io as _io, sys as _sys\n' +
    '_figs = []\n' +
    'if "matplotlib" in _sys.modules:\n' +
    '    import matplotlib.pyplot as _plt\n' +
    '    for _n in _plt.get_fignums():\n' +
    '        _b = _io.BytesIO()\n' +
    '        _plt.figure(_n).savefig(_b, format="png", dpi=85, bbox_inches="tight",\n' +
    '                                facecolor="#0b1220", edgecolor="none")\n' +
    '        _figs.append(_b64.b64encode(_b.getvalue()).decode())\n' +
    '    _plt.close("all")\n' +
    '_figs\n';

  var MPL_STYLE =
    'import warnings\n' +
    'warnings.filterwarnings("ignore", category=DeprecationWarning)\n' +
    'warnings.filterwarnings("ignore", category=FutureWarning)\n' +
    'import sys\n' +
    'if "matplotlib" in sys.modules or True:\n' +
    '    try:\n' +
    '        import matplotlib\n' +
    '        matplotlib.use("Agg")\n' +
    '        import matplotlib.pyplot as plt\n' +
    '        plt.rcParams.update({"figure.facecolor": "#0b1220", "axes.facecolor": "#0b1220",\n' +
    '            "axes.edgecolor": "#475569", "axes.labelcolor": "#94a3b8", "text.color": "#e2e8f0",\n' +
    '            "xtick.color": "#94a3b8", "ytick.color": "#94a3b8", "grid.color": "#1e293b",\n' +
    '            "figure.figsize": (7.6, 3.4), "font.size": 9, "axes.grid": True})\n' +
    '    except Exception:\n' +
    '        pass\n';

  function runBlock(block) {
    var codeEl = block.querySelector('.pyrun-code');
    var out = block.querySelector('.pyrun-out');
    var figs = block.querySelector('.pyrun-figs');
    var statusEl = block.querySelector('.pyrun-status');
    var btn = block.querySelector('.pyrun-run');
    function status(t) { statusEl.textContent = t; }
    var code = codeEl.value;
    btn.disabled = true;
    out.textContent = '';
    figs.innerHTML = '';
    out.classList.remove('err');
    status('Loading Python...');
    ensurePyodide(status).then(function (py) {
      status('Fetching packages...');
      // always include pandas: the injected load() helper depends on it
      return py.loadPackagesFromImports(code + '\nimport pandas\n').then(function () {
        status('Running...');
        var stdout = [];
        py.setStdout({ batched: function (s) { stdout.push(s); } });
        py.setStderr({ batched: function (s) { stdout.push(s); } });
        return py.runPythonAsync(MPL_STYLE)
          .then(function () { return py.runPythonAsync(code); })
          .then(function (ret) {
            // harvest figures
            return py.runPythonAsync(FIG_HARVEST).then(function (figList) {
              var arr = figList ? figList.toJs() : [];
              if (figList && figList.destroy) figList.destroy();
              arr.forEach(function (b64) {
                var img = document.createElement('img');
                img.src = 'data:image/png;base64,' + b64;
                figs.appendChild(img);
              });
              var txt = stdout.join('\n');
              if (ret !== undefined && ret !== null && String(ret) !== 'undefined' && txt.indexOf(String(ret)) === -1) {
                var r = String(ret);
                if (r && r !== 'None') txt += (txt ? '\n' : '') + r;
              }
              out.textContent = txt || '(no output)';
              status('Done. Edit the code and run again.');
            });
          });
      });
    }).catch(function (e) {
      out.textContent = String(e.message || e).replace(/^PythonError:\s*/, '');
      out.classList.add('err');
      status('Error - fix the code and run again.');
    }).finally(function () {
      btn.disabled = false;
      py_autoresize(codeEl);
    });
  }

  function py_autoresize(ta) {
    ta.style.height = 'auto';
    ta.style.height = Math.min(ta.scrollHeight + 4, 560) + 'px';
  }

  function remeasureVisible() {
    document.querySelectorAll('.pyrun textarea.pyrun-code').forEach(function (ta) {
      if (ta.offsetParent !== null) py_autoresize(ta);
    });
  }

  PYRUN.init = function (root) {
    // hidden reveal slides report zero scrollHeight: re-measure cells when a slide becomes visible
    if (global.Reveal && global.Reveal.on && !PYRUN._revealHooked) {
      PYRUN._revealHooked = true;
      global.Reveal.on('slidechanged', function () { requestAnimationFrame(remeasureVisible); });
      global.Reveal.on('ready', function () { requestAnimationFrame(remeasureVisible); });
      requestAnimationFrame(remeasureVisible);
    }
    var blocks = (root || document).querySelectorAll('.pyrun');
    blocks.forEach(function (block) {
      if (block._wired) return;
      block._wired = true;
      var codeEl = block.querySelector('.pyrun-code');
      if (!codeEl) return;
      // de-indent template whitespace
      codeEl.value = codeEl.value.replace(/^\n+/, '').replace(/\s+$/, '') + '\n';
      block._initialCode = codeEl.value;

      var bar = document.createElement('div');
      bar.className = 'pyrun-toolbar';
      var run = document.createElement('button');
      run.className = 'pyrun-run';
      run.type = 'button';
      run.textContent = '▶ Run';
      var reset = document.createElement('button');
      reset.className = 'pyrun-reset';
      reset.type = 'button';
      reset.textContent = 'Reset code';
      var st = document.createElement('span');
      st.className = 'pyrun-status';
      st.textContent = 'Edit the code, then press Run. Python executes in your browser.';
      bar.appendChild(run); bar.appendChild(reset); bar.appendChild(st);
      block.insertBefore(bar, codeEl);

      var out = document.createElement('pre');
      out.className = 'pyrun-out';
      var figs = document.createElement('div');
      figs.className = 'pyrun-figs';
      block.appendChild(out);
      block.appendChild(figs);

      run.addEventListener('click', function () { runBlock(block); });
      reset.addEventListener('click', function () {
        codeEl.value = block._initialCode;
        out.textContent = ''; figs.innerHTML = '';
        py_autoresize(codeEl);
      });
      // keep reveal.js from stealing keystrokes while editing
      codeEl.addEventListener('focus', function () {
        if (global.Reveal && global.Reveal.configure) global.Reveal.configure({ keyboard: false });
      });
      codeEl.addEventListener('blur', function () {
        if (global.Reveal && global.Reveal.configure) global.Reveal.configure({ keyboard: true });
      });
      codeEl.addEventListener('input', function () { py_autoresize(codeEl); });
      // Tab inserts 4 spaces
      codeEl.addEventListener('keydown', function (ev) {
        if (ev.key === 'Tab') {
          ev.preventDefault();
          var s = codeEl.selectionStart, e = codeEl.selectionEnd;
          codeEl.value = codeEl.value.slice(0, s) + '    ' + codeEl.value.slice(e);
          codeEl.selectionStart = codeEl.selectionEnd = s + 4;
        }
      });
      py_autoresize(codeEl);
    });
  };

  global.PYRUN = PYRUN;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { PYRUN.init(); });
  } else {
    PYRUN.init();
  }
})(typeof window !== 'undefined' ? window : this);
