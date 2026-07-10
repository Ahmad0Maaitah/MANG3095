* =============================================================
* MANG3095 - Week 7: Volatility spillovers (Diebold & Yilmaz 2012)
* Stata workflow on the module FX data (EUR/GBP/JPY daily % returns)
* Run from inside lectures/lecture07/code/ (data paths are relative)
* =============================================================

* ---------- 1. Load and describe ----------
import delimited using "../../../data/csv/fx_returns.csv", clear
gen t = _n
tsset t                          // integer daily index (returns, no gaps)
summarize eur gbp jpy
* T = 7141 daily % log changes of each dollar exchange rate,
* 15dec1998 to 03jul2018; positive = the currency weakens vs USD

* ---------- 2. Stationarity (ADF with constant) ----------
dfuller eur, lags(3)
dfuller gbp, lags(3)
dfuller jpy, lags(3)
* all three statistics are around -42 against a 5% cv of -2.86:
* daily returns are emphatically stationary, so a VAR in levels of
* RETURNS is valid (never run this framework on price levels)

* ---------- 3. VAR lag order ----------
varsoc eur gbp jpy, maxlag(8)
* AIC -> 4, SBIC -> 1, HQIC -> 2; the deck's baseline is p = 2,
* with p = 1..4 kept as a robustness dimension (the paper varies 2-6)

* ---------- 4. VAR(2) and the built-in (Cholesky) FEVD ----------
var eur gbp jpy, lags(1/2)
varstable                        // all eigenvalue moduli < 1: stable VAR
irf create dy, set(dyirf, replace) step(10)
irf table fevd                   // 10-step forecast-error variance decomp.

* HONEST NOTE 1: Stata's fevd is CHOLESKY-based, so every number above
* depends on the ordering (eur gbp jpy). Demonstrate it yourself:
var jpy gbp eur, lags(1/2)
irf create dy2, set(dyirf2, replace) step(10)
irf table fevd
* Different ordering, different decomposition - this is exactly the
* problem Diebold and Yilmaz (2012) solve with the GENERALIZED FEVD
* (Koop-Pesaran-Potter 1996; Pesaran-Shin 1998), which Stata does not
* implement natively.

* HONEST NOTE 2: a community-contributed -spillover- command circulates
* for the Diebold-Yilmaz index (try: search spillover, all). Before
* using any such add-on in assessed work, read its help file and check
* whether it implements the Cholesky (DY 2009) or the generalized
* (DY 2012) decomposition, and verify one table against the R or
* Python output below.

* HONEST NOTE 3: the generalized table, the rolling total index and the
* net directional plots for this week are produced by code/lecture07.R
* (ConnectednessApproach package) and code/lecture07.py (numpy). A
* practical Stata route is to compute the index there, export it, and
* bring it back for plotting/regressions:
*   import delimited using "spillover_index.csv", clear
*   tsset window_end
*   tsline tci

* ------------------------------------------------------------------
* What to interpret: the own-share (diagonal) entries of the FEVD are
* large and the cross entries between EUR and GBP are the biggest
* off-diagonal terms, whichever ordering you use. The generalized
* full-sample total connectedness index (p = 2, H = 10) is 23.68%,
* with EUR the net transmitter (+2.45) and JPY the net receiver
* (-2.30); Cholesky totals span 15.31-16.01% across the 6 orderings.
* ------------------------------------------------------------------
