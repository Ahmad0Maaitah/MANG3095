# Lecture 10 - Replicating a Banking Panel (panel methods week)

Interactive deck for Week 10 of MANG3095: the paper-replication unit built around
Gopal, M. and Schnabl, P. (2022) 'The rise of finance companies and FinTech lenders
in small business lending', *The Review of Financial Studies*, 35(11), pp. 4859-4901,
doi: 10.1093/rfs/hhac034. This week doubles as the module's panel-methods week.

## Objectives

- Explain the paper's question, identification strategy (county exposure to the
  nationwide 2008 bank shock via the 2006 bank share) and headline findings, with
  the paper's own numbers (Table 4: 0.212***/0.534***/0.016; a 10th to 90th
  percentile move in bank share raises the nonbank market share by 6.9 pp with a
  precise null on total lending).
- Prepare panel data: entity (county FIPS) and time (year) identifiers, m:1 merges
  of multiple public sources (UCC, CBP, CRA, HMDA, LAUS, SUSB, FDIC deposits) on a
  common id, balanced vs unbalanced panels.
- Estimate and interpret fixed-effects models (pooled OLS vs county FE vs two-way
  FE via the within transformation) and cluster-robust standard errors (CRVE,
  Moulton factor, choice of clustering level, few-clusters caution).
- Read a real replication package: the run_file.do -> data_creation.do ->
  figures_and_tables.do pipeline, with verbatim excerpts from the actual do-files.

## IMPORTANT: missing replication dataset

The paper's replication package data (about 171 MB) did NOT download when this
unit was built; only a browser `.crdownload` stub arrived. The unit therefore
teaches the replication ARCHITECTURE and the panel METHODS on a seeded synthetic
county-year teaching panel, and says so honestly on the agenda slide. All numbers
quoted from the paper come from the published article text.

To re-download the data: the replication package (code + public data) is hosted as
supplementary material on The Review of Financial Studies website next to the
article (https://doi.org/10.1093/rfs/hhac034). The loan-level UCC data themselves
are proprietary and must be purchased from the vendor named in the package README
(Mailinglists.com, contact Becky Santaniello). The ten Stata do-files ARE available
locally under `_extracted-knowledge/Week 10/code/code/` and are quoted in the deck.

## Simulations (3, all seeded, canvas, ST./SIM. only)

1. **The fixed-effects machine** - a 10-year county panel where branch closures
   target permanently weak counties; sliders for confounding strength, FE
   dispersion, true effect and county count; compares pooled OLS, county FE and
   two-way FE bars against the truth.
2. **The clustering machine** - 400 placebo panels with a county-level regressor
   and within-county error correlation rho; histogram of naive t-statistics vs
   N(0,1) plus false-rejection rates for naive vs cluster-robust SEs and the
   Moulton factor readout.
3. **Event study around staggered closures** - event-time coefficient path from a
   two-way FE regression with +/-2 SE whiskers; sliders for effect size,
   differential pre-trend and noise; tests the parallel-trends logic.

Each simulation has a "Reading the results" panel tying it back to the paper.

## pyrun cells (4, all verified locally against code/lecture10.py)

1. Build a county x year panel with entity/time ids, xtset-style balance check and
   the package's m:1 merge pattern (section 2).
2. Pooled vs county FE vs two-way FE with county-clustered SEs: prints
   -1.684 / -1.470 / -1.532 against a true effect of -1.50 (section 6).
3. Naive vs clustered inference: single-draw SE ratio 1.84, then a 1,000-rep Monte
   Carlo giving 35.5% vs 6.9% false rejections at a nominal 5% (section 6).
4. Robustness: long-difference gamma = 0.212 (matching the paper's Table 4 value by
   calibration), SEs by clustering level (iid/county/state) and leave-one-state-out
   range 0.197 to 0.226 (section 7).

## Code files (code/)

- `lecture10.py` - full synthetic-panel workflow; runs to exit 0 and prints every
  number used in the deck (python lecture10.py).
- `lecture10.do` - the same workflow in the replication package's idioms (globals,
  collapse/reshape, merge m:1, xtset, reghdfe with absorb() and cluster();
  requires ssc install reghdfe winsor2 estout).
- `lecture10.R` - fixest/dplyr version (feols with FE and cluster arguments,
  i() event study).
- `lecture10.prg` - EViews panel workfile with cross-section/period fixed effects
  and White cross-section SEs, plus an honest note that the paper's full pipeline
  (fuzzy merges, reghdfe, two-way clustering) lives outside EViews.

## Data

No real data are shipped (see above). Everything is generated with seeded RNGs
(numpy default_rng(42)/(300)/(7)/(2024) in Python; ST.rng seeds in the browser
sims), calibrated to the paper's Table 3 moments (bank share mean 0.476, sd 0.130).
