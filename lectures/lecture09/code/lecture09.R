# ------------------------------------------------------------------
# MANG3095 Advanced Financial Econometrics - Lecture 9
# Multivariate GARCH forecasting:
# Laurent, Rombouts and Violante (2012, J. Applied Econometrics
# 27(6), 934-955), "On the forecasting accuracy of multivariate
# GARCH models".
#
# Data: ../../../data/csv/lrv_returns.csv - the paper's OWN
# estimation sample (2,740 daily open-to-close % returns, 10 NYSE
# stocks, from 2 March 1988; date_serial is a Julian day number).
#
# Packages: rugarch, rmgarch (Ghalanos); optionally MCS (Bernardi
# and Catania) for the model confidence set, tseries for ADF.
# Run from this folder:  Rscript lecture09.R
# ------------------------------------------------------------------
library(rugarch)
library(rmgarch)

# 1. Import and clean ------------------------------------------------
lrv <- read.csv("../../../data/csv/lrv_returns.csv")
lrv <- na.omit(as.data.frame(lapply(lrv, function(c) suppressWarnings(as.numeric(c)))))
dates <- as.Date(lrv$date_serial - 2440588, origin = "1970-01-01")  # Julian day -> Date
cat(sprintf("%d trading days, %s to %s\n", nrow(lrv), min(dates), max(dates)))

X <- lrv[, c("KO", "PEP", "PG")]

# 2. Descriptives, zeros, stationarity ------------------------------
print(round(sapply(X, function(v) c(mean = mean(v), sd = sd(v),
                                    min = min(v), max = max(v),
                                    zero.pct = 100 * mean(v == 0))), 3))
# ADF (tseries): returns are hugely stationary
if (requireNamespace("tseries", quietly = TRUE)) {
  for (tk in names(X)) print(tseries::adf.test(X[[tk]]))
}

# 3. Univariate GARCH(1,1) per stock --------------------------------
uspec1 <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model     = list(armaOrder = c(0, 0), include.mean = TRUE))
for (tk in names(X)) {
  fit <- ugarchfit(uspec1, data = X[[tk]])
  cat(tk, ": ", paste(names(coef(fit)), round(coef(fit), 4),
                      collapse = "  "),
      "  persistence =", round(persistence(fit), 4), "\n")
}
# expected (KO): omega ~ 0.05, alpha1 ~ 0.04, beta1 ~ 0.93

# 4. DCC(1,1) with GARCH(1,1) marginals (Engle 2002) ----------------
# rmgarch estimates exactly the paper's two-step DCC with
# correlation targeting: dcca1 = a (news), dccb1 = b (memory).
dspec <- dccspec(uspec = multispec(replicate(3, uspec1)),
                 dccOrder = c(1, 1), distribution = "mvnorm")
dfit <- dccfit(dspec, data = X)
show(dfit)
cat("\nDCC parameters: a =", round(coef(dfit)["[Joint]dcca1"], 4),
    " b =", round(coef(dfit)["[Joint]dccb1"], 4), "\n")
# expected (full 2,740 obs, two-step): a ~ 0.015, b ~ 0.971
# on the deck's window (last 2,000 obs): a ~ 0.016, b ~ 0.933
dfit2000 <- dccfit(dspec, data = tail(X, 2000))
cat("last 2000 obs: a =", round(coef(dfit2000)["[Joint]dcca1"], 4),
    " b =", round(coef(dfit2000)["[Joint]dccb1"], 4), "\n")

# conditional correlations (compare the deck's DCC laboratory)
Rt <- rcor(dfit)                    # 3 x 3 x T array
plot(dates, Rt[1, 2, ], type = "l",
     main = "DCC conditional correlation: KO-PEP",
     xlab = "", ylab = "correlation")
abline(h = mean(Rt[1, 2, ]), lty = 2)

# 5. Forecast and evaluate ------------------------------------------
fc <- dccforecast(dfit, n.ahead = 20)
H20 <- rcov(fc)                     # forecast H_{T+1}, ..., H_{T+20}
print(H20[[1]][, , 1])              # one-step-ahead covariance matrix

# Out-of-sample race (CCC vs DCC vs EWMA) and matrix losses:
# see lecture09.py for the transparent numpy implementation of the
# Frobenius and QLIKE losses against the outer-product proxy.
# For the model confidence set on your own loss series:
#   library(MCS)
#   MCSprocedure(Loss = cbind(ccc = L_ccc, dcc = L_dcc, ewma = L_ewma),
#                alpha = 0.25, B = 10000, statistic = "TR")
# (the paper uses alpha = 0.25, block length 2, 10,000 bootstraps)

# 6. Robustness: estimation window ----------------------------------
for (W in c(1000, 2000)) {
  f <- dccfit(dspec, data = tail(X, W))
  cat(sprintf("window %4d: a = %.4f  b = %.4f\n", W,
              coef(f)["[Joint]dcca1"], coef(f)["[Joint]dccb1"]))
}
# Interpretation: shorter, more turbulent windows raise a (news) and
# lower b (memory); persistence a+b stays high throughout. The paper
# re-estimates every 22 days on a rolling 2,740-day window for
# exactly this reason.
# ------------------------------------------------------------------
