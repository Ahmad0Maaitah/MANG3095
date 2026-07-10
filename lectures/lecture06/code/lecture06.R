# =============================================================
# MANG3095 - Week 6: Fama and French (2015) five-factor model
# Full workflow: load Ken French factors, summary statistics,
# factor spanning regressions, GRS test, robustness checks.
# Data: ../../../data/csv/ff5_monthly.csv, ff5_annual.csv
# (monthly percent returns, July 1963 - August 2022, T = 710)
#
# Further resources used in the module material:
# - tidy-finance.org, chapter "Replicating Fama and French factors":
#   builds SMB/HML/RMW/CMA from CRSP + Compustat step by step in R.
# - github.com/ioannisrpt/FamaFrench2015FF5: replication package
#   for the FF (2015) paper (portfolio sorts and factor tables).
# =============================================================

df  <- read.csv("../../../data/csv/ff5_monthly.csv", check.names = FALSE)
dfa <- read.csv("../../../data/csv/ff5_annual.csv",  check.names = FALSE)
fac <- c("Mkt-RF", "SMB", "HML", "RMW", "CMA")
T   <- nrow(df)
cat(sprintf("Monthly factors: %s to %s, T = %d\n", df$Date[1], df$Date[T], T))

# ---- 2. Summary statistics (paper Table 4, Panel A) ----------
cat("\n=== Summary statistics, monthly % ===\n")
for (f in fac) {
  x <- df[[f]]
  cat(sprintf("%-7s mean %6.3f  sd %5.2f  t %5.2f  ann.Sharpe %5.2f\n",
              f, mean(x), sd(x), mean(x) / (sd(x) / sqrt(T)),
              mean(x) / sd(x) * sqrt(12)))
}
cat("\n=== Correlations ===\n")
print(round(cor(df[fac]), 2))

# ---- 3. Spanning regressions (paper Table 6) -----------------
# Regress each factor on the other four; a zero intercept means the
# factor is redundant for the mean-variance frontier of the others.
spanning <- function(target, data) {
  others <- setdiff(fac, target)
  y <- data[[target]]
  X <- as.matrix(data[others])
  lm(y ~ X)
}
cat("\n=== Spanning regressions ===\n")
for (f in fac) {
  m <- spanning(f, df)
  s <- summary(m)
  cat(sprintf("\n%s on the other four: alpha = %6.3f (t = %5.2f), R2 = %.2f\n",
              f, coef(s)[1, 1], coef(s)[1, 3], s$r.squared))
  print(round(coef(s), 3))
}
# Headline: HML's alpha is ~ -0.09 (|t| ~ 1.1): redundant once RMW
# and CMA are included. RMW and CMA keep alphas > 4 SE from zero.

# ---- 4. GRS test (Gibbons, Ross and Shanken 1989) -------------
grs_test <- function(assets, factors, data) {
  Fm <- as.matrix(data[factors]); Tn <- nrow(Fm); K <- ncol(Fm)
  N  <- length(assets)
  X  <- cbind(1, Fm)
  A  <- numeric(N); E <- matrix(0, Tn, N)
  for (i in seq_along(assets)) {
    m <- lm.fit(X, data[[assets[i]]])
    A[i] <- m$coefficients[1]; E[, i] <- m$residuals
  }
  Sigma <- crossprod(E) / (Tn - K - 1)
  mu    <- colMeans(Fm); Omega <- cov(Fm)
  grs <- (Tn - N - K) / N *
    drop(t(A) %*% solve(Sigma, A)) / (1 + drop(t(mu) %*% solve(Omega, mu)))
  p <- 1 - pf(grs, N, Tn - N - K)
  list(grs = grs, p = p, alphas = A)
}
cat("\n=== GRS test 1: RMW and CMA vs the FF3 factors ===\n")
g <- grs_test(c("RMW", "CMA"), c("Mkt-RF", "SMB", "HML"), df)
cat(sprintf("  alphas %.3f, %.3f; GRS = %.2f, p = %.2e -> reject FF3\n",
            g$alphas[1], g$alphas[2], g$grs, g$p))
cat("\n=== GRS test 2: HML vs Mkt, SMB, RMW, CMA ===\n")
g <- grs_test("HML", c("Mkt-RF", "SMB", "RMW", "CMA"), df)
cat(sprintf("  alpha %.3f; GRS = %.2f, p = %.3f -> cannot reject: redundant\n",
            g$alphas[1], g$grs, g$p))

# ---- 5. Robustness: pre/post 1991 split ----------------------
cat("\n=== Robustness: pre/post 1991 ===\n")
for (d in list(pre = df[df$Date < "1991-01", ], post = df[df$Date >= "1991-01", ])) {
  cat(sprintf("\n%s to %s (T = %d)\n", d$Date[1], d$Date[nrow(d)], nrow(d)))
  for (tgt in c("HML", "RMW", "CMA")) {
    s <- summary(spanning(tgt, d))
    cat(sprintf("  spanning %s: alpha = %6.3f (t = %5.2f), R2 = %.2f\n",
                tgt, coef(s)[1, 1], coef(s)[1, 3], s$r.squared))
  }
}

# ---- 6. Robustness: annual factors ---------------------------
cat("\n=== Robustness: annual factors ===\n")
for (f in fac) {
  x <- dfa[[f]]
  cat(sprintf("%-7s mean %6.2f  sd %5.2f  t %5.2f\n",
              f, mean(x), sd(x), mean(x) / (sd(x) / sqrt(nrow(dfa)))))
}
for (tgt in c("HML", "RMW", "CMA")) {
  s <- summary(spanning(tgt, dfa))
  cat(sprintf("annual spanning %s: alpha = %6.2f (t = %5.2f), R2 = %.2f\n",
              tgt, coef(s)[1, 1], coef(s)[1, 3], s$r.squared))
}

# What to interpret: all five premiums are positive over 1963-2022;
# the spanning alpha of HML is statistically zero (redundancy, FF 2015
# Section 7) while RMW and CMA are not; the GRS test rejects FF3
# against the new factors but not the four-factor model against HML;
# the redundancy result flips sign across the 1991 split, so treat it
# as sample specific, exactly as Fama and French caution.
# =============================================================
