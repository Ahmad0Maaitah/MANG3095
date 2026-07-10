# =============================================================
# MANG3095 - Week 7: Volatility spillovers (Diebold & Yilmaz 2012)
# R workflow on the module FX data (EUR/GBP/JPY daily % returns)
# Run from inside lectures/lecture07/code/ (data paths are relative)
#
# Packages (install once):
#   install.packages(c("vars", "tseries", "zoo", "ConnectednessApproach"))
# ConnectednessApproach (Gabauer) is the standard tool of this
# literature; its website replicates the DY 2012 paper itself:
#   https://gabauerdavid.github.io/ConnectednessApproach/2012DieboldYilmaz
# =============================================================
library(vars)
library(tseries)
library(zoo)
library(ConnectednessApproach)

# ---------- 1. Load and describe ----------
fx <- read.csv("../../../data/csv/fx_returns.csv")
X  <- zoo(fx[, c("EUR", "GBP", "JPY")], order.by = as.Date(fx$date))
cat("T =", nrow(X), "obs,", format(start(X)), "to", format(end(X)), "\n")
print(summary(coredata(X)))

# ---------- 2. Stationarity ----------
print(apply(coredata(X), 2, function(s) adf.test(s)$p.value))
# every p-value < 0.01: returns are stationary. (adf.test defaults to
# k = trunc((T-1)^(1/3)) = 19 lags, so its statistics are smaller in
# magnitude than the -42 that Stata/Python report with 3 lags; the
# conclusion is identical.)

# ---------- 3. Lag order ----------
print(VARselect(coredata(X), lag.max = 8, type = "const")$selection)
# AIC -> 4, SC -> 1, HQ -> 2: baseline p = 2, robustness p = 1..4

# ---------- 4. Full-sample connectedness table (generalized FEVD) ----------
dca <- ConnectednessApproach(X, nlag = 2, nfore = 10, model = "VAR")
print(dca$TABLE)          # the spillover table: FROM, TO, NET, TCI
# expected (matches code/lecture07.py): TCI = 23.68%,
# NET = +2.45 (EUR), -0.15 (GBP), -2.30 (JPY)
# The package's own DY2012 replication uses nlag = 4, nfore = 10.

# ---------- 5. Rolling connectedness, w = 200 (the paper's window) ----------
dca_roll <- ConnectednessApproach(X, nlag = 2, nfore = 10,
                                  window.size = 200, model = "VAR")
PlotTCI(dca_roll, ylim = c(0, 60))    # rolling total index (paper Fig. 2)
PlotNET(dca_roll)                     # net directional spillovers (Fig. 5)
PlotNPDC(dca_roll)                    # net pairwise spillovers    (Fig. 6)

# ---------- 6. Robustness: lag order, horizon, window ----------
for (p in 1:4) {
  d <- ConnectednessApproach(X, nlag = p, nfore = 10, model = "VAR")
  cat("p =", p, " TCI =", round(mean(d$TCI), 2), "%\n")   # 23.62 to 23.71
}
for (h in c(5, 10, 20)) {
  d <- ConnectednessApproach(X, nlag = 2, nfore = h, model = "VAR")
  cat("H =", h, " TCI =", round(mean(d$TCI), 2), "%\n")   # flat in H
}

# subsamples: connectedness itself moves over time
pre  <- window(X, end   = as.Date("2007-12-31"))
post <- window(X, start = as.Date("2008-01-01"))
cat("pre-2008 :", round(mean(ConnectednessApproach(pre,  nlag = 2,
    nfore = 10, model = "VAR")$TCI), 2), "%\n")           # about 29.3
cat("2008 on  :", round(mean(ConnectednessApproach(post, nlag = 2,
    nfore = 10, model = "VAR")$TCI), 2), "%\n")           # about 20.4

# ------------------------------------------------------------------
# What to interpret: rows of dca$TABLE sum to 100 (own share on the
# diagonal); FROM/TO are the off-diagonal row/column sums; NET = TO -
# FROM separates transmitters (EUR) from receivers (JPY). The rolling
# index averages about 30% and spikes above 50% in stress episodes,
# while p and H barely move the full-sample number - the same
# robustness pattern as the paper's Figs. A.1 and A.2.
# ------------------------------------------------------------------
