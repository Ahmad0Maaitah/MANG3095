' ------------------------------------------------------------------
' MANG3095 Advanced Financial Econometrics - Lecture 9
' Multivariate GARCH forecasting:
' Laurent, Rombouts and Violante (2012, J. Applied Econometrics
' 27(6), 934-955), "On the forecasting accuracy of multivariate
' GARCH models".
'
' Data: ..\..\..\data\csv\lrv_returns.csv - the paper's OWN
' estimation sample (2,740 daily open-to-close % returns, 10 NYSE
' stocks, from 2 March 1988).
'
' HONESTY NOTE. EViews estimates multivariate GARCH through a
' SYSTEM object: Diagonal VECH, Diagonal BEKK and Constant
' Conditional Correlation (CCC) are built in. The DCC of Engle
' (2002) is NOT a native estimator: use the "DCC GARCH" add-in
' (Add-ins menu > Download Add-ins), or estimate the two steps
' yourself (univariate ARCH equations + a LOGL object for the
' correlation recursion), or switch to Stata/R for DCC proper.
' This program shows the native route plus the univariate step.
' ------------------------------------------------------------------

' 1. Import the csv as an undated workfile --------------------------
wfopen "..\..\..\data\csv\lrv_returns.csv"
' the file carries a stray text row at the end - keep the 2,740 obs:
smpl 1 2740
pagestruct(end=2740) *

' 2. Descriptives and stationarity ----------------------------------
group stocks ko pep pg
freeze(tab_desc) stocks.stats
show tab_desc
' ADF: returns are stationary (the unit root is in prices)
uroot(adf, const) ko
uroot(adf, const) pep
uroot(adf, const) pg

' 3. Univariate GARCH(1,1), one equation per stock ------------------
equation eq_ko.arch(1,1) ko c
equation eq_pep.arch(1,1) pep c
equation eq_pg.arch(1,1) pg c
show eq_ko
' coefficients: C(2) = omega, RESID(-1)^2 = alpha, GARCH(-1) = beta
' expected (KO): omega ~ 0.05, alpha ~ 0.04, beta ~ 0.93,
' persistence ~ 0.97

' conditional variance series for the two-step logic:
eq_ko.makegarch garch_ko
eq_pep.makegarch garch_pep
eq_pg.makegarch garch_pg
series u_ko  = (ko  - @mean(ko))  / @sqrt(garch_ko)
series u_pep = (pep - @mean(pep)) / @sqrt(garch_pep)
series u_pg  = (pg  - @mean(pg))  / @sqrt(garch_pg)
' the correlation targets (compare the deck: 0.44, 0.43, 0.33):
scalar rbar_ko_pep = @cor(u_ko, u_pep)
scalar rbar_ko_pg  = @cor(u_ko, u_pg)
scalar rbar_pep_pg = @cor(u_pep, u_pg)

' 4. Native multivariate route: SYSTEM ARCH -------------------------
' Menu route (recommended): Object > New Object > System, then
'   ko  = c(1)
'   pep = c(2)
'   pg  = c(3)
' Proc > Estimate > method "ARCH - Conditional Heteroskedasticity",
' choose "Constant Conditional Correlation" (the CCC of Bollerslev
' 1990, the paper's benchmark) or "Diagonal BEKK" (Engle-Kroner
' 1995), GARCH(1,1) errors. Command equivalent (check the System::
' arch entry of your version's Command Reference for the exact
' option names before running):
system mgsys
mgsys.append ko = c(1)
mgsys.append pep = c(2)
mgsys.append pg = c(3)
' mgsys.arch(1,1,model=ccc) @ diagvech
show mgsys

' After estimation: View > Conditional Covariances gives the H_t
' paths; Proc > Make GARCH Variance Series exports them; forecasts
' come from Proc > Forecast.

' 5. What EViews cannot do here -------------------------------------
' - DCC(1,1): use the DCC add-in or the LOGL object with the
'   recursion Q_t = (1-a-b)*Qbar + a*u(-1)u(-1)' + b*Q(-1)
' - MCS / SPA tests: not available; export the loss series
'   (Frobenius, QLIKE) and run R's MCS package or OxMetrics -
'   the authors themselves used Ox with G@RCH 6.
' ------------------------------------------------------------------
