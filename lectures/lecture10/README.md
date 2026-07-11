# Lecture 10 - Replicating a Banking Panel (panel methods week)

Interactive deck for Week 10 of MANG3095: the paper-replication unit built around
Gopal, M. and Schnabl, P. (2022) 'The rise of finance companies and FinTech lenders
in small business lending', *The Review of Financial Studies*, 35(11), pp. 4859-4901,
doi: 10.1093/rfs/hhac034. This week doubles as the module's panel-methods week.

## Objectives

- Explain the paper's question, identification strategy (county exposure to the
  nationwide 2008 bank shock via the 2006 bank share) and headline findings, and
  REPRODUCE them on the paper's own data: Table 4's 0.212***/0.534***/0.016 come
  out exactly in the preferred specification (controls + state FE, county-clustered
  SEs), and a 10th to 90th percentile move in bank share raises the nonbank market
  share by 6.8 pp with a precise null on total lending.
- Prepare panel data: entity (county FIPS) and time (year) identifiers, m:1 merges
  of multiple public sources (UCC, CBP, CRA, HMDA, LAUS, SUSB, FDIC deposits) on a
  common id, balanced vs unbalanced panels, all demonstrated on the real files.
- Estimate and interpret fixed-effects models (specification ladder, two-way FE via
  the within transformation, the real crisis event study) and cluster-robust
  standard errors (CRVE, Moulton factor, choice of clustering level).
- Read a real replication package: the run_file.do -> data_creation.do ->
  figures_and_tables.do pipeline, with verbatim excerpts from the actual do-files.

## Data (REAL, shipped in ../../data/csv/)

- `gopal_county.csv` (3,056 counties) - the paper's county cross-section, built
  from the replication package's final files (county_lending_changes_baseline +
  pre_crisis_bank_share_county_baseline + county_pre_crisis_controls, merged and
  filtered exactly as figures_and_tables.do does): 2006 bank share, 2007-2016
  changes in nonbank market share and lending growth (full period and subperiods),
  and the paper's eight controls. The analysis sample after dropping missing
  controls is 3,021 counties, matching the paper.
- `gopal_county_year.csv` (34,385 rows) - the county x year panel of UCC-filing
  loan counts by lender type (nonbank_loans, bank_loans), 2006-2016, from
  county_lending.dta.
- `data_gopal.js` (in this folder) - the 3,021-county analysis sample embedded for
  the canvas scatter (bank share vs each Table 4 outcome).

The replication package (code + public data) is supplementary material on the RFS
website next to the article. The loan-level UCC records are proprietary and are
NOT shipped; Tables 5 to 8 (loan-level and firm-level results) are quoted from the
published article. The full 2.6 GB package archive lives outside this repo.

## Verified real-data results (all reproduced by code/lecture10.py, exit 0)

- Table 4 ladder: 0.215/0.197/0.212 (share), 0.788/0.645/0.534 (nonbank growth),
  0.240/0.126/0.016 (total); preferred column = the paper exactly.
- Bank share moments: mean 0.475, sd 0.129 (paper Table 3: 0.476, 0.130);
  p10/p90 = 0.312/0.634; implied 10->90 effect +6.8 pp.
- Crisis event study (county + year FE, base 2007, 2006 excluded as the
  exposure-measurement year): 0.038 (2008), 0.016 (2009), 0.056 (2010), 0.070,
  0.112, 0.145, 0.171, 0.207, 0.217 (2016).
- SEs by clustering (preferred spec): iid 0.019, county 0.024, state 0.027.
- Subperiods: 0.073 (2007-10), 0.138 (2010-16). Leave-one-state-out: 0.199-0.229.

## Simulations and interactive elements

1. **Real Table 4 scatter** - 3,021 counties, outcome switcher (share / nonbank
   growth / total), binscatter-style bin means and the raw OLS fit.
2. **Real crisis event study** - the estimated gamma_t path with 2 SE whiskers.
3. **The fixed-effects machine** (method demo, simulated with known truth) -
   pooled vs county FE vs two-way FE under selection into treatment.
4. **The clustering machine** (method demo) - naive t-statistics across 400
   placebo panels vs N(0,1), false-rejection readouts.
5. **Event study and parallel trends** (method demo) - staggered adoption with
   adjustable pre-trend.

## pyrun cells (4, all real data unless stated)

1. Load the real county x year panel, xtset-style balance check, the package's
   m:1 merge pattern (section 2).
2. Table 4, for real: all three outcomes x three specifications; the preferred
   column prints 0.212/0.534/0.016 (section 6).
3. Naive vs clustered inference: real SEs by clustering level, then a placebo
   Monte Carlo for false-rejection rates, 35.5% vs 6.9% (section 6).
4. Robustness: real subperiods 0.073/0.138 and the 50-state leave-one-state-out
   loop, range 0.199-0.229 (section 7).

## Code files (code/)

- `lecture10.py` - full real-data workflow; runs to exit 0 and prints every number
  used in the deck (python lecture10.py).
- `lecture10.do` - the same workflow in the replication package's idioms (globals,
  merge m:1, xtset, reghdfe with absorb() and cluster(); ssc install reghdfe estout).
- `lecture10.R` - fixest/dplyr version (feols with FE and cluster arguments, i()
  event study).
- `lecture10.prg` - EViews: the Table 4 cross-section with @expand state dummies
  and White SEs, the panel page with cross-section/period FE, plus an honest note
  that the package's full pipeline (fuzzy merges, reghdfe, two-way clustering)
  lives outside EViews.
