# MANG3095 · Advanced Financial Econometrics

Interactive course site for **MANG3095** (University of Southampton). The site shows the current
academic year automatically.

**Live site:** https://ahmad0maaitah.github.io/MANG3095/

## Structure

- **Weeks 1-5** - research and writing skills: module introduction, project foundations,
  the research proposal, literature review in finance, and the bridge into applied work.
- **Weeks 6-10** - five landmark papers rebuilt as interactive teaching units:
  - Week 6: Fama and French (2015), *A five-factor asset pricing model*, JFE
  - Week 7: Diebold and Yilmaz (2012), volatility spillovers and connectedness
  - Week 8: Antonakakis, Chatziantoniou and Gabauer (2020), TVP-VAR connectedness
  - Week 9: Laurent, Rombouts and Violante (2012), multivariate GARCH forecast accuracy, JAE
  - Week 10: a Review of Financial Studies banking replication package (Stata panel methods)

Each paper unit contains: a data-preparation introduction (stationarity, transformations,
panel identification), parameterised interactive simulations of the paper's method, code in
four languages (EViews, Stata, R, Python) with in-browser execution for Python, robustness
checks rebuilt as simulations, and a results discussion under every simulation.

## Data (`data/csv/`)

- `ff5_monthly.csv`, `ff5_annual.csv` - Ken French five-factor data (course copies)
- `lrv_returns.csv` - the original Laurent-Rombouts-Violante 10-stock daily returns
  (JAE data archive)
- `fx_returns.csv` - daily EUR/GBP/JPY returns for connectedness demonstrations
- `crypto_returns.csv` - aligned BTC and ETH daily returns

## Running the code

Python cells run directly in the browser (first run downloads the runtime, ~15 MB).
Stata, EViews and R code ships as downloadable files per unit; expected outputs are shown
on the page so students can verify their runs.

Site built with reveal.js and KaTeX (vendored). Simulations are dependency-free vanilla JS.

---
Dr. Ahmad Maaitah · University of Southampton
