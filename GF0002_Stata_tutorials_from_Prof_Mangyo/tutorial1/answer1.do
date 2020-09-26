log using answer1, replace

* This is a suggested answer to the problems in Tutorial 1.

* An asterisk at the beginning of each line tells Stata not to
* read the line (but just copy the line into the smcl file),
* so it is useful to make some notes.  

clear
use auto

* (i)
summarize length if length<200

* (ii)
summarize length if length<200 & mpg>=20

* (iii)
tabulate rep78, missing

* (iv)
bysort foreign: summarize price if mpg>=20

* (v)
* There are at least two ways to do this.
* The first way
bysort foreign: tabulate rep78
* The second way
tabulate foreign rep78, row

log close
