' ===========================================================================
' MANG3095 Advanced Financial Econometrics - Week 10
' Replicating a banking panel: Gopal and Schnabl (2022, RFS 35(11), 4859-4901)
' "The Rise of Finance Companies and FinTech Lenders in Small Business Lending"
' ===========================================================================
' HONEST NOTE ON EVIEWS AND THIS WORKFLOW
' The paper's replication package is a pure Stata pipeline (run_file.do ->
' data_creation.do -> figures_and_tables.do) built around loan-level text
' files, fuzzy name merges, reshape/collapse steps and reghdfe with
' multi-way clustering. That data-engineering layer lives OUTSIDE EViews:
' EViews has no native equivalent of merge m:1 on string keys at the
' 11-million-row scale, no reghdfe, and no two-way (county AND industry)
' clustered covariance. Researchers who estimate this paper's tables do so
' in Stata, R (fixest) or Python (statsmodels/linearmodels/pyfixest).
'
' What EViews CAN do well is the panel-methods core of this week:
' a dated panel workfile, cross-section fixed effects, period fixed
' effects, and one-way cluster-robust ("White cross-section") SEs.
' The program below builds the same synthetic county-year teaching panel
' and estimates the pooled / FE / two-way FE comparison.
' ===========================================================================

' --- 1. synthetic county-year panel: 200 counties, 2007-2016 --------------
wfcreate(wf=week10, page=panel) a(2007, 2016) 200
rndseed 42

' county-level confounder and treatment (constant within cross-section)
series bank_share_06 = 0.476 + 0.130*@qnorm(rnd)
' hold county-level draws fixed across the ten years of each county:
series bank_share_06 = @meansby(bank_share_06, @crossid)
series alpha_c = -2.5*(bank_share_06 - @mean(bank_share_06)) + 0.60*@qnorm(rnd)
series alpha_c = @meansby(alpha_c, @crossid)

' staggered closures from 2010-2013, more likely where bank share is high
series close_prob = 0.15 + 0.55*(bank_share_06 - 0.2)/0.6
series treat_draw = rnd
series treat_draw = @meansby(treat_draw, @crossid)
series treat_year = 2010 + @floor(4*@meansby(rnd, @crossid))
series closure = (treat_draw < close_prob) and (@year >= treat_year)

' outcome: ln(county small business loans), true closure effect -1.50
series ln_loans = 6.0 - 1.50*closure + alpha_c + 0.02*(@year-2007) _
    + 0.35*@qnorm(rnd)

' --- 2. pooled OLS vs fixed effects vs two-way FE --------------------------
' pooled OLS with cluster-robust (White cross-section) SEs: biased upward
equation eq_pooled.ls(cov=cxwhite) ln_loans c closure

' county (cross-section) fixed effects: the within estimator
equation eq_fe.ls(cx=f, cov=cxwhite) ln_loans c closure

' two-way FE: cross-section AND period fixed effects
equation eq_2wfe.ls(cx=f, per=f, cov=cxwhite) ln_loans c closure

show eq_pooled
show eq_fe
show eq_2wfe
' expected: pooled about -1.7 (biased); FE and two-way FE about -1.5 (truth)

' --- 3. the long-difference cross-section ----------------------------------
' The paper's Table 4 is a COUNTY CROSS-SECTION (one long difference per
' county) with state FE. In EViews you would collapse the panel to a
' cross-section workfile page and use ls with state dummies:
'   pagecreate(page=cross) u 200
'   equation eq_ld.ls d_nonbank_share c bank_share_06 @expand(state, @dropfirst)
' County-level clustering with one observation per county equals White
' (HC) robust SEs: add (cov=white) to the ls command.

' --- what to interpret ------------------------------------------------------
' The FE comparison is the heart of the week: closures target permanently
' weak counties, so pooled OLS overstates the damage; county FE removes the
' permanent differences and recovers the truth. For the paper's full merge
' and multi-way clustering pipeline, use the Stata, R or Python versions.
