# Week 6 · Fama and French (2015): A Five-Factor Asset Pricing Model

**The paper:** Fama, E.F. and French, K.R. (2015) 'A five-factor asset pricing model',
*Journal of Financial Economics*, 116(1), pp. 1-22.
**Data:** `data/csv/ff5_monthly.csv` (Ken French five factors, % per month, July 1963 - August 2022,
T = 710) and `data/csv/ff5_annual.csv` (1964-2021, 58 years).

## Learning objectives
- Derive the value, profitability and investment predictions from the dividend discount model
- Write down the FF3 and FF5 time-series regressions and the zero-intercept hypothesis
- Explain factor construction from 2x3 sorts (and the 2x2 / 2x2x2x2 alternatives)
- Run and interpret **factor spanning regressions**, including the paper's HML-redundancy result
- Compute and interpret the **GRS joint test** (Gibbons, Ross and Shanken, 1989)
- Stress-test a factor result across subsamples and measurement frequencies

## Embedded simulations (all seeded, canvas, ST./SIM. only)
1. **The 2x3 sorting machine** (method section) - 400 simulated firms; move the B/M breakpoints
   and the value-effect strength and watch the implied HML premium change (2x3 vs 2x2 logic)
2. **Factor premia explorer** - cumulative log returns of the five real factors with series
   toggles and a date-range window; readout of annualised mean / sd / Sharpe per factor
3. **Live spanning regression** - pick a target factor, it is regressed on the other four in the
   browser (real data); intercept and slopes with 95% CIs; reproduces the paper's Table 6
4. **Alpha map / GRS intuition** - N simulated portfolios with slider-controlled true alpha
   dispersion on the real factors; intercept t-statistics vs the GRS joint verdict
5. **Split-slider robustness** - the spanning alpha of HML/RMW/CMA before and after a movable
   split date, with confidence whiskers and the full-sample alpha for reference

Each simulation has a "Reading the results" panel underneath.

## Run-it-yourself Python cells (Pyodide, in the browser)
Five live cells: ADF on factor returns vs the cumulative index · factor premium summary table ·
spanning regressions (HML redundancy) · two GRS tests (scipy.stats.f) · the full robustness table
(pre/post 1991 and annual vs monthly).

## Code (`code/`)
| File | Language | Run |
|---|---|---|
| `lecture06.py` | Python | `python lecture06.py` (pandas, statsmodels, scipy) - verified exit 0 |
| `lecture06.R` | R | `Rscript lecture06.R` (base R only; see tidy-finance.org chapter and the FamaFrench2015FF5 GitHub package for full factor replication) |
| `lecture06.do` | Stata | `do lecture06.do` (GRS via user-written `grstest2`, ssc install) |
| `lecture06.prg` | EViews | open + Run (GRS built with matrix algebra; no native command) |

All scripts: load factors -> summary statistics and correlations -> spanning regressions
(each factor on the other four) -> GRS tests (RMW+CMA vs FF3; HML vs the four-factor model) ->
robustness (pre/post 1991 split; annual factors). Run from inside `code/`
(data paths are relative: `../../../data/csv/`).

## Headline numbers (our sample, T = 710)
- Premiums %/month: Mkt-RF 0.56 (t = 3.32), SMB 0.23 (2.00), HML 0.30 (2.68), RMW 0.27 (3.28), CMA 0.28 (3.71)
- HML spanning alpha **-0.090 (t = -1.07)**, CMA slope 1.04 (t = 24.3): HML redundant (paper: -0.04, t = -0.47)
- RMW spanning alpha 0.404 (t = 5.18); CMA 0.267 (t = 4.97): not redundant
- GRS: RMW+CMA vs FF3 = 21.72 (p = 7e-10, reject); HML vs four-factor = 1.13 (p = 0.29, cannot reject)
- Robustness: HML spanning alpha +0.21 (t = 2.15) pre-1991, **-0.31 (t = -2.45)** post-1991 - the
  redundancy verdict is sample specific, exactly as the paper cautions

`data_ff5.js` embeds the monthly factor series (rounded to 2 dp) for the canvas simulations.
