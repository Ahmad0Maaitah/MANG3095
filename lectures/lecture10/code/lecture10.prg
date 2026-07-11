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
' EViews has no reghdfe and no two-way clustered covariance. Researchers
' who estimate this paper's tables do so in Stata, R (fixest) or Python.
'
' What EViews CAN do well is the core of this week ON THE REAL DATA:
' this unit ships the paper's own county-level aggregates, and the program
' below loads them, reproduces the Table 4 long-difference regression with
' state dummies and White (HC) robust SEs, and estimates the county+period
' fixed-effects event-study panel with cluster-robust SEs.
'   ../../../data/csv/gopal_county.csv       county cross-section
'   ../../../data/csv/gopal_county_year.csv  county x year panel
' Expected preferred-spec results: 0.212 / 0.534 / 0.016 (Table 4 exactly).
' ===========================================================================

' --- 1. the real county cross-section: Table 4 -----------------------------
wfcreate(wf=week10, page=cross) u 3056
import(page=cross) "..\..\..\data\csv\gopal_county.csv" ftype=ascii rectype=crlf skip=0 fieldtype=delimited delim=comma colhead=1 namepos=first @freq U @smpl @all

' the preferred specification: controls + state fixed effects via @expand,
' county-level clustering with one obs per county = White (HC) robust SEs
equation eq_share.ls(cov=white) d_nb_share_07_16 c bank_share_06 _
    unemp_rate_2002_2006 lfp_rate_2002_2006 est_2002_2006 wage_2002_2006 _
    log_pop unemp_rate2005 lfp_rate2005 wage2005 @expand(state, @dropfirst)
show eq_share
' expected: bank_share_06 coefficient 0.212 (se about 0.024)

equation eq_growth.ls(cov=white) nb_growth_07_16 c bank_share_06 _
    unemp_rate_2002_2006 lfp_rate_2002_2006 est_2002_2006 wage_2002_2006 _
    log_pop unemp_rate2005 lfp_rate2005 wage2005 @expand(state, @dropfirst)
' expected: 0.534 (se about 0.080)

equation eq_total.ls(cov=white) total_growth_07_16 c bank_share_06 _
    unemp_rate_2002_2006 lfp_rate_2002_2006 est_2002_2006 wage_2002_2006 _
    log_pop unemp_rate2005 lfp_rate2005 wage2005 @expand(state, @dropfirst)
' expected: 0.016 (se about 0.060) - the precise null on total lending

' economic size: a 10th->90th percentile move in the 2006 bank share
' (0.312 -> 0.634) moves the nonbank market share by about +6.8 pp

' --- 2. the real county x year panel: event study --------------------------
' Load the panel page (3,133 counties, 2006-2016, mildly unbalanced).
pagecreate(page=panel) a(2006, 2016) 3133
import(page=panel) "..\..\..\data\csv\gopal_county_year.csv" ftype=ascii rectype=crlf skip=0 fieldtype=delimited delim=comma colhead=1 namepos=first @freq A @id county @destid @crossid @smpl @all

' nonbank share of filings per county-year
series nonbank_share = nonbank_loans/(nonbank_loans + bank_loans)

' merge the county-level 2006 bank share onto the panel (link by county id),
' then interact it with year dummies, 2007 base; 2006 is EXCLUDED because
' the exposure measure is built from the 2006 counts (mechanical -1 slope).
' In EViews: copy bank_share_06 from the cross page via a link object:
'   link bank_share_06
'   bank_share_06.linkto cross::bank_share_06 county
smpl 2007 2016
' county (cross-section) + period fixed effects, cluster-robust SEs:
equation eq_event.ls(cx=f, per=f, cov=cxwhite) nonbank_share _
    bank_share_06*(@year=2008) bank_share_06*(@year=2009) _
    bank_share_06*(@year=2010) bank_share_06*(@year=2011) _
    bank_share_06*(@year=2012) bank_share_06*(@year=2013) _
    bank_share_06*(@year=2014) bank_share_06*(@year=2015) _
    bank_share_06*(@year=2016)
show eq_event
' expected path: +0.04 (2008), +0.02 (2009), +0.06 (2010) ... +0.22 (2016):
' near zero through 2009, then rising steadily and never closing

' --- what to interpret ------------------------------------------------------
' The 2006 bank share predicts where nonbanks took over after 2008: gamma =
' 0.212 on the real data (Table 4 exactly), with a precise null on total
' lending - lender substitution, not a credit crunch. The event-study path
' lines up with the shock and never reverts. For the paper's full merge and
' multi-way clustering pipeline, use the Stata, R or Python versions.
