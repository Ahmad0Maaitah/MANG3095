' =============================================================
' MANG3095 - Week 6: Fama and French (2015) five-factor model
' Full workflow: load Ken French factors, summary statistics,
' factor spanning regressions, GRS test, robustness checks.
' Data: ../../../data/csv/ff5_monthly.csv, ff5_annual.csv
' (monthly percent returns, July 1963 - August 2022, T = 710)
' =============================================================

' ---- 1. Load the monthly factors into a monthly workfile -----
' wfopen auto-detects the csv, creates a monthly workfile from the
' Date column and imports each column as a series. EViews replaces
' the illegal "-" in Mkt-RF with an underscore: the series arrives
' as mkt_rf (check the workfile window if your version differs).
wfopen "..\..\..\data\csv\ff5_monthly.csv"

' ---- 2. Summary statistics (paper Table 4, Panel A) ----------
' Factors are already percent excess returns per month
group factors mkt_rf smb hml rmw cma
freeze(tab_stats) factors.stats
show tab_stats
freeze(tab_corr) factors.cor
show tab_corr

' t-statistic of each mean: mean / (sd / sqrt(T))
scalar t_hml = @mean(hml) / (@stdev(hml) / @sqrt(@obs(hml)))
scalar t_rmw = @mean(rmw) / (@stdev(rmw) / @sqrt(@obs(rmw)))
scalar t_cma = @mean(cma) / (@stdev(cma) / @sqrt(@obs(cma)))

' ---- 3. Spanning regressions (paper Table 6) -----------------
' Regress each factor on the other four; the intercept C(1) is the
' spanning alpha. A zero alpha means the factor is redundant.
equation eq_mkt.ls mkt_rf c smb hml rmw cma
equation eq_smb.ls smb c mkt_rf hml rmw cma
equation eq_hml.ls hml c mkt_rf smb rmw cma
show eq_hml   ' headline: C(1) ~ -0.09 with |t| ~ 1.1 - redundant
equation eq_rmw.ls rmw c mkt_rf smb hml cma
equation eq_cma.ls cma c mkt_rf smb hml rmw

' ---- 4. GRS test (Gibbons, Ross and Shanken 1989) ------------
' No native EViews command; compute it with matrix algebra.
' GRS 1: are RMW and CMA priced by the FF3 factors (K=3, N=2)?
equation eq_g1.ls rmw c mkt_rf smb hml
equation eq_g2.ls cma c mkt_rf smb hml
vector(2) alpha
alpha(1) = eq_g1.@coefs(1)
alpha(2) = eq_g2.@coefs(1)
matrix(@obs(rmw), 2) resids
eq_g1.makeresids res1
eq_g2.makeresids res2
stomna(res1, rvec1)
stomna(res2, rvec2)
colplace(resids, rvec1, 1)
colplace(resids, rvec2, 2)
scalar T = @obs(rmw)
scalar K = 3
scalar N = 2
matrix sigma = (@transpose(resids) * resids) / (T - K - 1)
group gfac mkt_rf smb hml
stomna(gfac, fmat)
vector mu = @cmean(fmat)
matrix omega = @cov(fmat) * T / (T - 1)
scalar quad_a = @transpose(alpha) * @inverse(sigma) * alpha
scalar quad_f = @transpose(mu) * @inverse(omega) * mu
scalar grs1 = (T - N - K) / N * quad_a / (1 + quad_f)
scalar p1 = 1 - @cfdist(grs1, N, T - N - K)
' Expect GRS ~ 21.7, p ~ 0.000: reject - FF3 cannot price RMW, CMA

' GRS 2 (N=1): is HML priced by the other four? With one test asset
' the GRS statistic is (T-K-1)/T * t(alpha)^2 / (1 + quad_f); use the
' intercept t-statistic from eq_hml: expect GRS ~ 1.1, p ~ 0.29.
scalar t_alpha_hml = eq_hml.@tstats(1)

' ---- 5. Robustness: pre/post 1991 split ----------------------
smpl 1963m07 1990m12
equation eq_hml_pre.ls hml c mkt_rf smb rmw cma    ' alpha ~ 0.21 (t ~ 2.2)
equation eq_rmw_pre.ls rmw c mkt_rf smb hml cma
equation eq_cma_pre.ls cma c mkt_rf smb hml rmw
smpl 1991m01 2022m08
equation eq_hml_post.ls hml c mkt_rf smb rmw cma   ' alpha ~ -0.31 (t ~ -2.5)
equation eq_rmw_post.ls rmw c mkt_rf smb hml cma
equation eq_cma_post.ls cma c mkt_rf smb hml rmw
smpl @all

' ---- 6. Robustness: annual factors ---------------------------
wfopen "..\..\..\data\csv\ff5_annual.csv"
equation eq_hml_a.ls hml c mkt_rf smb rmw cma      ' alpha ~ -3.0 (t ~ -1.8)
equation eq_rmw_a.ls rmw c mkt_rf smb hml cma
equation eq_cma_a.ls cma c mkt_rf smb hml rmw

' What to interpret: all five premiums are positive over 1963-2022;
' HML's spanning alpha is statistically zero once RMW and CMA are in
' the model (FF 2015 Section 7) while RMW and CMA are not redundant;
' the GRS test rejects FF3 against RMW and CMA overwhelmingly; the
' redundancy of HML flips sign across the 1991 split - sample specific.
' =============================================================
