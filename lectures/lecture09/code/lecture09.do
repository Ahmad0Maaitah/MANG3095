* ------------------------------------------------------------------
* MANG3095 Advanced Financial Econometrics - Lecture 9
* Multivariate GARCH forecasting:
* Laurent, Rombouts and Violante (2012, J. Applied Econometrics
* 27(6), 934-955), "On the forecasting accuracy of multivariate
* GARCH models".
*
* Data: ../../../data/csv/lrv_returns.csv - the paper's OWN
* estimation sample: 2,740 daily open-to-close % returns for
* 10 NYSE stocks, 2 March 1988 onwards. date_serial is a Julian
* day number.
*
* 1. Import & clean            2. Descriptives, zeros, ADF
* 3. Univariate GARCH(1,1)     4. DCC and CCC (mgarch)
* 5. Conditional correlations  6. One-step variance forecasts
* 7. Robustness: estimation window
*
* Run from this folder:  do lecture09.do
* ------------------------------------------------------------------
version 16
clear all

* 1. Import the paper's data ----------------------------------------
* The csv carries a stray text row at the end, so import as strings
* and destring; returns are already in percent.
import delimited using "../../../data/csv/lrv_returns.csv", ///
    clear stringcols(_all)
destring date_serial abt bp cl ek fdx ko wmt pep pg wye, replace force
drop if missing(date_serial)
gen t = _n
tsset t

* 2. Descriptives, zero-return days, stationarity -------------------
summarize abt-wye
foreach v of varlist ko pep pg {
    quietly count if `v' == 0
    display as text "`v': " as result r(N) " zero-return days " ///
        as text "(" %4.1f 100*r(N)/_N "%)"
}
* returns are stationary (the unit root lives in prices):
dfuller ko
dfuller pep
dfuller pg

* 3. Univariate GARCH(1,1), stock by stock --------------------------
* (the paper demeans first; arch's constant-only mean is equivalent)
foreach v of varlist ko pep pg {
    display as text _n "--- GARCH(1,1) for `v' ---"
    arch `v', arch(1) garch(1) nolog
    display as text "persistence alpha+beta = " as result ///
        %6.4f _b[ARCH:L.arch] + _b[ARCH:L.garch]
}
* expected (KO, full sample): omega ~ 0.053, alpha ~ 0.038,
* beta ~ 0.934, persistence ~ 0.972

* 4. DCC(1,1) of Engle (2002) and the CCC benchmark -----------------
* Stata's mgarch dcc IS the model in the paper's equations (5)-(7);
* lambda1 = a (news), lambda2 = b (memory).
mgarch dcc (ko pep pg = ), arch(1) garch(1) nolog
estimates store dcc
* expected (full 2,740 obs): a ~ 0.015, b ~ 0.971 (Stata's exact
* values differ slightly: it maximises the joint likelihood in one
* step, while the paper - and lecture09.py - use the two-step
* estimator with correlation targeting)

mgarch ccc (ko pep pg = ), arch(1) garch(1) nolog
estimates store ccc
lrtest dcc ccc     // is correlation dynamics worth two parameters?

* 5. Conditional correlations and (co)variances ---------------------
estimates restore dcc
predict H_*, variance      // H_ko_ko, H_pep_ko, ... in-sample
gen corr_ko_pep = H_pep_ko / sqrt(H_ko_ko * H_pep_pep)
tsline corr_ko_pep, title("DCC conditional correlation: KO-PEP") ///
    yline(0.44, lpattern(dash)) name(dcc_corr, replace)

* 6. One-step-ahead forecast ----------------------------------------
tsappend, add(1)
predict F_*, variance dynamic(2741)
list t F_ko_ko F_pep_pep F_pg_pg F_pep_ko in -1

* 7. Robustness: estimation window ----------------------------------
* shorter windows load on news (higher a), longer on memory (higher b)
mgarch dcc (ko pep pg = ) if t > 1740, arch(1) garch(1) nolog  // last 1000
mgarch dcc (ko pep pg = ) if t > 740,  arch(1) garch(1) nolog  // last 2000

* Interpretation: persistence a+b stays high across windows, so
* correlations move slowly and mean-revert; in the paper's full race
* (125 models, MCS at alpha = 0.25) DCC-type models with leverage do
* best in turbulent periods while CCC survives in calm ones. Stata
* has no MCS command; export losses and use R's MCS package.
* ------------------------------------------------------------------
