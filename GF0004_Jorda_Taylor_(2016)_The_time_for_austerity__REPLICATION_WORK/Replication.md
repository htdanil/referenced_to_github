[Jordà, Ò., & Taylor, A. M. (2016). The time for austerity: estimating the average treatment effect of fiscal policy. _The Economic Journal_, _126_(590), 219-255.](https://onlinelibrary.wiley.com/doi/abs/10.1111/ecoj.12332)

Replication Code Downloaded from https://sites.google.com/site/oscarjorda/home/local-projections

# Table of Contents
* [Initiating environment and downloading datasets](#initiating_env)
* [Preparation of dataset](#dataset)
* [Table 1](#table1)
* [Table 2 and A1](#tbl2A1)
     - [Table 2 - Panel (a)](#table2_a)
     - [Table 2 - Panel (b)](#table2_b)
     - [Table A1](#tableA1)
     - [Table A1 - Panel (a)](#tableA1_a)
     - [Table A1 - Panel (b)](#tableA1_b)

<a class="anchor" id="initiating_env"></a>

------
    
# Initiating environment and downloading datasets
---


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

<a class='anchor' id='dataset'></a>

---
# Preparation of dataset (dataset.do)
---


```python
%%capture
%%stata -os -cwd
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
**datset now complete, now preparing for the empirical analysis**

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

<a class='anchor' id='table1'></a>

---
# Table 1 (table1.do)
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
    
    

<a class='anchor' id='tbl2A1'></a>

---
# Table 2 and A1 (table2andA1.do)
---

![Table2](https://github.com/htdanil/referenced_to_github/raw/master/GF0004_Jorda_Taylor_%282016%29_The_time_for_austerity__REPLICATION_WORK/results/table2.PNG)

<a class='anchor' id='table2_a'></a>

## Table 2 - Panel (a)

[Click here for summarized result of code below](https://github.com/htdanil/referenced_to_github/blob/master/GF0004_Jorda_Taylor_(2016)_The_time_for_austerity__REPLICATION_WORK/results/table2-panel(a).pdf)


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
    
    

<a class='anchor' id='table2_b'></a>

## Table 2 - Panel (b)

[Click here for summarized result of code below](https://github.com/htdanil/referenced_to_github/blob/master/GF0004_Jorda_Taylor_(2016)_The_time_for_austerity__REPLICATION_WORK/results/table2-panel(b).pdf)


```python
%%stata -os
* # replicating Table 2 - Panel (b) Separate effects of d.CAPB for Large( >1.5%) and Small (<= 1.5%) changes
forvalues i=1/6 {
    foreach c in boom slump {
        reg ly`i'   smfAA lgfAA ///
            hply dml0dly dml1dly dmdumiso1-dmdumiso16 ///
            if `c' == 1 & year >= 1980 & year <= 2007, cluster(iso)
    }
}
```

    . forvalues i=1/6 {
      2.     foreach c in boom slump {
      3.         reg ly`i'   smfAA lgfAA hply dml0dly dml1dly dmdumiso1-dmdumiso16 if `c' == 1 & year >= 1980 & yea
      4.     }
      5. }
    
    Linear regression                               Number of obs     =        222
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6330
                                                    Root MSE          =     1.2424
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |      .0637   .1116935     0.57   0.576    -.1730796    .3004796
           lgfAA |    .228328   .0783888     2.91   0.010     .0621512    .3945048
            hply |  -.5231558   .0534679    -9.78   0.000    -.6365027    -.409809
         dml0dly |   .8044187   .0655075    12.28   0.000     .6655491    .9432884
         dml1dly |    .095918   .0899745     1.07   0.302    -.0948195    .2866555
       dmdumiso1 |  -.1935113   .0297218    -6.51   0.000    -.2565188   -.1305039
       dmdumiso2 |    -.44806    .067196    -6.67   0.000    -.5905091   -.3056109
       dmdumiso3 |  -.2726025   .0822036    -3.32   0.004    -.4468664   -.0983385
       dmdumiso4 |  -.0238948   .0378643    -0.63   0.537    -.1041636     .056374
       dmdumiso5 |  -.5866923   .1162967    -5.04   0.000    -.8332302   -.3401544
       dmdumiso6 |   .0976619   .1159052     0.84   0.412    -.1480461    .3433699
       dmdumiso7 |   .3826962    .037689    10.15   0.000     .3027991    .4625933
       dmdumiso8 |   .3521116   .0750718     4.69   0.000     .1929664    .5112568
       dmdumiso9 |  -.0264764   .0890714    -0.30   0.770    -.2152994    .1623465
      dmdumiso10 |   .5149223   .0578156     8.91   0.000     .3923586     .637486
      dmdumiso11 |   .5579528   .1103492     5.06   0.000     .3240229    .7918827
      dmdumiso12 |  -.3737814   .1220958    -3.06   0.007    -.6326129     -.11495
      dmdumiso13 |   .0825186   .0517626     1.59   0.130    -.0272131    .1922504
      dmdumiso14 |  -.1245646   .0633128    -1.97   0.067    -.2587818    .0096526
      dmdumiso15 |  -.0863655   .0805158    -1.07   0.299    -.2570514    .0843204
      dmdumiso16 |   .4614945   .0741204     6.23   0.000     .3043663    .6186227
           _cons |     2.6693   .1128448    23.65   0.000      2.43008    2.908521
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6520
                                                    Root MSE          =     1.1037
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.0466655   .1217533    -0.38   0.707    -.3047709    .2114399
           lgfAA |  -.0237812   .0451087    -0.53   0.605    -.1194075     .071845
            hply |  -.6291361   .0937953    -6.71   0.000    -.8279732    -.430299
         dml0dly |   .4624011   .0350947    13.18   0.000     .3880037    .5367985
         dml1dly |     .23411   .0401692     5.83   0.000      .148955    .3192649
       dmdumiso1 |   .4024137    .035722    11.27   0.000     .3266865    .4781409
       dmdumiso2 |  -.0396792   .0788529    -0.50   0.622    -.2068399    .1274815
       dmdumiso3 |  -.2257671   .0492768    -4.58   0.000    -.3302293   -.1213049
       dmdumiso4 |  -.1482619   .0802583    -1.85   0.083    -.3184019    .0218782
       dmdumiso5 |   -.087832   .0573646    -1.53   0.145    -.2094394    .0337755
       dmdumiso6 |  -.4620514   .0396642   -11.65   0.000    -.5461358    -.377967
       dmdumiso7 |  -.3460573   .0502958    -6.88   0.000    -.4526797    -.239435
       dmdumiso8 |  -.6394968   .1086862    -5.88   0.000    -.8699013   -.4090923
       dmdumiso9 |  -.2004633   .0423341    -4.74   0.000    -.2902075    -.110719
      dmdumiso10 |  -.5403618   .0367871   -14.69   0.000     -.618347   -.4623767
      dmdumiso11 |   .7411184   .1035177     7.16   0.000     .5216707    .9605662
      dmdumiso12 |   -.248158   .0450297    -5.51   0.000    -.3436167   -.1526993
      dmdumiso13 |  -.2978484   .0347185    -8.58   0.000    -.3714484   -.2242483
      dmdumiso14 |  -.0581992   .0307032    -1.90   0.076     -.123287    .0068886
      dmdumiso15 |  -.4716166   .0948697    -4.97   0.000    -.6727314   -.2705018
      dmdumiso16 |  -.4473981   .0677649    -6.60   0.000    -.5910533   -.3037429
           _cons |   2.403472   .1685136    14.26   0.000     2.046239    2.760705
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        205
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7479
                                                    Root MSE          =     1.7737
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .2079462   .3489767     0.60   0.560    -.5318515    .9477438
           lgfAA |   .2426915   .0810818     2.99   0.009     .0708057    .4145773
            hply |  -1.568685   .1476043   -10.63   0.000    -1.881592   -1.255778
         dml0dly |   1.130637   .0746013    15.16   0.000     .9724888    1.288784
         dml1dly |   .4657757   .1413536     3.30   0.005     .1661194    .7654321
       dmdumiso1 |  -.4438675   .0793028    -5.60   0.000     -.611982    -.275753
       dmdumiso2 |  -1.113933   .1269349    -8.78   0.000    -1.383023   -.8448432
       dmdumiso3 |  -.6556265   .1621784    -4.04   0.001    -.9994295   -.3118236
       dmdumiso4 |   .0853731    .067644     1.26   0.225    -.0580257    .2287719
       dmdumiso5 |  -1.038386   .2375741    -4.37   0.000    -1.542021   -.5347517
       dmdumiso6 |   .0976658   .2413387     0.40   0.691    -.4139495     .609281
       dmdumiso7 |   1.050608   .0900428    11.67   0.000     .8597257     1.24149
       dmdumiso8 |   .9990003   .2099171     4.76   0.000     .5539959    1.444005
       dmdumiso9 |   -.054441   .1841436    -0.30   0.771    -.4448079     .335926
      dmdumiso10 |   .7933677    .122752     6.46   0.000      .533145     1.05359
      dmdumiso11 |   1.432425   .2364889     6.06   0.000     .9310908    1.933759
      dmdumiso12 |  -.7072093   .2108514    -3.35   0.004    -1.154194   -.2602244
      dmdumiso13 |  -.1995904    .083398    -2.39   0.029    -.3763864   -.0227944
      dmdumiso14 |  -.3948448   .1213781    -3.25   0.005    -.6521548   -.1375348
      dmdumiso15 |   .0113515   .2107124     0.05   0.958    -.4353387    .4580418
      dmdumiso16 |   .4847332   .1437323     3.37   0.004     .1800343    .7894322
           _cons |   5.637691   .3063952    18.40   0.000     4.988162     6.28722
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7838
                                                    Root MSE          =     1.4732
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.1574075   .2097152    -0.75   0.464    -.6019839    .2871689
           lgfAA |  -.0496074   .0794361    -0.62   0.541    -.2180044    .1187896
            hply |  -1.215393   .1297787    -9.37   0.000    -1.490512   -.9402745
         dml0dly |   .6617462   .0427775    15.47   0.000      .571062    .7524305
         dml1dly |   .5450133   .0540031    10.09   0.000     .4305317    .6594949
       dmdumiso1 |   .8692715   .0878547     9.89   0.000     .6830279    1.055515
       dmdumiso2 |  -.1971516   .1084506    -1.82   0.088    -.4270566    .0327534
       dmdumiso3 |  -.5031037   .0925364    -5.44   0.000    -.6992721   -.3069353
       dmdumiso4 |  -.1826425   .1070376    -1.71   0.107    -.4095521    .0442672
       dmdumiso5 |  -.3109913   .1126845    -2.76   0.014    -.5498717   -.0721108
       dmdumiso6 |  -.7792566   .0643287   -12.11   0.000    -.9156274   -.6428859
       dmdumiso7 |  -.5356175   .0685035    -7.82   0.000    -.6808383   -.3903966
       dmdumiso8 |  -1.114823   .1362331    -8.18   0.000    -1.403624   -.8260216
       dmdumiso9 |  -.7144375    .080489    -8.88   0.000    -.8850666   -.5438083
      dmdumiso10 |  -.7393473   .0425065   -17.39   0.000    -.8294571   -.6492376
      dmdumiso11 |   2.542249   .2507932    10.14   0.000     2.010592    3.073907
      dmdumiso12 |   -.834192   .0688397   -12.12   0.000    -.9801255   -.6882584
      dmdumiso13 |  -.7049722   .0679491   -10.38   0.000    -.8490177   -.5609266
      dmdumiso14 |  -.0084034   .0567661    -0.15   0.884    -.1287421    .1119352
      dmdumiso15 |  -.3437891    .134892    -2.55   0.021    -.6297473   -.0578308
      dmdumiso16 |  -.5316192   .1132078    -4.70   0.000    -.7716091   -.2916294
           _cons |   5.212033   .2102653    24.79   0.000      4.76629    5.657775
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        192
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8216
                                                    Root MSE          =     1.9098
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.0372098   .3966904    -0.09   0.926     -.878156    .8037364
           lgfAA |   .0572917   .0551812     1.04   0.315    -.0596873    .1742708
            hply |  -2.459658   .2202117   -11.17   0.000    -2.926486    -1.99283
         dml0dly |   1.009898   .0923374    10.94   0.000     .8141516    1.205645
         dml1dly |   .7785711   .1368365     5.69   0.000     .4884906    1.068652
       dmdumiso1 |  -.0313373   .0601535    -0.52   0.610    -.1588571    .0961824
       dmdumiso2 |   -1.44375   .1450316    -9.95   0.000    -1.751203   -1.136297
       dmdumiso3 |  -1.084109   .1743605    -6.22   0.000    -1.453736   -.7144808
       dmdumiso4 |   .4966273   .1116111     4.45   0.000     .2600224    .7332322
       dmdumiso5 |  -1.832847   .3258546    -5.62   0.000    -2.523628   -1.142066
       dmdumiso6 |  -.7706122   .2587533    -2.98   0.009    -1.319145   -.2220797
       dmdumiso7 |   1.448612   .1269495    11.41   0.000     1.179492    1.717733
       dmdumiso8 |   .9530639   .3224704     2.96   0.009     .2694572    1.636671
       dmdumiso9 |  -.7134641   .2105773    -3.39   0.004    -1.159868   -.2670601
      dmdumiso10 |    .465425   .1401781     3.32   0.004     .1682607    .7625894
      dmdumiso11 |   3.370021   .3037936    11.09   0.000     2.726007    4.014034
      dmdumiso12 |  -1.450475   .2371523    -6.12   0.000    -1.953215   -.9477342
      dmdumiso13 |  -.5325656   .1295762    -4.11   0.001     -.807255   -.2578763
      dmdumiso14 |  -.6560501    .162434    -4.04   0.001    -1.000395   -.3117053
      dmdumiso15 |  -.0435416   .3176419    -0.14   0.893    -.7169123    .6298291
      dmdumiso16 |  -.1581828   .1913815    -0.83   0.421    -.5638935    .2475279
           _cons |   8.563126   .4211802    20.33   0.000     7.670264    9.455988
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        231
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8384
                                                    Root MSE          =      1.741
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.1026149   .2286959    -0.45   0.660    -.5874285    .3821987
           lgfAA |  -.1814866   .1273416    -1.43   0.173    -.4514387    .0884655
            hply |  -1.697194   .1930008    -8.79   0.000    -2.106337   -1.288051
         dml0dly |   .8541551   .0867978     9.84   0.000      .670152    1.038158
         dml1dly |   .7166004    .095065     7.54   0.000     .5150717    .9181292
       dmdumiso1 |   .6744233   .1289326     5.23   0.000     .4010985    .9477482
       dmdumiso2 |  -1.013247   .1940289    -5.22   0.000     -1.42457   -.6019244
       dmdumiso3 |  -1.412664   .1533242    -9.21   0.000    -1.737696   -1.087631
       dmdumiso4 |  -.7064507   .1688668    -4.18   0.001    -1.064432    -.348469
       dmdumiso5 |  -1.373426   .1408511    -9.75   0.000    -1.672017   -1.074835
       dmdumiso6 |  -1.438679   .1450995    -9.92   0.000    -1.746276   -1.131082
       dmdumiso7 |  -.9773753   .1269743    -7.70   0.000    -1.246549   -.7082017
       dmdumiso8 |  -1.353266   .1711575    -7.91   0.000    -1.716104   -.9904286
       dmdumiso9 |  -1.733869   .1120637   -15.47   0.000    -1.971433   -1.496305
      dmdumiso10 |  -1.157861   .0652443   -17.75   0.000    -1.296173    -1.01955
      dmdumiso11 |   3.873766   .5417788     7.15   0.000     2.725247    5.022286
      dmdumiso12 |  -2.090201   .1493902   -13.99   0.000    -2.406894   -1.773508
      dmdumiso13 |  -1.717686   .0803288   -21.38   0.000    -1.887975   -1.547396
      dmdumiso14 |  -.4149089   .0794063    -5.23   0.000    -.5832427   -.2465751
      dmdumiso15 |   -.368377   .1913906    -1.92   0.072     -.774107     .037353
      dmdumiso16 |  -.9840559   .2047693    -4.81   0.000    -1.418147   -.5499644
           _cons |   8.091094   .2890985    27.99   0.000     7.478233    8.703956
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        180
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8386
                                                    Root MSE          =     2.0685
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.3162318   .3662122    -0.86   0.401    -1.092567    .4601035
           lgfAA |   -.152742   .1051604    -1.45   0.166    -.3756721    .0701881
            hply |  -2.699756   .3060531    -8.82   0.000     -3.34856   -2.050952
         dml0dly |   .6252922   .0972286     6.43   0.000     .4191768    .8314076
         dml1dly |   1.109344   .1869112     5.94   0.000     .7131096    1.505578
       dmdumiso1 |   .8120231    .049543    16.39   0.000     .7069966    .9170496
       dmdumiso2 |  -2.458718   .2278087   -10.79   0.000    -2.941651   -1.975785
       dmdumiso3 |  -2.102682   .2947629    -7.13   0.000    -2.727552   -1.477813
       dmdumiso4 |   .2526157   .2256791     1.12   0.280    -.2258027    .7310342
       dmdumiso5 |  -2.916669   .4940607    -5.90   0.000    -3.964031   -1.869307
       dmdumiso6 |  -2.229829   .3982041    -5.60   0.000    -3.073984   -1.385675
       dmdumiso7 |    .985499   .2122443     4.64   0.000     .5355612    1.435437
       dmdumiso8 |  -.4693702   .4344456    -1.08   0.296    -1.390354    .4516134
       dmdumiso9 |  -1.944063    .333216    -5.83   0.000     -2.65045   -1.237677
      dmdumiso10 |  -.3901574   .2114644    -1.85   0.084    -.8384419    .0581271
      dmdumiso11 |   5.083142   .3874765    13.12   0.000     4.261728    5.904555
      dmdumiso12 |  -2.663101   .3659129    -7.28   0.000    -3.438802     -1.8874
      dmdumiso13 |  -1.770659   .2257038    -7.85   0.000     -2.24913   -1.292188
      dmdumiso14 |  -1.225117   .2778528    -4.41   0.000    -1.814138    -.636095
      dmdumiso15 |  -1.193759   .4701258    -2.54   0.022    -2.190381    -.197137
      dmdumiso16 |  -1.612418   .3010133    -5.36   0.000    -2.250538   -.9742983
           _cons |   10.65035   .5056901    21.06   0.000     9.578331    11.72236
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        226
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8557
                                                    Root MSE          =     2.0738
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |    .125715   .3176303     0.40   0.697    -.5476311     .799061
           lgfAA |  -.2988341     .15945    -1.87   0.079     -.636853    .0391847
            hply |   -2.17133    .284066    -7.64   0.000    -2.773523   -1.569137
         dml0dly |   .8828481   .0947624     9.32   0.000     .6819608    1.083736
         dml1dly |   .8975949   .1527051     5.88   0.000     .5738744    1.221315
       dmdumiso1 |   .4600863   .2002852     2.30   0.035     .0355007     .884672
       dmdumiso2 |  -1.478056   .3038814    -4.86   0.000    -2.122255   -.8338558
       dmdumiso3 |  -1.988692   .2398224    -8.29   0.000    -2.497093   -1.480292
       dmdumiso4 |  -.9952842   .2062366    -4.83   0.000    -1.432486   -.5580821
       dmdumiso5 |  -2.595501   .1699642   -15.27   0.000    -2.955809   -2.235193
       dmdumiso6 |  -1.965414   .2108555    -9.32   0.000    -2.412407    -1.51842
       dmdumiso7 |  -.9442034   .1746674    -5.41   0.000    -1.314482   -.5739251
       dmdumiso8 |  -1.194089   .2234752    -5.34   0.000    -1.667835   -.7203422
       dmdumiso9 |  -2.555504   .1566936   -16.31   0.000     -2.88768   -2.223328
      dmdumiso10 |  -1.500082    .081255   -18.46   0.000    -1.672335   -1.327829
      dmdumiso11 |   5.988909   .8291611     7.22   0.000     4.231166    7.746652
      dmdumiso12 |  -3.235863   .2424333   -13.35   0.000    -3.749798   -2.721927
      dmdumiso13 |  -2.349437   .0993887   -23.64   0.000    -2.560131   -2.138742
      dmdumiso14 |  -.6135116   .1132998    -5.41   0.000    -.8536963   -.3733268
      dmdumiso15 |   .0999802   .3184284     0.31   0.758    -.5750579    .7750183
      dmdumiso16 |  -1.296254   .2780739    -4.66   0.000    -1.885744   -.7067633
           _cons |   10.76768   .3972135    27.11   0.000     9.925623    11.60973
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7866
                                                    Root MSE          =     2.6609
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.5699297   .4118105    -1.38   0.185    -1.442929    .3030696
           lgfAA |  -.1841928   .1502554    -1.23   0.238      -.50272    .1343344
            hply |  -2.474992   .3465997    -7.14   0.000    -3.209751   -1.740234
         dml0dly |   .3710891   .1966579     1.89   0.077     -.045807    .7879851
         dml1dly |   1.299457   .2546208     5.10   0.000     .7596845    1.839229
       dmdumiso1 |   1.617368   .0792406    20.41   0.000     1.449386    1.785351
       dmdumiso2 |  -2.610011   .4234801    -6.16   0.000    -3.507749   -1.712273
       dmdumiso3 |  -2.749075   .5032046    -5.46   0.000    -3.815821   -1.682329
       dmdumiso4 |  -.3825635   .3477586    -1.10   0.288    -1.119779    .3546519
       dmdumiso5 |  -3.364965   .7218606    -4.66   0.000    -4.895241   -1.834689
       dmdumiso6 |  -3.619006   .5820172    -6.22   0.000    -4.852828   -2.385185
       dmdumiso7 |    .476529   .3474537     1.37   0.189    -.2600399    1.213098
       dmdumiso8 |  -1.885445   .4740776    -3.98   0.001    -2.890445   -.8804455
       dmdumiso9 |  -2.898883   .5389231    -5.38   0.000    -4.041349   -1.756417
      dmdumiso10 |  -1.227005   .3467042    -3.54   0.003    -1.961985   -.4920249
      dmdumiso11 |   7.228496   .4434561    16.30   0.000     6.288411    8.168581
      dmdumiso12 |  -3.761611   .6279937    -5.99   0.000    -5.092899   -2.430324
      dmdumiso13 |  -3.926994   .3265339   -12.03   0.000    -4.619215   -3.234773
      dmdumiso14 |  -1.198923   .4523989    -2.65   0.017    -2.157965     -.23988
      dmdumiso15 |  -2.057454   .5336378    -3.86   0.001    -3.188715   -.9261919
      dmdumiso16 |   -2.67497   .5200901    -5.14   0.000    -3.777512   -1.572428
           _cons |    12.3699    .464396    26.64   0.000     11.38542    13.35437
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8379
                                                    Root MSE          =     2.6182
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .1652878   .4920317     0.34   0.741    -.8777728    1.208348
           lgfAA |  -.5237829   .2320691    -2.26   0.038    -1.015747   -.0318184
            hply |  -2.521455   .3644902    -6.92   0.000     -3.29414   -1.748771
         dml0dly |   .8866571   .1529576     5.80   0.000     .5624014    1.210913
         dml1dly |   .8474975   .2103503     4.03   0.001     .4015748     1.29342
       dmdumiso1 |   .5552805   .2785855     1.99   0.064    -.0352943    1.145855
       dmdumiso2 |  -2.158641    .484467    -4.46   0.000    -3.185666   -1.131617
       dmdumiso3 |   -2.78263    .404275    -6.88   0.000    -3.639655   -1.925605
       dmdumiso4 |  -1.063537   .1829226    -5.81   0.000    -1.451315   -.6757579
       dmdumiso5 |  -3.893863   .2983452   -13.05   0.000    -4.526326   -3.261399
       dmdumiso6 |  -2.630255   .3455316    -7.61   0.000    -3.362749   -1.897761
       dmdumiso7 |  -.7011524   .1871665    -3.75   0.002    -1.097928   -.3043771
       dmdumiso8 |  -1.552443    .250918    -6.19   0.000    -2.084366   -1.020521
       dmdumiso9 |  -3.441433   .2466914   -13.95   0.000    -3.964396   -2.918471
      dmdumiso10 |  -1.789935   .1029793   -17.38   0.000    -2.008241   -1.571628
      dmdumiso11 |   8.483787   1.122758     7.56   0.000     6.103647    10.86393
      dmdumiso12 |   -4.60839   .3175916   -14.51   0.000    -5.281655   -3.935126
      dmdumiso13 |  -2.285655   .2022996   -11.30   0.000    -2.714511   -1.856799
      dmdumiso14 |  -1.166766   .1898704    -6.15   0.000    -1.569274    -.764259
      dmdumiso15 |   .1706637   .4548953     0.38   0.712    -.7936713    1.134999
      dmdumiso16 |  -1.868985    .393882    -4.75   0.000    -2.703978   -1.033992
           _cons |   13.25077   .4538392    29.20   0.000     12.28868    14.21287
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8902
                                                    Root MSE          =     6.3342
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -1.552817   1.136396    -1.37   0.191     -3.96187    .8562352
           lgfAA |   .1266883   .2806802     0.45   0.658    -.4683273    .7217038
            hply |  -9.825122   .9048119   -10.86   0.000    -11.74324   -7.907007
         dml0dly |    4.00076   .3865594    10.35   0.000     3.181291    4.820229
         dml1dly |   3.944077   .5964756     6.61   0.000     2.679605    5.208549
       dmdumiso1 |   1.356033   .1086427    12.48   0.000      1.12572    1.586345
       dmdumiso2 |  -7.525456   .8387129    -8.97   0.000    -9.303448   -5.747465
       dmdumiso3 |  -6.693836   1.015503    -6.59   0.000    -8.846607   -4.541065
       dmdumiso4 |   .0140017   .6913823     0.02   0.984    -1.451663    1.479667
       dmdumiso5 |  -9.209088   1.704135    -5.40   0.000    -12.82169   -5.596484
       dmdumiso6 |  -6.313676   1.226346    -5.15   0.000    -8.913414   -3.713938
       dmdumiso7 |   3.660338   .7744495     4.73   0.000     2.018579    5.302098
       dmdumiso8 |  -.3563831   1.373423    -0.26   0.799    -3.267909    2.555143
       dmdumiso9 |  -5.375024   1.191205    -4.51   0.000    -7.900266   -2.849783
      dmdumiso10 |   .1557106   .7809863     0.20   0.844    -1.499906    1.811328
      dmdumiso11 |    14.7364   1.242333    11.86   0.000     12.10277    17.37003
      dmdumiso12 |  -8.889267   1.260408    -7.05   0.000    -11.56121   -6.217322
      dmdumiso13 |  -6.009339   .7861803    -7.64   0.000    -7.675966   -4.342711
      dmdumiso14 |  -3.226768    .957733    -3.37   0.004    -5.257071   -1.196465
      dmdumiso15 |  -3.197059   1.369309    -2.33   0.033    -6.099865   -.2942531
      dmdumiso16 |  -3.902609   1.119385    -3.49   0.003    -6.275599    -1.52962
           _cons |   39.14904   1.726169    22.68   0.000     35.48973    42.80836
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8929
                                                    Root MSE          =     6.7231
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .0301897   1.096483     0.03   0.978    -2.294251     2.35463
           lgfAA |  -1.164991   .5649276    -2.06   0.056    -2.362584    .0326019
            hply |  -8.452333   .8947508    -9.45   0.000    -10.34912   -6.555546
         dml0dly |   3.748671    .309652    12.11   0.000     3.092238    4.405104
         dml1dly |   3.291318   .4867085     6.76   0.000     2.259542    4.323094
       dmdumiso1 |   3.075871   .6438828     4.78   0.000       1.7109    4.440841
       dmdumiso2 |  -4.927249   1.130598    -4.36   0.000     -7.32401   -2.530488
       dmdumiso3 |  -6.848132    .822891    -8.32   0.000    -8.592583    -5.10368
       dmdumiso4 |  -3.068887   .6080385    -5.05   0.000    -4.357871   -1.779903
       dmdumiso5 |  -8.217808   .6063314   -13.55   0.000    -9.503173   -6.932442
       dmdumiso6 |  -7.641148   .7958495    -9.60   0.000    -9.328273   -5.954022
       dmdumiso7 |  -3.435682   .4600743    -7.47   0.000    -4.410996   -2.460369
       dmdumiso8 |  -7.227209   .7635305    -9.47   0.000    -8.845821   -5.608597
       dmdumiso9 |   -8.81198   .5098084   -17.28   0.000    -9.892725   -7.731234
      dmdumiso10 |  -5.621761   .2320541   -24.23   0.000    -6.113694   -5.129829
      dmdumiso11 |    21.4643    2.58728     8.30   0.000     15.97951    26.94909
      dmdumiso12 |  -10.95396   .7270817   -15.07   0.000     -12.4953   -9.412616
      dmdumiso13 |  -7.056327   .3838081   -18.39   0.000    -7.869963    -6.24269
      dmdumiso14 |  -2.388644   .4373567    -5.46   0.000    -3.315799   -1.461489
      dmdumiso15 |  -.6771757   1.209595    -0.56   0.583    -3.241403    1.887051
      dmdumiso16 |  -5.720503   .9690029    -5.90   0.000    -7.774698   -3.666309
           _cons |   39.17984   1.278887    30.64   0.000     36.46872    41.89096
    ------------------------------------------------------------------------------
    
    

<a class='anchor' id='tableA1'></a>

![TableA1](https://github.com/htdanil/referenced_to_github/raw/master/GF0004_Jorda_Taylor_%282016%29_The_time_for_austerity__REPLICATION_WORK/results/tableA1.PNG)

<a class='anchor' id='tableA1_a'></a>

## Table A1 - Panel (a)

[Click here for summarized result of code below](https://github.com/htdanil/referenced_to_github/blob/master/GF0004_Jorda_Taylor_(2016)_The_time_for_austerity__REPLICATION_WORK/results/tableA1-panel(a).pdf)


```python
%%stata -os
* #================================================================================
* #Table A1: Fiscal muliplier, d.CAPB, OLS estimate boom/slump (world gdp included)
* #================================================================================

* # replicating Table 2 - Panel (a) Uniform effect of d.CAPB changes
forvalues i=1/6 {
    foreach c in boom slump {
        * #the dummy for the U.S. is dropped to avoid collinearity with the constant
        reg ly`i'   fAA ///
            hply dml0dly dml1dly dmdumiso1-dmdumiso16 wgdp ///
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
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6684
                                                    Root MSE          =      1.181
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .2103142   .0677412     3.10   0.007     .0667092    .3539191
            hply |  -.5484677   .0522436   -10.50   0.000    -.6592192   -.4377162
         dml0dly |   .6329522   .0588225    10.76   0.000      .508254    .7576503
         dml1dly |   .2246317   .0760774     2.95   0.009     .0633548    .3859086
       dmdumiso1 |  -.0461677   .0319524    -1.44   0.168    -.1139036    .0215683
       dmdumiso2 |  -.2310835   .0732743    -3.15   0.006     -.386418   -.0757489
       dmdumiso3 |   -.097082   .0761867    -1.27   0.221    -.2585905    .0644265
       dmdumiso4 |   .0931618   .0344325     2.71   0.016     .0201682    .1661554
       dmdumiso5 |  -.2951614   .1185138    -2.49   0.024    -.5463994   -.0439234
       dmdumiso6 |   .1485429   .0590715     2.51   0.023     .0233168     .273769
       dmdumiso7 |    .550782    .039421    13.97   0.000     .4672133    .6343508
       dmdumiso8 |   .4520485   .0536016     8.43   0.000     .3384182    .5656789
       dmdumiso9 |   .1921167   .0948567     2.03   0.060    -.0089705     .393204
      dmdumiso10 |   .5052563   .0381397    13.25   0.000     .4244037     .586109
      dmdumiso11 |   .8829364   .0934197     9.45   0.000     .6848955    1.080977
      dmdumiso12 |  -.2334094   .1031477    -2.26   0.038    -.4520727    -.014746
      dmdumiso13 |   .1744852    .049982     3.49   0.003     .0685281    .2804422
      dmdumiso14 |   .1989254   .0771751     2.58   0.020     .0353214    .3625294
      dmdumiso15 |   .2997187   .0880846     3.40   0.004     .1129876    .4864498
      dmdumiso16 |   .4957858   .0554126     8.95   0.000     .3783164    .6132553
            wgdp |   .4038451   .0604339     6.68   0.000      .275731    .5319592
           _cons |   1.247546   .2620869     4.76   0.000     .6919462    1.803145
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6529
                                                    Root MSE          =     1.1024
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |    -.02925   .0349624    -0.84   0.415     -.103367    .0448669
            hply |  -.6323773   .0965902    -6.55   0.000    -.8371393   -.4276153
         dml0dly |   .4489786   .0414933    10.82   0.000     .3610167    .5369404
         dml1dly |   .2349045   .0392647     5.98   0.000      .151667     .318142
       dmdumiso1 |   .3878828   .0312748    12.40   0.000     .3215832    .4541824
       dmdumiso2 |  -.0806498   .0615572    -1.31   0.209    -.2111451    .0498455
       dmdumiso3 |  -.2646415   .0572731    -4.62   0.000    -.3860551   -.1432279
       dmdumiso4 |  -.1602328   .0935926    -1.71   0.106    -.3586402    .0381746
       dmdumiso5 |  -.1531935   .0727395    -2.11   0.051    -.3073943    .0010072
       dmdumiso6 |  -.4745989    .033905   -14.00   0.000    -.5464743   -.4027236
       dmdumiso7 |  -.3750307   .0643544    -5.83   0.000     -.511456   -.2386053
       dmdumiso8 |  -.6656444   .1277333    -5.21   0.000     -.936427   -.3948618
       dmdumiso9 |    -.24914   .0547621    -4.55   0.000    -.3652305   -.1330495
      dmdumiso10 |  -.5549225   .0464929   -11.94   0.000     -.653483   -.4563619
      dmdumiso11 |   .7413126   .1048903     7.07   0.000     .5189551    .9636701
      dmdumiso12 |  -.2857378   .0467089    -6.12   0.000    -.3847563   -.1867193
      dmdumiso13 |  -.3235549   .0459786    -7.04   0.000    -.4210251   -.2260846
      dmdumiso14 |  -.1097319   .0590578    -1.86   0.082    -.2349289    .0154651
      dmdumiso15 |  -.5369946   .1565592    -3.43   0.003    -.8688853   -.2051038
      dmdumiso16 |   -.462502   .0707131    -6.54   0.000    -.6124072   -.3125969
            wgdp |   .0585033   .0681339     0.86   0.403    -.0859341    .2029406
           _cons |   2.204687   .3473198     6.35   0.000     1.468402    2.940972
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        205
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7670
                                                    Root MSE          =     1.7051
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .2477621   .0727857     3.40   0.004     .0934633    .4020609
            hply |   -1.56411    .162773    -9.61   0.000    -1.909173   -1.219046
         dml0dly |   .9212511     .06757    13.63   0.000      .778009    1.064493
         dml1dly |   .5687324   .1136287     5.01   0.000     .3278504    .8096144
       dmdumiso1 |  -.2466967   .0528991    -4.66   0.000    -.3588378   -.1345557
       dmdumiso2 |  -.7677884   .1368805    -5.61   0.000    -1.057962   -.4776147
       dmdumiso3 |  -.4694577   .1465122    -3.20   0.006    -.7800497   -.1588657
       dmdumiso4 |   .1960036   .0875178     2.24   0.040      .010474    .3815331
       dmdumiso5 |  -.7171709   .2327262    -3.08   0.007    -1.210528   -.2238133
       dmdumiso6 |  -.0016672   .1331112    -0.01   0.990    -.2838502    .2805158
       dmdumiso7 |   1.260281   .1049317    12.01   0.000     1.037835    1.482726
       dmdumiso8 |   1.122117   .1860429     6.03   0.000     .7277241    1.516511
       dmdumiso9 |   .2120051   .1837952     1.15   0.266    -.1776233    .6016335
      dmdumiso10 |   .7691442   .0787244     9.77   0.000      .602256    .9360324
      dmdumiso11 |   1.907339   .2770323     6.88   0.000     1.320057    2.494621
      dmdumiso12 |  -.5866803   .1840934    -3.19   0.006    -.9769409   -.1964196
      dmdumiso13 |  -.0847366   .0992147    -0.85   0.406    -.2950625    .1255892
      dmdumiso14 |   .0012781   .1554106     0.01   0.994    -.3281777    .3307338
      dmdumiso15 |   .5105719    .336055     1.52   0.148     -.201833    1.222977
      dmdumiso16 |   .5001918   .1172094     4.27   0.001     .2517191    .7486646
            wgdp |   .5382786   .1434837     3.75   0.002     .2341068    .8424504
           _cons |   3.790429    .514279     7.37   0.000     2.700206    4.880652
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7846
                                                    Root MSE          =     1.4705
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.0631616   .0648891    -0.97   0.345    -.2007204    .0743972
            hply |  -1.210828   .1304337    -9.28   0.000    -1.487335   -.9343211
         dml0dly |   .6848824   .0444135    15.42   0.000     .5907299    .7790349
         dml1dly |   .5415425   .0495645    10.93   0.000     .4364704    .6466146
       dmdumiso1 |   .8544938   .0601071    14.22   0.000     .7270724    .9819153
       dmdumiso2 |  -.0779869   .1143612    -0.68   0.505    -.3204218    .1644481
       dmdumiso3 |  -.4436785   .1094705    -4.05   0.001    -.6757456   -.2116114
       dmdumiso4 |  -.1417821   .1063811    -1.33   0.201    -.3672998    .0837357
       dmdumiso5 |  -.2300937   .1199335    -1.92   0.073    -.4843414     .024154
       dmdumiso6 |  -.7318364   .0666834   -10.97   0.000     -.873199   -.5904739
       dmdumiso7 |   -.503358   .0778127    -6.47   0.000    -.6683135   -.3384024
       dmdumiso8 |  -1.067239   .1452043    -7.35   0.000    -1.375058   -.7594192
       dmdumiso9 |  -.6445453   .0942818    -6.84   0.000    -.8444137   -.4446769
      dmdumiso10 |  -.7172334   .0501316   -14.31   0.000    -.8235076   -.6109591
      dmdumiso11 |   2.555397    .233998    10.92   0.000     2.059343    3.051451
      dmdumiso12 |  -.7450861   .0886395    -8.41   0.000    -.9329935   -.5571787
      dmdumiso13 |  -.6689474   .0775929    -8.62   0.000    -.8334369   -.5044579
      dmdumiso14 |   .0875075   .0970595     0.90   0.381    -.1182495    .2932646
      dmdumiso15 |  -.1886869   .1691922    -1.12   0.281    -.5473583    .1699845
      dmdumiso16 |  -.4623877    .105917    -4.37   0.000    -.6869216   -.2378538
            wgdp |  -.1161845   .0780819    -1.49   0.156    -.2817108    .0493418
           _cons |   5.594705   .3657459    15.30   0.000     4.819358    6.370052
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        192
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8231
                                                    Root MSE          =      1.902
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |   .0589469   .0540536     1.09   0.292    -.0556417    .1735355
            hply |  -2.453954   .2231046   -11.00   0.000    -2.926914   -1.980993
         dml0dly |   .9216938   .0966602     9.54   0.000     .7167833    1.126604
         dml1dly |   .8203044   .1076834     7.62   0.000     .5920257    1.048583
       dmdumiso1 |   .0538444   .0483285     1.11   0.282    -.0486074    .1562962
       dmdumiso2 |   -1.35401   .1424913    -9.50   0.000    -1.656078   -1.051942
       dmdumiso3 |  -1.011348   .1756592    -5.76   0.000    -1.383729   -.6389675
       dmdumiso4 |   .5311778   .1214088     4.38   0.000     .2738026     .788553
       dmdumiso5 |  -1.726715   .3069535    -5.63   0.000    -2.377427   -1.076003
       dmdumiso6 |  -.7911615   .1806527    -4.38   0.000    -1.174128   -.4081949
       dmdumiso7 |   1.522056   .1360886    11.18   0.000     1.233561    1.810551
       dmdumiso8 |   .9824886   .2714691     3.62   0.002     .4069997    1.557977
       dmdumiso9 |  -.6128324   .2218347    -2.76   0.014    -1.083101   -.1425639
      dmdumiso10 |   .4405947   .1054799     4.18   0.001     .2169872    .6642022
      dmdumiso11 |   3.556922   .3660797     9.72   0.000     2.780867    4.332976
      dmdumiso12 |   -1.39811   .2250522    -6.21   0.000      -1.8752    -.921021
      dmdumiso13 |  -.4807137   .1317844    -3.65   0.002    -.7600841   -.2013432
      dmdumiso14 |  -.5226423   .1744029    -3.00   0.009      -.89236   -.1529246
      dmdumiso15 |   .1396736   .4332145     0.32   0.751    -.7787001    1.058047
      dmdumiso16 |  -.1742591   .1703163    -1.02   0.321    -.5353137    .1867954
            wgdp |   .2053433   .1463065     1.40   0.180    -.1048125    .5154991
           _cons |    7.87385   .5220789    15.08   0.000     6.767092    8.980608
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        231
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8385
                                                    Root MSE          =     1.7403
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.1669656   .1029041    -1.62   0.124    -.3851125    .0511814
            hply |  -1.693274   .1900527    -8.91   0.000    -2.096167    -1.29038
         dml0dly |    .871676   .1073523     8.12   0.000     .6440993    1.099253
         dml1dly |   .7163018   .0935073     7.66   0.000     .5180751    .9145285
       dmdumiso1 |   .7067028   .0737158     9.59   0.000     .5504323    .8629732
       dmdumiso2 |  -.9792032   .2404882    -4.07   0.001    -1.489016    -.469391
       dmdumiso3 |  -1.359221   .2307703    -5.89   0.000    -1.848432   -.8700093
       dmdumiso4 |  -.6980136   .1621116    -4.31   0.001    -1.041675   -.3543524
       dmdumiso5 |  -1.279845   .2507565    -5.10   0.000    -1.811425   -.7482644
       dmdumiso6 |  -1.430688   .1529969    -9.35   0.000    -1.755027   -1.106349
       dmdumiso7 |  -.9340043   .1209392    -7.72   0.000    -1.190384   -.6776246
       dmdumiso8 |  -1.320668   .1856838    -7.11   0.000      -1.7143   -.9270358
       dmdumiso9 |  -1.665702   .2036091    -8.18   0.000    -2.097334    -1.23407
      dmdumiso10 |  -1.138007   .0836512   -13.60   0.000     -1.31534   -.9606746
      dmdumiso11 |   3.868189   .5463384     7.08   0.000     2.710004    5.026375
      dmdumiso12 |  -2.049252    .213326    -9.61   0.000    -2.501483   -1.597021
      dmdumiso13 |  -1.681293   .1030223   -16.32   0.000     -1.89969   -1.462895
      dmdumiso14 |  -.3541511   .1718857    -2.06   0.056    -.7185325    .0102304
      dmdumiso15 |  -.3024893   .2287873    -1.32   0.205    -.7874967    .1825181
      dmdumiso16 |  -.9786009   .1877294    -5.21   0.000    -1.376569   -.5806324
            wgdp |  -.0706884   .1429286    -0.49   0.628    -.3736835    .2323067
           _cons |   8.333704   .5303961    15.71   0.000     7.209315    9.458094
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        180
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8402
                                                    Root MSE          =     2.0581
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.1844947   .1006684    -1.83   0.086    -.3979021    .0289128
            hply |  -2.690069   .2949095    -9.12   0.000    -3.315249   -2.064888
         dml0dly |   .7208445   .1342585     5.37   0.000     .4362291     1.00546
         dml1dly |   1.092587   .1682227     6.49   0.000     .7359711    1.449204
       dmdumiso1 |   .7145252   .0805269     8.87   0.000     .5438158    .8852345
       dmdumiso2 |    -2.6185   .2478676   -10.56   0.000    -3.143956   -2.093044
       dmdumiso3 |  -2.214113     .30441    -7.27   0.000    -2.859433   -1.568793
       dmdumiso4 |   .1922832   .2256568     0.85   0.407    -.2860879    .6706542
       dmdumiso5 |  -2.998078    .471662    -6.36   0.000    -3.997957   -1.998199
       dmdumiso6 |  -2.057737   .3420065    -6.02   0.000    -2.782758   -1.332715
       dmdumiso7 |   .8429062   .2333815     3.61   0.002     .3481594    1.337653
       dmdumiso8 |  -.6027563   .3844127    -1.57   0.136    -1.417675    .2121622
       dmdumiso9 |  -2.121557   .3452624    -6.14   0.000    -2.853481   -1.389633
      dmdumiso10 |  -.4266529   .2039012    -2.09   0.053    -.8589042    .0055984
      dmdumiso11 |   4.790866   .4572281    10.48   0.000     3.821586    5.760147
      dmdumiso12 |  -2.747627   .3694095    -7.44   0.000     -3.53074   -1.964514
      dmdumiso13 |  -1.906747   .2240673    -8.51   0.000    -2.381748   -1.431745
      dmdumiso14 |  -1.362813    .282228    -4.83   0.000     -1.96111   -.7645163
      dmdumiso15 |  -1.400031   .5384479    -2.60   0.019     -2.54149   -.2585725
      dmdumiso16 |  -1.652664   .3055238    -5.41   0.000    -2.300345   -1.004982
            wgdp |  -.2786369   .1762079    -1.58   0.133    -.6521811    .0949072
           _cons |   11.51814   .6018183    19.14   0.000     10.24235    12.79394
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        226
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8538
                                                    Root MSE          =     2.0874
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.2285531   .1191927    -1.92   0.073    -.4812303    .0241242
            hply |  -2.167536   .2873417    -7.54   0.000    -2.776674   -1.558399
         dml0dly |   .9042766   .1513331     5.98   0.000     .5834649    1.225088
         dml1dly |   .9050706   .1598163     5.66   0.000     .5662753    1.243866
       dmdumiso1 |   .5866298   .0946501     6.20   0.000     .3859805     .787279
       dmdumiso2 |  -1.531982   .3860852    -3.97   0.001    -2.350446   -.7135174
       dmdumiso3 |  -1.902452   .3994689    -4.76   0.000    -2.749288   -1.055615
       dmdumiso4 |  -1.031996    .200442    -5.15   0.000    -1.456914   -.6070779
       dmdumiso5 |  -2.398079   .3889842    -6.16   0.000    -3.222689   -1.573469
       dmdumiso6 |  -2.010581   .2121713    -9.48   0.000    -2.460364   -1.560798
       dmdumiso7 |  -.8524153   .1334802    -6.39   0.000    -1.135381     -.56945
       dmdumiso8 |  -1.160654   .2442073    -4.75   0.000     -1.67835   -.6429571
       dmdumiso9 |  -2.436868   .3513052    -6.94   0.000    -3.181601   -1.692134
      dmdumiso10 |  -1.469309    .115895   -12.68   0.000    -1.714996   -1.223623
      dmdumiso11 |   5.941071   .8937486     6.65   0.000     4.046409    7.835733
      dmdumiso12 |  -3.235266   .3680942    -8.79   0.000    -4.015591   -2.454942
      dmdumiso13 |  -2.286311   .1436774   -15.91   0.000    -2.590893   -1.981728
      dmdumiso14 |  -.5807591    .247162    -2.35   0.032    -1.104719    -.056799
      dmdumiso15 |   .0692536   .3311395     0.21   0.837    -.6327308    .7712379
      dmdumiso16 |   -1.38568    .261983    -5.29   0.000     -1.94106   -.8303013
            wgdp |  -.0559993   .2412004    -0.23   0.819    -.5673213    .4553227
           _cons |   10.98143   .7815484    14.05   0.000      9.32462    12.63824
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7943
                                                    Root MSE          =     2.6127
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.2602478   .1417918    -1.84   0.085    -.5608329    .0403374
            hply |  -2.445988   .3330351    -7.34   0.000     -3.15199   -1.739985
         dml0dly |   .6025643   .1821992     3.31   0.004     .2163191    .9888094
         dml1dly |   1.258955   .2313009     5.44   0.000     .7686186    1.749291
       dmdumiso1 |   1.341325   .1310021    10.24   0.000     1.063613    1.619037
       dmdumiso2 |  -2.990507   .4296882    -6.96   0.000    -3.901405   -2.079609
       dmdumiso3 |  -3.015267   .5035194    -5.99   0.000    -4.082681   -1.947854
       dmdumiso4 |  -.5543937   .3536691    -1.57   0.137    -1.304139    .1953513
       dmdumiso5 |  -3.557167   .7009762    -5.07   0.000     -5.04317   -2.071163
       dmdumiso6 |  -3.206843   .5196896    -6.17   0.000    -4.308536    -2.10515
       dmdumiso7 |   .0750909   .3804571     0.20   0.846    -.7314421    .8816239
       dmdumiso8 |  -2.210915   .4387139    -5.04   0.000    -3.140947   -1.280883
       dmdumiso9 |  -3.323438   .5527549    -6.01   0.000    -4.495226    -2.15165
      dmdumiso10 |  -1.329774   .3039663    -4.37   0.000    -1.974154   -.6853943
      dmdumiso11 |   6.496917   .4425109    14.68   0.000     5.558836    7.434998
      dmdumiso12 |  -3.962994   .6171327    -6.42   0.000    -5.271257   -2.654731
      dmdumiso13 |  -4.256613   .3326661   -12.80   0.000    -4.961834   -3.551392
      dmdumiso14 |   -1.52842   .4787632    -3.19   0.006    -2.543353   -.5134876
      dmdumiso15 |  -2.562325   .5980523    -4.28   0.001     -3.83014   -1.294511
      dmdumiso16 |   -2.77124   .4857866    -5.70   0.000    -3.801062   -1.741418
            wgdp |  -.6697013   .2384528    -2.81   0.013    -1.175199    -.164204
           _cons |   14.43542   .8356218    17.28   0.000     12.66398    16.20685
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8364
                                                    Root MSE          =     2.6306
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.4123173   .1743895    -2.36   0.031    -.7820064   -.0426281
            hply |   -2.52358   .3783925    -6.67   0.000    -3.325737   -1.721424
         dml0dly |   .9788693   .2474905     3.96   0.001      .454213    1.503526
         dml1dly |   .8690456   .2195878     3.96   0.001     .4035402    1.334551
       dmdumiso1 |   .8123814   .1430084     5.68   0.000     .5092171    1.115546
       dmdumiso2 |  -2.099771   .6337116    -3.31   0.004    -3.443179   -.7563622
       dmdumiso3 |  -2.436715   .6668972    -3.65   0.002    -3.850474   -1.022957
       dmdumiso4 |  -1.046569   .1800777    -5.81   0.000    -1.428316   -.6648213
       dmdumiso5 |  -3.361105   .6042684    -5.56   0.000    -4.642097   -2.080113
       dmdumiso6 |  -2.735959   .3168589    -8.63   0.000     -3.40767   -2.064248
       dmdumiso7 |  -.4306275   .1694289    -2.54   0.022    -.7898007   -.0714543
       dmdumiso8 |  -1.354117   .2934935    -4.61   0.000    -1.976295   -.7319384
       dmdumiso9 |  -3.047628   .5515224    -5.53   0.000    -4.216803   -1.878453
      dmdumiso10 |  -1.657865   .2061395    -8.04   0.000    -2.094861   -1.220869
      dmdumiso11 |   8.373631   1.222425     6.85   0.000     5.782206    10.96506
      dmdumiso12 |  -4.432085   .5345038    -8.29   0.000    -5.565182   -3.298987
      dmdumiso13 |  -2.094246   .2841761    -7.37   0.000    -2.696673    -1.49182
      dmdumiso14 |  -1.011198   .3715353    -2.72   0.015    -1.798818   -.2235787
      dmdumiso15 |    .333142   .3909047     0.85   0.407    -.4955391    1.161823
      dmdumiso16 |  -1.895448   .4220448    -4.49   0.000    -2.790143   -1.000753
            wgdp |  -.3231019   .3490791    -0.93   0.368    -1.063117    .4169128
           _cons |   14.33164    1.00483    14.26   0.000      12.2015    16.46178
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8887
                                                    Root MSE          =     6.3761
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.0686806   .2357332    -0.29   0.775    -.5684126    .4310514
            hply |  -9.751383   .9153956   -10.65   0.000    -11.69193   -7.810831
         dml0dly |   4.173659   .5702928     7.32   0.000     2.964692    5.382626
         dml1dly |   3.989359   .4969904     8.03   0.000     2.935787    5.042932
       dmdumiso1 |    1.08314    .344157     3.15   0.006     .3535599     1.81272
       dmdumiso2 |   -8.29441   .6960747   -11.92   0.000    -9.770022   -6.818797
       dmdumiso3 |  -7.118373   .8845295    -8.05   0.000    -8.993492   -5.243254
       dmdumiso4 |  -.2229579   .7190556    -0.31   0.761    -1.747288    1.301372
       dmdumiso5 |  -9.392079   1.505217    -6.24   0.000      -12.583   -6.201162
       dmdumiso6 |  -5.455545   1.284827    -4.25   0.001    -8.179255   -2.731834
       dmdumiso7 |   3.070414   .8503217     3.61   0.002     1.267812    4.873015
       dmdumiso8 |  -1.128637   1.257502    -0.90   0.383    -3.794423    1.537148
       dmdumiso9 |  -6.008167   .9619607    -6.25   0.000    -8.047433   -3.968902
      dmdumiso10 |   -.296819   .6139203    -0.48   0.635    -1.598272    1.004634
      dmdumiso11 |   13.99695   1.942867     7.20   0.000     9.878259    18.11565
      dmdumiso12 |  -9.227045   1.145057    -8.06   0.000    -11.65446   -6.799633
      dmdumiso13 |  -6.600817   .7329591    -9.01   0.000    -8.154621   -5.047013
      dmdumiso14 |  -3.597118   .7943029    -4.53   0.000    -5.280965   -1.913271
      dmdumiso15 |  -3.646745   1.821987    -2.00   0.063    -7.509186    .2156954
      dmdumiso16 |  -4.290185   1.015762    -4.22   0.001    -6.443505   -2.136865
            wgdp |  -.7351568   .7489773    -0.98   0.341    -2.322918    .8526041
           _cons |   41.37122   1.806097    22.91   0.000     37.54247    45.19998
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(4, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8932
                                                    Root MSE          =     6.7148
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             fAA |  -.9699347   .3655727    -2.65   0.017    -1.744914   -.1949551
            hply |  -8.463429   .9108546    -9.29   0.000    -10.39435   -6.532503
         dml0dly |   3.968981   .4945792     8.02   0.000      2.92052    5.017442
         dml1dly |   3.334697   .5053899     6.60   0.000     2.263319    4.406076
       dmdumiso1 |   3.576594     .28268    12.65   0.000     2.977339    4.175849
       dmdumiso2 |  -4.626418   1.365371    -3.39   0.004    -7.520875    -1.73196
       dmdumiso3 |  -6.056665   1.380698    -4.39   0.000    -8.983614   -3.129717
       dmdumiso4 |  -2.962211   .5757699    -5.14   0.000    -4.182788   -1.741633
       dmdumiso5 |  -7.058907   1.245517    -5.67   0.000    -9.699284    -4.41853
       dmdumiso6 |  -7.779665    .672072   -11.58   0.000    -9.204394   -6.354936
       dmdumiso7 |  -2.835948   .4324279    -6.56   0.000    -3.752654   -1.919242
       dmdumiso8 |   -6.77317   .8552065    -7.92   0.000    -8.586126   -4.960213
       dmdumiso9 |  -7.902051   1.145383    -6.90   0.000    -10.33015   -5.473947
      dmdumiso10 |  -5.310099   .4459608   -11.91   0.000    -6.255494   -4.364704
      dmdumiso11 |   21.25307   2.765624     7.68   0.000     15.39021    27.11593
      dmdumiso12 |  -10.44893   1.139485    -9.17   0.000    -12.86453   -8.033328
      dmdumiso13 |   -6.60521   .5224272   -12.64   0.000    -7.712707   -5.497714
      dmdumiso14 |   -1.92324   .7637494    -2.52   0.023    -3.542316   -.3041634
      dmdumiso15 |   -.155263   1.156224    -0.13   0.895    -2.606349    2.295823
      dmdumiso16 |  -5.650216   .8900081    -6.35   0.000    -7.536948   -3.763483
            wgdp |  -.8246926   .7565769    -1.09   0.292    -2.428564    .7791787
           _cons |    41.8979   2.456097    17.06   0.000     36.69121     47.1046
    ------------------------------------------------------------------------------
    
    

<a class='anchor' id='tableA1_b'></a>

## Table A1 - Panel (b)

[Click here for summarized result of code below](https://github.com/htdanil/referenced_to_github/blob/master/GF0004_Jorda_Taylor_(2016)_The_time_for_austerity__REPLICATION_WORK/results/tableA1-panel(b).pdf)


```python
%%stata -os
* # replicating Table 2 - Panel (b) Separate effects of d.CAPB for Large( >1.5%) and Small (<= 1.5%) changes
forvalues i=1/6 {
    foreach c in boom slump {
        reg ly`i'   smfAA lgfAA ///
            hply dml0dly dml1dly dmdumiso1-dmdumiso16 wgdp ///
            if `c' == 1 & year >= 1980 & year <= 2007, cluster(iso)
    }
}
```

    . forvalues i=1/6 {
      2.     foreach c in boom slump {
      3.         reg ly`i'   smfAA lgfAA hply dml0dly dml1dly dmdumiso1-dmdumiso16 wgdp if `c' == 1 & year >= 1980 
      4.     }
      5. }
    
    Linear regression                               Number of obs     =        222
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6709
                                                    Root MSE          =     1.1795
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |    .044735   .1170588     0.38   0.707    -.2034186    .2928887
           lgfAA |   .2299019   .0783991     2.93   0.010     .0637033    .3961006
            hply |  -.5543072   .0532424   -10.41   0.000    -.6671759   -.4414384
         dml0dly |   .6417751   .0616135    10.42   0.000     .5111604    .7723899
         dml1dly |   .2111651   .0808655     2.61   0.019     .0397379    .3825923
       dmdumiso1 |  -.0655793   .0367163    -1.79   0.093    -.1434145    .0122558
       dmdumiso2 |  -.1901037   .0780159    -2.44   0.027      -.35549   -.0247174
       dmdumiso3 |  -.1046652   .0781237    -1.34   0.199      -.27028    .0609496
       dmdumiso4 |   .0865225   .0352875     2.45   0.026     .0117162    .1613287
       dmdumiso5 |  -.3203059   .1202258    -2.66   0.017    -.5751732   -.0654387
       dmdumiso6 |   .0565479   .0989659     0.57   0.576    -.1532504    .2663462
       dmdumiso7 |   .5699668    .044862    12.70   0.000     .4748637      .66507
       dmdumiso8 |   .5011651   .0684804     7.32   0.000     .3559931    .6463371
       dmdumiso9 |   .2069808   .0991303     2.09   0.053    -.0031661    .4171277
      dmdumiso10 |   .5444896   .0522994    10.41   0.000     .4336197    .6553595
      dmdumiso11 |   .9034113   .0895937    10.08   0.000     .7134812    1.093341
      dmdumiso12 |  -.2323503   .1038174    -2.24   0.040    -.4524334   -.0122672
      dmdumiso13 |   .1866333    .054284     3.44   0.003     .0715563    .3017103
      dmdumiso14 |   .1776191   .0800708     2.22   0.041     .0078765    .3473617
      dmdumiso15 |   .2889195   .0863411     3.35   0.004     .1058846    .4719544
      dmdumiso16 |   .5393913   .0739829     7.29   0.000     .3825546    .6962279
            wgdp |   .4068079   .0639533     6.36   0.000     .2712329    .5423828
           _cons |   1.249476   .2814407     4.44   0.000     .6528486    1.846104
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.6529
                                                    Root MSE          =     1.1049
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly1 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.0500558   .1241966    -0.40   0.692    -.3133407    .2132292
           lgfAA |  -.0253179   .0449951    -0.56   0.581    -.1207033    .0700676
            hply |  -.6320897   .0968752    -6.52   0.000     -.837456   -.4267235
         dml0dly |    .449483   .0409099    10.99   0.000     .3627579    .5362081
         dml1dly |   .2352154   .0407132     5.78   0.000     .1489073    .3215235
       dmdumiso1 |   .3948869    .036336    10.87   0.000     .3178581    .4719158
       dmdumiso2 |  -.0869823   .0797668    -1.09   0.292    -.2560803    .0821158
       dmdumiso3 |  -.2619511    .056325    -4.65   0.000    -.3813549   -.1425473
       dmdumiso4 |  -.1630629   .0933007    -1.75   0.100    -.3608515    .0347257
       dmdumiso5 |  -.1455861   .0782805    -1.86   0.081    -.3115333    .0203612
       dmdumiso6 |    -.47831   .0426573   -11.21   0.000    -.5687394   -.3878806
       dmdumiso7 |  -.3710746    .068549    -5.41   0.000    -.5163921   -.2257571
       dmdumiso8 |  -.6650695   .1283852    -5.18   0.000    -.9372339    -.392905
       dmdumiso9 |  -.2450386   .0538904    -4.55   0.000    -.3592812   -.1307961
      dmdumiso10 |  -.5538914   .0472874   -11.71   0.000    -.6541361   -.4536466
      dmdumiso11 |   .7391189    .108674     6.80   0.000     .5087404    .9694975
      dmdumiso12 |   -.288271   .0519091    -5.55   0.000    -.3983134   -.1782286
      dmdumiso13 |  -.3212453   .0428807    -7.49   0.000    -.4121482   -.2303423
      dmdumiso14 |  -.1089442   .0585301    -1.86   0.081    -.2330226    .0151341
      dmdumiso15 |  -.5414152   .1567746    -3.45   0.003    -.8737625    -.209068
      dmdumiso16 |  -.4689394   .0821506    -5.71   0.000    -.6430909    -.294788
            wgdp |   .0587929   .0687352     0.86   0.405    -.0869193     .204505
           _cons |   2.205666   .3489191     6.32   0.000     1.465991    2.945342
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        205
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7671
                                                    Root MSE          =     1.7095
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .1940963    .334303     0.58   0.570    -.5145945    .9027871
           lgfAA |   .2541794   .0813766     3.12   0.007     .0816687    .4266901
            hply |  -1.565378   .1664405    -9.41   0.000    -1.918216    -1.21254
         dml0dly |   .9244149    .075235    12.29   0.000     .7649239    1.083906
         dml1dly |   .5642328   .1239996     4.55   0.000     .3013655    .8271002
       dmdumiso1 |  -.2557267   .0807773    -3.17   0.006    -.4269669   -.0844865
       dmdumiso2 |  -.7578684    .159629    -4.75   0.000    -1.096267   -.4194699
       dmdumiso3 |  -.4710333   .1475843    -3.19   0.006     -.783898   -.1581685
       dmdumiso4 |   .1920404   .0787048     2.44   0.027     .0251937    .3588871
       dmdumiso5 |  -.7249062   .2381547    -3.04   0.008    -1.229772   -.2200409
       dmdumiso6 |  -.0315274   .2227531    -0.14   0.889    -.5037428    .4406881
       dmdumiso7 |   1.266314   .1245507    10.17   0.000     1.002279     1.53035
       dmdumiso8 |   1.135256   .2370003     4.79   0.000     .6328378    1.637674
       dmdumiso9 |   .2169126   .1863682     1.16   0.262    -.1781704    .6119956
      dmdumiso10 |   .7808697   .1191023     6.56   0.000     .5283842    1.033355
      dmdumiso11 |   1.909598   .2815205     6.78   0.000     1.312801    2.506395
      dmdumiso12 |  -.5860648   .1847721    -3.17   0.006    -.9777643   -.1943654
      dmdumiso13 |  -.0834228   .1024608    -0.81   0.427      -.30063    .1337844
      dmdumiso14 |  -.0047043   .1535107    -0.03   0.976    -.3301324    .3207238
      dmdumiso15 |   .4988223   .3059777     1.63   0.123    -.1498214    1.147466
      dmdumiso16 |   .5106573   .1482717     3.44   0.003     .1963354    .8249793
            wgdp |   .5393567   .1443959     3.74   0.002     .2332511    .8454622
           _cons |    3.79002   .5144234     7.37   0.000     2.699492    4.880549
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        235
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7849
                                                    Root MSE          =     1.4727
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly2 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.1507782   .2075755    -0.73   0.478    -.5908185    .2892622
           lgfAA |  -.0466026   .0766988    -0.61   0.552    -.2091967    .1159915
            hply |  -1.209617   .1291007    -9.37   0.000    -1.483299   -.9359361
         dml0dly |   .6870066   .0444259    15.46   0.000      .592828    .7811853
         dml1dly |   .5428517   .0511553    10.61   0.000     .4344074     .651296
       dmdumiso1 |   .8839895   .0807644    10.95   0.000     .7127766    1.055202
       dmdumiso2 |   -.104654   .1403241    -0.75   0.467    -.4021278    .1928198
       dmdumiso3 |  -.4323487   .1077996    -4.01   0.001    -.6608736   -.2038238
       dmdumiso4 |  -.1537001   .1138064    -1.35   0.196    -.3949589    .0875587
       dmdumiso5 |  -.1980574    .124151    -1.60   0.130    -.4612458    .0651309
       dmdumiso6 |  -.7474642   .0774647    -9.65   0.000     -.911682   -.5832464
       dmdumiso7 |  -.4866982   .0746991    -6.52   0.000    -.6450532   -.3283431
       dmdumiso8 |  -1.064817   .1439937    -7.39   0.000     -1.37007   -.7595644
       dmdumiso9 |  -.6272737   .0928511    -6.76   0.000    -.8241091   -.4304382
      dmdumiso10 |  -.7128913   .0495196   -14.40   0.000    -.8178682   -.6079143
      dmdumiso11 |   2.546159    .243111    10.47   0.000     2.030787    3.061531
      dmdumiso12 |  -.7557539   .0970639    -7.79   0.000    -.9615201   -.5499877
      dmdumiso13 |  -.6592213   .0744699    -8.85   0.000    -.8170903   -.5013523
      dmdumiso14 |   .0908247     .09473     0.96   0.352    -.1099939    .2916432
      dmdumiso15 |  -.2073031   .1861556    -1.11   0.282    -.6019354    .1873292
      dmdumiso16 |  -.4894968   .1315497    -3.72   0.002    -.7683697   -.2106238
            wgdp |   -.114965   .0813579    -1.41   0.177    -.2874361    .0575061
           _cons |   5.598827   .3665035    15.28   0.000     4.821875     6.37578
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        192
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8232
                                                    Root MSE          =     1.9069
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.0231207   .3966802    -0.06   0.954    -.8640451    .8178038
           lgfAA |   .0680812   .0550328     1.24   0.234    -.0485833    .1847456
            hply |  -2.456866   .2304226   -10.66   0.000     -2.94534   -1.968392
         dml0dly |   .9274601   .1010811     9.18   0.000     .7131777    1.141743
         dml1dly |   .8140048   .1271751     6.40   0.000     .5444055    1.083604
       dmdumiso1 |   .0433176   .0790385     0.55   0.591    -.1242365    .2108718
       dmdumiso2 |  -1.335272   .1564169    -8.54   0.000    -1.666861   -1.003683
       dmdumiso3 |  -1.007103   .1712583    -5.88   0.000    -1.370154   -.6440512
       dmdumiso4 |   .5322499   .1226487     4.34   0.001     .2722462    .7922535
       dmdumiso5 |  -1.734258   .3247408    -5.34   0.000    -2.422678   -1.045838
       dmdumiso6 |  -.8265674    .250375    -3.30   0.005    -1.357339   -.2957962
       dmdumiso7 |   1.530991   .1530885    10.00   0.000     1.206458    1.855524
       dmdumiso8 |   1.004983   .3429859     2.93   0.010      .277885     1.73208
       dmdumiso9 |  -.6036896   .2113176    -2.86   0.011    -1.051663   -.1557163
      dmdumiso10 |   .4602066   .1454888     3.16   0.006     .1517842     .768629
      dmdumiso11 |   3.555771   .3625437     9.81   0.000     2.787213    4.324329
      dmdumiso12 |  -1.402425    .231633    -6.05   0.000    -1.893465    -.911385
      dmdumiso13 |  -.4699463   .1504804    -3.12   0.007    -.7889504   -.1509422
      dmdumiso14 |  -.5282167   .1828448    -2.89   0.011    -.9158303   -.1406032
      dmdumiso15 |     .12523   .3964381     0.32   0.756    -.7151811    .9656412
      dmdumiso16 |   -.152266   .1978147    -0.77   0.453    -.5716144    .2670824
            wgdp |   .2047496   .1458452     1.40   0.179    -.1044284    .5139275
           _cons |   7.880299   .5408146    14.57   0.000     6.733824    9.026775
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        231
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8386
                                                    Root MSE          =     1.7438
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly3 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.0978198   .2345749    -0.42   0.682    -.5950963    .3994567
           lgfAA |  -.1802233   .1246533    -1.45   0.168    -.4444764    .0840299
            hply |  -1.694427   .1911522    -8.86   0.000    -2.099651   -1.289202
         dml0dly |   .8701881   .1055501     8.24   0.000     .6464319    1.093944
         dml1dly |   .7152993   .0916822     7.80   0.000     .5209417    .9096569
       dmdumiso1 |   .6835111   .1148423     5.95   0.000     .4400564    .9269658
       dmdumiso2 |  -.9582343    .279265    -3.43   0.003     -1.55025    -.366219
       dmdumiso3 |   -1.36756   .2162455    -6.32   0.000     -1.82598   -.9091401
       dmdumiso4 |  -.6884914   .1716739    -4.01   0.001    -1.052424   -.3245591
       dmdumiso5 |  -1.307548     .21461    -6.09   0.000      -1.7625   -.8525948
       dmdumiso6 |  -1.417986   .1771877    -8.00   0.000    -1.793607   -1.042365
       dmdumiso7 |  -.9469168   .1145126    -8.27   0.000    -1.189673    -.704161
       dmdumiso8 |  -1.322429   .1842748    -7.18   0.000    -1.713074   -.9317842
       dmdumiso9 |  -1.678748   .1836307    -9.14   0.000    -2.068028   -1.289469
      dmdumiso10 |  -1.141264    .078706   -14.50   0.000    -1.308113    -.974415
      dmdumiso11 |   3.875155   .5359509     7.23   0.000      2.73899     5.01132
      dmdumiso12 |  -2.040269   .2280994    -8.94   0.000    -2.523818    -1.55672
      dmdumiso13 |  -1.688595   .0947359   -17.82   0.000    -1.889427   -1.487764
      dmdumiso14 |  -.3575026   .1646204    -2.17   0.045    -.7064823    -.008523
      dmdumiso15 |  -.2886458   .2525645    -1.14   0.270    -.8240586    .2467669
      dmdumiso16 |  -.9566975    .234921    -4.07   0.001    -1.454708   -.4586872
            wgdp |  -.0722092   .1455863    -0.50   0.627    -.3808383      .23642
           _cons |   8.331714   .5252444    15.86   0.000     7.218246    9.445183
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        180
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8406
                                                    Root MSE          =     2.0619
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   -.353009   .3654839    -0.97   0.348      -1.1278    .4217823
           lgfAA |  -.1676819   .0994672    -1.69   0.111    -.3785429     .043179
            hply |  -2.695602   .2945215    -9.15   0.000    -3.319959   -2.071244
         dml0dly |   .7342425   .1294948     5.67   0.000     .4597259    1.008759
         dml1dly |   1.079724   .1862966     5.80   0.000      .684793    1.474655
       dmdumiso1 |   .6996927   .0941155     7.43   0.000     .5001767    .8992088
       dmdumiso2 |   -2.57041   .2305203   -11.15   0.000    -3.059091   -2.081729
       dmdumiso3 |  -2.197289    .296749    -7.40   0.000    -2.826369   -1.568209
       dmdumiso4 |   .2059697   .2259703     0.91   0.376     -.273066    .6850055
       dmdumiso5 |  -3.004367   .4860401    -6.18   0.000    -4.034726   -1.974008
       dmdumiso6 |  -2.115246   .3929335    -5.38   0.000    -2.948228   -1.282265
       dmdumiso7 |   .8537739   .2309546     3.70   0.002      .364172    1.343376
       dmdumiso8 |  -.5443539   .4298374    -1.27   0.223    -1.455569    .3668608
       dmdumiso9 |  -2.100499   .3314053    -6.34   0.000    -2.803047   -1.397951
      dmdumiso10 |  -.3793573    .201772    -1.88   0.078    -.8070949    .0483803
      dmdumiso11 |    4.79091   .4533182    10.57   0.000     3.829918    5.751902
      dmdumiso12 |   -2.73302   .3639916    -7.51   0.000    -3.504648   -1.961392
      dmdumiso13 |  -1.875435   .2283491    -8.21   0.000    -2.359514   -1.391357
      dmdumiso14 |  -1.365379   .2888053    -4.73   0.000    -1.977619   -.7531388
      dmdumiso15 |  -1.422443   .5197404    -2.74   0.015    -2.524244   -.3206428
      dmdumiso16 |  -1.611384   .2908034    -5.54   0.000    -2.227859   -.9949078
            wgdp |  -.2854647    .174868    -1.63   0.122    -.6561683    .0852388
           _cons |   11.54533   .6283474    18.37   0.000      10.2133    12.87737
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        226
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8558
                                                    Root MSE          =     2.0781
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly4 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .1277918    .324491     0.39   0.699    -.5600984    .8156821
           lgfAA |  -.2986896   .1572291    -1.90   0.076    -.6320004    .0346211
            hply |  -2.171081   .2839546    -7.65   0.000    -2.773038   -1.569125
         dml0dly |   .8961705   .1402255     6.39   0.000     .5989057    1.193435
         dml1dly |     .89815   .1526748     5.88   0.000      .574494    1.221806
       dmdumiso1 |   .4679085   .1756638     2.66   0.017     .0955179    .8402991
       dmdumiso2 |  -1.435476   .4388957    -3.27   0.005    -2.365893   -.5050588
       dmdumiso3 |  -1.948061   .3567439    -5.46   0.000    -2.704325   -1.191798
       dmdumiso4 |  -.9807393   .2051565    -4.78   0.000    -1.415652   -.5458269
       dmdumiso5 |  -2.544596    .295219    -8.62   0.000    -3.170432   -1.918759
       dmdumiso6 |  -1.954984   .2423438    -8.07   0.000    -2.468729   -1.441238
       dmdumiso7 |  -.9182018   .1353677    -6.78   0.000    -1.205168   -.6312351
       dmdumiso8 |  -1.168794   .2401987    -4.87   0.000    -1.677992   -.6595954
       dmdumiso9 |  -2.507124   .2977653    -8.42   0.000    -3.138358    -1.87589
      dmdumiso10 |  -1.485791   .1045837   -14.21   0.000    -1.707499   -1.264084
      dmdumiso11 |   5.985438   .8369938     7.15   0.000      4.21109    7.759785
      dmdumiso12 |  -3.192119   .3849615    -8.29   0.000    -4.008201   -2.376038
      dmdumiso13 |  -2.323926    .126077   -18.43   0.000    -2.591197   -2.056655
      dmdumiso14 |  -.5699009   .2481141    -2.30   0.035    -1.095879   -.0439226
      dmdumiso15 |   .1584884   .3595596     0.44   0.665    -.6037439    .9207207
      dmdumiso16 |  -1.271465   .3353957    -3.79   0.002    -1.982473   -.5604584
            wgdp |  -.0613378   .2434095    -0.25   0.804     -.577343    .4546673
           _cons |   10.96825   .7733198    14.18   0.000     9.328889    12.60762
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.7963
                                                    Root MSE          =     2.6085
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -.6785607    .391397    -1.73   0.102    -1.508285    .1511639
           lgfAA |  -.2208823   .1433502    -1.54   0.143    -.5247711    .0830066
            hply |  -2.460713   .3238086    -7.60   0.000    -3.147156   -1.774269
         dml0dly |   .6407658   .1797654     3.56   0.003     .2596801    1.021852
         dml1dly |   1.223968   .2412665     5.07   0.000     .7125059     1.73543
       dmdumiso1 |   1.320761   .1306716    10.11   0.000      1.04375    1.597773
       dmdumiso2 |  -2.871673   .4451632    -6.45   0.000    -3.815377   -1.927969
       dmdumiso3 |  -2.974628   .5154145    -5.77   0.000    -4.067258   -1.881998
       dmdumiso4 |  -.5420557   .3536027    -1.53   0.145     -1.29166    .2075485
       dmdumiso5 |  -3.574114    .720793    -4.96   0.000    -5.102127   -2.046101
       dmdumiso6 |  -3.345002   .5427248    -6.16   0.000    -4.495528   -2.194477
       dmdumiso7 |   .1175272   .3812932     0.31   0.762    -.6907783    .9258326
       dmdumiso8 |  -2.066362   .4581195    -4.51   0.000    -3.037532   -1.095192
       dmdumiso9 |  -3.275092   .5654148    -5.79   0.000    -4.473718   -2.076467
      dmdumiso10 |  -1.205938   .3245118    -3.72   0.002    -1.893872   -.5180038
      dmdumiso11 |   6.448495   .4278069    15.07   0.000     5.541585    7.355405
      dmdumiso12 |  -3.926028   .6306017    -6.23   0.000    -5.262844   -2.589212
      dmdumiso13 |  -4.181641   .3382215   -12.36   0.000    -4.898639   -3.464644
      dmdumiso14 |   -1.53625   .4915003    -3.13   0.007    -2.578184   -.4943157
      dmdumiso15 |  -2.618454    .577616    -4.53   0.000    -3.842945   -1.393963
      dmdumiso16 |   -2.66885   .4969475    -5.37   0.000    -3.722332   -1.615368
            wgdp |  -.6922004   .2364054    -2.93   0.010    -1.193357   -.1910434
           _cons |   14.52175   .8440153    17.21   0.000     12.73252    16.31098
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8400
                                                    Root MSE          =     2.6084
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly5 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .1644152   .4923561     0.33   0.743     -.879333    1.208164
           lgfAA |   -.521139   .2199609    -2.37   0.031    -.9874353   -.0548427
            hply |  -2.530398   .3665622    -6.90   0.000    -3.307475   -1.753321
         dml0dly |      .9599   .2250764     4.26   0.001     .4827593    1.437041
         dml1dly |   .8548453   .2075044     4.12   0.001     .4149556    1.294735
       dmdumiso1 |   .6226346   .2312209     2.69   0.016     .1324681    1.112801
       dmdumiso2 |  -1.918794   .6944536    -2.76   0.014     -3.39097   -.4466178
       dmdumiso3 |  -2.550042   .5950368    -4.29   0.001    -3.811463    -1.28862
       dmdumiso4 |  -.9703341   .2009601    -4.83   0.000    -1.396351   -.5443176
       dmdumiso5 |  -3.608055   .5006174    -7.21   0.000    -4.669316   -2.546793
       dmdumiso6 |  -2.576761   .3843481    -6.70   0.000    -3.391542   -1.761979
       dmdumiso7 |  -.5424448   .1588287    -3.42   0.004    -.8791466   -.2057429
       dmdumiso8 |  -1.418777   .2729028    -5.20   0.000    -1.997305   -.8402489
       dmdumiso9 |  -3.165931   .4803767    -6.59   0.000    -4.184284   -2.147578
      dmdumiso10 |  -1.689704   .1854556    -9.11   0.000    -2.082852   -1.296556
      dmdumiso11 |   8.458918   1.128015     7.50   0.000     6.067632     10.8502
      dmdumiso12 |  -4.367327   .5402422    -8.08   0.000    -5.512589   -3.222064
      dmdumiso13 |  -2.141085    .270131    -7.93   0.000    -2.713737   -1.568433
      dmdumiso14 |  -.9302181   .3991592    -2.33   0.033    -1.776398   -.0840384
      dmdumiso15 |   .4609169    .419087     1.10   0.288    -.4275078    1.349342
      dmdumiso16 |  -1.729062   .4961566    -3.48   0.003    -2.780867   -.6772572
            wgdp |  -.3202219   .3359915    -0.95   0.355    -1.032492    .3920481
           _cons |   14.27286   .9542636    14.96   0.000     12.24991    16.29581
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        175
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8914
                                                    Root MSE          =     6.3191
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |  -1.681806   1.113949    -1.51   0.151    -4.043272    .6796602
           lgfAA |   .0831231   .2740228     0.30   0.766    -.4977792    .6640255
            hply |  -9.808167   .8806692   -11.14   0.000     -11.6751   -7.941232
         dml0dly |   4.320974   .5677204     7.61   0.000     3.117461    5.524488
         dml1dly |   3.854442   .5523768     6.98   0.000     2.683455    5.025428
       dmdumiso1 |   1.003841   .3208618     3.13   0.006     .3236445    1.684038
       dmdumiso2 |  -7.836154   .7593352   -10.32   0.000    -9.445873   -6.226435
       dmdumiso3 |  -6.961658   .9221122    -7.55   0.000    -8.916448   -5.006867
       dmdumiso4 |  -.1753794   .7084995    -0.25   0.808    -1.677331    1.326572
       dmdumiso5 |  -9.457432   1.565547    -6.04   0.000    -12.77624    -6.13862
       dmdumiso6 |  -5.988323   1.373868    -4.36   0.000    -8.900793   -3.075854
       dmdumiso7 |   3.234059    .859537     3.76   0.002     1.411922    5.056196
       dmdumiso8 |  -.5712044   1.410051    -0.41   0.691     -3.56038    2.417971
       dmdumiso9 |  -5.821736   1.004679    -5.79   0.000    -7.951561   -3.691911
      dmdumiso10 |   .1807255   .7632894     0.24   0.816    -1.437376    1.798827
      dmdumiso11 |   13.81022   1.878475     7.35   0.000     9.828036    17.79241
      dmdumiso12 |  -9.084496   1.189118    -7.64   0.000    -11.60531   -6.563679
      dmdumiso13 |  -6.311707   .8032465    -7.86   0.000    -8.014513     -4.6089
      dmdumiso14 |  -3.627311   .8278414    -4.38   0.000    -5.382256   -1.872365
      dmdumiso15 |  -3.863191   1.682116    -2.30   0.035    -7.429119   -.2972636
      dmdumiso16 |  -3.895343   1.098547    -3.55   0.003    -6.224159   -1.566526
            wgdp |  -.8219193   .7050534    -1.17   0.261    -2.316566    .6727272
           _cons |   41.70416   1.738353    23.99   0.000     38.01902     45.3893
    ------------------------------------------------------------------------------
    
    Linear regression                               Number of obs     =        214
                                                    F(5, 16)          =          .
                                                    Prob > F          =          .
                                                    R-squared         =     0.8943
                                                    Root MSE          =     6.6983
    
                                       (Std. Err. adjusted for 17 clusters in iso)
    ------------------------------------------------------------------------------
                 |               Robust
             ly6 |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
           smfAA |   .0279561    1.09472     0.03   0.980    -2.292747    2.348659
           lgfAA |  -1.158223    .533543    -2.17   0.045    -2.289284   -.0271627
            hply |  -8.475225   .9013953    -9.40   0.000     -10.3861   -6.564352
         dml0dly |    3.93616   .4536031     8.68   0.000     2.974564    4.897755
         dml1dly |   3.310127    .476716     6.94   0.000     2.299534     4.32072
       dmdumiso1 |   3.248285    .511248     6.35   0.000     2.164488    4.332082
       dmdumiso2 |  -4.313283   1.555532    -2.77   0.014    -7.610863   -1.015702
       dmdumiso3 |  -6.252748   1.211476    -5.16   0.000    -8.820961   -3.684534
       dmdumiso4 |  -2.830306   .6405738    -4.42   0.000    -4.188261    -1.47235
       dmdumiso5 |  -7.486192   .9869175    -7.59   0.000    -9.578364    -5.39402
       dmdumiso6 |  -7.504212   .8756572    -8.57   0.000    -9.360522   -5.647901
       dmdumiso7 |   -3.02942   .3666887    -8.26   0.000    -3.806765   -2.252075
       dmdumiso8 |  -6.885048   .8095223    -8.51   0.000    -8.601159   -5.168937
       dmdumiso9 |  -8.106744   .9807112    -8.27   0.000    -10.18576   -6.027729
      dmdumiso10 |  -5.365189   .3924408   -13.67   0.000    -6.197126   -4.533251
      dmdumiso11 |   21.40064   2.587697     8.27   0.000     15.91497    26.88631
      dmdumiso12 |  -10.33688   1.183839    -8.73   0.000    -12.84651   -7.827255
      dmdumiso13 |  -6.686253   .4809859   -13.90   0.000    -7.705898   -5.666609
      dmdumiso14 |  -1.783124    .861442    -2.07   0.055    -3.609299    .0430518
      dmdumiso15 |   .0658194   1.237757     0.05   0.958    -2.558108    2.689746
      dmdumiso16 |  -5.362327   1.150675    -4.66   0.000    -7.801648   -2.923005
            wgdp |  -.8197096   .7364004    -1.11   0.282    -2.380809    .7413896
           _cons |   41.79621   2.359092    17.72   0.000     36.79515    46.79726
    ------------------------------------------------------------------------------
    
    
