* This is a suggested answer to the problems in Tutorial 4.

log using answer4, replace
* Name
* Student ID
clear

* (i)
* Although cancer_ascii.txt is Tab-delimited, a single observation
* is stored in two rows. You need to use either infix or infile to
* import the cancer data.
* It is easier to create a dictionary file first. I created
* cancer_fixed.dct which is attached to this do file.

infix using cancer_fixed.dct

* (ii)
encode drug, gen(drug1) label(DRUG)
drop drug
rename drug1 drug

* (iii)
* The interactive graphics tells you that an appropriate command is
* as follow.
histogram age, by(died)

log close
