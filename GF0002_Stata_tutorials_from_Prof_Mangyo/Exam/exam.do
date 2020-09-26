* This is a suggested answer to the Stata Exam, Spring 2012

clear
log using exam, replace
* Your name, Your student ID

* 1
infix using dictionary.dct

* 2
label define SEX 1 "male" 2 "female"
label values sex SEX

* 3
gen num_wealth=1 if wealth=="poorest"
replace num_wealth=2 if wealth=="poorer"
replace num_wealth=3 if wealth=="middle"
replace num_wealth=4 if wealth=="richer"
replace num_wealth=5 if wealth=="richest"

* 4
su age

* 5
bysort wealth: su childzha
*** or ***
bysort num_wealth: su childzha

* 6
* Child height and mother's height should be positively correlated. Further,
* due to regression towards the mean, beta1 should be less than unity. That is,
* 0 < beta1 < 1.

* 7
regress childzha momzha

* 8
* One standard-deviation increase in mother's height is associated with
* 0.34 standard-deviation increase in child height. Given the magnitude
* of 0.34, the hypothesis of regression towards the mean is supported. 

log close
