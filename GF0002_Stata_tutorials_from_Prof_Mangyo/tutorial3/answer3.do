* This is a suggested answer to the problems in Tutorial 3.

log using answer3, replace
* Name
* Student ID
clear

* (i)
use palau_hh_2000
rename h17 toilet
label variable toilet "Access to flush toilet"

* I write the next command in two lines.
* So far, we have written one command in one line.
* However, we sometimes need to write a long command,
* which is easy to see if written in two or multiple lines.
* Here is how to do this.
* Stata ignores anything between /* and */, literally
* anything including line break (return). For example,
* Stata ignores the following message.

/*
This is Stata Tutorial 3. Only two more Tutorials left.
*/

* Likewise, we can write the following long command in three lines.

label define TOILET 1 "Yes, in this unit" 2 "Yes, in this building" /*
*/ 3 "Yes, outside this building" 4 "No, outhouse or privy" /*
*/ 5 "No, other or none"
label values toilet TOILET
save household_labeled, replace

* (ii)
clear
use palau_individual_2000

* First, you should check the original values used by /*
*/ the variable religion. To do so, type /*
*/ label list RELIGION /*
*/ in the command line. You can find the name of the value label RELIGION /*
*/ by "describe religion" 

des religion
label list RELIGION
gen religious_group=3 if religion<.
replace religious_group=1 if religion==2 | religion==3
replace religious_group=2 if religion==9

* (iii)
label variable religious_group "Religious group"
label define RELIGIOUS_GROUP 1 "Catholic or Protestant" /*
*/ 2 "None or Refused to answer" 3 "Other religions"
label values religious_group RELIGIOUS_GROUP

* (iv)
save individual_labeled, replace
clear

use household_labeled
merge 1:m CASE_ID using individual_labeled

* You could tabulate _merge, if you like, /*
*/ to see how the merge was done.
tab _merge,m

* It is a good idea to confirm that variables you use /*
*/ in your analysis do not contain irrelevant values. /*
*/ You can use the command summarize and quickly check /*
*/ whether the income variable fam_income does not contain /*
*/ obvious irrelevant values (such as negative values or /*
*/ extremetly large positive values) by simply checking /*
*/ its min and max values.

su fam_income
bysort religious_group: su fam_income

log close
