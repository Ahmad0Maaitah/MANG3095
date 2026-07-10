"""
MANG3095 Advanced Financial Econometrics - Week 10
Replicating a banking panel: Gopal and Schnabl (2022, RFS 35(11), 4859-4901),
"The Rise of Finance Companies and FinTech Lenders in Small Business Lending".

The paper's 171 MB replication dataset is NOT shipped with this unit (see README),
so everything below runs on a SYNTHETIC county-year teaching panel that mimics the
replication package's architecture: entity/time identifiers, m:1 merges on county,
long-difference cross-sections with state fixed effects, panel fixed effects via
within-demeaning, cluster-robust standard errors, an event study, and robustness.

Requires: numpy, pandas, statsmodels (all in the module's Python distribution).
Run from inside code/:  python lecture10.py   (must exit 0)
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm

rng = np.random.default_rng(42)

G, S, T0, T1 = 200, 25, 2007, 2016            # counties, states, first/last year
YEARS = np.arange(T0, T1 + 1)
T = len(YEARS)

print("=" * 72)
print("1. BUILD THE SYNTHETIC COUNTY-YEAR TEACHING PANEL")
print("=" * 72)

# --- county-level frame (like pre_crisis_bank_share_county_baseline.dta) -----
county = pd.DataFrame({
    "county": np.arange(1001, 1001 + G),               # FIPS-style entity id
    "state":  np.repeat(np.arange(1, S + 1), G // S),  # 8 counties per state
})
# pre-crisis bank share, calibrated to the paper: mean .476, sd .130 (Table 3)
county["bank_share_06"] = np.clip(rng.normal(0.476, 0.130, G), 0.05, 0.95)
# unobserved county quality: counties with more banks are also 'weaker' counties
alpha_c = -2.5 * (county["bank_share_06"] - county["bank_share_06"].mean()) \
          + rng.normal(0, 0.60, G)
county["alpha_c"] = alpha_c

# --- county-year panel (like county_lending.dta) -----------------------------
panel = county.loc[county.index.repeat(T)].reset_index(drop=True)
panel["year"] = np.tile(YEARS, G)

# branch closures: more likely in high-bank-share (weak alpha) counties after 2009
close_prob = 0.15 + 0.55 * (panel["bank_share_06"] - 0.2) / 0.6
treated_from = {}
for c, p in zip(county["county"], close_prob[::T]):
    treated_from[c] = rng.choice(np.arange(2010, 2014)) if rng.random() < p else 9999
panel["closure"] = (panel["year"] >= panel["county"].map(treated_from)).astype(int)

# outcome: ln(county small business loans), two-way error components
delta_t = {y: v for y, v in zip(YEARS, np.cumsum(rng.normal(0.02, 0.05, T)))}
BETA_TRUE = -1.50
panel["ln_loans"] = (6.0 + BETA_TRUE * panel["closure"]
                     + panel["alpha_c"] + panel["year"].map(delta_t)
                     + rng.normal(0, 0.35, G * T))

n_treat = int((pd.Series(treated_from).ne(9999)).sum())
print(f"counties = {G}  states = {S}  years = {T0}-{T1}  N = {len(panel)}")
counts = panel.groupby("county").size()
print(f"balanced: {counts.min() == counts.max()} "
      f"(every county observed {counts.min()} times)  |  ever-treated counties: {n_treat}")
print(panel[["county", "state", "year", "bank_share_06", "closure", "ln_loans"]]
      .head(4).to_string(index=False))

print()
print("=" * 72)
print("2. WHY THE PAPER NEEDS FIXED EFFECTS (pooled vs FE vs two-way FE)")
print("=" * 72)

y = panel["ln_loans"].to_numpy()
d = panel["closure"].to_numpy().astype(float)

def ols_beta_se(yv, Xv, groups=None):
    X = sm.add_constant(Xv)
    fit = sm.OLS(yv, X).fit()
    if groups is not None:
        fit = fit.get_robustcov_results(cov_type="cluster", groups=groups)
    return fit.params[1], fit.bse[1]

# pooled OLS
b_pool, se_pool = ols_beta_se(y, d, panel["county"])
# county FE via within-demeaning
def demean(v, by):
    return v - pd.Series(v).groupby(np.asarray(by)).transform("mean").to_numpy()
y_c = demean(y, panel["county"]); d_c = demean(d, panel["county"])
b_fe, se_fe = ols_beta_se(y_c, d_c, panel["county"])
# two-way FE: demean by county, then by year, then re-add grand means (small panel: exact enough)
y_2w = demean(demean(y, panel["county"]), panel["year"])
d_2w = demean(demean(d, panel["county"]), panel["year"])
b_2w, se_2w = ols_beta_se(y_2w, d_2w, panel["county"])

print(f"true closure effect on ln(loans): {BETA_TRUE:+.2f}")
print(f"pooled OLS          : {b_pool:+.3f}  (cluster se {se_pool:.3f})   <- biased")
print(f"county FE (within)  : {b_fe:+.3f}  (cluster se {se_fe:.3f})")
print(f"two-way FE          : {b_2w:+.3f}  (cluster se {se_2w:.3f})")
print("closures hit low-alpha counties, so pooled OLS blames the closure for")
print("what is really a permanent county difference; FE removes it.")

print()
print("=" * 72)
print("3. GOPAL-SCHNABL LONG DIFFERENCE (their Table 4, eq. (1), synthetic)")
print("=" * 72)

# cross-section: change in nonbank market share 2007-2016 on bank share 2006
# (own generator so the deck's browser cell can reproduce these numbers exactly)
GAMMA_TRUE = 0.212                             # paper's headline coefficient
rng3 = np.random.default_rng(300)
state_fe = rng3.normal(0, 0.02, S)
cs = county.copy()
cs["d_nonbank_share"] = (GAMMA_TRUE * cs["bank_share_06"]
                         + state_fe[cs["state"] - 1]
                         + rng3.normal(0, 0.05, G))
# absorb state FE by within-state demeaning, then OLS with county-clustered SEs
ys = demean(cs["d_nonbank_share"].to_numpy(), cs["state"])
xs = demean(cs["bank_share_06"].to_numpy(), cs["state"])
g_hat, g_se = ols_beta_se(ys, xs, cs["county"])
p10, p90 = np.percentile(cs["bank_share_06"], [10, 90])
print("Delta(nonbank share)_c 07-16 = a_s + gamma * BankShare_06,c + e_c")
print(f"gamma_hat = {g_hat:.3f}  (se {g_se:.3f})     paper: 0.212 (0.024)")
print(f"10th->90th pct of bank share ({p10:.3f} -> {p90:.3f}) moves the nonbank")
print(f"market share by {g_hat * (p90 - p10) * 100:+.1f} pp    paper: +6.9 pp")

print()
print("=" * 72)
print("4. CLUSTERED STANDARD ERRORS (county-level shocks, Moulton problem)")
print("=" * 72)

def one_draw(rg, Gc=40, Tc=8, icc=0.5, beta=0.0):
    """county-level regressor, errors with within-county correlation icc"""
    x_c = rg.normal(0, 1, Gc)
    u = (np.sqrt(icc) * np.repeat(rg.normal(0, 1, Gc), Tc)
         + np.sqrt(1 - icc) * rg.normal(0, 1, Gc * Tc))
    yv = beta * np.repeat(x_c, Tc) + u
    xv = np.repeat(x_c, Tc)
    ids = np.repeat(np.arange(Gc), Tc)
    return yv, xv, ids

yv, xv, ids = one_draw(np.random.default_rng(7))
fit = sm.OLS(yv, sm.add_constant(xv)).fit()
se_naive = fit.bse[1]
se_clust = fit.get_robustcov_results(cov_type="cluster", groups=ids).bse[1]
print(f"single draw (G=40 counties, T=8 years, icc=0.5, true beta=0):")
print(f"  naive OLS se = {se_naive:.4f}   cluster-robust se = {se_clust:.4f}"
      f"   ratio = {se_clust / se_naive:.2f}")

# Monte Carlo false rejection rates at the 5% level (fast closed-form OLS)
REPS = 1000
rej_naive = rej_clust = 0
mc = np.random.default_rng(2024)
for _ in range(REPS):
    yv, xv, ids = one_draw(mc)
    n = len(yv)
    xd = xv - xv.mean()
    b = (xd @ (yv - yv.mean())) / (xd @ xd)
    e = (yv - yv.mean()) - b * xd
    se_n = np.sqrt((e @ e) / (n - 2) / (xd @ xd))
    # cluster-robust (CR0 with G/(G-1) small-sample factor)
    scores = np.array([xd[ids == g] @ e[ids == g] for g in range(40)])
    se_c = np.sqrt((scores @ scores) / (xd @ xd) ** 2 * 40 / 39)
    rej_naive += abs(b / se_n) > 1.96
    rej_clust += abs(b / se_c) > 2.02          # t(39) 5% critical value
print(f"Monte Carlo, {REPS} draws, H0 true (beta = 0), nominal size 5%:")
print(f"  naive OLS rejects H0        : {100 * rej_naive / REPS:.1f}% of the time")
print(f"  cluster-robust rejects H0   : {100 * rej_clust / REPS:.1f}% of the time")
print("ignoring within-county correlation makes t-stats look 2x too good;")
print("this is why every table in the paper clusters at the county level.")

print()
print("=" * 72)
print("5. EVENT STUDY AROUND STAGGERED CLOSURES (parallel trends)")
print("=" * 72)

ev = panel[panel["county"].map(treated_from) != 9999].copy()
ev["etime"] = ev["year"] - ev["county"].map(treated_from)
ev = ev[(ev["etime"] >= -3) & (ev["etime"] <= 3)]
# two-way demeaned outcome regressed on event-time dummies (omit t = -1)
y_ev = demean(demean(panel["ln_loans"].to_numpy(), panel["county"]), panel["year"])
panel["_y2w"] = y_ev
ev = ev.join(panel["_y2w"], rsuffix="_")
means = ev.groupby("etime")["_y2w"].mean()
base = means.loc[-1]
print("event time :  " + "  ".join(f"{k:+d}" for k in means.index))
print("coefficient:  " + "  ".join(f"{v - base:+.2f}" for v in means.values))
print("pre-event coefficients sit near zero (parallel trends); the outcome")
print(f"drops by about {abs(means.loc[1] - base):.1f} log points after closure and stays down.")

print()
print("=" * 72)
print("6. ROBUSTNESS: FE STRUCTURE, CLUSTERING LEVEL, LEAVE-ONE-STATE-OUT")
print("=" * 72)

# (a) alternative FE structures for the closure effect
print("closure effect under alternative FE structures:")
print(f"  no FE (pooled)        {b_pool:+.3f}")
print(f"  county FE             {b_fe:+.3f}")
print(f"  county + year FE      {b_2w:+.3f}   (truth {BETA_TRUE:+.2f})")

# (b) alternative clustering levels for the long-difference gamma
X = sm.add_constant(xs)
base_fit = sm.OLS(ys, X).fit()
se_none = base_fit.bse[1]
se_cty = base_fit.get_robustcov_results(cov_type="cluster",
                                        groups=cs["county"]).bse[1]
se_state = base_fit.get_robustcov_results(cov_type="cluster",
                                          groups=cs["state"]).bse[1]
print(f"long-difference gamma = {g_hat:.3f}; se by clustering level:")
print(f"  none (iid)   {se_none:.4f}")
print(f"  county       {se_cty:.4f}   (paper's choice; here 1 obs per county)")
print(f"  state        {se_state:.4f}   (coarser: only {S} clusters)")

# (c) leave-one-state-out: is gamma driven by any single state?
gammas = []
for s in range(1, S + 1):
    m = cs["state"] != s
    yl = demean(cs.loc[m, "d_nonbank_share"].to_numpy(), cs.loc[m, "state"])
    xl = demean(cs.loc[m, "bank_share_06"].to_numpy(), cs.loc[m, "state"])
    gammas.append(sm.OLS(yl, sm.add_constant(xl)).fit().params[1])
print(f"leave-one-state-out gamma: min {min(gammas):.3f}, max {max(gammas):.3f}"
      f"  (full sample {g_hat:.3f}) -> no single state drives the result")

print()
print("Done. This synthetic panel reproduces the paper's METHODS, not its data:")
print("the published numbers quoted in the deck come from the article itself.")
