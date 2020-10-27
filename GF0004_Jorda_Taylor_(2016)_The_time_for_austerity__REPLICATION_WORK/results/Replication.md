[Jordà, Ò., & Taylor, A. M. (2016). The time for austerity: estimating the average treatment effect of fiscal policy. _The Economic Journal_, _126_(590), 219-255.](https://onlinelibrary.wiley.com/doi/abs/10.1111/ecoj.12332)

Replication Code Downloaded from https://sites.google.com/site/oscarjorda/home/local-projections

<b>Table of Contents</b>
<div id="toc"></div>


```javascript
%%javascript
$.getScript('https://kmahelona.github.io/ipython_notebook_goodies/ipython_notebook_toc.js')
```


    <IPython.core.display.Javascript object>



```python
#--------------------------------------------------------------------------------------------
# Necessary packages loading for python
#--------------------------------------------------------------------------------------------
import ipystata #package for executing stata code from python
import wget
from pathlib import Path
import os
```


```python
#--------------------------------------------------------------------------------------------
# Downloading data from Github repository
#--------------------------------------------------------------------------------------------
path = 'https://github.com/htdanil/referenced_to_github/raw/master/GF0004_Jorda_Taylor_(2016)_The_time_for_austerity__REPLICATION_WORK/dataset/'
datasets = ['01_wdi_worldgdp.xlsx',
           '02_JST_panel2_v1.dta',
           '03_IMF-fiscalshocks.dta',
           '04_Leigh_database.dta',
           '05_IMFWEO_AUTIRL.dta',
           '06_03YR.xlsx',
           '07_aut_irl_8Apr2013.xlsx',
           '08_austria_gaggl.dta']

#creating data folder for downloading datasets
try:
    os.mkdir('data')
except:
    pass

for x in datasets:
    already_exists = len(list(Path().rglob(x))) #checking whether file exists or not
    
    if already_exists == 0:
        wget.download(path + x, 'data')
```

---
# globals.do
---


```python
%%stata -os -cwd
* #stata globals
global tHi	a
global tMid	b
global tHi	c
global tPool d

global fe1
global fe2 wgdp

* #RHS 1 variable set
global rhs1 dly ldly

* #RHS 6 variable set (excluding output)
global rhs6 drprv dlcpi dlriy stir ltrate cay ///
        ldrprv ldlcpi ///
        ldlriy lstir lltrate lcay

* #RHS 7 variable set
global rhs7 drprv dly dlcpi dlriy stir ltrate cay ///
        ldrprv ldly ldlcpi ///
        ldlriy lstir lltrate lcay	

```

    Set the working directory of Stata to: G:\My Drive\anilsth@iuj.ac.jp\Hiroshima Study\Research works\Replication - The time for Austerity
    

---
# dataset.do
---


```python
%%capture
%%stata -os
clear
*#================================================================
*# importing excel data and saving it in tempfile for later use
*#================================================================
import excel  using data/01_wdi_worldgdp.xlsx, firstrow
tempfile wgdp
save `wgdp'

*#================================================================
* #read in the JST dataset
*#================================================================
use data/02_JST_panel2_v1.dta, clear
replace iso="PRT" if iso=="POR"

*#================================================================
* #read in the full IMF-GLP dataset from Leigh and merging it
*#================================================================
sort iso year
merge 1:1 iso year using data/03_IMF-fiscalshocks.dta
drop _merge //#dropping the column created on the merge process

*#================================================================
* #get the Leigh and AA variables
*#================================================================
sort iso year
tempfile data
save `data'

use data/04_Leigh_database.dta, clear
gen iso = wdicode
merge 1:1 iso year using `data'
drop _merge

*#================================================================
* #merge in AUT IRL data from WEO Oct 2012 to fill some gaps
* #to deal with missing data for AUT and IRL
*#================================================================
merge 1:1 iso year using data/05_IMFWEO_AUTIRL.dta
drop _merge
replace debtgdp = debtgdpweo/100 if iso=="IRL"|iso=="AUT"
gen rgdpnew = rgdpbarro
replace rgdpnew = rgdpweo if iso=="IRL"|iso=="AUT"

*#================================================================
* #cut down to the 17 country sample to match the IMF
*#================================================================
drop if iso=="CHE"
drop if iso=="NOR"

*#================================================================
* #read in world GDP back in here
*#================================================================
merge m:1 year using `wgdp'
drop _merge
```


```python
%%capture
%%stata -o stata_df -os
*#================================================================
* #create treatment variable (fiscal consolidation action according to IMF)
*#================================================================
gen treatment = 0 if year>=1978 & year<=2007
replace treatment = 1 if total ~= . //# set treatment variable to 1 if total variable is not set to null
gen control = 1-treatment //#generating control variable which is opposite of treatment. Control means not received any treatment.

replace total = 0 if treatment == 0
replace tax = 0 if treatment == 0
replace spend = 0 if treatment == 0
```


```python
%%stata -os
*#================================================================
* #defining panel dataset
*#================================================================
capture drop ccode //# does not show any error if drop ccode throws any error
egen ccode=group(iso)
sort iso year
xtset ccode year //#defining panel data
```

    
    (1 missing value generated)
    
           panel variable:  ccode (unbalanced)
            time variable:  year, 1977 to 2011
                    delta:  1 year
    
    


```python
%%capture
%%stata -os
*#================================================================================
* #treatment happens at t=1 in IMF study setup, but known at t=0
* #use ftreatment as the indicator of policy choice at t=0 to match the IMF setup
*#=================================================================================
gen ftreatment = f.treatment

* #drop events around time of German reunification to match AA variable
replace ftreatment=. if iso=="DEU" & year ==1990 | iso=="DEU" & year ==1991


* #save to tempfile for later use
tempfile data
save `data'
```


```python
%%capture
%%stata -os
*#================================================================================
* #more gaps to fill for broad datset
*** #read in short- and long-term interest rates for IRL // 
*** #short-term data from Israel Malkin
*** #long-term data from Alan
*#================================================================================
clear
import excel using data/06_03YR.xlsx, sheet(IRL) firstrow

gen d = date(date, "MDY")
format d %td
gen year = year(d)
rename IRL stir
collapse stir, by(year) //# creating average of stir variable by year
replace stir=16 if year == 1992 // #this is a fix for the code error in the data
replace stir = stir/100 
gen iso = "IRL"

tempfile sIRL
save `sIRL'
clear

import excel  using data/07_aut_irl_8Apr2013.xlsx, firstrow //# IRL ltrate from Alan
destring year, replace //#converting year from string to numerical value
keep year iso ltrate 
keep if iso=="IRL"
merge 1:1 iso year using `sIRL'
drop _merge
tempfile IRL
save `IRL'
clear
```


```python
%%capture
%%stata -os
*#================================================================================
*** #read in data for AUT from Paul Gaggl
*#================================================================================
use data/08_austria_gaggl.dta
rename  at_i_3m_a stir
rename at_i_10y_a ltrate
replace stir = stir/100
replace ltrate = ltrate/100
merge 1:1 iso year using `IRL'
drop _merge

merge 1:1 iso year using `data'
drop _merge

gen lrgdp   = log(rgdpbarro) // #real GDP index from Barro
gen lrcon   = log(rconsbarro) // #real consumption index from Barro
gen lmoney  = log(money) // #M2, more or less
gen lstocks = log(stocks) // #Stock indices
gen lnarrow = log(narrowm) // #M1, more or less
gen cay = ca/gdp // #Current Account over GDP ratio
gen lloans  = log(loans1)

tempfile data
save `data'
clear
```


```python
%%capture
%%stata -os
*#================================================================================
*** #read in data from Alan for AUT and IRL except for interest rates 
* #(goes in here because he already applied the necessary transformations)
*#================================================================================

import excel using data/07_aut_irl_8Apr2013.xlsx, firstrow
destring year, replace
drop ltrate
merge 1:1 year iso using `data'
drop _merge

replace ccode = 2 if ccode==. & iso=="AUT"
replace ccode = 11 if ccode==. & iso=="IRL"

replace cay = cay/100 if iso=="AUT" | iso=="IRL"
gen lcpi    = log(cpi)  //#CPI
gen lpop    = log(pop)

replace lrgdp = log(rgdp) - lpop if iso=="AUT" | iso=="IRL" //# log of per capita GDP

gen rprv  = lloans - lcpi - lpop  // #real per capita private loans
replace rprv = log(realloans) - lpop if iso=="AUT" | iso=="IRL"

gen riy = iy*rgdpbarro // #real per capita investment
replace riy = realinv/pop if iso=="AUT" | iso=="IRL"
gen lriy = log(riy)

gen rlmoney = lmoney - lcpi

sort ccode year
gen dlrgdp  = 100*d.lrgdp // #Annual real per capita GDP growth in percent
gen dlriy = 100*d.lriy // #Annual real per capita investment growth in percent
gen dlcpi   = 100*d.lcpi // #Annual inflation in percent
gen dlrcon  = 100*d.lrcon // #Annual real consumption growth in percent

gen drprv = 100*d.rprv // #Annual real per capita private loan growth 
gen drlmoney= 100*d.rlmoney  // #Annual Growth in M2 

replace cay = 100*cay
replace stir = 100*stir
replace ltrate = 100*ltrate 
```


```python
%%capture
%%stata -os
*#================================================================================
* #match IMF: cumulate IMF real GDP growth rate (N=17) to recoup levels
* #g = growth of real GDP (OECD)
*#================================================================================
gen dlogy = log(1+g) if year>=1978 //# log(1+g) is to create log of Y difference variable i.e. growth of Y using log difference
by ccode: gen logyIMF=sum(dlogy) if year>=1978 // #creating cummulative column of dlogy
by ccode: replace logyIMF=0 if year==1977 // #start year =0

```

---
# datset now complete
## now prepare for the empirical analysis

---


```python
%%capture
%%stata -os
*#================================================================================
* #define dependent variable and lags
*#================================================================================
gen ly = 100*logyIMF //# converted in % multiplying by 100. logyIMF is cummulative growth rate by ccode
gen dly = d.ly //#non-cummulative growth rate (I guess)
gen ldly = l.dly

*#================================================================================
* #generate lags of the broad set of controls
*#================================================================================
gen ldrprv = l.drprv 
gen ldlcpi = l.dlcpi
gen ldlriy = l.dlriy 
gen lstir = l.stir 
gen lltrate = l.ltrate 
gen lcay = l.cay

*#================================================================================
* #construct the HP filter of log y
*#================================================================================
drop if year > 2011

bysort ccode: hprescott ly, stub(HP) smooth(100) //#creates separate columns for each ccode
* #VERY HIGH smoothing (cf 6.25 Ravn-Uhlig)
* #but we want something like "output gap"

*#since the above code creates separate columns for HP extraction for each ccode,
*# the following code creates a single column for cyclical component
summarize ccode
local countries = r(max) //#number of countries

gen hply=.
forvalues i=1/`countries' {
	replace hply = HP_ly_`i' if ccode==`i'
}

*#================================================================================
* #now drop unwanted years after the HP filtering
* #all regressions are restricted to year>=1980 & year<=2007
*#================================================================================
drop if year<=1977
drop if year>=2008

*#================================================================================
* #bins - dividing whole dataset into group based on cyclical component of HP filter on Y
*#================================================================================
gen boom = cond(hply > +0,1,0) //#if positive boom
gen slump = 1 - boom

gen Hi = cond(hply > +1, 1, 0) //# if greater than +1 High, from +1 to -1 Medium and Less or equal to -1 low
gen Mid = cond(hply>-1 & hply<= +1, 1, 0)
gen Low = 1 - Hi - Mid

*#================================================================================
* #dummy interactions
*#================================================================================
gen ccodeLMH = ccode
replace ccodeLMH =  ccodeLMH+100 if Mid==1 //#greater than 100 ccode represents Medium, greater than 200 High, and less than 100 low
replace ccodeLMH =  ccodeLMH+200 if Hi==1
tabulate ccodeLMH, gen(ccodeLMHdum) //# generating dummy variable based on tabulation of ccodeLMH

*#================================================================================
* #dep vars for h-step ahead forecast (h=1,...,5)
*#================================================================================

local var ly ftreatment // #ftreatment depvar used in Table A5. storing ly and ftreatment variable in local macro named var

foreach v of local var { //#looping through var macro i.e. ly and ftreatment
    forvalues i=1/5 { //#looping through horizon 1 to 5

        if "`v'"=="ly" {
            gen `v'`i' = f`i'.`v' - `v' //#generating dependent variable, Y(t+h) - Y(t)
        }

        if "`v'"=="ftreatment" { //#creating ftreatment variable for horizon 
            gen `v'`i' = f`i'.`v'
        }
        label var `v'`i' "Year `i'" //#labelling newly created variable
    }
}

gen ly6 = (ly1+ly2+ly3+ly4+ly5)
label var ly6 "Sum" //# sum column for total effect

*#================================================================================
* # transform and interact AA dCAPB measure
*#================================================================================
gen AA = AA_dcapb * 100
gen fAA = f.AA
gen lfAA = l.fAA //# AA and lfAA is the same thing
gen fAAMid = fAA * Mid
gen fAALo = fAA * Lo

* #housekeeping
tab year, gen(y)
tabulate year, gen(dumyr)
tabulate iso, gen(dumiso)

*#================================================================================
* #dmdum = demeaned dummies
* #demeaned dummy variable
*#================================================================================
forvalues k = 1/17 {
    gen dmdumiso`k' = dumiso`k' - 1/17 //# mean is 1 divided by 17 (1/17). There is 17 countries.
}

*#================================================================================
* #dml0dly dml1dly = demeaned growth rates
* # demeaned growth rates
*#================================================================================
sum dly
gen dml0dly = dly - r(mean)

sum ldly
gen dml1dly = ldly - r(mean)

```

---
# table1.do
---

![Table1](https://github.com/htdanil/referenced_to_github/raw/master/GF0004_Jorda_Taylor_%282016%29_The_time_for_austerity__REPLICATION_WORK/results/table1.PNG)

### For the summarized result of the code in the following cell, click the link below 

[Link to see summarized results](https://github.com/htdanil/referenced_to_github/blob/master/GF0004_Jorda_Taylor_%282016%29_The_time_for_austerity__REPLICATION_WORK/results/table1_summarized.pdf)


```python
%%stata -os
*#================================================================================
* #Table 1: Fiscal muliplier, d.CAPB, OLS estimate
*#================================================================================

gen lgfAA = 0
replace lgfAA = fAA if abs(fAA)>1.5 //# Fiscal multiplier, large change in CAPB (> 1.5%)

gen smfAA = 0
replace smfAA = fAA if abs(fAA)<=1.5 //# Fiscal multiplier, small change in CAPB (<= 1.5%)

*** #OLS AA all changes in dCAPB full sample
label var fAA "Fisc multiplier. Full sample"
label var lgfAA "Fisc multiplier. Large Cons."
label var smfAA "Fisc multiplier. Small Cons."


forvalues i=1/6 {
    * #the dummy for the U.S. is dropped to avoid collinearity with the constant
    * #specification a la AA
    reg ly`i'   fAA ///
        hply dml0dly dml1dly dmdumiso1-dmdumiso16 ///
        if year>=1980 & year<=2007,  cluster(iso) 
   
    reg ly`i'   smfAA lgfAA  ///
        hply dml0dly dml1dly dmdumiso1-dmdumiso16  ///
        if year>=1980 & year<=2007,  cluster(iso) 

}
```

    
    (159 real changes made, 19 to missing)
    
    (351 real changes made)
    
    Linear regression                               Number of obs     =        457
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6087
                                                    Root MSE          =      1.218
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .1148758   .0403991     2.84   0.012     .0292337     .200518
            hply |   -.493521    .038125   -12.94   0.000    -.5743423   -.4126996
         dml0dly |   .5772986   .0369698    15.62   0.000     .4989261    .6556711
         dml1dly |   .1789687   .0414609     4.32   0.001     .0910755    .2668619
       dmdumiso1 |     .04388   .0105103     4.17   0.001     .0215993    .0661608
       dmdumiso2 |   -.253133   .0310123    -8.16   0.000    -.3188762   -.1873898
       dmdumiso3 |  -.3486068   .0409988    -8.50   0.000    -.4355205   -.2616931
       dmdumiso4 |  -.1097549   .0199835    -5.49   0.000     -.152118   -.0673918
       dmdumiso5 |  -.3857143   .0477369    -8.08   0.000     -.486912   -.2845165
       dmdumiso6 |   -.249429   .0381773    -6.53   0.000    -.3303613   -.1684966
       dmdumiso7 |  -.0655346   .0164888    -3.97   0.001    -.1004893     -.03058
       dmdumiso8 |  -.0679739   .0162478    -4.18   0.001    -.1024177   -.0335301
       dmdumiso9 |  -.2398741   .0312477    -7.68   0.000    -.3061162   -.1736321
      dmdumiso10 |   -.092122   .0210767    -4.37   0.000    -.1368026   -.0474414
      dmdumiso11 |   .6676884   .0693865     9.62   0.000     .5205956    .8147813
      dmdumiso12 |  -.4004013   .0444542    -9.01   0.000    -.4946399   -.3061626
      dmdumiso13 |  -.2600278   .0203448   -12.78   0.000    -.3031568   -.2168988
      dmdumiso14 |  -.1993819   .0267761    -7.45   0.000    -.2561446   -.1426192
      dmdumiso15 |  -.2187938   .0198589   -11.02   0.000    -.2608929   -.1766947
      dmdumiso16 |  -.2007123   .0394967    -5.08   0.000    -.2844416   -.1169831
           _cons |   2.601446   .0075026   346.74   0.000     2.585541    2.617351
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        457
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6090
                                                    Root MSE          =     1.2188
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .0562097   .0734119     0.77   0.455    -.0994165    .2118359
           lgfAA |   .1237715   .0438159     2.82   0.012     .0308861     .216657
            hply |  -.4944241     .03853   -12.83   0.000     -.576104   -.4127442
         dml0dly |   .5795215   .0372326    15.56   0.000     .5005919     .658451
         dml1dly |   .1780666   .0414373     4.30   0.001     .0902236    .2659097
       dmdumiso1 |   .0497576   .0076006     6.55   0.000      .033645    .0658701
       dmdumiso2 |  -.2571699   .0294569    -8.73   0.000    -.3196158    -.194724
       dmdumiso3 |   -.343519   .0428878    -8.01   0.000     -.434437    -.252601
       dmdumiso4 |  -.1145839    .020569    -5.57   0.000    -.1581882   -.0709796
       dmdumiso5 |  -.3720599      .0563    -6.61   0.000    -.4914106   -.2527091
       dmdumiso6 |   -.267947   .0359141    -7.46   0.000    -.3440815   -.1918125
       dmdumiso7 |  -.0557479    .020481    -2.72   0.015    -.0991657   -.0123302
       dmdumiso8 |  -.0589884   .0208038    -2.84   0.012    -.1030905   -.0148864
       dmdumiso9 |  -.2282754   .0392894    -5.81   0.000    -.3115653   -.1449856
      dmdumiso10 |  -.0824753   .0276996    -2.98   0.009    -.1411958   -.0237548
      dmdumiso11 |   .6674062   .0679353     9.82   0.000     .5233899    .8114225
      dmdumiso12 |  -.4017212   .0433275    -9.27   0.000    -.4935715    -.309871
      dmdumiso13 |  -.2517396   .0242881   -10.36   0.000    -.3032281    -.200251
      dmdumiso14 |  -.1997862   .0264305    -7.56   0.000    -.2558164   -.1437561
      dmdumiso15 |  -.2295348   .0224333   -10.23   0.000    -.2770914   -.1819783
      dmdumiso16 |  -.1997813   .0396263    -5.04   0.000    -.2837852   -.1157774
           _cons |   2.602915   .0077443   336.11   0.000     2.586498    2.619332
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        440
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7524
                                                    Root MSE          =     1.7198
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .1239696   .0521561     2.38   0.030     .0134037    .2345355
            hply |  -1.264743   .0587056   -21.54   0.000    -1.389193   -1.140293
         dml0dly |   .8217975   .0361425    22.74   0.000     .7451788    .8984163
         dml1dly |   .5249845    .055152     9.52   0.000     .4080676    .6419015
       dmdumiso1 |   .1099093   .0248123     4.43   0.000     .0573096     .162509
       dmdumiso2 |  -.5096218   .0574688    -8.87   0.000    -.6314502   -.3877934
       dmdumiso3 |  -.6853585   .0734686    -9.33   0.000     -.841105   -.5296119
       dmdumiso4 |  -.2268698   .0295255    -7.68   0.000    -.2894611   -.1642785
       dmdumiso5 |  -.7423369   .0921445    -8.06   0.000    -.9376745   -.5469993
       dmdumiso6 |  -.5042371   .0722894    -6.98   0.000    -.6574837   -.3509905
       dmdumiso7 |  -.0352366   .0212311    -1.66   0.116    -.0802445    .0097713
       dmdumiso8 |  -.1772899   .0272416    -6.51   0.000    -.2350396   -.1195403
       dmdumiso9 |  -.5628764   .0662015    -8.50   0.000    -.7032173   -.4225354
      dmdumiso10 |  -.1915511   .0397859    -4.81   0.000    -.2758935   -.1072087
      dmdumiso11 |   1.712009   .1495998    11.44   0.000     1.394872    2.029147
      dmdumiso12 |  -.8995998   .0804948   -11.18   0.000    -1.070241   -.7289585
      dmdumiso13 |   -.723017    .031798   -22.74   0.000    -.7904257   -.6556082
      dmdumiso14 |  -.3516075   .0483843    -7.27   0.000    -.4541776   -.2490373
      dmdumiso15 |  -.3892616   .0291605   -13.35   0.000     -.451079   -.3274441
      dmdumiso16 |  -.3991153   .0635146    -6.28   0.000    -.5337603   -.2644703
           _cons |   5.147467   .0086359   596.06   0.000      5.12916    5.165775
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        440
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7524
                                                    Root MSE          =     1.7218
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .1083591   .1492654     0.73   0.478    -.2080695    .4247876
           lgfAA |   .1263152   .0534039     2.37   0.031     .0131039    .2395265
            hply |   -1.26499   .0591153   -21.40   0.000    -1.390309   -1.139671
         dml0dly |   .8224176    .037654    21.84   0.000     .7425947    .9022405
         dml1dly |   .5247519   .0549846     9.54   0.000     .4081898    .6413141
       dmdumiso1 |   .1111748   .0254508     4.37   0.000     .0572215     .165128
       dmdumiso2 |  -.5113324   .0554131    -9.23   0.000     -.628803   -.3938618
       dmdumiso3 |  -.6838726   .0778021    -8.79   0.000    -.8488058   -.5189394
       dmdumiso4 |  -.2283997   .0294203    -7.76   0.000     -.290768   -.1660315
       dmdumiso5 |  -.7385977    .104807    -7.05   0.000    -.9607788   -.5164167
       dmdumiso6 |  -.5090559   .0731323    -6.96   0.000    -.6640895   -.3540224
       dmdumiso7 |  -.0326044   .0344472    -0.95   0.358    -.1056293    .0404205
       dmdumiso8 |  -.1753051   .0355816    -4.93   0.000    -.2507348   -.0998754
       dmdumiso9 |  -.5597961   .0771725    -7.25   0.000    -.7233945   -.3961977
      dmdumiso10 |  -.1891867   .0489905    -3.86   0.001    -.2930419   -.0853314
      dmdumiso11 |   1.711289   .1511217    11.32   0.000     1.390925    2.031652
      dmdumiso12 |  -.8999828   .0797289   -11.29   0.000    -1.069001    -.730965
      dmdumiso13 |  -.7211629   .0391274   -18.43   0.000    -.8041092   -.6382165
      dmdumiso14 |   -.351646   .0483124    -7.28   0.000    -.4540636   -.2492284
      dmdumiso15 |  -.3933663   .0402121    -9.78   0.000    -.4786121   -.3081205
      dmdumiso16 |   -.399495   .0627446    -6.37   0.000    -.5325077   -.2664824
           _cons |   5.147873   .0099891   515.35   0.000     5.126697    5.169049
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        423
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8379
                                                    Root MSE          =      1.901
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.0350636   .0369413    -0.95   0.357    -.1133757    .0432486
            hply |  -1.948935   .0547352   -35.61   0.000    -2.064969   -1.832902
         dml0dly |   .9153188   .0639588    14.31   0.000     .7797322    1.050905
         dml1dly |   .7557194   .0634068    11.92   0.000     .6213029    .8901359
       dmdumiso1 |   .2649788    .032062     8.26   0.000     .1970103    .3329472
       dmdumiso2 |  -1.057456   .0925043   -11.43   0.000    -1.253556   -.8613555
       dmdumiso3 |  -1.282881   .1106196   -11.60   0.000    -1.517384   -1.048378
       dmdumiso4 |  -.3465643   .0363389    -9.54   0.000    -.4235994   -.2695292
       dmdumiso5 |  -1.500266   .1406158   -10.67   0.000    -1.798358   -1.202173
       dmdumiso6 |  -1.193822   .1132438   -10.54   0.000    -1.433888   -.9537558
       dmdumiso7 |  -.1600468   .0256694    -6.23   0.000    -.2144635   -.1056301
       dmdumiso8 |  -.6064806   .0449058   -13.51   0.000    -.7016766   -.5112845
       dmdumiso9 |  -1.317156   .1050119   -12.54   0.000    -1.539771    -1.09454
      dmdumiso10 |  -.6189505   .0600991   -10.30   0.000    -.7463549    -.491546
      dmdumiso11 |   3.155294   .2292756    13.76   0.000     2.669252    3.641337
      dmdumiso12 |  -1.819432    .123924   -14.68   0.000     -2.08214   -1.556725
      dmdumiso13 |  -1.444697   .0401646   -35.97   0.000    -1.529842   -1.359552
      dmdumiso14 |   -.585384   .0739038    -7.92   0.000    -.7420531   -.4287149
      dmdumiso15 |  -.7123553   .0330294   -21.57   0.000    -.7823745    -.642336
      dmdumiso16 |  -.9217511   .0965047    -9.55   0.000    -1.126332   -.7171702
           _cons |   7.717404     .00876   880.98   0.000     7.698834    7.735974
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        423
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8380
                                                    Root MSE          =     1.9029
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .0288546   .1428788     0.20   0.843    -.2740349    .3317441
           lgfAA |  -.0444405   .0423366    -1.05   0.309      -.13419    .0453091
            hply |   -1.94748    .053603   -36.33   0.000    -2.061113   -1.833847
         dml0dly |   .9127479   .0627636    14.54   0.000      .779695    1.045801
         dml1dly |   .7563984   .0634007    11.93   0.000     .6219949    .8908019
       dmdumiso1 |   .2578043   .0380152     6.78   0.000     .1772156    .3383929
       dmdumiso2 |  -1.053012    .094929   -11.09   0.000    -1.254253   -.8517719
       dmdumiso3 |  -1.292111   .1071179   -12.06   0.000    -1.519191   -1.065031
       dmdumiso4 |  -.3429743   .0387243    -8.86   0.000    -.4250662   -.2608824
       dmdumiso5 |  -1.518637   .1365673   -11.12   0.000    -1.808146   -1.229127
       dmdumiso6 |  -1.177627   .1256949    -9.37   0.000    -1.444088   -.9111652
       dmdumiso7 |   -.171011   .0324337    -5.27   0.000    -.2397673   -.1022548
       dmdumiso8 |   -.615271   .0435633   -14.12   0.000    -.7076211   -.5229209
       dmdumiso9 |  -1.330812   .1013548   -13.13   0.000    -1.545675    -1.11595
      dmdumiso10 |  -.6289242   .0590699   -10.65   0.000    -.7541467   -.5037017
      dmdumiso11 |   3.160007   .2263878    13.96   0.000     2.680086    3.639927
      dmdumiso12 |  -1.815824   .1256289   -14.45   0.000    -2.082145   -1.549502
      dmdumiso13 |  -1.455687    .041552   -35.03   0.000    -1.543773   -1.367601
      dmdumiso14 |  -.5874271   .0726838    -8.08   0.000    -.7415098   -.4333444
      dmdumiso15 |  -.6973476   .0526868   -13.24   0.000    -.8090386   -.5856567
      dmdumiso16 |  -.9218565   .0960509    -9.60   0.000    -1.125475   -.7182377
           _cons |   7.716036   .0091576   842.58   0.000     7.696623     7.73545
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        406
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8705
                                                    Root MSE          =     2.0956
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.2053227   .0701557    -2.93   0.010    -.3540462   -.0565991
            hply |  -2.456078    .092912   -26.43   0.000    -2.653042   -2.259113
         dml0dly |   .8088781   .0877521     9.22   0.000     .6228519    .9949043
         dml1dly |   .9998579   .1295786     7.72   0.000     .7251635    1.274552
       dmdumiso1 |   .6550974   .0475187    13.79   0.000     .5543623    .7558325
       dmdumiso2 |  -1.750569   .1574163   -11.12   0.000    -2.084276   -1.416861
       dmdumiso3 |  -1.929367   .2004587    -9.62   0.000    -2.354321   -1.504414
       dmdumiso4 |  -.5068226   .0657268    -7.71   0.000    -.6461571    -.367488
       dmdumiso5 |  -2.485161   .2258996   -11.00   0.000    -2.964047   -2.006275
       dmdumiso6 |  -2.036984   .1908749   -10.67   0.000    -2.441621   -1.632347
       dmdumiso7 |  -.2156499   .0507799    -4.25   0.001    -.3232984   -.1080014
       dmdumiso8 |  -1.147559   .0823916   -13.93   0.000    -1.322221   -.9728961
       dmdumiso9 |  -2.197529    .179435   -12.25   0.000    -2.577914   -1.817144
      dmdumiso10 |   -1.12334   .1029276   -10.91   0.000    -1.341537   -.9051436
      dmdumiso11 |   5.148325   .3890289    13.23   0.000      4.32362    5.973029
      dmdumiso12 |  -2.909061   .2058989   -14.13   0.000    -3.345547   -2.472575
      dmdumiso13 |  -2.168039   .0684488   -31.67   0.000    -2.313144   -2.022934
      dmdumiso14 |  -.8211741   .1269562    -6.47   0.000    -1.090309   -.5520391
      dmdumiso15 |  -.9762923     .04776   -20.44   0.000    -1.077539   -.8750457
      dmdumiso16 |  -1.543204   .1747073    -8.83   0.000    -1.913567   -1.172841
           _cons |   10.29925   .0109167   943.44   0.000     10.27611    10.32239
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        406
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8708
                                                    Root MSE          =     2.0963
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.0658113   .1933824    -0.34   0.738    -.4757637    .3441411
           lgfAA |  -.2255097   .0742749    -3.04   0.008    -.3829653    -.068054
            hply |  -2.452247   .0894515   -27.41   0.000    -2.641876   -2.262618
         dml0dly |   .8037066   .0832751     9.65   0.000     .6271713    .9802419
         dml1dly |   1.000374   .1293145     7.74   0.000     .7262397    1.274509
       dmdumiso1 |   .6344437   .0644752     9.84   0.000     .4977624     .771125
       dmdumiso2 |  -1.748202   .1569738   -11.14   0.000    -2.080972   -1.415433
       dmdumiso3 |  -1.953208   .1846511   -10.58   0.000     -2.34465   -1.561765
       dmdumiso4 |   -.503462   .0667195    -7.55   0.000     -.644901    -.362023
       dmdumiso5 |  -2.529346   .1997641   -12.66   0.000    -2.952827   -2.105865
       dmdumiso6 |  -2.007482   .2101516    -9.55   0.000    -2.452984   -1.561981
       dmdumiso7 |  -.2393206   .0495948    -4.83   0.000    -.3444568   -.1341844
       dmdumiso8 |  -1.171682   .0697763   -16.79   0.000    -1.319601   -1.023762
       dmdumiso9 |  -2.230557   .1589769   -14.03   0.000    -2.567573   -1.893541
      dmdumiso10 |  -1.148185   .0906681   -12.66   0.000    -1.340392   -.9559768
      dmdumiso11 |   5.156285   .3798184    13.58   0.000     4.351106    5.961464
      dmdumiso12 |  -2.910005   .2026444   -14.36   0.000    -3.339592   -2.480418
      dmdumiso13 |  -2.196468   .0601968   -36.49   0.000     -2.32408   -2.068857
      dmdumiso14 |  -.8240057   .1234933    -6.67   0.000      -1.0858   -.5622116
      dmdumiso15 |  -.9452877   .0752508   -12.56   0.000    -1.104812   -.7857633
      dmdumiso16 |  -1.542039   .1730139    -8.91   0.000    -1.908812   -1.175266
           _cons |   10.29806   .0114441   899.86   0.000      10.2738    10.32232
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        389
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8473
                                                    Root MSE          =     2.6611
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.3201197   .1184924    -2.70   0.016    -.5713124    -.068927
            hply |  -2.663626   .1587336   -16.78   0.000    -3.000126   -2.327126
         dml0dly |   .7296746   .1624803     4.49   0.000     .3852317    1.074117
         dml1dly |   1.016057   .1894939     5.36   0.000     .6143481    1.417766
       dmdumiso1 |   1.087813   .0579056    18.79   0.000     .9650587    1.210567
       dmdumiso2 |  -2.327646   .2837015    -8.20   0.000    -2.929066   -1.726225
       dmdumiso3 |  -2.665308   .3478672    -7.66   0.000    -3.402754   -1.927863
       dmdumiso4 |  -.7339883   .1190674    -6.16   0.000    -.9863999   -.4815768
       dmdumiso5 |  -3.475728   .3622261    -9.60   0.000    -4.243613   -2.707843
       dmdumiso6 |  -3.022753   .3152298    -9.59   0.000     -3.69101   -2.354495
       dmdumiso7 |  -.1497423   .0890617    -1.68   0.112    -.3385446    .0390599
       dmdumiso8 |  -1.720247   .1509516   -11.40   0.000     -2.04025   -1.400244
       dmdumiso9 |  -3.144416   .2941618   -10.69   0.000    -3.768011   -2.520821
      dmdumiso10 |  -1.589285   .1714348    -9.27   0.000     -1.95271   -1.225859
      dmdumiso11 |   7.677375   .6213046    12.36   0.000     6.360268    8.994482
      dmdumiso12 |  -4.139843   .3368765   -12.29   0.000    -4.853989   -3.425696
      dmdumiso13 |  -2.835223   .1167008   -24.29   0.000    -3.082618   -2.587829
      dmdumiso14 |  -1.126393   .2023509    -5.57   0.000    -1.555358   -.6974281
      dmdumiso15 |  -.9647972   .0755067   -12.78   0.000    -1.124864   -.8047301
      dmdumiso16 |  -2.325998   .3054778    -7.61   0.000    -2.973582   -1.678414
           _cons |   12.92456   .0209393   617.24   0.000     12.88017    12.96895
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        389
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8474
                                                    Root MSE          =     2.6641
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.2331764   .2823108    -0.83   0.421    -.8316485    .3652957
           lgfAA |  -.3320837     .12201    -2.72   0.015    -.5907334   -.0734339
            hply |  -2.660957   .1554126   -17.12   0.000    -2.990417   -2.331497
         dml0dly |   .7259375   .1585546     4.58   0.000     .3898167    1.062058
         dml1dly |   1.016059   .1893005     5.37   0.000     .6147604    1.417358
       dmdumiso1 |   1.071798   .0854131    12.55   0.000     .8907307    1.252866
       dmdumiso2 |  -2.325407   .2842402    -8.18   0.000    -2.927969   -1.722844
       dmdumiso3 |  -2.683662   .3350045    -8.01   0.000     -3.39384   -1.973485
       dmdumiso4 |  -.7301005   .1214657    -6.01   0.000    -.9875963   -.4726048
       dmdumiso5 |  -3.503693   .3441693   -10.18   0.000      -4.2333   -2.774087
       dmdumiso6 |  -2.999026   .3406134    -8.80   0.000    -3.721095   -2.276958
       dmdumiso7 |  -.1668517    .093683    -1.78   0.094    -.3654507    .0317473
       dmdumiso8 |  -1.738996   .1433427   -12.13   0.000    -2.042869   -1.435123
       dmdumiso9 |  -3.165191     .27932   -11.33   0.000    -3.757323   -2.573059
      dmdumiso10 |  -1.605512   .1634619    -9.82   0.000    -1.952035   -1.258988
      dmdumiso11 |   7.687463   .6096382    12.61   0.000     6.395088    8.979838
      dmdumiso12 |  -4.141361   .3339004   -12.40   0.000    -4.849198   -3.433524
      dmdumiso13 |  -2.851968   .1141272   -24.99   0.000    -3.093907   -2.610029
      dmdumiso14 |  -1.123436   .2039912    -5.51   0.000    -1.555878   -.6909941
      dmdumiso15 |  -.9459124   .1015507    -9.31   0.000     -1.16119   -.7306346
      dmdumiso16 |  -2.327345   .3028726    -7.68   0.000    -2.969406   -1.685284
           _cons |   12.92457   .0210498   614.00   0.000     12.87994    12.96919
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        389
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.9064
                                                    Root MSE          =     6.6951
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.4234556   .1646643    -2.57   0.020    -.7725282   -.0743829
            hply |  -9.051626   .3255342   -27.81   0.000    -9.741728   -8.361525
         dml0dly |   3.860317    .297888    12.96   0.000     3.228823    4.491812
         dml1dly |   3.648733   .4141863     8.81   0.000     2.770698    4.526769
       dmdumiso1 |   2.133017    .136645    15.61   0.000     1.843342    2.422691
       dmdumiso2 |  -5.939121    .565934   -10.49   0.000    -7.138847   -4.739394
       dmdumiso3 |  -6.863966   .6911232    -9.93   0.000    -8.329081    -5.39885
       dmdumiso4 |   -2.20561   .2157315   -10.22   0.000     -2.66294   -1.748279
       dmdumiso5 |  -8.533727   .7566718   -11.28   0.000     -10.1378   -6.929654
       dmdumiso6 |  -7.040783   .6427306   -10.95   0.000    -8.403311   -5.678255
       dmdumiso7 |  -1.260121   .1688357    -7.46   0.000    -1.618036   -.9022049
       dmdumiso8 |  -4.686304   .2966818   -15.80   0.000    -5.315241   -4.057366
       dmdumiso9 |  -7.567195   .6185309   -12.23   0.000    -8.878422   -6.255968
      dmdumiso10 |  -3.891912   .3632916   -10.71   0.000    -4.662056   -3.121768
      dmdumiso11 |   16.85218   1.353914    12.45   0.000     13.98202    19.72235
      dmdumiso12 |  -10.18049   .6887573   -14.78   0.000    -11.64059   -8.720389
      dmdumiso13 |   -7.26244   .2138153   -33.97   0.000    -7.715708   -6.809172
      dmdumiso14 |  -3.102488   .4020041    -7.72   0.000    -3.954698   -2.250277
      dmdumiso15 |  -3.019936   .1282105   -23.55   0.000     -3.29173   -2.748142
      dmdumiso16 |  -6.100839   .6144603    -9.93   0.000    -7.403437   -4.798242
           _cons |   38.13721   .0407966   934.81   0.000     38.05073     38.2237
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        389
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.9064
                                                    Root MSE          =     6.7039
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.5277924   .4952502    -1.07   0.302    -1.577676    .5220911
           lgfAA |  -.4090981   .1946225    -2.10   0.052    -.8216794    .0034832
            hply |  -9.054829   .3202394   -28.28   0.000    -9.733707   -8.375952
         dml0dly |   3.864802   .2918798    13.24   0.000     3.246044    4.483559
         dml1dly |   3.648731   .4154055     8.78   0.000      2.76811    4.529351
       dmdumiso1 |   2.152235   .1830989    11.75   0.000     1.764083    2.540388
       dmdumiso2 |  -5.941808   .5739003   -10.35   0.000    -7.158422   -4.725193
       dmdumiso3 |   -6.84194    .659272   -10.38   0.000    -8.239534   -5.444345
       dmdumiso4 |  -2.210275   .2271567    -9.73   0.000    -2.691826   -1.728725
       dmdumiso5 |  -8.500167   .7155387   -11.88   0.000    -10.01704   -6.983293
       dmdumiso6 |  -7.069256   .7106612    -9.95   0.000     -8.57579   -5.562721
       dmdumiso7 |  -1.239588    .164189    -7.55   0.000    -1.587654   -.8915233
       dmdumiso8 |  -4.663804   .2719434   -17.15   0.000    -5.240298    -4.08731
       dmdumiso9 |  -7.542264   .5856344   -12.88   0.000    -8.783754   -6.300775
      dmdumiso10 |  -3.872439   .3431978   -11.28   0.000    -4.599985   -3.144892
      dmdumiso11 |   16.84008     1.3389    12.58   0.000     14.00174    19.67842
      dmdumiso12 |  -10.17867   .6883854   -14.79   0.000    -11.63798   -8.719356
      dmdumiso13 |  -7.242346   .1970972   -36.75   0.000    -7.660173   -6.824518
      dmdumiso14 |  -3.106036   .4111656    -7.55   0.000    -3.977668   -2.234404
      dmdumiso15 |  -3.042599   .2030076   -14.99   0.000    -3.472956   -2.612242
      dmdumiso16 |  -6.099223   .6142912    -9.93   0.000    -7.401462   -4.796983
           _cons |    38.1372   .0409148   932.11   0.000     38.05047    38.22394
    ------------------------------------------------------------------------------
    
    

---
# table2andA1.do
---

![Table2](https://github.com/htdanil/referenced_to_github/raw/master/GF0004_Jorda_Taylor_%282016%29_The_time_for_austerity__REPLICATION_WORK/results/table2.PNG)

![TableA1](https://github.com/htdanil/referenced_to_github/raw/master/GF0004_Jorda_Taylor_%282016%29_The_time_for_austerity__REPLICATION_WORK/results/tableA1.PNG)


```python
%%stata -os
* #================================================================================
* #Table 2: Fiscal muliplier, d.CAPB, OLS estimate boom/slump
* #================================================================================

* # replicating Table 2 - Panel (a) Uniform effect of d.CAPB changes
forvalues i=1/6 {
    foreach c in boom slump {
        * #the dummy for the U.S. is dropped to avoid collinearity with the constant
        reg ly`i'   fAA ///
            hply dml0dly dml1dly dmdumiso1-dmdumiso16 ///
            if `c' == 1 & year >= 1980 & year <= 2007, cluster(iso)
    }
}
```

    . forvalues i=1/6 {
      2.     foreach c in boom slump {
      3.         * #the dummy for the U.S. is dropped to avoid collinearity with the constant
      4.     }
      5. }
    
    Linear regression                               Number of obs     =        222
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6310
                                                    Root MSE          =     1.2427
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .2109091    .067535     3.12   0.007     .0677414    .3540768
            hply |  -.5181618   .0500614   -10.35   0.000    -.6242872   -.4120363
         dml0dly |   .7955141   .0632366    12.58   0.000     .6614586    .9295696
         dml1dly |   .1086474   .0854428     1.27   0.222    -.0724833    .2897781
       dmdumiso1 |  -.1754098   .0216452    -8.10   0.000    -.2212957    -.129524
       dmdumiso2 |   -.482852   .0713389    -6.77   0.000    -.6340838   -.3316203
       dmdumiso3 |  -.2647666   .0809076    -3.27   0.005     -.436283   -.0932503
       dmdumiso4 |  -.0172716   .0366943    -0.47   0.644      -.09506    .0605168
       dmdumiso5 |  -.5625925   .1137138    -4.95   0.000    -.8036549     -.32153
       dmdumiso6 |   .1792524    .078503     2.28   0.036     .0128335    .3456714
       dmdumiso7 |   .3668392     .03061    11.98   0.000     .3019489    .4317295
       dmdumiso8 |   .3093737   .0508341     6.09   0.000     .2016103    .4171372
       dmdumiso9 |  -.0381896   .0898308    -0.43   0.676    -.2286223    .1522432
      dmdumiso10 |   .4802043   .0461298    10.41   0.000     .3824134    .5779951
      dmdumiso11 |    .541973   .1071251     5.06   0.000     .3148779    .7690682
      dmdumiso12 |  -.3738073   .1229126    -3.04   0.008    -.6343703   -.1132443
      dmdumiso13 |    .072384   .0472354     1.53   0.145    -.0277507    .1725186
      dmdumiso14 |   -.103648   .0590579    -1.76   0.098    -.2288451     .021549
      dmdumiso15 |  -.0743244   .0789816    -0.94   0.361     -.241758    .0931092
      dmdumiso16 |   .4231993   .0561017     7.54   0.000     .3042691    .5421295
           _cons |   2.658381   .1075543    24.72   0.000     2.430377    2.886386
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6520
                                                    Root MSE          =     1.1012
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.0274271   .0354085    -0.77   0.450    -.1024897    .0476355
            hply |  -.6294156   .0934385    -6.74   0.000    -.8274964   -.4313349
         dml0dly |   .4618754   .0357658    12.91   0.000     .3860553    .5376956
         dml1dly |   .2338273   .0387936     6.03   0.000     .1515886     .316066
       dmdumiso1 |   .3958977   .0298312    13.27   0.000     .3326584     .459137
       dmdumiso2 |  -.0340347   .0641242    -0.53   0.603    -.1699719    .1019025
       dmdumiso3 |  -.2284218   .0491066    -4.65   0.000    -.3325232   -.1243204
       dmdumiso4 |  -.1457103   .0816659    -1.78   0.093    -.3188343    .0274136
       dmdumiso5 |  -.0951352   .0429082    -2.22   0.041    -.1860966   -.0041738
       dmdumiso6 |  -.4586913   .0314402   -14.59   0.000    -.5253414   -.3920411
       dmdumiso7 |  -.3498324   .0419605    -8.34   0.000    -.4387846   -.2608802
       dmdumiso8 |  -.6401454   .1077045    -5.94   0.000    -.8684688   -.4118221
       dmdumiso9 |  -.2044619   .0405825    -5.04   0.000     -.290493   -.1184308
      dmdumiso10 |  -.5413777   .0353559   -15.31   0.000    -.6163288   -.4664265
      dmdumiso11 |   .7431393   .1003882     7.40   0.000     .5303258    .9559529
      dmdumiso12 |  -.2459965   .0408684    -6.02   0.000    -.3326338   -.1593593
      dmdumiso13 |  -.3000923   .0377111    -7.96   0.000    -.3800363   -.2201484
      dmdumiso14 |  -.0591595   .0310416    -1.91   0.075    -.1249647    .0066458
      dmdumiso15 |  -.4678438   .0984965    -4.75   0.000     -.676647   -.2590407
      dmdumiso16 |   -.441539   .0567008    -7.79   0.000    -.5617393   -.3213388
           _cons |   2.401665   .1653788    14.52   0.000     2.051077    2.752252
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        205
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7479
                                                    Root MSE          =      1.769
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .2389906   .0730449     3.27   0.005     .0841422     .393839
            hply |  -1.567947   .1428764   -10.97   0.000    -1.870832   -1.265063
         dml0dly |   1.128567   .0622812    18.12   0.000     .9965365    1.260597
         dml1dly |   .4684939   .1296873     3.61   0.002     .1935691    .7434186
       dmdumiso1 |  -.4384235   .0307844   -14.24   0.000    -.5036834   -.3731636
       dmdumiso2 |  -1.119263   .1075383   -10.41   0.000    -1.347234   -.8912917
       dmdumiso3 |  -.6545011   .1600002    -4.09   0.001    -.9936864   -.3153157
       dmdumiso4 |   .0877902   .0753511     1.17   0.261    -.0719469    .2475273
       dmdumiso5 |  -1.033547   .2263029    -4.57   0.000    -1.513287   -.5538059
       dmdumiso6 |   .1147986   .1560955     0.74   0.473     -.216109    .4457062
       dmdumiso7 |   1.047365   .0675965    15.49   0.000     .9040671    1.190663
       dmdumiso8 |   .9915536   .1514449     6.55   0.000     .6705047    1.312603
       dmdumiso9 |  -.0569674   .1848578    -0.31   0.762    -.4488485    .3349137
      dmdumiso10 |   .7865668   .0833318     9.44   0.000     .6099112    .9632224
      dmdumiso11 |    1.43167   .2333387     6.14   0.000     .9370137    1.926325
      dmdumiso12 |  -.7074254   .2103691    -3.36   0.004    -1.153388   -.2614628
      dmdumiso13 |  -.2002164   .0804813    -2.49   0.024    -.3708292   -.0296036
      dmdumiso14 |   -.390931   .1156414    -3.38   0.004    -.6360797   -.1457823
      dmdumiso15 |   .0187158   .2472359     0.08   0.941    -.5054009    .5428325
      dmdumiso16 |    .478706   .1130577     4.23   0.001     .2390344    .7183777
           _cons |    5.63579   .2949859    19.11   0.000     5.010448    6.261132
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7834
                                                    Root MSE          =      1.471
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.0667818   .0671692    -0.99   0.335    -.2091741    .0756105
            hply |   -1.21671   .1312015    -9.27   0.000    -1.494845   -.9385753
         dml0dly |   .6592699   .0420316    15.69   0.000     .5701669     .748373
         dml1dly |   .5436818   .0525887    10.34   0.000     .4321987    .6551649
       dmdumiso1 |   .8385767   .0610877    13.73   0.000     .7090766    .9680768
       dmdumiso2 |  -.1705621   .0964947    -1.77   0.096    -.3751218    .0339975
       dmdumiso3 |   -.515609   .0870939    -5.92   0.000    -.7002397   -.3309782
       dmdumiso4 |   -.170623   .1017898    -1.68   0.113    -.3864077    .0451617
       dmdumiso5 |  -.3453945   .0745945    -4.63   0.000    -.5035278   -.1872612
       dmdumiso6 |  -.7634283   .0578074   -13.21   0.000    -.8859745   -.6408821
       dmdumiso7 |  -.5534004   .0618634    -8.95   0.000     -.684545   -.4222559
       dmdumiso8 |  -1.117878   .1373672    -8.14   0.000    -1.409084   -.8266728
       dmdumiso9 |  -.7332737   .0650699   -11.27   0.000    -.8712157   -.5953317
      dmdumiso10 |  -.7441327   .0412468   -18.04   0.000    -.8315719   -.6566935
      dmdumiso11 |   2.551769   .2422687    10.53   0.000     2.038182    3.065356
      dmdumiso12 |  -.8240102   .0681657   -12.09   0.000     -.968515   -.6795055
      dmdumiso13 |  -.7155428    .065636   -10.90   0.000    -.8546848   -.5764007
      dmdumiso14 |  -.0129268    .057072    -0.23   0.824     -.133914    .1080604
      dmdumiso15 |  -.3260167   .1295616    -2.52   0.023    -.6006751   -.0513583
      dmdumiso16 |  -.5040191   .0917572    -5.49   0.000    -.6985358   -.3095025
           _cons |   5.203518   .2120861    24.53   0.000     4.753916    5.653121
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        192
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8215
                                                    Root MSE          =     1.9049
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .0477936   .0538808     0.89   0.388    -.0664286    .1620158
            hply |  -2.456649   .2129109   -11.54   0.000       -2.908   -2.005298
         dml0dly |    1.00417   .0896626    11.20   0.000     .8140941    1.194247
         dml1dly |   .7849928   .1186769     6.61   0.000     .5334091    1.036577
       dmdumiso1 |  -.0206529   .0190021    -1.09   0.293    -.0609356    .0196298
       dmdumiso2 |  -1.463493   .1246127   -11.74   0.000     -1.72766   -1.199326
       dmdumiso3 |   -1.08874   .1795129    -6.06   0.000     -1.46929   -.7081896
       dmdumiso4 |   .4954093   .1100128     4.50   0.000     .2621926    .7286259
       dmdumiso5 |  -1.825326   .3092662    -5.90   0.000    -2.480941   -1.169711
       dmdumiso6 |  -.7337532   .1791729    -4.10   0.001    -1.113583   -.3539237
       dmdumiso7 |   1.439105   .1039948    13.84   0.000     1.218646    1.659564
       dmdumiso8 |   .9295975   .2444151     3.80   0.002     .4114606    1.447734
       dmdumiso9 |  -.7232685   .2220875    -3.26   0.005    -1.194073   -.2524641
      dmdumiso10 |   .4451171   .1040236     4.28   0.001      .224597    .6656372
      dmdumiso11 |   3.370655   .3054781    11.03   0.000      2.72307    4.018239
      dmdumiso12 |  -1.446148   .2307436    -6.27   0.000    -1.935302   -.9569932
      dmdumiso13 |  -.5439119   .1074334    -5.06   0.000    -.7716606   -.3161633
      dmdumiso14 |  -.6506576   .1547981    -4.20   0.001     -.978815   -.3225002
      dmdumiso15 |  -.0290811   .3620856    -0.08   0.937    -.7966683    .7385062
      dmdumiso16 |  -.1809918   .1676588    -1.08   0.296    -.5364125    .1744288
           _cons |   8.558494   .4089709    20.93   0.000     7.691515    9.425474
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        231
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8382
                                                    Root MSE          =     1.7374
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.1687601   .1050696    -1.61   0.128    -.3914977    .0539775
            hply |  -1.696034   .1918477    -8.84   0.000    -2.102733   -1.289335
         dml0dly |    .855904   .0875059     9.78   0.000     .6703998    1.041408
         dml1dly |   .7175345   .0968525     7.41   0.000     .5122164    .9228527
       dmdumiso1 |   .6968244   .0838403     8.31   0.000     .5190909     .874558
       dmdumiso2 |  -1.032226   .1653637    -6.24   0.000    -1.382781   -.6816705
       dmdumiso3 |  -1.403764   .1632563    -8.60   0.000    -1.749852   -1.057676
       dmdumiso4 |  -.7152106   .1633552    -4.38   0.000    -1.061508    -.368913
       dmdumiso5 |  -1.345558   .1438091    -9.36   0.000    -1.650419   -1.040696
       dmdumiso6 |   -1.45043   .1235881   -11.74   0.000    -1.712425   -1.188435
       dmdumiso7 |  -.9643905   .1195691    -8.07   0.000    -1.217866   -.7109153
       dmdumiso8 |  -1.350957   .1711831    -7.89   0.000    -1.713849   -.9880648
       dmdumiso9 |  -1.720259   .1179896   -14.58   0.000    -1.970385   -1.470132
      dmdumiso10 |  -1.154406   .0677181   -17.05   0.000    -1.297962   -1.010851
      dmdumiso11 |   3.867121   .5517477     7.01   0.000     2.697468    5.036774
      dmdumiso12 |    -2.0978   .1398011   -15.01   0.000    -2.394165   -1.801435
      dmdumiso13 |  -1.710103   .0789172   -21.67   0.000      -1.8774   -1.542806
      dmdumiso14 |  -.4105399   .0836131    -4.91   0.000    -.5877917   -.2332881
      dmdumiso15 |  -.3800305   .1854314    -2.05   0.057    -.7731275    .0130665
      dmdumiso16 |  -1.004487   .1639397    -6.13   0.000    -1.352024   -.6569507
           _cons |   8.097855   .2879498    28.12   0.000     7.487429    8.708282
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        180
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8383
                                                    Root MSE          =      2.064
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.1679317   .1066421    -1.57   0.135    -.3940027    .0581394
            hply |  -2.694773   .3050897    -8.83   0.000    -3.341535   -2.048012
         dml0dly |   .6157448    .103996     5.92   0.000     .3952832    .8362065
         dml1dly |   1.120096   .1721829     6.51   0.000     .7550849    1.485108
       dmdumiso1 |   .8227679    .037358    22.02   0.000     .7435724    .9019634
       dmdumiso2 |  -2.503625   .2334419   -10.72   0.000    -2.998499    -2.00875
       dmdumiso3 |  -2.119568   .3009582    -7.04   0.000    -2.757571   -1.481565
       dmdumiso4 |   .2395207   .2224434     1.08   0.298    -.2320382    .7110797
       dmdumiso5 |  -2.912961   .4840936    -6.02   0.000    -3.939194   -1.886729
       dmdumiso6 |  -2.176528   .3432037    -6.34   0.000    -2.904088   -1.448969
       dmdumiso7 |   .9730975   .2103248     4.63   0.000     .5272289    1.418966
       dmdumiso8 |  -.5226232   .3779028    -1.38   0.186    -1.323741     .278495
       dmdumiso9 |  -1.966003    .346092    -5.68   0.000    -2.699685   -1.232321
      dmdumiso10 |  -.4317695   .2091355    -2.06   0.056    -.8751169    .0115779
      dmdumiso11 |    5.07692   .3771218    13.46   0.000     4.277457    5.876382
      dmdumiso12 |  -2.677503   .3703958    -7.23   0.000    -3.462707   -1.892299
      dmdumiso13 |  -1.800576    .211452    -8.52   0.000    -2.248834   -1.352318
      dmdumiso14 |  -1.225815    .275167    -4.45   0.000    -1.809143   -.6424867
      dmdumiso15 |  -1.178771   .4879882    -2.42   0.028     -2.21326    -.144282
      dmdumiso16 |  -1.648915   .3112977    -5.30   0.000    -2.308837   -.9889935
           _cons |   10.64523   .5030958    21.16   0.000     9.578714    11.71174
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        226
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8537
                                                    Root MSE          =     2.0829
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.2289753   .1213562    -1.89   0.077     -.486239    .0282884
            hply |  -2.167778   .2874195    -7.54   0.000     -2.77708   -1.558476
         dml0dly |   .8920755   .1049941     8.50   0.000     .6694979    1.114653
         dml1dly |    .904535   .1595164     5.67   0.000     .5663754    1.242695
       dmdumiso1 |   .5789943      .1171     4.94   0.000     .3307535    .8272352
       dmdumiso2 |  -1.570471   .2568515    -6.11   0.000    -2.114972    -1.02597
       dmdumiso3 |   -1.93975   .2725153    -7.12   0.000    -2.517456   -1.362043
       dmdumiso4 |  -1.045068   .2103513    -4.97   0.000    -1.490993   -.5991431
       dmdumiso5 |  -2.445178   .2207066   -11.08   0.000    -2.913055   -1.977301
       dmdumiso6 |  -2.019877   .1809998   -11.16   0.000     -2.40358   -1.636175
       dmdumiso7 |  -.8764354   .1457641    -6.01   0.000    -1.185441   -.5674294
       dmdumiso8 |   -1.18379   .2238538    -5.29   0.000    -1.658338   -.7092406
       dmdumiso9 |  -2.481345   .1925832   -12.88   0.000    -2.889603   -2.073087
      dmdumiso10 |  -1.482429   .0855594   -17.33   0.000    -1.663807   -1.301052
      dmdumiso11 |   5.944425   .8846519     6.72   0.000     4.069047    7.819804
      dmdumiso12 |   -3.27504   .2265804   -14.45   0.000    -3.755369   -2.794711
      dmdumiso13 |  -2.309766   .0929937   -24.84   0.000    -2.506904   -2.112628
      dmdumiso14 |  -.6205448   .1093127    -5.68   0.000    -.8522775   -.3888122
      dmdumiso15 |   .0161858   .3330107     0.05   0.962    -.6897654     .722137
      dmdumiso16 |  -1.407847   .2110812    -6.67   0.000     -1.85532   -.9603752
           _cons |   10.79818    .393746    27.42   0.000     9.963479    11.63289
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7852
                                                    Root MSE          =     2.6611
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.2185511    .148635    -1.47   0.161    -.5336433     .096541
            hply |  -2.462125   .3529447    -6.98   0.000    -3.210334   -1.713915
         dml0dly |   .3461526    .193982     1.78   0.093    -.0650709     .757376
         dml1dly |   1.327017   .2480959     5.35   0.000     .8010768    1.852956
       dmdumiso1 |   1.626622   .0806701    20.16   0.000     1.455609    1.797635
       dmdumiso2 |  -2.717885   .3948444    -6.88   0.000    -3.554918   -1.880852
       dmdumiso3 |  -2.789713   .4894063    -5.70   0.000    -3.827208   -1.752218
       dmdumiso4 |  -.3974072   .3463511    -1.15   0.268    -1.131639    .3368243
       dmdumiso5 |  -3.356367   .7071886    -4.75   0.000     -4.85554   -1.857194
       dmdumiso6 |  -3.494421   .5630499    -6.21   0.000    -4.688034   -2.300809
       dmdumiso7 |   .4306944   .3404453     1.27   0.224    -.2910174    1.152406
       dmdumiso8 |  -2.012883   .4412128    -4.56   0.000    -2.948212   -1.077554
       dmdumiso9 |  -2.950197   .5245172    -5.62   0.000    -4.062124    -1.83827
      dmdumiso10 |  -1.331331   .3171207    -4.20   0.001    -2.003597   -.6590656
      dmdumiso11 |   7.248039   .4397338    16.48   0.000     6.315845    8.180233
      dmdumiso12 |  -3.797453   .6133416    -6.19   0.000    -5.097679   -2.497227
      dmdumiso13 |  -3.997518   .3119676   -12.81   0.000    -4.658859   -3.336176
      dmdumiso14 |  -1.201578   .4431841    -2.71   0.015    -2.141087     -.26207
      dmdumiso15 |  -2.025352   .5514289    -3.67   0.002    -3.194329   -.8563752
      dmdumiso16 |   -2.76154   .5011174    -5.51   0.000    -3.823861   -1.699218
           _cons |   12.35601   .4758857    25.96   0.000     11.34718    13.36484
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8343
                                                    Root MSE          =     2.6404
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.4144218   .1843617    -2.25   0.039    -.8052512   -.0235924
            hply |  -2.514522   .3756911    -6.69   0.000    -3.310951   -1.718092
         dml0dly |   .9050625   .1719461     5.26   0.000      .540553    1.269572
         dml1dly |   .8617048   .2227713     3.87   0.001     .3894507    1.333959
       dmdumiso1 |   .7454005   .1671657     4.46   0.000      .391025    1.099776
       dmdumiso2 |  -2.342723   .4114911    -5.69   0.000    -3.215045   -1.470401
       dmdumiso3 |   -2.67082   .4540476    -5.88   0.000    -3.633358   -1.708282
       dmdumiso4 |  -1.141008   .1843395    -6.19   0.000    -1.531791   -.7502262
       dmdumiso5 |  -3.648218   .3322676   -10.98   0.000    -4.352594   -2.943842
       dmdumiso6 |  -2.790761   .2698614   -10.34   0.000    -3.362842   -2.218681
       dmdumiso7 |  -.5901911   .1353303    -4.36   0.000    -.8770784   -.3033038
       dmdumiso8 |  -1.488657    .253234    -5.88   0.000    -2.025489   -.9518245
       dmdumiso9 |  -3.325009    .284682   -11.68   0.000    -3.928508    -2.72151
      dmdumiso10 |  -1.758837    .112755   -15.60   0.000    -1.997867   -1.519807
      dmdumiso11 |   8.398284   1.220916     6.88   0.000     5.810057    10.98651
      dmdumiso12 |  -4.675663   .3001825   -15.58   0.000    -5.312021   -4.039304
      dmdumiso13 |  -2.239881   .1936137   -11.57   0.000    -2.650324   -1.829438
      dmdumiso14 |  -1.250304   .1563285    -8.00   0.000    -1.581706   -.9189025
      dmdumiso15 |   .0396036   .4940858     0.08   0.937    -1.007812    1.087019
      dmdumiso16 |  -2.037497   .3109653    -6.55   0.000    -2.696714    -1.37828
           _cons |   13.30061    .457507    29.07   0.000     12.33074    14.27049
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8877
                                                    Root MSE          =     6.3837
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.0229086   .2437446    -0.09   0.926     -.539624    .4938069
            hply |  -9.769097   .9314421   -10.49   0.000    -11.74367   -7.794528
         dml0dly |   3.892186   .3733594    10.42   0.000     3.100699    4.683673
         dml1dly |   4.064074   .5464042     7.44   0.000     2.905748    5.222399
       dmdumiso1 |   1.396321   .1168287    11.95   0.000     1.148655    1.643987
       dmdumiso2 |  -7.995142   .7683071   -10.41   0.000     -9.62388   -6.366404
       dmdumiso3 |  -6.870774   .9796412    -7.01   0.000     -8.94752   -4.794027
       dmdumiso4 |  -.0506279   .6884053    -0.07   0.942    -1.509982    1.408726
       dmdumiso5 |  -9.171654   1.654026    -5.55   0.000    -12.67803   -5.665274
       dmdumiso6 |   -5.77123   1.107883    -5.21   0.000    -8.119837   -3.422623
       dmdumiso7 |   3.460773   .7243451     4.78   0.000      1.92523    4.996316
       dmdumiso8 |  -.9112499   1.171691    -0.78   0.448    -3.395125    1.572625
       dmdumiso9 |  -5.598447   1.154798    -4.85   0.000    -8.046509   -3.150384
      dmdumiso10 |  -.2985286   .6252174    -0.48   0.639     -1.62393    1.026873
      dmdumiso11 |   14.82149   1.259629    11.77   0.000     12.15119    17.49178
      dmdumiso12 |  -9.045325   1.218836    -7.42   0.000    -11.62914   -6.461509
      dmdumiso13 |  -6.316398    .682235    -9.26   0.000    -7.762671   -4.870124
      dmdumiso14 |  -3.238331   .9283779    -3.49   0.003    -5.206404   -1.270258
      dmdumiso15 |  -3.057289   1.484606    -2.06   0.056    -6.204514    .0899361
      dmdumiso16 |  -4.279537   1.034274    -4.14   0.001      -6.4721   -2.086973
           _cons |   39.08858   1.769358    22.09   0.000     35.33771    42.83945
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(3, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8918
                                                    Root MSE          =     6.7398
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.9753062    .397399    -2.45   0.026    -1.817754   -.1328581
            hply |  -8.440307   .9034797    -9.34   0.000     -10.3556   -6.525015
         dml0dly |   3.780595   .3423618    11.04   0.000      3.05482    4.506369
         dml1dly |   3.315961   .5164213     6.42   0.000     2.221196    4.410725
       dmdumiso1 |    3.40563   .3725373     9.14   0.000     2.615887    4.195374
       dmdumiso2 |  -5.246535   .9328554    -5.62   0.000      -7.2241    -3.26897
       dmdumiso3 |  -6.654199   .9491478    -7.01   0.000    -8.666302   -4.642096
       dmdumiso4 |   -3.20326   .5770213    -5.55   0.000    -4.426491    -1.98003
       dmdumiso5 |  -7.791742   .6903485   -11.29   0.000    -9.255215   -6.328268
       dmdumiso6 |  -7.919543   .5778683   -13.70   0.000    -9.144569   -6.694517
       dmdumiso7 |  -3.243222   .3902146    -8.31   0.000     -4.07044   -2.416004
       dmdumiso8 |  -7.116572   .7768796    -9.16   0.000    -8.763484   -5.469661
       dmdumiso9 |  -8.610044    .600133   -14.35   0.000    -9.882269   -7.337819
      dmdumiso10 |  -5.567823   .2669615   -20.86   0.000    -6.133756    -5.00189
      dmdumiso11 |   21.31599   2.773815     7.68   0.000     15.43577    27.19622
      dmdumiso12 |  -11.07064   .6681814   -16.57   0.000    -12.48712   -9.654162
      dmdumiso13 |  -6.976932   .3666002   -19.03   0.000    -7.754089   -6.199774
      dmdumiso14 |  -2.533539   .3308214    -7.66   0.000    -3.234849   -1.832229
      dmdumiso15 |  -.9044972   1.246709    -0.73   0.479    -3.547401    1.738407
      dmdumiso16 |  -6.012784   .6919631    -8.69   0.000     -7.47968   -4.545888
           _cons |   39.26629    1.27802    30.72   0.000     36.55701    41.97557
    ------------------------------------------------------------------------------
    
    

