# MANG3095 · Advanced Financial Econometrics

Interactive course site for **MANG3095** (University of Southampton). The site shows the current
academic year automatically.

> **This repository holds the source code.** To USE the course (interactive slides, simulations,
> in-browser Python), open the live site:
>
> ## &#128073; https://ahmad0maaitah.github.io/MANG3095/

## Open the interactive slides

| Week | Unit | Interactive slides |
|---|---|---|
| 1 | Introduction to the Module | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture01/) |
| 2 | Foundations for Your Project | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture02/) |
| 3 | The Research Proposal | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture03/) |
| 4 | Literature Review in Finance | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture04/) |
| 5 | From Skills to Applications | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture05/) |
| 6 | Fama and French (2015), five-factor model | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture06/) |
| 7 | Diebold and Yilmaz (2012), volatility spillovers | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture07/) |
| 8 | Antonakakis, Chatziantoniou and Gabauer (2020), TVP-VAR | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture08/) |
| 9 | Laurent, Rombouts and Violante (2012), multivariate GARCH | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture09/) |
| 10 | Gopal and Schnabl (2022), banking panel replication | [open](https://ahmad0maaitah.github.io/MANG3095/lectures/lecture10/) |

Inside a deck: &rarr; moves between sections, &darr; dives into a section's slides (the
simulations live on those vertical slides), `o` shows the overview grid, `f` is full screen.

## Structure

- **Weeks 1-5** - research and writing skills: module introduction, project foundations,
  the research proposal, literature review in finance, and the bridge into applied work.
- **Weeks 6-10** - five landmark papers rebuilt as interactive teaching units:
  - Week 6: Fama and French (2015), *A five-factor asset pricing model*, JFE
  - Week 7: Diebold and Yilmaz (2012), volatility spillovers and connectedness
  - Week 8: Antonakakis, Chatziantoniou and Gabauer (2020), TVP-VAR connectedness
  - Week 9: Laurent, Rombouts and Violante (2012), multivariate GARCH forecast accuracy, JAE
  - Week 10: Gopal and Schnabl (2022), finance companies and FinTech lenders, RFS
    (real replication data; Table 4 reproduced exactly)

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
- `gopal_county.csv`, `gopal_county_year.csv` - real county-level analysis data from
  the Gopal and Schnabl (2022, RFS) replication package (supplementary material,
  doi 10.1093/rfs/hhac034), shipped with attribution; the proprietary loan-level
  UCC records are not included

## Running the code

Python cells run directly in the browser (first run downloads the runtime, ~15 MB).
Stata, EViews and R code ships as downloadable files per unit; expected outputs are shown
on the page so students can verify their runs.

Site built with reveal.js and KaTeX (vendored). Simulations are dependency-free vanilla JS.

---
Dr. Ahmad Maaitah · University of Southampton
