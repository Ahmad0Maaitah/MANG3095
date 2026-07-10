# =============================================================================
# MANG3095 Advanced Financial Econometrics - Lecture 8
# TVP-VAR dynamic connectedness (Antonakakis, Chatziantoniou and Gabauer 2020,
# Journal of Risk and Financial Management 13(4), 84)
#
# Data: daily EUR/GBP/JPY % log returns vs USD, Dec 1998 - Jul 2018 (T = 7141)
#
# R is the reference environment for this paper: the third author maintains
# the ConnectednessApproach package, which implements the paper's full
# Bayesian TVP-VAR connectedness framework (and ships the paper's own data
# as data(acg2020)). Replication page:
# gabauerdavid.github.io/ConnectednessApproach/2020AntonakakisChatziantoniouGabauer
#
# install.packages(c("ConnectednessApproach", "zoo", "tseries"))
# =============================================================================
library(ConnectednessApproach)
library(zoo)

# ---------------------------------------------------------------- 1. data
raw <- read.csv("../../../data/csv/fx_returns.csv")
x   <- zoo(raw[, c("EUR", "GBP", "JPY")], order.by = as.Date(raw$date))

summary(x)
cor(x)

# stationarity: all three return series comfortably reject the unit root
tseries::adf.test(raw$EUR)
tseries::adf.test(raw$GBP)
tseries::adf.test(raw$JPY)

# optional: weekly (5-trading-day) aggregation, as used by the deck's
# in-browser simulations (log returns are additive)
g  <- (seq_len(nrow(raw)) - 1) %/% 5
wk <- aggregate(raw[, c("EUR", "GBP", "JPY")], list(g), sum)[, -1]
wd <- raw$date[tapply(seq_len(nrow(raw)), g, max)]
xw <- zoo(round(wk, 4), order.by = as.Date(wd))
xw <- xw[1:1428, ]                       # complete 5-day weeks only

# --------------------------------- 2. TVP-VAR dynamic connectedness (paper)
# model = "TVP-VAR": the paper's estimator. kappa1 = coefficient forgetting
# factor, kappa2 = error-covariance decay; 0.99/0.96 are the Koop-Korobilis
# (2014) benchmark values used in the paper. nfore = GFEVD horizon H.
dca <- ConnectednessApproach(xw,
        model          = "TVP-VAR",
        connectedness  = "Time",
        nlag           = 1,             # BIC choice, as in the paper
        nfore          = 10,
        VAR_config     = list(TVPVAR = list(kappa1 = 0.99, kappa2 = 0.96,
                                            prior = "BayesPrior", gamma = 0.01)))

dca$TABLE            # averaged connectedness table (the paper's Table 3 layout)

PlotTCI(dca)         # dynamic total connectedness      (paper Figure 7)
PlotTO(dca)          # directional TO others
PlotFROM(dca)        # directional FROM others
PlotNET(dca)         # net transmitter/receiver paths   (paper Figure 8, top)
PlotNPDC(dca)        # net pairwise directional paths   (paper Figure 8, lower)

# --------------------------------- 3. rolling-window comparison (Week 7)
dca_rw <- ConnectednessApproach(xw,
        model         = "VAR",
        connectedness = "Time",
        nlag          = 1,
        nfore         = 10,
        window.size   = 100)
PlotTCI(dca_rw)      # note the 99 lost observations and the choppier path

# --------------------------------- 4. robustness reruns
for (k1 in c(0.97, 1.00)) {
  d <- ConnectednessApproach(xw, model = "TVP-VAR", connectedness = "Time",
        nlag = 1, nfore = 10,
        VAR_config = list(TVPVAR = list(kappa1 = k1, kappa2 = 0.96,
                                        prior = "BayesPrior", gamma = 0.01)))
  cat("kappa1 =", k1, ": mean TCI =", round(mean(d$TCI), 2), "%\n")
}

# --------------------------------- 5. the paper's own data (replication)
# data(acg2020)   # monthly EUR/GBP/CHF/JPY vs USD, Feb 1975 - Jan 2019
# dca_paper <- ConnectednessApproach(acg2020, model = "TVP-VAR",
#                connectedness = "Time", nlag = 1, nfore = 12,
#                VAR_config = list(TVPVAR = list(kappa1 = 0.99, kappa2 = 0.99,
#                                                prior = "BayesPrior", gamma = 0.01)))
# dca_paper$TABLE   # reproduces Table 3: TCI 53.4%, NET EUR +9.6 ... JPY -11.6

# WHAT TO INTERPRET: exact numbers differ slightly from the deck's teaching
# filter (the package uses a Bayesian prior and a slightly different
# initialisation) but the findings match: TCI averages in the high 20s on
# the weekly data, EUR is the persistent net transmitter and JPY the
# persistent net receiver, and the TVP index needs no window choice.
# =============================================================================
