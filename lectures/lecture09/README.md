# Lecture 9 · Forecasting with Multivariate GARCH

**Deck:** `index.html` (reveal.js) ·
**Paper:** Laurent, S., Rombouts, J.V.K. and Violante, F. (2012) 'On the forecasting accuracy of
multivariate GARCH models', *Journal of Applied Econometrics*, 27(6), pp. 934-955.

## Learning objectives
- Why forecasting the conditional covariance matrix H_t is hard: positive definiteness and the
  curse of dimensionality (N(N+1)/2 moving targets)
- The three MGARCH families the paper races: BEKK/RiskMetrics, orthogonal, and conditional
  correlation (CCC, DCC and relatives)
- The DCC(1,1) of Engle (2002): devolatilised innovations, correlation targeting, the (a, b)
  recursion, and two-step estimation
- Robust loss functions (Euclidean, Frobenius, Stein, L3) and the proxy problem
- The model confidence set (Hansen, Lunde and Nason) and SPA test as honest model-selection tools
- The paper's findings: DCC with leverage is never significantly beaten; CCC survives in calm
  markets; rankings move with horizon, subsample and loss function

## The data (the paper's own)
`data/csv/lrv_returns.csv` is the **original Laurent-Rombouts-Violante estimation sample**
published by the authors: 2,740 daily open-to-close % returns for ABT, BP, CL, EK, FDX, KO, WMT,
PEP, PG, WYE. `date_serial` is a Julian day number; it decodes to 2 March 1988 - 31 December 1998
(the authors' readme describes the same 2,740-obs file as running to 31 March 1999 - a small
documented discrepancy). The csv carries a stray text row at the end; all code coerces to numeric
and drops it. Every simulation, cell and code file this week runs on this data.

`data_lrv3.js` embeds the last 2,000 days of KO, PEP and PG (rounded to 4 dp) plus their
scipy-MLE GARCH(1,1) parameters for the canvas simulations.

## Embedded simulations (all seeded, teaching grade, on the paper's data)
1. **DCC(1,1) laboratory** - a and b sliders drive the correlation recursion on GARCH-filtered
   KO/PEP/PG; "fit a, b by MLE" runs a grid MLE (a = 0.016, b = 0.933, matching Python);
   "CCC" button flattens the lines at the targets (0.44 / 0.43 / 0.33)
2. **Covariance forecast race** - CCC vs DCC vs EWMA (RiskMetrics 0.96) one-step forecasts over
   the last 800 days, Frobenius/QLIKE toggle, cumulative average advantage vs CCC
3. **Curse of dimensionality** - estimated-parameter counts vs N (2-50, log scale) for full VEC,
   full/diagonal/scalar BEKK, DCC and CCC, with the paper's N = 10 marked
4. **MCS intuition** - block-bootstrap elimination on the race's loss differentials with an
   alpha slider (the paper's full procedure is Hansen-Lunde-Nason with 10,000 bootstraps)
5. **Robustness explorer** - average Frobenius loss relative to CCC at H = 1/5/20 over the full,
   calm (1995-97) and turbulent (1997-98) evaluation windows

## Runnable Python cells (pyrun)
1. Data preparation: descriptives, zero-return days, ADF tests on the real data
2. GARCH(1,1) on KO by scipy MLE (omega 0.0527, alpha 0.0376, beta 0.9342)
3. Two-step DCC on KO/PEP/PG, last 2,000 obs (a = 0.0163, b = 0.9330)
4. Estimation-window robustness (window 1,000: a = 0.0320, b = 0.8847)

## Code (`code/`)
| File | Language | Notes |
|---|---|---|
| `lecture09.py` | Python | full workflow; exits 0; prints every number quoted in the deck |
| `lecture09.R` | R | rugarch + rmgarch (`dccspec`/`dccfit`), MCS package pointer |
| `lecture09.do` | Stata | native `mgarch dcc` / `mgarch ccc`, window robustness |
| `lecture09.prg` | EViews | honest route: system ARCH gives CCC/diagonal BEKK; DCC needs the add-in |

Run each from inside `code/` (data path `../../../data/csv/lrv_returns.csv`).

Key numbers: 3-stock DCC full sample **a = 0.0150, b = 0.9708**; deck window (last 2,000)
**a = 0.0163, b = 0.9330**; all 10 stocks **a = 0.0044, b = 0.9863**. Race (800 days, Frobenius):
CCC 374.90, DCC **374.65**, EWMA 379.06; turbulent half carries ~13x the calm half's loss;
at H = 20 EWMA is ~24% worse than CCC (flat forecasts do not mean-revert).
