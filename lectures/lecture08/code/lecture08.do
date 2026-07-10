* =============================================================================
* MANG3095 Advanced Financial Econometrics - Lecture 8
* TVP-VAR dynamic connectedness (Antonakakis, Chatziantoniou and Gabauer 2020,
* Journal of Risk and Financial Management 13(4), 84)
*
* Data: daily EUR/GBP/JPY % log returns vs USD, Dec 1998 - Jul 2018 (T = 7141)
*
* HONEST NOTE ON STATA COVERAGE. Official Stata has no TVP-VAR (Kalman filter
* with forgetting factors) routine and -irf- reports Cholesky (orthogonalised)
* FEVDs, not the GENERALISED FEVD of Pesaran and Shin (1998) that the
* connectedness literature requires. This script therefore covers:
*   1. the data preparation and diagnostics (fully native),
*   2. a full-sample VAR(1) with Cholesky FEVDs as the nearest official
*      route, with comments on what differs,
*   3. pointers for the real thing: the authors' R package
*      ConnectednessApproach (model = "TVP-VAR"), called from the R tab /
*      lecture08.R, or a hand-coded Mata Kalman filter. Community commands
*      for Diebold-Yilmaz spillovers exist on SSC (search: spillover,
*      connectedness) but are user-written, not official.
* =============================================================================

* ---------------------------------------------------------------- 1. data
import delimited "../../../data/csv/fx_returns.csv", clear
gen day = date(date, "YMD")
format day %td
tsset day

summarize eur gbp jpy
correlate eur gbp jpy

* stationarity: all three series comfortably reject the unit root
dfuller eur, lags(5)
dfuller gbp, lags(5)
dfuller jpy, lags(5)

* weekly (5-trading-day) aggregation used by the deck's simulations:
gen grp = floor((_n - 1) / 5)
collapse (sum) eur gbp jpy (last) day, by(grp)
tsset grp

* ------------------------------------------- 2. nearest official route
* lag choice: BIC selects 1 lag, as in the paper (Table 3 notes)
varsoc eur gbp jpy, maxlag(4)

* full-sample VAR(1)
var eur gbp jpy, lags(1)

* Cholesky FEVD at horizon 10. CAUTION: unlike the generalised FEVD, these
* shares depend on the variable ordering (eur gbp jpy here). Reorder the
* -var- statement and the table changes; the generalised version does not.
irf create dy, set(dyirf, replace) step(10) replace
irf table fevd

* The Diebold-Yilmaz measures are simple sums of the (generalised) FEVD
* table: TO_i = column sum of off-diagonal shares, FROM_i = row sum,
* NET_i = TO_i - FROM_i, NPDC_ij = share(j from i) - share(i from j),
* TCI = average off-diagonal share * 100.
* A rolling version loops -var- over windows; a TVP-VAR version needs the
* Kalman filter recursions coded in Mata (see lecture08.py for the exact
* algorithm: ~40 lines of matrix algebra).

* ------------------------------------------- 3. the real thing, from R
* In R (see lecture08.R): the authors' own package.
*   library(ConnectednessApproach)
*   dca <- ConnectednessApproach(x, model = "TVP-VAR",
*            connectedness = "Time", nlag = 1, nfore = 10,
*            VAR_config = list(TVPVAR = list(kappa1 = 0.99, kappa2 = 0.96,
*                                            prior = "BayesPrior", gamma = 0.01)))
* Export dca$TABLE to csv and pull it back with -import delimited- if you
* want to post-process the connectedness table in Stata.

* WHAT TO INTERPRET: the deck's headline numbers (weekly data, kappa1 = 0.99,
* H = 10) are mean TCI = 28.44%, NET = +3.8 (EUR), +0.1 (GBP), -4.0 (JPY):
* EUR transmits, JPY receives, matching the paper's Table 3 ranking.
* =============================================================================
