# =============================================================
# MANG3095 - Week 6: Fama and French (2015) five-factor model
# Full workflow: load Ken French factors, summary statistics,
# factor spanning regressions, GRS test, robustness checks.
# Data: ../../../data/csv/ff5_monthly.csv, ff5_annual.csv
# (monthly percent returns, July 1963 - August 2022, T = 710)
# =============================================================

import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats

FACTORS = ["Mkt-RF", "SMB", "HML", "RMW", "CMA"]

# -------------------------------------------------------------
# 1. Load the factors
# -------------------------------------------------------------
df = pd.read_csv("../../../data/csv/ff5_monthly.csv")
dfa = pd.read_csv("../../../data/csv/ff5_annual.csv")
T = len(df)
print(f"Monthly factors: {df['Date'].iloc[0]} to {df['Date'].iloc[-1]}, T = {T}")
print(f"Annual factors : {dfa['Date'].iloc[0]} to {dfa['Date'].iloc[-1]}, T = {len(dfa)}")

# The factors are already excess returns in percent per month:
# Mkt-RF is the market return minus the T-bill rate, and SMB, HML,
# RMW, CMA are long-short (zero-investment) portfolio returns.
# Only RF (the riskfree rate itself) is not an excess return.

# -------------------------------------------------------------
# 2. Summary statistics (compare with paper Table 4, Panel A)
# -------------------------------------------------------------
print("\n=== Summary statistics, monthly % ===")
print(f"{'factor':8s} {'mean':>7s} {'sd':>6s} {'t(mean)':>8s} {'ann.Sharpe':>11s}")
for f in FACTORS:
    x = df[f]
    tstat = x.mean() / (x.std() / np.sqrt(T))
    sharpe = x.mean() / x.std() * np.sqrt(12)
    print(f"{f:8s} {x.mean():7.3f} {x.std():6.2f} {tstat:8.2f} {sharpe:11.2f}")

print("\n=== Factor correlations ===")
print(df[FACTORS].corr().round(2).to_string())

# -------------------------------------------------------------
# 3. Factor spanning regressions (paper Table 6):
#    regress each factor on the other four. If the intercept
#    (alpha) is zero, the factor adds nothing to the mean-
#    variance frontier spanned by the other four.
# -------------------------------------------------------------
def spanning(target, data):
    others = [f for f in FACTORS if f != target]
    m = sm.OLS(data[target], sm.add_constant(data[others])).fit()
    return m, others

print("\n=== Spanning regressions: each factor on the other four ===")
for f in FACTORS:
    m, others = spanning(f, df)
    print(f"\n{f} on {' + '.join(others)}:")
    print(f"  alpha = {m.params['const']:6.3f}  (t = {m.tvalues['const']:5.2f})   R2 = {m.rsquared:.2f}")
    for o in others:
        print(f"  {o:8s} {m.params[o]:6.3f}  (t = {m.tvalues[o]:6.2f})")

# Headline: the HML alpha is indistinguishable from zero once RMW and
# CMA are in the regression - HML is redundant (paper Section 7).

# -------------------------------------------------------------
# 4. GRS test (Gibbons, Ross and Shanken 1989)
#    Tests H0: all N intercepts are jointly zero when N test
#    assets are regressed on K factors.
# -------------------------------------------------------------
def grs_test(test_assets, factor_names, data):
    """GRS statistic and p-value. test_assets, factor_names: column lists."""
    F = data[factor_names].values                     # T x K
    Tn, K = F.shape
    N = len(test_assets)
    X = sm.add_constant(data[factor_names])
    alphas, resids = [], []
    for a in test_assets:
        m = sm.OLS(data[a], X).fit()
        alphas.append(m.params["const"])
        resids.append(m.resid.values)
    alphas = np.array(alphas)
    E = np.column_stack(resids)                       # T x N
    Sigma = E.T @ E / (Tn - K - 1)                    # residual covariance
    mu = F.mean(axis=0)
    Omega = np.cov(F.T, ddof=1)                       # factor covariance
    if Omega.ndim == 0:
        Omega = Omega.reshape(1, 1)
    quad_a = alphas @ np.linalg.solve(Sigma, alphas)
    quad_f = mu @ np.linalg.solve(Omega, mu)
    grs = (Tn - N - K) / N * quad_a / (1 + quad_f)
    p = 1 - stats.f.cdf(grs, N, Tn - N - K)
    return grs, p, alphas

print("\n=== GRS test 1: are RMW and CMA priced by the FF3 factors? ===")
g, p, al = grs_test(["RMW", "CMA"], ["Mkt-RF", "SMB", "HML"], df)
print(f"  FF3 alphas: RMW = {al[0]:.3f}, CMA = {al[1]:.3f}")
print(f"  GRS = {g:.2f}, p = {p:.2e}  -> reject: FF3 cannot price RMW and CMA")

print("\n=== GRS test 2: is HML priced by Mkt, SMB, RMW, CMA? ===")
g, p, al = grs_test(["HML"], ["Mkt-RF", "SMB", "RMW", "CMA"], df)
print(f"  four-factor alpha of HML = {al[0]:.3f}")
print(f"  GRS = {g:.2f}, p = {p:.3f}  -> cannot reject: HML is redundant")

# -------------------------------------------------------------
# 5. Robustness (a): subsample stability, split at 1991-01
# -------------------------------------------------------------
print("\n=== Robustness: pre/post 1991 split ===")
pre = df[df["Date"] < "1991-01"]
post = df[df["Date"] >= "1991-01"]
for label, d in [("pre-1991 ", pre), ("post-1991", post)]:
    print(f"\n{label} ({d['Date'].iloc[0]} to {d['Date'].iloc[-1]}, T = {len(d)})")
    for f in FACTORS:
        x = d[f]
        tstat = x.mean() / (x.std() / np.sqrt(len(d)))
        print(f"  {f:8s} mean {x.mean():6.3f} (t = {tstat:5.2f})")
    for tgt in ["HML", "RMW", "CMA"]:
        m, _ = spanning(tgt, d)
        print(f"  spanning {tgt}: alpha = {m.params['const']:6.3f} "
              f"(t = {m.tvalues['const']:5.2f}), R2 = {m.rsquared:.2f}")

# -------------------------------------------------------------
# 6. Robustness (b): annual factors vs monthly factors
# -------------------------------------------------------------
print("\n=== Robustness: annual factors (percent per year) ===")
Ta = len(dfa)
for f in FACTORS:
    x = dfa[f]
    tstat = x.mean() / (x.std() / np.sqrt(Ta))
    print(f"  {f:8s} mean {x.mean():6.2f}  sd {x.std():5.2f}  t = {tstat:5.2f}")
for tgt in ["HML", "RMW", "CMA"]:
    others = [f for f in FACTORS if f != tgt]
    m = sm.OLS(dfa[tgt], sm.add_constant(dfa[others])).fit()
    print(f"  annual spanning {tgt}: alpha = {m.params['const']:6.2f} "
          f"(t = {m.tvalues['const']:5.2f}), R2 = {m.rsquared:.2f}")

# -------------------------------------------------------------
# What to interpret:
# - Table 4 flavour: all five factor premiums are positive over the
#   full sample; CMA has the highest t-statistic, SMB the lowest.
# - Spanning: HML's four-factor alpha is around -0.09% per month with
#   |t| ~ 1.1: once RMW and CMA are included, HML adds nothing to the
#   description of average returns (FF 2015, Table 6 and Section 7).
#   RMW and CMA keep large, significant alphas: they are NOT redundant.
# - GRS: the joint test rejects FF3 against RMW+CMA overwhelmingly,
#   but cannot reject that HML's alpha is zero in the four-factor model.
# - Robustness: the redundancy result is sample specific. Pre-1991 the
#   HML spanning alpha is positive and significant (~0.21, t ~ 2.2);
#   post-1991 it is negative (~-0.31, t ~ -2.4). Annual-factor
#   regressions tell the same broad story as monthly ones.
# =============================================================
