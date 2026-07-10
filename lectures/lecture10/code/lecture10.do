*****************************************************************************
*** MANG3095 Advanced Financial Econometrics - Week 10
*** Replicating a banking panel: Gopal and Schnabl (2022, RFS 35(11), 4859-4901)
*** "The Rise of Finance Companies and FinTech Lenders in Small Business Lending"
*****************************************************************************
*** The paper's 171 MB replication dataset is NOT shipped with this unit, so
*** this do-file builds a SYNTHETIC county-year teaching panel and then walks
*** the same architecture as the paper's replication package (run_file.do ->
*** data_creation.do -> figures_and_tables.do): entity/time ids, m:1 merges,
*** long differences with state FE, panel FE, county-clustered SEs, robustness.
*** Idioms follow the package: globals, egen group, collapse, merge m:1,
*** reghdfe with absorb() and cluster().
*** User-written commands used by the package (install once):
***   ssc install reghdfe
***   ssc install winsor2
***   ssc install estout
*****************************************************************************

set more off
clear all
set seed 42

*****************************************************************************
*** 1. Build the synthetic county-year teaching panel
*****************************************************************************

// county-level frame: 200 counties in 25 states, FIPS-style ids
set obs 200
gen county = 1000 + _n
gen state  = ceil(_n/8)                        // 8 counties per state

// pre-crisis bank share, calibrated to the paper (Table 3: mean .476, sd .130)
gen bank_share_06 = max(min(rnormal(0.476, 0.130), 0.95), 0.05)

// unobserved county quality, correlated with the bank share (the confounder)
sum bank_share_06
gen alpha_c = -2.5*(bank_share_06 - r(mean)) + rnormal(0, 0.60)

// staggered branch closures: more likely where the bank share is high
gen close_prob = 0.15 + 0.55*(bank_share_06 - 0.2)/0.6
gen treat_year = 2010 + floor(4*runiform()) if runiform() < close_prob
replace treat_year = 9999 if treat_year ==.

save county_frame, replace

// expand to a balanced county x year panel, 2007-2016
expand 10
bysort county: gen year = 2006 + _n

// declare the panel: THE key step - entity id + time id (xtset = tsset for panels)
xtset county year
xtdescribe                                      // balanced: 200 counties x 10 years

// treatment indicator and outcome ln(county small business loans)
gen closure = year >= treat_year
gen delta_t = 0.02*(year-2007) + rnormal(0, 0.02)  // common year shocks
gen ln_loans = 6.0 - 1.50*closure + alpha_c + delta_t + rnormal(0, 0.35)

save county_panel, replace

*****************************************************************************
*** 2. Why the paper needs fixed effects (pooled vs FE vs two-way FE)
*****************************************************************************

// pooled OLS: biased, closures target permanently weak counties
reg ln_loans closure, cluster(county)

// county FE (the within estimator); xtreg,fe is the built-in route
xtreg ln_loans closure, fe cluster(county)

// two-way FE, the way the replication package does it everywhere:
reghdfe ln_loans closure, absorb(county year) cluster(county)

// expected: pooled about -1.68; county FE about -1.47; two-way about -1.53
// (true effect -1.50; compare code/lecture10.py output)

*****************************************************************************
*** 3. The Gopal-Schnabl long difference (their Table 4, eq. (1))
*****************************************************************************
*** The paper collapses the panel to one long difference per county and
*** regresses it on the 2006 bank share with state FE + county-clustered SEs.
*** Their exact line (figures_and_tables.do) is:
***   reghdfe share_07_16 pre_crisis_bank_share `controls' if bank==0, ///
***       abs(state) cluster(county)

use county_frame, clear

// synthetic change in nonbank market share 2007-2016 (small state shocks + noise)
gen state_shock = rnormal(0, 0.02)
bysort state (county): replace state_shock = state_shock[1]
gen d_nonbank_share = 0.212*bank_share_06 + state_shock + rnormal(0, 0.05)

reghdfe d_nonbank_share bank_share_06, absorb(state) cluster(county)

// economic size: 10th -> 90th percentile of the bank share
_pctile bank_share_06, p(10 90)
display "10-90 effect on nonbank share (pp): " %5.1f _b[bank_share_06]*(r(r2)-r(r1))*100
// paper: gamma = 0.212 (0.024); 10th->90th pct = +6.9 pp (Table 4, col 1)

*****************************************************************************
*** 4. Clustered standard errors (the Moulton problem)
*****************************************************************************

use county_panel, clear

// regressor that only varies BETWEEN counties + errors correlated WITHIN county
gen x_c = rnormal()
bysort county (year): replace x_c = x_c[1]
gen u = sqrt(0.5)*rnormal()
bysort county (year): replace u = u[1]
replace u = u + sqrt(0.5)*rnormal()
gen y_placebo = 0*x_c + u                       // true effect is ZERO

reg y_placebo x_c                                // naive: se far too small
reg y_placebo x_c, cluster(county)               // honest: about 2x larger
// with icc = 0.5 and T = 10 the naive t-stat is inflated by roughly
// sqrt(1 + (T-1)*icc) = 2.3: the Moulton factor

*****************************************************************************
*** 5. Event study around staggered closures (parallel trends)
*****************************************************************************

gen etime = year - treat_year if treat_year != 9999
gen esample = inrange(etime, -3, 3)

// event-time dummies, omitting t = -1 as the base period
forvalues k = 0/3 {
    gen post`k' = etime == `k'
    gen pre`k'  = etime == -`k'
}
drop pre0 pre1
reghdfe ln_loans pre3 pre2 post0 post1 post2 post3 if treat_year!=9999 ///
    , absorb(county year) cluster(county)
// pre coefficients near 0 (parallel trends); post about -1.3 and flat

*****************************************************************************
*** 6. Robustness: FE structure, clustering level, leave-one-state-out
*****************************************************************************

// (a) alternative FE structures
eststo clear
eststo a1: reg     ln_loans closure, cluster(county)
eststo a2: xtreg   ln_loans closure, fe cluster(county)
eststo a3: reghdfe ln_loans closure, absorb(county year) cluster(county)
esttab a1 a2 a3, b(%8.3f) se(%8.3f) mtitle("pooled" "county FE" "two-way FE")

// (b) alternative clustering levels for the long difference
use county_frame, clear
gen state_shock = rnormal(0, 0.02)
bysort state (county): replace state_shock = state_shock[1]
gen d_nonbank_share = 0.212*bank_share_06 + state_shock + rnormal(0, 0.05)
reghdfe d_nonbank_share bank_share_06, absorb(state) cluster(county)
reghdfe d_nonbank_share bank_share_06, absorb(state) cluster(state)
// with only 25 state clusters, treat state-clustered SEs with caution
// (Cameron-Miller 2015 recommend at least ~40-50 clusters)

// (c) leave-one-state-out: no single state should drive gamma
forvalues s = 1/25 {
    quietly reghdfe d_nonbank_share bank_share_06 if state != `s', absorb(state)
    display "drop state `s': gamma = " %6.3f _b[bank_share_06]
}

*****************************************************************************
*** What to interpret: FE strips out permanent county differences that the
*** treatment targets; clustering repairs SEs when shocks are shared within a
*** county; the long-difference gamma (about 0.21) matches the paper's Table 4
*** and moving from the 10th to the 90th percentile of the 2006 bank share
*** raises the nonbank market share by about 7 pp with NO effect on total
*** lending - the paper's substitution result.
*****************************************************************************
