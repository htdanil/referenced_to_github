log using tutorial5,  replace
clear

*** Merge the data sets
use "C:\MyFiles\IUJ\Teaching\Stata\stata-tutorial\tutorial5\data\pcexp.dta"
sort s00key s10key
merge 1:1 s00key s10key using "C:\MyFiles\IUJ\Teaching\Stata\stata-tutorial\tutorial5\data\chronic.dta"
tab _merge,m
drop _merge

*** Check the observations 
su s4001 pcannualexp
histogram pcannualexp
gen log_pcannualexp=log(pcannualexp)
histogram log_pcannualexp

*** Mean comparison test
ttest log_pcannualexp, by (s4001) unequal

*** OLS regression

** regress chronic on log_pcannualexp and a constant
gen chronic=0 if s4001==2
replace chronic=1 if s4001==1

su chronic log_pcannualexp
regress chronic log_pcannualexp

** regress chronic on log_pcannualexp, age-group dummies, and a constant
su s1006y
des s1006y
label list S1006Y

gen age_minor=0 if s1006y<.
replace age_minor=1 if s1006y>=0 & s1006y<20

gen age20=0 if s1006y<.
replace age20=1 if s1006y>=20 & s1006y<30

gen age30=0 if s1006y<.
replace age30=1 if s1006y>=30 & s1006y<40

gen age40=0 if s1006y<.
replace age40=1 if s1006y>=40 & s1006y<50

gen age50=0 if s1006y<.
replace age50=1 if s1006y>=50 & s1006y<60

gen age60=0 if s1006y<.
replace age60=1 if s1006y>=60 & s1006y<70

gen age70plus=0 if s1006y<.
replace age70plus=1 if s1006y>=70 & s1006y<.

su chronic log_pcannualexp age_minor age20 age30 age40 age50 age60 age70plus
regress chronic log_pcannualexp age_minor age30 age40 age50 age60 age70plus

** regress chronic on log_pcannualexp, age-group dummies,
** education dummies, sex , and a constant

tab s1010,m
des s1010
label list S1010

gen noeduc=0 if s1010<=4
replace noeduc=1 if s1010==4

gen primary=0 if s1010<=4
replace primary=1 if s1010==1

gen secondaryplus=0 if s1010<=4
replace secondaryplus=1 if s1010==2 | s1010==3

tab s1002,m
des s1002
label list S1002

gen male=0 if s1002==2
replace male=1 if s1002==1

su chronic log_pcannualexp age_minor age20 age30 age40 age50 age60 age70plus noeduc primary secondaryplus male
regress chronic log_pcannualexp age_minor age30 age40 age50 age60 age70plus primary secondaryplus male

*** OLS with robust standard errors
predict epsilon_hat, residuals 
egen pcannualexp3=cut(pcannualexp), group(3)
tab pcannualexp3,m
bysort pcannualexp3: su epsilon_hat
** Test of heteroskedasticity where the null hypothesis is
** a constant variance of the residuals
estat hettest

regress chronic log_pcannualexp age_minor age30 age40 age50 age60 age70plus primary secondaryplus male, vce(robust)

log close
