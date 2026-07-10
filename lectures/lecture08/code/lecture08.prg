' =============================================================================
' MANG3095 Advanced Financial Econometrics - Lecture 8
' TVP-VAR dynamic connectedness (Antonakakis, Chatziantoniou and Gabauer 2020,
' Journal of Risk and Financial Management 13(4), 84)
'
' Data: daily EUR/GBP/JPY % log returns vs USD, Dec 1998 - Jul 2018 (T = 7141)
'
' HONEST NOTE ON EVIEWS COVERAGE. EViews estimates VARs natively and, unlike
' Stata, offers the GENERALISED variance decomposition of Pesaran and Shin
' (1998) in the VAR view, so a full-sample or rolling Diebold-Yilmaz table is
' feasible (the rolling loop is sketched below). What EViews does NOT have is
' the paper's TVP-VAR: the sspace object handles single-equation time-varying
' regressions, not a multivariate Kalman filter with forgetting factors and
' an EWMA error covariance. For the paper's exact method use the authors'
' R package ConnectednessApproach (see lecture08.R).
' =============================================================================

' ---------------------------------------------------------------- 1. data
wfopen ..\..\..\data\csv\fx_returns.csv

group fx eur gbp jpy
fx.stats
freeze(tab_corr) fx.cor

' stationarity: ADF with constant; all three reject the unit root
eur.uroot(adf, const)
gbp.uroot(adf, const)
jpy.uroot(adf, const)

' ------------------------------------------- 2. VAR and generalised FEVD
' lag choice: information criteria select 1 lag, as in the paper
var fxvar.ls 1 1 eur gbp jpy

' Generalised variance decomposition, horizon 10:
'   menu route: View > Variance Decomposition...,
'   Factorization: Generalized, Horizon: 10
' The resulting m x m table of shares is the object every Diebold-Yilmaz
' measure is built from:
'   TO_i   = column sum of off-diagonal shares
'   FROM_i = row sum of off-diagonal shares
'   NET_i  = TO_i - FROM_i
'   NPDC_ij = share(j from i) - share(i from j)
'   TCI    = average off-diagonal share * 100

' ------------------------------------------- 3. rolling version (sketch)
' A rolling Diebold-Yilmaz index loops the same estimation over windows:
'   !w = 100
'   for !t = !w to 1428
'     smpl @first+!t-!w @first+!t-1
'     var v{!t}.ls 1 1 eur gbp jpy
'     ' freeze the generalised decomposition, sum the off-diagonals,
'     ' store in a series, delete the temporary objects
'   next
' This reproduces Week 7's approach and its two problems: the arbitrary
' window width and the !w-1 lost observations. The TVP-VAR fixes both.

' ------------------------------------------- 4. the real thing, from R
' library(ConnectednessApproach)
' dca <- ConnectednessApproach(x, model = "TVP-VAR", connectedness = "Time",
'          nlag = 1, nfore = 10,
'          VAR_config = list(TVPVAR = list(kappa1 = 0.99, kappa2 = 0.96,
'                                          prior = "BayesPrior", gamma = 0.01)))

' WHAT TO INTERPRET: on the deck's weekly aggregation (kappa1 = 0.99, H = 10)
' the dynamic total connectedness averages 28.44%, with EUR a net transmitter
' (+3.8) and JPY a net receiver (-4.0): the paper's Table 3 ranking.
' =============================================================================
