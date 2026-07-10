# Week 7 · Volatility Spillovers: Diebold and Yilmaz (2012)

**Paper:** Diebold, F.X. and Yilmaz, K. (2012) 'Better to give than to receive: predictive
directional measurement of volatility spillovers', *International Journal of Forecasting*,
28(1), pp. 57-66.
**Replication reference:** the R `ConnectednessApproach` package and its DY2012 page
(gabauerdavid.github.io/ConnectednessApproach/2012DieboldYilmaz).

## Learning objectives
- What the paper asks and finds: total and directional volatility spillovers across US stock,
  bond, FX and commodity markets, 1999-2010; full-sample total index 12.6%, surging above 30%
  in the 2007-09 crisis, with stocks the big net transmitter after Lehman
- The machinery: VAR(p), the MA representation, the **generalised FEVD** (Koop-Pesaran-Potter
  1996; Pesaran-Shin 1998) and why it removes the Cholesky ordering problem
- The **connectedness table**: own shares, FROM, TO, NET and the total connectedness index
  (rows sum to 100 after the DY row normalisation)
- Rolling-window connectedness, transmitters vs receivers, and the paper's robustness
  dimensions (lag order, horizon, window length) plus subsample analysis

## Data
- `data/csv/fx_returns.csv`: EUR, GBP, JPY daily % log changes of each dollar exchange rate,
  15 Dec 1998 to 3 Jul 2018, T = 7141 (positive = the currency weakens against the USD)
- `data_fx.js`: the most recent 2000 observations (Jan 2013 to Jul 2018, values rounded to
  4 dp) embedded for the in-browser simulations
- The paper models range-based (Parkinson) volatilities; the deck teaches the identical
  machinery on returns and says so explicitly

## Embedded simulations (all driven by the real embedded data)
1. **The connectedness table, live** - VAR(p) estimated equation by equation, generalised FEVD
   at horizon H, full FROM/TO/NET/TCI table with sliders for p (1-4) and H (2-20)
2. **Rolling total spillover index** - window-length slider (100-500 days), year axis, Brexit
   vote marked, live mean/range readout
3. **Net directional spillovers** - rolling NET per currency with a time scrubber and play
   button; bars flag each currency as net transmitter or receiver
4. **Cholesky vs generalised** - toggle identification scheme and cycle all 6 orderings:
   the Cholesky total index moves (13.23-14.98% on the subsample), the generalised one never does
5. **Robustness explorer** - rolling index under three window lengths at once plus a live
   p-by-H grid of the total index

## In-browser Python cells (pyrun)
- ADF stationarity tests on the three series
- VAR lag-order selection (AIC 4, BIC 1, HQ 2)
- The full-sample generalised connectedness table (TCI = 23.68%, p = 2, H = 10)
- The rolling total index on the full sample (mean about 30%, range 11-56%)
- Subsample analysis and the p-by-H robustness grid

## Code (`code/`)
| File | Language | Notes |
|---|---|---|
| `lecture07.py` | Python | full workflow in numpy/statsmodels; runs to exit 0; source of all deck numbers |
| `lecture07.R` | R | `ConnectednessApproach` pipeline: table, rolling, NET, robustness |
| `lecture07.do` | Stata | native ADF/varsoc/VAR/Cholesky-fevd route; honest notes on the community `spillover` add-on and the missing generalised FEVD |
| `lecture07.prg` | EViews | VAR + variance decomposition route; generalised option flagged as EViews-12+ |

Run each from inside `code/` (data paths are `../../../data/csv/fx_returns.csv`).

## Key numbers (full sample, p = 2, H = 10)
- Total connectedness index: **23.68%** (paper's cross-asset-class figure: 12.6%)
- NET: EUR **+2.45** (transmitter), GBP **-0.15**, JPY **-2.30** (receiver)
- Cholesky totals across the 6 orderings: 15.31-16.01%
- Rolling w = 200: mean 30.2%, range 9.7-56.1%; pre-2008 TCI 29.25% vs 20.38% from 2008
- Lag/horizon grid p = 1-4, H = 5-20: 23.62-23.71% (flat, as in the paper's appendix)
