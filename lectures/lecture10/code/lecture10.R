# ===========================================================================
# MANG3095 Advanced Financial Econometrics - Week 10
# Replicating a banking panel: Gopal and Schnabl (2022, RFS 35(11), 4859-4901)
# "The Rise of Finance Companies and FinTech Lenders in Small Business Lending"
# ===========================================================================
# The paper's 171 MB replication dataset is NOT shipped with this unit, so this
# script builds a SYNTHETIC county-year teaching panel and walks the same
# architecture as the paper's Stata replication package: entity/time ids,
# merges on county, long differences with state FE, panel FE via fixest,
# county-clustered SEs, an event study, and robustness checks.
# Packages: install.packages(c("fixest", "dplyr"))
#   fixest::feols() is the R twin of the package's reghdfe: the formula
#   y ~ x | fe1 + fe2 absorbs FE and cluster = ~id clusters the SEs.
# ===========================================================================

library(dplyr)
library(fixest)

set.seed(42)

G <- 200; S <- 25; years <- 2007:2016; T <- length(years)

# ---------------------------------------------------------------------------
# 1. Build the synthetic county-year teaching panel
# ---------------------------------------------------------------------------

county <- tibble(
  county        = 1001:(1000 + G),
  state         = rep(1:S, each = G / S),
  bank_share_06 = pmin(pmax(rnorm(G, 0.476, 0.130), 0.05), 0.95)  # Table 3
)
# unobserved county quality, correlated with the bank share (the confounder)
county$alpha_c <- -2.5 * (county$bank_share_06 - mean(county$bank_share_06)) +
  rnorm(G, 0, 0.60)

# staggered branch closures: more likely where the bank share is high
close_prob <- 0.15 + 0.55 * (county$bank_share_06 - 0.2) / 0.6
county$treat_year <- ifelse(runif(G) < close_prob,
                            sample(2010:2013, G, replace = TRUE), 9999)

# balanced county x year panel: expand and merge back on the county id -
# this is the m:1 merge pattern used throughout data_creation.do
panel <- tidyr::expand_grid(county = county$county, year = years) |>
  left_join(county, by = "county")

delta_t <- cumsum(rnorm(T, 0.02, 0.05))                 # common year shocks
panel <- panel |>
  mutate(closure  = as.integer(year >= treat_year),
         ln_loans = 6.0 - 1.50 * closure + alpha_c +
                    delta_t[match(year, years)] + rnorm(n(), 0, 0.35))

cat("panel:", G, "counties x", T, "years =", nrow(panel), "rows; balanced:",
    n_distinct(table(panel$county)) == 1, "\n")

# ---------------------------------------------------------------------------
# 2. Why the paper needs fixed effects (pooled vs FE vs two-way FE)
# ---------------------------------------------------------------------------

m_pool <- feols(ln_loans ~ closure,                 panel, cluster = ~county)
m_fe   <- feols(ln_loans ~ closure | county,        panel, cluster = ~county)
m_2w   <- feols(ln_loans ~ closure | county + year, panel, cluster = ~county)
etable(m_pool, m_fe, m_2w, headers = c("pooled", "county FE", "two-way FE"))
# expected: pooled about -1.68 (biased); county FE about -1.47;
# two-way FE about -1.53 (true effect -1.50)

# ---------------------------------------------------------------------------
# 3. The Gopal-Schnabl long difference (their Table 4, eq. (1))
# ---------------------------------------------------------------------------
# The package's line:  reghdfe share_07_16 pre_crisis_bank_share `controls'
#                          if bank==0, abs(state) cluster(county)

county$d_nonbank_share <- 0.212 * county$bank_share_06 +
  rnorm(S, 0, 0.02)[county$state] + rnorm(G, 0, 0.05)

m_ld <- feols(d_nonbank_share ~ bank_share_06 | state, county,
              cluster = ~county)
print(summary(m_ld))
q <- quantile(county$bank_share_06, c(0.10, 0.90))
cat("10th->90th pct of bank share moves the nonbank share by",
    round(coef(m_ld)["bank_share_06"] * diff(q) * 100, 1),
    "pp   (paper: +6.9 pp; gamma = 0.212 (0.024), Table 4)\n")

# ---------------------------------------------------------------------------
# 4. Clustered standard errors (the Moulton problem)
# ---------------------------------------------------------------------------

icc <- 0.5
placebo <- tidyr::expand_grid(county = 1:40, year = 1:8) |>
  mutate(x_c = rnorm(40)[county],
         u   = sqrt(icc) * rnorm(40)[county] + sqrt(1 - icc) * rnorm(n()),
         y   = 0 * x_c + u)                       # true effect is ZERO

m_naive <- feols(y ~ x_c, placebo)                          # iid SEs
m_clust <- feols(y ~ x_c, placebo, cluster = ~county)       # honest SEs
cat("naive se:", round(se(m_naive)["x_c"], 4),
    " cluster se:", round(se(m_clust)["x_c"], 4),
    " ratio:", round(se(m_clust)["x_c"] / se(m_naive)["x_c"], 2), "\n")
# the ratio is about sqrt(1 + (T-1)*icc), the Moulton factor (about 1.9 here)

# ---------------------------------------------------------------------------
# 5. Event study around staggered closures (parallel trends)
# ---------------------------------------------------------------------------

ev <- panel |> filter(treat_year != 9999) |>
  mutate(etime = pmax(pmin(year - treat_year, 3), -3))
m_ev <- feols(ln_loans ~ i(etime, ref = -1) | county + year, ev,
              cluster = ~county)
print(coef(m_ev))
# pre-event terms near 0 (parallel trends); post terms about -1.3 and flat
# (fixest::iplot(m_ev) draws the event-study path)

# ---------------------------------------------------------------------------
# 6. Robustness: FE structure, clustering level, leave-one-state-out
# ---------------------------------------------------------------------------

# (a) FE structures: see etable() above
# (b) clustering level for the long difference
cat("gamma se, county cluster:", round(se(m_ld)["bank_share_06"], 4), "\n")
m_ld_state <- feols(d_nonbank_share ~ bank_share_06 | state, county,
                    cluster = ~state)
cat("gamma se, state cluster :", round(se(m_ld_state)["bank_share_06"], 4),
    " (only", S, "clusters: treat with caution, Cameron-Miller 2015)\n")

# (c) leave-one-state-out
gammas <- sapply(1:S, function(s)
  coef(feols(d_nonbank_share ~ bank_share_06 | state,
             county[county$state != s, ]))["bank_share_06"])
cat("leave-one-state-out gamma: min", round(min(gammas), 3),
    "max", round(max(gammas), 3), "\n")

# ===========================================================================
# What to interpret: FE strips out permanent county differences targeted by
# the treatment; clustering repairs SEs when shocks are shared within county;
# the long-difference gamma (about 0.21) mirrors the paper's Table 4: a 10th
# to 90th percentile move in the 2006 bank share raises the nonbank market
# share by about 7 pp with no effect on total lending - the substitution result.
# ===========================================================================
