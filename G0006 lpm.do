*-------------------------------------------------------------------------------
* This code is originally written by Hiroaki Miyamoto
* (C) Hiroaki Miyamoto
* Please do not circulate this code without author's permission
*-------------------------------------------------------------------------------

capture log close
clear *
set more off


use "https://github.com/htdanil/referenced_to_github/raw/master/G0005%20multipliers_ex.dta", clear

// use multipliers_ex

tsset ifscode year, yearly

gen lny = ln(gdpv)
gen f1 = 100*(lny-l.lny)
gen f2 = 100*(f.lny-l.lny)
gen f3 = 100*(f2.lny-l.lny)
gen f4 = 100*(f3.lny-l.lny)
gen f5 = 100*(f4.lny-l.lny)

gen gry = 100*(lny-l.lny)




gen trend2=trend^2


*-------------------------------------------------------------------------------
*                              Linear Model  
*-------------------------------------------------------------------------------


foreach X in f {
	gen b_`X'=.
	gen se_`X'=.
	
	forvalues y = 1/5 {
			
			areg `X'`y' shock i.year,  cluster(ifscode) absorb(ifscode)			
			
			replace b_`X' = e(N) if _n==20+`y'
			replace se_`X' = e(N_clust) if _n==20+`y'
			
			replace b_`X' =  _b[shock] if _n==`y'+1
			replace se_`X' = _se[shock] if _n==`y'+1
			}
	}
	

*-------------------------------------------------------------------------------
*                      State dependent Fiscal Multipliers  
*-------------------------------------------------------------------------------

summarize gry if shock!=. 
gen f1mn = r(mean)
gen f1se = r(sd)

gen zslack = (gry- f1mn)/ f1se
gen g_slack = exp(-1.5*zslack)/(1+exp(-1.5*zslack))

gen fl_slack_shock  = shock*(1-g_slack) /*boom*/
gen fh_slack_shock  = shock*(g_slack)   /*recession*/


*Endogenous variables: f de p pv u tm emp

foreach X in f{	
	foreach z in slack {
	gen bfh_`z'=.
	gen sefh_`z'=.
	gen bfl_`z' = .
	gen sefl_`z'=.
	
	forvalues y = 1/5 {
	areg `X'`y'  fh_`z'_shock fl_`z'_shock i.year , absorb(ifscode) cluster(ifscode) 
	
	replace bfh_`z'  = _b[fh_`z'] if _n==`y'+1
	replace sefh_`z' = _se[fh_`z'] if _n==`y'+1
	replace bfl_`z'  = _b[fl_`z'] if _n==`y'+1
	replace sefl_`z' = _se[fl_`z'] if _n==`y'+1
	replace bfh_`z'  = e(N) if _n==10+`y'
	replace sefh_`z' = e(N_clust) if _n==10+`y'
	}
}
}

	

