' =============================================================
' MANG3095 - Week 7: Volatility spillovers (Diebold & Yilmaz 2012)
' EViews workflow on the module FX data (EUR/GBP/JPY daily % returns)
' Run from inside lectures/lecture07/code/ (data paths are relative)
' =============================================================

' ---------- 1. Load the data ----------
wfopen ..\..\..\data\csv\fx_returns.csv
' imports as an undated workfile with series eur, gbp, jpy (T = 7141
' daily % log changes of each dollar exchange rate, Dec 1998 - Jul 2018)

' ---------- 2. Stationarity (ADF with constant) ----------
uroot(adf, const) eur
uroot(adf, const) gbp
uroot(adf, const) jpy
' all three ADF statistics are around -42 vs a 5% cv of -2.86:
' returns are stationary, so the VAR below is on safe ground

' ---------- 3. VAR and lag-length criteria ----------
var fxvar.ls 1 2 eur gbp jpy
freeze(tab_lag) fxvar.laglen(8)
show tab_lag
' AIC -> 4, SC -> 1, HQ -> 2; the deck's baseline is p = 2 and
' p = 1..4 is a robustness dimension (the paper varies 2 to 6)

' ---------- 4. Variance decomposition at horizon 10 ----------
' Menu route: open fxvar, View > Variance Decomposition, horizon 10.
freeze(tab_fevd) fxvar.decomp(10)
show tab_fevd
' HONEST NOTE: EViews 12 and later offer a "Generalized" factorization
' choice in the variance decomposition dialog, matching DY 2012.
' Older versions offer Cholesky (ordering matters!) and structural
' factors only - if that is what you have, say so in your write-up and
' show the ordering sensitivity by re-estimating with a reversed order:
var fxvar2.ls 1 2 jpy gbp eur
freeze(tab_fevd2) fxvar2.decomp(10)
show tab_fevd2

' Generalized IMPULSE RESPONSES (Pesaran-Shin) are available in all
' recent EViews versions and are ordering-invariant:
freeze(gr_girf) fxvar.impulse(10, imp=gen)
show gr_girf

' ---------- 5. Rolling windows ----------
' EViews does not automate rolling variance decompositions; a program
' loop over smpl statements would be needed, storing each table:
'   for !s = 1 to 6941 step 5
'     smpl @first+!s @first+!s+199
'     fxvar.ls 1 2 eur gbp jpy
'     ...
'   next
' For this step use code/lecture07.R (ConnectednessApproach) or
' code/lecture07.py, which produce the rolling index in seconds.

' ------------------------------------------------------------------
' What to interpret: with the generalized decomposition the full-sample
' total connectedness index (p = 2, H = 10) is 23.68%; EUR is the net
' transmitter (+2.45 pp) and JPY the net receiver (-2.30 pp). Under
' Cholesky the total spans 15.31-16.01% depending on the ordering -
' the paper's motivating problem, visible in tab_fevd vs tab_fevd2.
' ------------------------------------------------------------------
