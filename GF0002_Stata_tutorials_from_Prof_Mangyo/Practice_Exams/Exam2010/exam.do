* Your name, Your student ID

* This is a suggested answer to the Stata Exam, Spring 2010

clear
log using exam, replace

* 1
use data
su

* 2
gen no_prime_female=0 if wf19_60<.
replace no_prime_female=1 if wf19_60==0

* 3
bysort no_prime_female: su wfdout
* Households without prime-age females, on average, have
* a higher ratio of expenditure on food out of home to
* total household expenditure in comparison with
* households with prime-age females.
 
* 4
gen lnrpce_pl=log(rpce_pl)

* 5
des island
label list ISLAND

gen usumatra=0 if island<. & urban<.
replace usumatra=1 if island==1 & urban==1

gen rsumatra=0 if island<. & urban<.
replace rsumatra=1 if island==1 & urban==0

gen ujava=0 if island<. & urban<.
replace ujava=1 if island==3 & urban==1

gen rjava=0 if island<. & urban<.
replace rjava=1 if island==3 & urban==0

gen utenggara=0 if island<. & urban<.
replace utenggara=1 if island==5 & urban==1

gen rtenggara=0 if island<. & urban<.
replace rtenggara=1 if island==5 & urban==0

gen ukalimantan=0 if island<. & urban<.
replace ukalimantan=1 if island==6 & urban==1

gen rkalimantan=0 if island<. & urban<.
replace rkalimantan=1 if island==6 & urban==0

gen usulawesi=0 if island<. & urban<.
replace usulawesi=1 if island==7 & urban==1

gen rsulawesi=0 if island<. & urban<.
replace rsulawesi=1 if island==7 & urban==0

* 6
ttest waltb, by(urban) unequal
* Yes, we can reject the null hypothesis in favor of
* the alternative hypothesis, because the p-value for
* the test is 0.0000.

* 7
* The dependent variable is the expenditure share on so-called
* an adult good which is consumed exclusively by adults. By this
* regression model, we examine whether we observe a difference
* in the expenditure on alcohol and tobacco between two types of
* households: households with (a larger number of) girls and
* households with (a larger number of) boys. If girls are
* discriminated against and boys are favored in terms of
* the intra-household allocation of resources, households should
* cut back the expenditure on alcohol and tobacco more when they
* have boys than when they have girls in order to allocate
* a larger amount of household resoures to boys rather than girls. 

* 8
regress waltb lnrpce_pl lnhhsize wm0_6 wf0_6 wm6_19 wf6_19 wf19_60 wm60p wf60p usumatra rsumatra rjava utenggara rtenggara ukalimantan rkalimantan usulawesi rsulawesi

* 9
* The ratio of the monthly expenditure on alcohol and tobacco
* to total monthly household expenditure is, on average,
* 0.015 higher (or 1.5% point higher) in rural Sulawesi
* in comparison with urban Java. 

* 10
* No, I cannot find evidence of unequal distribution of
* household resources against girls in favor of boys.
* Comparing the coefficient estimates on wm0_6 and wf0_6,
* girls have a more negative coefficient estimate than
* boys (-0.044 is more negative than -0.037), implying
* that households cut back the expenditure on alcohol
* and tobacco more when they have girls rather than boys
* (although we do not know whether the difference in
* the coefficient estimates is statistically significant
* or not). Similarily, we observe a more negative
* coefficient estimate for wf6_19 than for wm6_19.
 
log close
