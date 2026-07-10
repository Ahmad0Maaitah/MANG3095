# Lecture 5 · Building a Research Methodology in Finance

Faithful rebuild of the Week 5 lecture "Building a Research Methodology in Finance:
Empirical and Theoretical Foundations", plus a closing bridge section into the five
paper-replication weeks.

## Objectives

- Explain why rigorous methodology bridges economic theory and empirical data.
- Distinguish cross-sectional, time series and panel data, with the strengths and
  requirements of each.
- Plan sampling, data sources (CRSP, TAQ, Compustat, central bank data) and research ethics.
- Map the econometric toolkit: OLS and IV, ARCH/GARCH, event studies, VAR, Granger
  causality, BEKK spillovers and ICSS structural break detection.
- Recognise and avoid the classic pitfalls: data snooping, omitted variable bias and
  endogeneity, overfitting, survivorship and look-ahead bias.
- Preview the five papers of Weeks 6 to 10 and run the standard data-preparation warm-up
  (load, plot, ADF stationarity test).

## Interactive elements

1. **Event study machine** - seeded canvas simulation of market-model abnormal returns for
   N stocks around an announcement day: sliders for the event-day effect, post-event drift,
   noise sd and the number of events; plots the average CAR against a 95% no-effect band and
   reports the event-window CAR(0, +10) with its t statistic. A "Reading the results" panel links the
   picture to semi-strong efficiency and the FinTech-and-banks example from the source deck.
2. **Warm-up pyrun cell** (five-papers-ahead section) - loads `fx_returns`, plots the EUR
   daily % log returns, and runs an ADF test via statsmodels. Verified locally: 7141 obs,
   mean 0.0002, sd 0.4640, ADF statistic -42.34 (3 lags by AIC) against a 5% critical value
   of -2.86, so returns are emphatically stationary.
3. Two self-check quizzes: choosing the data structure (panel fixed effects) and spotting
   survivorship bias in a backtest.

## The five papers ahead (bridge section)

One slide per paper week, each with the method, why it matters and a link to the unit:

- Week 6: Fama and French (2015), five-factor model - `../lecture06/`
- Week 7: Diebold and Yilmaz (2012), volatility spillovers - `../lecture07/`
- Week 8: Antonakakis, Chatziantoniou and Gabauer (2020), TVP-VAR connectedness - `../lecture08/`
- Week 9: Laurent, Rombouts and Violante (2012), multivariate GARCH forecasting - `../lecture09/`
- Week 10: Gopal and Schnabl (2022), FinTech lenders, RFS replication package - `../lecture10/`

## Files

- `index.html` - reveal.js deck (title, overview, methodology and data, econometric toolkit
  with event-study sim, resources and pitfalls, conclusion, the five papers ahead with the
  pyrun warm-up, summary, references).

## Sources

- `Week 5/Lecture 5(1).pdf` (all 12 pages represented).
- Paper previews drawn from the Week 6 to 10 knowledge-base extractions.
- Data: `data/csv/fx_returns.csv` (browser cell via `load("fx_returns")`).
