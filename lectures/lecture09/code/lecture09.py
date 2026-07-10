# =====================================================================
# MANG3095 Advanced Financial Econometrics - Lecture 9
# Multivariate GARCH forecasting: Laurent, Rombouts and Violante (2012),
# "On the forecasting accuracy of multivariate GARCH models",
# Journal of Applied Econometrics 27(6), 934-955.
#
# Data: lrv_returns.csv - the paper's OWN estimation sample (readme by
# J. Rombouts): daily open-to-close % returns for 10 NYSE stocks,
# 2 March 1988 to 31 March 1999, 2740 observations. Column date_serial
# is a Julian day number.
#
# Workflow: descriptives -> stationarity -> univariate GARCH(1,1) by
# scipy MLE for each stock -> two-step DCC(1,1) (Engle 2002) with
# correlation targeting on a 3-stock subset (KO, PEP, PG) and on all
# 10 stocks -> CCC vs DCC vs EWMA one-step covariance forecast race ->
# robustness: horizon (1/5/20 days), estimation window, subsamples.
# =====================================================================
import numpy as np
import pandas as pd
from scipy.optimize import minimize
from statsmodels.tsa.stattools import adfuller

np.set_printoptions(precision=4, suppress=True)
pd.set_option("display.width", 120)

# ---------------------------------------------------------------------
# 1. Load the paper's estimation sample and describe it
# ---------------------------------------------------------------------
df = pd.read_csv("../../../data/csv/lrv_returns.csv")
df = df.apply(pd.to_numeric, errors="coerce").dropna()   # drop a stray text row
df = df.reset_index(drop=True)
dates = pd.to_datetime(df["date_serial"], unit="D", origin="julian")
tickers = [c for c in df.columns if c != "date_serial"]
R = df[tickers].values  # T x 10, daily open-to-close returns in %
T, N = R.shape
print("=" * 72)
print("LRV (2012) estimation sample: %d obs x %d stocks, %s to %s"
      % (T, N, dates.iloc[0].date(), dates.iloc[-1].date()))
print("=" * 72)

desc = pd.DataFrame({
    "mean": R.mean(0), "sd": R.std(0, ddof=1),
    "min": R.min(0), "max": R.max(0),
    "skew": pd.DataFrame(R).skew().values,
    "exc.kurt": pd.DataFrame(R).kurt().values,
    "zero days %": (R == 0).mean(0) * 100}, index=tickers)
print(desc.round(3))

# ---------------------------------------------------------------------
# 2. Stationarity: ADF on the return series (levels of returns)
# ---------------------------------------------------------------------
print("\nADF unit-root tests on the returns (constant, auto lags by AIC):")
for tk in ["KO", "PEP", "PG"]:
    stat, p, lags, nobs, crit, _ = adfuller(df[tk].values, autolag="AIC")
    print("  %-4s ADF = %8.2f  p = %.4f  (lags used %d)" % (tk, stat, p, lags))

# ---------------------------------------------------------------------
# 3. Univariate GARCH(1,1) by scipy MLE for each stock
#    (the arch package gives near-identical answers; scipy keeps the
#     code identical to what runs in the browser cells)
# ---------------------------------------------------------------------
def garch11_negll(theta, e):
    omega, alpha, beta = theta
    s2 = np.empty(len(e))
    s2[0] = e.var()
    for t in range(1, len(e)):
        s2[t] = omega + alpha * e[t - 1] ** 2 + beta * s2[t - 1]
    return 0.5 * np.sum(np.log(2 * np.pi) + np.log(s2) + e ** 2 / s2)

def fit_garch11(e):
    best = None
    for x0 in ([0.05, 0.05, 0.90], [0.10, 0.10, 0.80]):
        opt = minimize(garch11_negll, x0=x0, args=(e,), method="L-BFGS-B",
                       bounds=[(1e-6, None), (1e-6, 0.999), (1e-6, 0.999)])
        if best is None or opt.fun < best.fun:
            best = opt
    return best.x, -best.fun

def garch11_filter(e, omega, alpha, beta):
    s2 = np.empty(len(e))
    s2[0] = e.var()
    for t in range(1, len(e)):
        s2[t] = omega + alpha * e[t - 1] ** 2 + beta * s2[t - 1]
    return s2

print("\nUnivariate GARCH(1,1), scipy MLE, demeaned returns, full sample:")
print("  %-4s %8s %8s %8s %8s" % ("", "omega", "alpha", "beta", "a+b"))
E = R - R.mean(0)  # the paper subtracts unconditional means before estimation
upars = {}
for i, tk in enumerate(tickers):
    (o, a, b), ll = fit_garch11(E[:, i])
    upars[tk] = (o, a, b)
    print("  %-4s %8.4f %8.4f %8.4f %8.4f" % (tk, o, a, b, a + b))

# ---------------------------------------------------------------------
# 4. Two-step DCC(1,1) of Engle (2002), correlation targeting
# ---------------------------------------------------------------------
def dcc_negll(theta, U, Qbar):
    a, b = theta
    if a < 0 or b < 0 or a + b >= 0.9999:
        return 1e10
    Tn, n = U.shape
    Q = Qbar.copy()
    ll = 0.0
    for t in range(Tn):
        if t > 0:
            u = U[t - 1][:, None]
            Q = (1 - a - b) * Qbar + a * (u @ u.T) + b * Q
        d = np.sqrt(np.diag(Q))
        Rt = Q / np.outer(d, d)
        sign, logdet = np.linalg.slogdet(Rt)
        Ri = np.linalg.inv(Rt)
        ll += -0.5 * (logdet + U[t] @ Ri @ U[t] - U[t] @ U[t])
    return -ll

def fit_dcc_ab(U, Qbar):
    """(a, b) MLE with several starting values (the surface is flat)."""
    best = None
    for x0 in ([0.02, 0.95], [0.05, 0.90], [0.01, 0.80]):
        opt = minimize(dcc_negll, x0=x0, args=(U, Qbar), method="Nelder-Mead",
                       options={"xatol": 1e-5, "fatol": 1e-6, "maxiter": 400})
        if best is None or opt.fun < best.fun:
            best = opt
    return best

def fit_dcc(E3, verbose_name=""):
    """Two-step DCC: univariate GARCH(1,1) filters, then (a,b) MLE."""
    Tn, n = E3.shape
    U = np.empty_like(E3)
    pars = []
    for i in range(n):
        (o, a, b), _ = fit_garch11(E3[:, i])
        s2 = garch11_filter(E3[:, i], o, a, b)
        U[:, i] = E3[:, i] / np.sqrt(s2)
        pars.append((o, a, b))
    Qbar = (U.T @ U) / Tn                      # correlation targeting
    opt = fit_dcc_ab(U, Qbar)
    a, b = opt.x
    if verbose_name:
        print("  %s: a = %.4f  b = %.4f  a+b = %.4f  (2nd-step logL = %.1f)"
              % (verbose_name, a, b, a + b, -opt.fun))
    return a, b, U, Qbar, pars

sub = ["KO", "PEP", "PG"]
idx = [tickers.index(t) for t in sub]
E3_full = E[:, idx]
E3_2000 = R[-2000:, idx] - R[-2000:, idx].mean(0)  # window used in the deck sims

print("\nDCC(1,1) on KO, PEP, PG (two-step, correlation targeting):")
a3f, b3f, _, _, _ = fit_dcc(E3_full, "full sample  (T=2740)")
a3, b3, U3, Qbar3, upars3 = fit_dcc(E3_2000, "last 2000 obs (deck window)")
print("  unconditional correlations, deck window (from targeting matrix):")
Dq = np.sqrt(np.diag(Qbar3))
Rbar3 = Qbar3 / np.outer(Dq, Dq)
for i in range(3):
    for j in range(i + 1, 3):
        print("    corr(%s,%s) = %.3f" % (sub[i], sub[j], Rbar3[i, j]))

print("\nDCC(1,1) on all 10 stocks (two-step, correlation targeting):")
a10, b10, _, _, _ = fit_dcc(E, "10 stocks    (T=2740)")

# ---------------------------------------------------------------------
# 5. Forecast race: CCC vs DCC vs EWMA (RiskMetrics, lambda = 0.96)
#    One-step-ahead covariance forecasts on KO, PEP, PG. Parameters are
#    estimated once on the full deck window (the paper re-estimates
#    monthly on a rolling 2740-day window - this is the teaching-grade
#    shortcut, and it matches the in-browser simulations). Forecasts are
#    evaluated over the last 800 days. Proxy: outer product of demeaned
#    returns (noisy but unbiased; the paper uses 5-minute realised
#    covariance, unavailable for the estimation years).
# ---------------------------------------------------------------------
def dcc_filter_Q(U, Qbar, a, b):
    Tn, n = U.shape
    Qs = np.empty((Tn, n, n))
    Q = Qbar.copy()
    for t in range(Tn):
        if t > 0:
            u = U[t - 1][:, None]
            Q = (1 - a - b) * Qbar + a * (u @ u.T) + b * Q
        Qs[t] = Q
    return Qs

def corr_from_Q(Q):
    d = np.sqrt(np.diag(Q))
    return Q / np.outer(d, d)

def frob(A):
    return np.sum(A * A)

def qlike(Sig, H):
    """Robust QLIKE for matrices: log|H| + tr(H^-1 Sigma-hat).
    The proxy-only term -log|Sigma-hat|-N is constant across models
    (and undefined for a rank-1 proxy), so it is dropped."""
    sign, logdet = np.linalg.slogdet(H)
    return logdet + np.trace(np.linalg.solve(H, Sig))

est, ev = 1200, 800
X = E3_2000
pars_e = upars3                # univariate GARCH from the deck-window fit
a_e, b_e = a3, b3              # DCC (a, b) from the deck-window fit
S2 = np.empty_like(X)
for i in range(3):
    o, aa, bb = pars_e[i]
    S2[:, i] = garch11_filter(X[:, i], o, aa, bb)
U = X / np.sqrt(S2)
Qbar_e = Qbar3
Rbar_e = corr_from_Q(Qbar_e)
print("\nRace parameters (estimated once on the 2000-obs deck window):")
print("  DCC a = %.4f, b = %.4f;  EWMA lambda = 0.96 (RiskMetrics, as in the paper)" % (a_e, b_e))

Qs = dcc_filter_Q(U, Qbar_e, a_e, b_e)
lam = 0.96
Hew = np.empty((len(X), 3, 3))
Hew[0] = np.cov(X[:est].T)
for t in range(1, len(X)):
    e = X[t - 1][:, None]
    Hew[t] = (1 - lam) * (e @ e.T) + lam * Hew[t - 1]

lossF = {"CCC": [], "DCC": [], "EWMA": []}
lossQ = {"CCC": [], "DCC": [], "EWMA": []}
for t in range(est, len(X)):
    D = np.diag(np.sqrt(S2[t]))
    H_ccc = D @ Rbar_e @ D
    H_dcc = D @ corr_from_Q(Qs[t]) @ D
    H_ew = Hew[t]
    Sig = np.outer(X[t], X[t])
    for name, H in (("CCC", H_ccc), ("DCC", H_dcc), ("EWMA", H_ew)):
        lossF[name].append(frob(Sig - H))
        lossQ[name].append(qlike(Sig, H))

print("\nOne-step covariance forecast race, %d evaluation days:" % ev)
print("  %-5s %14s %14s" % ("", "Frobenius", "QLIKE"))
for name in ("CCC", "DCC", "EWMA"):
    print("  %-5s %14.3f %14.4f" % (name, np.mean(lossF[name]), np.mean(lossQ[name])))

# calm vs turbulent halves of the evaluation window
half = ev // 2
print("\n  Frobenius loss by subsample (first 400 vs last 400 evaluation days):")
d1, d2 = dates.iloc[-2000 + est].date(), dates.iloc[-2000 + est + half].date()
print("  %-5s %14s %14s   (splits at %s)" % ("", "calmer half", "turbulent half", d2))
for name in ("CCC", "DCC", "EWMA"):
    print("  %-5s %14.3f %14.3f" % (name, np.mean(lossF[name][:half]), np.mean(lossF[name][half:])))

# ---------------------------------------------------------------------
# 6. Robustness: forecast horizon H = 1, 5, 20 (non-overlapping windows)
#    GARCH variances iterate h(s) = omega + (a+b) h(s-1); DCC correlations
#    decay to the target: R(t+s) ~ Rbar + (a+b)^(s-1) (R(t+1) - Rbar)
#    (the standard Engle-Sheppard approximation). EWMA is flat: H x H(t+1).
# ---------------------------------------------------------------------
def horizon_race(H):
    lf = {"CCC": [], "DCC": [], "EWMA": []}
    persDCC = a_e + b_e
    for t0 in range(est, len(X) - H + 1, H):
        # aggregate H-day covariance forecasts made at t0-1
        Hc = np.zeros((3, 3)); Hd = np.zeros((3, 3))
        R1 = corr_from_Q(Qs[t0])
        h = S2[t0].copy()
        for s in range(H):
            D = np.diag(np.sqrt(h))
            Rs = Rbar_e + persDCC ** s * (R1 - Rbar_e)
            Hc += D @ Rbar_e @ D
            Hd += D @ Rs @ D
            for i in range(3):
                o, aa, bb = pars_e[i]
                h[i] = o + (aa + bb) * h[i]
        He = H * Hew[t0]
        Sig = sum(np.outer(X[t0 + s], X[t0 + s]) for s in range(H))
        for name, Hm in (("CCC", Hc), ("DCC", Hd), ("EWMA", He)):
            lf[name].append(frob(Sig - Hm))
    return {k: np.mean(v) for k, v in lf.items()}, len(lf["CCC"])

print("\nRobustness: Frobenius loss by forecast horizon (non-overlapping):")
print("  %-5s %12s %12s %12s" % ("", "H=1", "H=5", "H=20"))
res = {H: horizon_race(H)[0] for H in (1, 5, 20)}
for name in ("CCC", "DCC", "EWMA"):
    print("  %-5s %12.2f %12.2f %12.2f"
          % (name, res[1][name], res[5][name], res[20][name]))

# ---------------------------------------------------------------------
# 7. Robustness: estimation window length for the DCC parameters
# ---------------------------------------------------------------------
print("\nRobustness: DCC (a, b) on KO, PEP, PG vs estimation window:")
for W in (1000, 2000, 2740):
    Ew = R[-W:, idx] - R[-W:, idx].mean(0)
    aw, bw, _, _, _ = fit_dcc(Ew)
    print("  last %4d obs: a = %.4f  b = %.4f  a+b = %.4f" % (W, aw, bw, aw + bw))

# ---------------------------------------------------------------------
# 8. Optional cross-check of the univariate step with the arch package
# ---------------------------------------------------------------------
try:
    from arch import arch_model
    print("\narch-package cross-check, GARCH(1,1) on KO (demeaned):")
    am = arch_model(E[:, tickers.index("KO")], mean="Zero", vol="GARCH",
                    p=1, q=1, rescale=False)
    fr = am.fit(disp="off")
    print("  arch : omega = %.4f  alpha = %.4f  beta = %.4f"
          % (fr.params["omega"], fr.params["alpha[1]"], fr.params["beta[1]"]))
    o, a, b = upars["KO"]
    print("  scipy: omega = %.4f  alpha = %.4f  beta = %.4f" % (o, a, b))
except ImportError:
    print("\n(arch package not installed - skipping the cross-check)")

print("\nInterpretation: the DCC persistence a+b is close to 1, so correlations")
print("move slowly and mean-revert to the targeting matrix; univariate GARCH")
print("persistence is also high. In the paper's out-of-sample race (125 models,")
print("MCS at alpha = 0.25), DCC-type models with leverage in the variances do")
print("best in turbulent periods, while in calm periods CCC cannot be rejected.")
