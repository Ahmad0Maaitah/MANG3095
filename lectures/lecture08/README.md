# Lecture 8 - TVP-VAR dynamic connectedness (paper week)

Interactive unit for **Antonakakis, N., Chatziantoniou, I. and Gabauer, D. (2020) 'Refined
measures of dynamic connectedness based on time-varying parameter vector autoregressions',
*Journal of Risk and Financial Management*, 13(4), 84.**

## Objectives
- Explain why replacing the rolling-window VAR with a TVP-VAR refines the Diebold-Yilmaz
  connectedness measures (accuracy, outlier robustness, no window choice, no observation loss).
- Estimate a forgetting-factor Kalman filter TVP-VAR(1) and compute the generalised FEVD,
  the total connectedness index, and the TO/FROM/NET/NPDC measures at every point in time.
- Reproduce the paper's headline comparison (TVP vs rolling windows) and its
  transmitter/receiver ranking on real EUR/GBP/JPY data.
- Run the paper's robustness dimensions (forgetting factor, horizon, lag order, subsamples)
  and judge whether the conclusions survive.

## Data
- `data/csv/fx_returns.csv`: daily EUR/GBP/JPY % log returns vs USD, 15 Dec 1998 to
  3 Jul 2018, T = 7141. Essentially the paper's setting (the paper uses monthly
  EUR/GBP/CHF/JPY vs USD, Feb 1975 - Jan 2019).
- `data_fx.js`: decimated copy embedded for the canvas simulations - weekly log returns
  (non-overlapping 5-trading-day sums, values rounded to 4 dp), T = 1428, with week-end
  dates and fractional-year x-coordinates.

## Simulations (all seeded/deterministic, driven by the real embedded data)
1. **TVP-VAR dynamic total connectedness, live** - full forgetting-factor Kalman filter +
   1427 GFEVDs per redraw; sliders for kappa1 (0.97-1.00), kappa2, and horizon H.
2. **Rolling-window vs TVP-VAR** - Week 7's rolling index (window slider, 26-520 weeks)
   overlaid on the TVP index; shows observation loss and the overreact/oversmooth trade-off.
3. **Net directional connectedness** - per-currency net transmitter/receiver paths with a
   time scrubber and episode buttons (Lehman, GFC trough, Brexit vote).
4. **Pairwise network snapshot** - 3-node diagram; arrow widths = |NPDC| at the scrubbed
   date, node size/colour = NET position.
5. **Robustness overlay** - TCI paths for kappa1 = 0.97/0.99/1.00 and H = 5/10/20.

## Runnable Python cells (pyrun, in-browser)
- Section 2: descriptives + ADF stationarity tests on the daily returns.
- Section 5: full TVP-VAR total connectedness index (reproduces mean TCI = 28.44%,
  min 13.98%, max 53.17%); averaged connectedness table with TO/FROM/NET.
- Section 6: robustness reruns (kappa1, H, VAR lag p = 2, subsample halves).

## Code files (`code/`)
- `lecture08.py` - full numpy workflow: data prep, ADF, weekly aggregation, forgetting-factor
  Kalman TVP-VAR + GFEVD, connectedness table, rolling comparison, robustness table, daily
  full-sample run. Verified: exits 0; its printed numbers are the ones quoted in the deck.
- `lecture08.R` - the authors' package `ConnectednessApproach` with `model = "TVP-VAR"`
  (kappa1 = 0.99, kappa2 = 0.96, nlag = 1, nfore = 10), plots, rolling comparison,
  robustness loop, and the paper's own `data(acg2020)` replication call.
- `lecture08.do` - Stata: data prep and diagnostics natively; honest note that official
  Stata has no TVP-VAR/generalised-FEVD route (Cholesky FEVD shown as nearest official
  route; R recommended for the method itself).
- `lecture08.prg` - EViews: data prep, VAR with generalised variance decomposition (native),
  rolling loop sketch; honest note that no multivariate forgetting-factor Kalman filter exists.

## Headline numbers (weekly data, kappa1 = 0.99, kappa2 = 0.96, H = 10)
- Mean dynamic total connectedness **28.44%** (JS simulation and Python agree; daily
  full sample: 31.45%). Peak 53.17% (June 2006), trough 13.98% (March 2009).
- NET: EUR +3.8 (transmitter in 89% of weeks), GBP +0.1, JPY -4.0 (receiver in 99%).
- Pairwise dominance EUR > GBP > JPY, matching the paper's Table 3.
- Rolling VAR (w = 100): mean 28.19%, correlation 0.81 with the TVP index, 99 obs lost.
