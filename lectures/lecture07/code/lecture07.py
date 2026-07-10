# =============================================================
# MANG3095 - Week 7: Volatility spillovers (Diebold & Yilmaz 2012)
# Python workflow: VAR(p) + generalized FEVD (Pesaran-Shin) +
# Diebold-Yilmaz connectedness table, rolling index, robustness.
# Data: ../../../data/csv/fx_returns.csv (EUR/GBP/JPY daily % returns)
# Teaching-grade implementation in numpy (~60 lines of method code);
# statsmodels is used only for the ADF tests and lag-order criteria.
# =============================================================
import numpy as np
import pandas as pd
from statsmodels.tsa.stattools import adfuller
from statsmodels.tsa.api import VAR

# ---------- 1. Load the data ----------
df = pd.read_csv("../../../data/csv/fx_returns.csv", parse_dates=["date"])
names = ["EUR", "GBP", "JPY"]
X = df[names].values                      # T x N matrix of % log returns
T, N = X.shape
print(f"fx_returns: {T} obs x {N} series, {df.date.iloc[0].date()} to {df.date.iloc[-1].date()}")
print(df[names].describe().round(3).loc[["mean", "std", "min", "max"]])

# ---------- 2. Data preparation: stationarity and lag order ----------
print("\nADF unit-root tests (constant, automatic lags by AIC):")
for c in names:
    stat, p, lags, nobs, crit, _ = adfuller(df[c], regression="c", autolag="AIC")
    print(f"  {c}: ADF = {stat:8.2f}   p = {p:.4f}   (5% cv = {crit['5%']:.2f})  lags used = {lags}")

sel = VAR(X).select_order(maxlags=8)
print("\nVAR lag order selection (max 8):")
print(f"  AIC -> p = {sel.aic}   BIC -> p = {sel.bic}   HQ -> p = {sel.hqic}   FPE -> p = {sel.fpe}")

# ---------- 3. The method: VAR(p) OLS + GFEVD + spillover table ----------
def var_ols(X, p):
    """Equation-by-equation OLS of a VAR(p) with a constant.
    Returns coefficient matrices Phi (p x N x N) and residual cov Sigma."""
    T, N = X.shape
    Z = np.hstack([np.ones((T - p, 1))] + [X[p - i - 1:T - i - 1] for i in range(p)])
    Y = X[p:]
    B = np.linalg.lstsq(Z, Y, rcond=None)[0]        # (1+N*p) x N
    E = Y - Z @ B                                   # residuals
    Sigma = E.T @ E / (T - p - N * p - 1)           # df-adjusted covariance
    Phi = np.stack([B[1 + i * N:1 + (i + 1) * N].T for i in range(p)])
    return Phi, Sigma, E

def ma_coefs(Phi, H):
    """MA coefficient matrices A_0..A_{H-1} from the VAR recursion."""
    p, N = Phi.shape[0], Phi.shape[1]
    A = [np.eye(N)]
    for h in range(1, H):
        A.append(sum(Phi[i] @ A[h - 1 - i] for i in range(min(h, p))))
    return A

def gfevd(Phi, Sigma, H):
    """Generalized FEVD (Koop-Pesaran-Potter 1996; Pesaran-Shin 1998),
    row-normalized as in Diebold & Yilmaz (2012), eq. (2). Rows sum to 1."""
    N = Sigma.shape[0]
    A = ma_coefs(Phi, H)
    num = np.zeros((N, N)); den = np.zeros(N)
    for Ah in A:
        AS = Ah @ Sigma
        num += AS**2 / np.diag(Sigma)               # (e_i' A_h S e_j)^2 / s_jj
        den += np.diag(AS @ Ah.T)                   # e_i' A_h S A_h' e_i
    theta = num / den[:, None]
    return theta / theta.sum(axis=1, keepdims=True)

def chol_fevd(Phi, Sigma, H):
    """Cholesky-factor FEVD (the Diebold & Yilmaz 2009 route): ordering matters."""
    P = np.linalg.cholesky(Sigma)
    A = ma_coefs(Phi, H)
    num = sum((Ah @ P)**2 for Ah in A)
    return num / num.sum(axis=1, keepdims=True)

def spillover_table(theta):
    """FROM, TO, NET and the total connectedness index, in percent."""
    D = theta * 100
    frm = D.sum(axis=1) - np.diag(D)                # off-diagonal row sums
    to = D.sum(axis=0) - np.diag(D)                 # off-diagonal column sums
    return D, frm, to, to - frm, frm.mean()         # TCI = mean off-diag row sum

def print_table(D, frm, to, net, tci, labels):
    hdr = "          " + "".join(f"{c:>9}" for c in labels) + "     FROM"
    print(hdr)
    for i, c in enumerate(labels):
        print(f"  {c:>6}  " + "".join(f"{D[i, j]:9.2f}" for j in range(len(labels))) + f"{frm[i]:9.2f}")
    print("  TO      " + "".join(f"{v:9.2f}" for v in to))
    print("  NET     " + "".join(f"{v:+9.2f}" for v in net) + f"     TCI = {tci:.2f}%")

# ---------- 4. Full-sample connectedness table (p = 2, H = 10) ----------
p, H = 2, 10
Phi, Sigma, E = var_ols(X, p)
th = gfevd(Phi, Sigma, H)
D, frm, to, net, tci = spillover_table(th)
print(f"\nFull-sample GENERALIZED connectedness table, VAR({p}), H = {H}:")
print_table(D, frm, to, net, tci, names)
print(f"\n>>> Total connectedness index, full sample, p=2, H=10: {tci:.2f}% <<<")

# sanity check: rows of the normalized GFEVD sum to 100
assert np.allclose(D.sum(axis=1), 100)

# ---------- 5. Cholesky vs generalized: the ordering problem ----------
from itertools import permutations
print(f"\nCholesky FEVD total index under all {N}! orderings (p={p}, H={H}):")
for perm in permutations(range(N)):
    Xp = X[:, perm]
    Phi_c, Sig_c, _ = var_ols(Xp, p)
    Dc = chol_fevd(Phi_c, Sig_c, H) * 100
    tci_c = (Dc.sum() - np.trace(Dc)) / N
    print(f"  order {'-'.join(names[i] for i in perm):>13}: TCI = {tci_c:.2f}%")
print(f"  generalized (order-free)  : TCI = {tci:.2f}%")

# ---------- 6. Rolling-window total connectedness (w = 200) ----------
def rolling_tci(X, p, H, w, step=1):
    out, idx = [], []
    for s in range(0, X.shape[0] - w + 1, step):
        Phi_r, Sig_r, _ = var_ols(X[s:s + w], p)
        th_r = gfevd(Phi_r, Sig_r, H)
        out.append((th_r.sum() - np.trace(th_r)) / N * 100)
        idx.append(s + w - 1)
    return np.array(idx), np.array(out)

w = 200
idx, roll = rolling_tci(X, p, H, w, step=5)
dates = df.date.values[idx]
print(f"\nRolling total connectedness, w = {w}, p = {p}, H = {H} (every 5th day):")
print(f"  mean = {roll.mean():.1f}%   min = {roll.min():.1f}%   max = {roll.max():.1f}%")
print(f"  max reached on {pd.Timestamp(dates[roll.argmax()]).date()}")
for y in [2008, 2016]:
    m = pd.DatetimeIndex(dates).year == y
    if m.any():
        print(f"  {y}: mean {roll[m].mean():.1f}%, max {roll[m].max():.1f}%")

# ---------- 7. Robustness: lag order, horizon, window, subsamples ----------
print("\nRobustness of the full-sample TCI (the paper's Fig. A.1/A.2 theme):")
print("        " + "".join(f"   H={h:<3}" for h in [5, 10, 20]))
for pp in [1, 2, 3, 4]:
    row = []
    Phi_r, Sig_r, _ = var_ols(X, pp)
    for h in [5, 10, 20]:
        th_r = gfevd(Phi_r, Sig_r, h)
        row.append((th_r.sum() - np.trace(th_r)) / N * 100)
    print(f"  p = {pp} " + "".join(f"{v:8.2f}" for v in row))

print("\nRolling-window mean/range for different window lengths (p=2, H=10):")
for ww in [100, 200, 500]:
    _, r = rolling_tci(X, p, H, ww, step=10)
    print(f"  w = {ww:>3}: mean {r.mean():5.1f}%   range [{r.min():.1f}%, {r.max():.1f}%]")

half = T // 2
cut = int(np.searchsorted(df.date.values, np.datetime64("2008-01-01")))
print("\nSubsample analysis (p=2, H=10):")
for lab, sl in [("first half ", slice(0, half)), ("second half", slice(half, T)),
                ("pre-2008   ", slice(0, cut)), ("2008 onward", slice(cut, T))]:
    Phi_s, Sig_s, _ = var_ols(X[sl], p)
    th_s = gfevd(Phi_s, Sig_s, H)
    t_s = (th_s.sum() - np.trace(th_s)) / N * 100
    d0, d1 = df.date.iloc[sl].iloc[0].date(), df.date.iloc[sl].iloc[-1].date()
    print(f"  {lab} ({d0} to {d1}): TCI = {t_s:.2f}%")

# ---------- 8. Net directional spillovers, full sample ----------
print("\nFull-sample net directional spillovers (TO minus FROM):")
for i, c in enumerate(names):
    role = "net TRANSMITTER" if net[i] > 0 else "net RECEIVER"
    print(f"  {c}: {net[i]:+.2f} pp  -> {role}")

# ---------- what to interpret ----------
# The connectedness table parses each currency's H-step forecast error
# variance into own and cross-market shares; rows sum to 100 by the DY
# normalization. The TCI is the average cross share: for these three
# heavily-traded USD rates it is far higher than the 12.6% Diebold and
# Yilmaz report across US asset CLASSES: currencies sharing a USD base
# are much more tightly connected than stocks vs bonds vs commodities.
# The rolling index spikes in crisis episodes; NET identifies which
# currency transmits shocks (positive) and which receives them.
