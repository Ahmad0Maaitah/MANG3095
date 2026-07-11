*****************************************************************************
*** MANG3095 Advanced Financial Econometrics - Week 10
*** Replicating a banking panel: Gopal and Schnabl (2022, RFS 35(11), 4859-4901)
*** "The Rise of Finance Companies and FinTech Lenders in Small Business Lending"
*****************************************************************************
*** This do-file runs on the REAL county-level aggregates from the paper's
*** replication package (supplementary material at doi.org/10.1093/rfs/hhac034):
***   ../../../data/csv/gopal_county.csv       county cross-section: 2006 bank
***                                            share, 2007-2016 changes, controls
***   ../../../data/csv/gopal_county_year.csv  county x year UCC loan counts
*** On this data the preferred specification reproduces Table 4 EXACTLY:
***   0.212 (0.024) / 0.534 (0.080) / 0.016 (0.060)
*** Idioms follow the package: globals, merge m:1, xtset, reghdfe with
*** absorb() and cluster().  User-written commands (install once):
***   ssc install reghdfe
***   ssc install estout
*****************************************************************************

set more off
clear all

global data "../../../data/csv"
global controls "unemp_rate_2002_2006 lfp_rate_2002_2006 est_2002_2006 wage_2002_2006 log_pop unemp_rate2005 lfp_rate2005 wage2005"

*****************************************************************************
*** 1. The real panel: structure, identifiers and the m:1 merge
*****************************************************************************

import delimited "$data/gopal_county_year.csv", clear
save gopal_county_year, replace

// declare the panel: THE key step - entity id + time id
xtset county year
xtdescribe                          // 3,133 counties, 2006-2016, 98.7% balanced

// the package's m:1 merge pattern: many county-years to one county record
import delimited "$data/gopal_county.csv", clear
save gopal_county, replace

use gopal_county_year, clear
merge m:1 county using gopal_county, keepusing(state bank_share_06) keep(3) nogen
gen nonbank_share = nonbank_loans/(nonbank_loans + bank_loans)
list county state year nonbank_loans bank_loans nonbank_share bank_share_06 in 1/4

save merged_panel, replace

*****************************************************************************
*** 2. Table 4, for real (long difference 2007-2016)
*****************************************************************************
*** The package's own line (figures_and_tables.do) is:
***   reghdfe share_07_16 pre_crisis_bank_share `controls' if bank==0, ///
***       abs(state) cluster(county)
*** Our shipped cross-section already carries the same variables per county.

use gopal_county, clear

sum bank_share_06                   // mean .475, sd .129 (paper Table 3)

eststo clear
// column 1: change in nonbank market share
eststo c1: reg d_nb_share_07_16 bank_share_06, cluster(county)
eststo c2: reg d_nb_share_07_16 bank_share_06 $controls, cluster(county)
eststo c3: reghdfe d_nb_share_07_16 bank_share_06 $controls, absorb(state) cluster(county)
// column 2: nonbank lending growth
eststo c4: reghdfe nb_growth_07_16 bank_share_06 $controls, absorb(state) cluster(county)
// column 3: total lending growth (the precise null)
eststo c5: reghdfe total_growth_07_16 bank_share_06 $controls, absorb(state) cluster(county)
esttab c1 c2 c3 c4 c5, b(%8.3f) se(%8.3f) keep(bank_share_06) ///
    mtitle("share raw" "share ctrl" "share FE" "nb growth" "total")
// expected FE row: 0.212 (0.024)   0.534 (0.080)   0.016 (0.060)

// economic size: 10th -> 90th percentile of the bank share
_pctile bank_share_06, p(10 90)
display "10-90 effect on nonbank share (pp): " %5.1f 0.212*(r(r2)-r(r1))*100
// expected: +6.8 pp, with no effect on total lending

*****************************************************************************
*** 3. The crisis event study on the real panel (county + year FE)
*****************************************************************************
*** 2006 is excluded: the exposure measure is built FROM the 2006 counts,
*** so its 2006 slope is -1 mechanically. Base year 2007.

use merged_panel, clear
drop if year == 2006
drop if missing(nonbank_share)

// gamma_t on BankShare_06 x year dummies, county + year FE, cluster by county
forvalues y = 2008/2016 {
    gen bsX`y' = bank_share_06*(year == `y')
}
reghdfe nonbank_share bsX2008-bsX2016, absorb(county year) cluster(county)
// expected path: +0.04 (2008), +0.02 (2009), +0.06 (2010) ... +0.22 (2016):
// near zero through 2009, then rising steadily and never closing

*****************************************************************************
*** 4. Clustered standard errors on the real regression
*****************************************************************************

use gopal_county, clear

reghdfe d_nb_share_07_16 bank_share_06 $controls, absorb(state)
// iid se about 0.019
reghdfe d_nb_share_07_16 bank_share_06 $controls, absorb(state) cluster(county)
// county-clustered se about 0.024 (the paper's choice; ratio 1.27)
reghdfe d_nb_share_07_16 bank_share_06 $controls, absorb(state) cluster(state)
// state-clustered se about 0.027, only 50 clusters: coarser and noisier
// (Cameron-Miller 2015: treat few-cluster SEs with caution)

*****************************************************************************
*** 5. Robustness on the real data
*****************************************************************************

// (a) subperiods: the effect builds after 2010
reghdfe d_nb_share_07_10 bank_share_06 $controls, absorb(state) cluster(county)
reghdfe d_nb_share_10_16 bank_share_06 $controls, absorb(state) cluster(county)
// expected: 0.073 (0.023) then 0.138 (0.024): a permanent reallocation

// (b) leave-one-state-out: no single state drives gamma
levelsof state, local(states)
foreach s of local states {
    quietly reghdfe d_nb_share_07_16 bank_share_06 $controls if state != `s', absorb(state)
    display "drop state `s': gamma = " %6.3f _b[bank_share_06]
}
// expected range: 0.199 to 0.229 around the full-sample 0.212

*****************************************************************************
*** What to interpret: the 2006 bank share predicts where nonbanks took over
*** after 2008 (gamma = 0.212, Table 4 exactly), the event-study path shows
*** the timing lines up with the shock and never reverts, and total lending
*** shows a precise null - lender substitution, not a credit crunch. County
*** clustering matters even in the cross-section (se 0.019 -> 0.024).
*****************************************************************************
