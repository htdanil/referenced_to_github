* This is a suggested answer to the problems in Tutorial 2.
* Name: you can type your name.
* Student ID: you can type your student ID.

log using answer2, replace
clear
use auto

* (i)
gen new_mpg=mpg
replace new_mpg=24 if make=="Honda Civic"
replace new_mpg=27 if make=="VW Rabbit"
replace new_mpg=. if make=="Chev. Nova" | make=="Peugeot 604"

* (ii)
gen efficient=0 if new_mpg<.
replace efficient=1 if new_mpg>25 & new_mpg<.

* (iii)
egen median_price=median(price)
gen median_deviation=price-median_price

* (iv)
gen reliable=0 if rep78<.
replace reliable=1 if rep78<3
bysort reliable: egen min_mpg=min(new_mpg)
gen more_miles=new_mpg-min_mpg

* Note that although new_mpg for Chev, Nova and Peugeot 604
* are missing, egen creates non-missing values of min_mpg
* for these observations, because other cars in the same
* categories in reliable have non-missing new_mpg.

* (v)
gen price_group=1 if median_deviation<-500
replace price_group=2 if median_deviation>=-500 & median_deviation<500
replace price_group=3 if median_deviation>=500 & median_deviation<.

log close
