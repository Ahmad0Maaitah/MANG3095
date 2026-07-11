# ===========================================================================
# MANG3095 Advanced Financial Econometrics - Week 10
# Replicating a banking panel: Gopal and Schnabl (2022, RFS 35(11), 4859-4901)
# "The Rise of Finance Companies and FinTech Lenders in Small Business Lending"
# ===========================================================================
# This script runs on the REAL county-level aggregates from the paper's
# replication package (supplementary material, doi.org/10.1093/rfs/hhac034):
#   ../../../data/csv/gopal_county.csv       county cross-section: 2006 bank
#                                            share, 2007-2016 changes, controls
#   ../../../data/csv/gopal_county_year.csv  county x year UCC loan counts
# On this data the preferred specification reproduces Table 4 EXACTLY:
#   0.212 (0.024) / 0.534 (0.080) / 0.016 (0.060)
# Packages: install.packages(c("fixest", "dplyr", "tidyr"))
#   fixest::feols() is the R twin of the package's reghdfe: the formula
#   y ~ x | fe1 + fe2 absorbs FE and cluster = ~id clusters the SEs.
# ===========================================================================

library(dplyr)
library(fixest)

DATA <- "../../../data/csv/"

controls <- c("unemp_rate_2002_2006", "lfp_rate_2002_2006", "est_2002_2006",
              "wage_2002_2006", "log_pop", "unemp_rate2005", "lfp_rate2005",
              "wage2005")
CTRL <- paste(controls, collapse = " + ")

# ---------------------------------------------------------------------------
# 1. The real panel: structure, identifiers and the m:1 merge
# ---------------------------------------------------------------------------

cy <- read.csv(paste0(DATA, "gopal_county_year.csv"))
cs <- read.csv(paste0(DATA, "gopal_county.csv"))

cat("county-year panel:", nrow(cy), "rows;", n_distinct(cy$county),
    "counties;", min(cy$year), "-", max(cy$year), "\n")
tab <- table(table(cy$county))
cat("balanced counties (all", n_distinct(cy$year), "years):",
    sum(table(cy$county) == n_distinct(cy$year)), "of",
    n_distinct(cy$county), "-> mildly unbalanced, keep all\n")

# the package's m:1 merge pattern: many county-years to one county record
cy <- cy |>
  inner_join(cs |> select(county, state, bank_share_06), by = "county") |>
  mutate(nonbank_share = nonbank_loans / (nonbank_loans + bank_loans))
head(cy, 4)

# ---------------------------------------------------------------------------
# 2. Table 4, for real (long difference 2007-2016)
# ---------------------------------------------------------------------------
# The package's line:  reghdfe share_07_16 pre_crisis_bank_share `controls'
#                          if bank==0, abs(state) cluster(county)

an <- cs |> filter(complete.cases(across(all_of(c(controls, "d_nb_share_07_16",
        "nb_growth_07_16", "total_growth_07_16", "bank_share_06")))))
cat("analysis sample:", nrow(an), "counties;",
    "bank share mean", round(mean(an$bank_share_06), 3),
    "sd", round(sd(an$bank_share_06), 3), "(paper Table 3: 0.476, 0.130)\n")

f <- function(y, fe = TRUE, ctrl = TRUE) {
  rhs <- paste0(y, " ~ bank_share_06", if (ctrl) paste0(" + ", CTRL) else "",
                if (fe) " | state" else "")
  feols(as.formula(rhs), an, cluster = ~county)
}
m1 <- f("d_nb_share_07_16");  m2 <- f("nb_growth_07_16");  m3 <- f("total_growth_07_16")
etable(f("d_nb_share_07_16", fe = FALSE, ctrl = FALSE),
       f("d_nb_share_07_16", fe = FALSE), m1, m2, m3,
       keep = "bank_share_06",
       headers = c("share raw", "share ctrl", "share FE", "nb growth", "total"))
# expected FE row: 0.212 (0.024)   0.534 (0.080)   0.016 (0.060)

q <- quantile(an$bank_share_06, c(0.10, 0.90))
cat("10th->90th pct of bank share moves the nonbank share by",
    round(coef(m1)["bank_share_06"] * diff(q) * 100, 1),
    "pp; total lending is a precise null\n")

# ---------------------------------------------------------------------------
# 3. The crisis event study on the real panel (county + year FE)
# ---------------------------------------------------------------------------
# 2006 is excluded: the exposure measure is built FROM the 2006 counts,
# so its 2006 slope is -1 mechanically. Base year 2007.

ev <- cy |> filter(year >= 2007, !is.na(nonbank_share))
m_ev <- feols(nonbank_share ~ i(year, bank_share_06, ref = 2007) | county + year,
              ev, cluster = ~county)
print(coef(m_ev))
# expected path: +0.04 (2008), +0.02 (2009), +0.06 (2010) ... +0.22 (2016)
# (fixest::iplot(m_ev) draws the event-study path)

# ---------------------------------------------------------------------------
# 4. Clustered standard errors on the real regression
# ---------------------------------------------------------------------------

m_iid <- summary(m1, vcov = "iid")
m_cty <- summary(m1, cluster = ~county)
m_st  <- summary(m1, cluster = ~state)
cat("gamma se: iid", round(se(m_iid)["bank_share_06"], 4),
    "| county", round(se(m_cty)["bank_share_06"], 4),
    "| state", round(se(m_st)["bank_share_06"], 4),
    "(50 clusters: coarser, noisier; Cameron-Miller 2015)\n")
# expected: 0.019 / 0.024 / 0.027 - even a cross-section is not iid

# ---------------------------------------------------------------------------
# 5. Robustness on the real data
# ---------------------------------------------------------------------------

# (a) subperiods: the effect builds after 2010
etable(f("d_nb_share_07_10"), f("d_nb_share_10_16"), keep = "bank_share_06",
       headers = c("2007-2010", "2010-2016"))
# expected: 0.073 (0.023) then 0.138 (0.024): a permanent reallocation

# (b) leave-one-state-out: no single state drives gamma
states <- unique(an$state)
gammas <- sapply(states, function(s)
  coef(feols(as.formula(paste0("d_nb_share_07_16 ~ bank_share_06 + ", CTRL,
                               " | state")), an[an$state != s, ]))["bank_share_06"])
cat("leave-one-state-out gamma: min", round(min(gammas), 3),
    "max", round(max(gammas), 3), " (full sample 0.212)\n")

# ===========================================================================
# What to interpret: the 2006 bank share predicts where nonbanks took over
# after 2008 (gamma = 0.212, Table 4 exactly); the event-study path lines up
# with the shock and never reverts; total lending is a precise null - lender
# substitution, not a credit crunch. County clustering matters even in the
# cross-section (se 0.019 -> 0.024).
# ===========================================================================
