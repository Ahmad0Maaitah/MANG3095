* =============================================================
* MANG3095 - Week 6: Fama and French (2015) five-factor model
* Full workflow: load Ken French factors, summary statistics,
* factor spanning regressions, GRS test, robustness checks.
* Data: ../../../data/csv/ff5_monthly.csv, ff5_annual.csv
* (monthly percent returns, July 1963 - August 2022, T = 710)
* =============================================================

* ---- 1. Load the monthly factors ----------------------------
import delimited using "../../../data/csv/ff5_monthly.csv", ///
    varnames(1) case(preserve) clear
* Stata renames Mkt-RF to mktrf on import (hyphens are illegal)
capture rename MktRF mktrf
capture rename mkt_rf mktrf
gen mdate = monthly(Date, "YM")
format mdate %tm
tsset mdate

* ---- 2. Summary statistics (paper Table 4, Panel A) ----------
* Factors are already percent excess returns per month
summarize mktrf SMB HML RMW CMA
* t-statistic for each mean and the annualised Sharpe ratio
foreach v of varlist mktrf SMB HML RMW CMA {
    quietly summarize `v'
    display "`v': mean " %6.3f r(mean) "  t(mean) " ///
        %5.2f r(mean)/(r(sd)/sqrt(r(N))) ///
        "  ann. Sharpe " %5.2f r(mean)/r(sd)*sqrt(12)
}
pwcorr mktrf SMB HML RMW CMA, sig

* ---- 3. Spanning regressions (paper Table 6) -----------------
* Regress each factor on the other four. A zero intercept means
* the factor adds nothing to the frontier of the other four.
regress mktrf SMB HML RMW CMA
regress SMB mktrf HML RMW CMA
regress HML mktrf SMB RMW CMA     // headline: alpha ~ -0.09, |t| ~ 1.1
regress RMW mktrf SMB HML CMA     // alpha ~ 0.40, t ~ 5.2
regress CMA mktrf SMB HML RMW     // alpha ~ 0.27, t ~ 5.0

* ---- 4. GRS test (Gibbons, Ross and Shanken 1989) ------------
* No built-in command. The user-written grstest2 (Stata Journal)
* implements it:  ssc install grstest2
* Syntax: test assets first, factors in varlist after flist().
* GRS 1: are RMW and CMA priced by the FF3 factors?
capture noisily grstest2 RMW CMA, flist(mktrf SMB HML)
* GRS 2: is HML priced by the other four (N = 1)?
capture noisily grstest2 HML, flist(mktrf SMB RMW CMA)
* With N = 1 the GRS statistic is close to the squared intercept
* t-statistic from -regress HML mktrf SMB RMW CMA- above.

* ---- 5. Robustness: pre/post 1991 split ----------------------
regress HML mktrf SMB RMW CMA if mdate <  tm(1991m1)   // alpha ~  0.21 (t ~  2.2)
regress HML mktrf SMB RMW CMA if mdate >= tm(1991m1)   // alpha ~ -0.31 (t ~ -2.5)
regress RMW mktrf SMB HML CMA if mdate <  tm(1991m1)
regress RMW mktrf SMB HML CMA if mdate >= tm(1991m1)
regress CMA mktrf SMB HML RMW if mdate <  tm(1991m1)
regress CMA mktrf SMB HML RMW if mdate >= tm(1991m1)

* ---- 6. Robustness: annual factors ---------------------------
import delimited using "../../../data/csv/ff5_annual.csv", ///
    varnames(1) case(preserve) clear
capture rename MktRF mktrf
capture rename mkt_rf mktrf
summarize mktrf SMB HML RMW CMA
regress HML mktrf SMB RMW CMA     // annual spanning alpha ~ -3.0 (t ~ -1.8)
regress RMW mktrf SMB HML CMA
regress CMA mktrf SMB HML RMW

* What to interpret: all five premiums are positive over 1963-2022;
* HML's spanning alpha is statistically zero once RMW and CMA are in
* the model (FF 2015 Section 7: HML is redundant), while RMW and CMA
* keep alphas more than 4 SE from zero; the redundancy result flips
* sign across the 1991 split, so it is sample specific.
* =============================================================
