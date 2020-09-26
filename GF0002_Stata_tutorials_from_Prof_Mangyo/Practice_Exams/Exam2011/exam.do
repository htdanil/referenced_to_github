* Your name, Your student ID

* This is a suggested answer to the Stata Exam, Spring 2011

clear
log using exam, replace

* 1
use hhinc
su rhhinc1997 rhhinc2000

* 2
merge id using hhexp

* 3
tab _merge,m
* Since _merge=3 for all sample households, there are no sample households
* whose expenditure data or income data are missing. There are 3,512 households
* which have both income and expenditure data.
 
* 4
gen commid=substr(id,1,4)

* 5
bysort commid: egen rcomexp1997=mean(rhhexp1997)
bysort commid: egen rcomexp2000=mean(rhhexp2000)

* 6
gen diff_rhhinc=rhhinc2000-rhhinc1997
gen diff_rhhexp=rhhexp2000-rhhexp1997
gen diff_rcomexp=rcomexp2000-rcomexp1997

* 7
* diff_rhhinc ==> own household income
* diff_rcomexp ==> community-level insurance (community risk-coping system)

* 8
* perfect insurance: beta1=0 and beta2=1
* imperfect insurance: 0<beta1<1 and 0<beta2<1

* 9
regress diff_rhhexp diff_rhhinc diff_rcomexp

* 10
* 1 Rupiah increase in household income is associated with 0.0006 Rupiah increase in household expenditure.
* Below is an additional description which is not necessary as an exam answer.
* In this regression result, own income does not matter for own consumption, but the average consumption levels
* within communities have the estimated coefficient almost equal to one. Thus, this result supports the hypothesis
* of perfect insurance. However, of course, this regression is subject to simultaneity and omitted variables.
 
log close
