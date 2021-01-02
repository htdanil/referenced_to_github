```python
%%capture
#--------------------------------------------------------------------------------------------
# Creating R environment to be executed in Jupyter Notebook
#--------------------------------------------------------------------------------------------
import rpy2.rinterface
from IPython.display import Image
%load_ext rpy2.ipython
%matplotlib inline
%config InlineBackend.figure_format = 'jpg'
```


```python
import ipystata
```

# Example 13.1 : Women's Fertility Over Time

## (STATA)


```python
%%stata -cwd -os
use https://github.com/htdanil/referenced_to_github/raw/master/GF0003_wooldridge_datasets/3rd%20edition/stata/FERTIL1.DTA, clear
reg kids educ age agesq black east northcen west farm othrural town smcity y74 y76 y78 y80 y82 y84
```

    Set the working directory of Stata to: G:\My Drive\anilsth@iuj.ac.jp\Hiroshima Study\self practice\Wooldridge Practice
    
          Source |       SS           df       MS      Number of obs   =     1,129
    -------------+----------------------------------   F(17, 1111)     =      9.72
           Model |  399.610888        17  23.5065228   Prob > F        =    0.0000
        Residual |  2685.89841     1,111  2.41755033   R-squared       =    0.1295
    -------------+----------------------------------   Adj R-squared   =    0.1162
           Total |   3085.5093     1,128  2.73538059   Root MSE        =    1.5548
    
    ------------------------------------------------------------------------------
            kids |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
            educ |  -.1284268   .0183486    -7.00   0.000    -.1644286    -.092425
             age |   .5321346   .1383863     3.85   0.000     .2606065    .8036626
           agesq |   -.005804   .0015643    -3.71   0.000    -.0088733   -.0027347
           black |   1.075658   .1735356     6.20   0.000     .7351631    1.416152
            east |    .217324   .1327878     1.64   0.102    -.0432192    .4778672
        northcen |    .363114   .1208969     3.00   0.003      .125902    .6003261
            west |   .1976032   .1669134     1.18   0.237    -.1298978    .5251041
            farm |  -.0525575     .14719    -0.36   0.721    -.3413592    .2362443
        othrural |  -.1628537    .175442    -0.93   0.353    -.5070887    .1813814
            town |   .0843532    .124531     0.68   0.498    -.1599893    .3286957
          smcity |   .2118791    .160296     1.32   0.187    -.1026379    .5263961
             y74 |   .2681825    .172716     1.55   0.121    -.0707039    .6070689
             y76 |  -.0973795   .1790456    -0.54   0.587     -.448685    .2539261
             y78 |  -.0686665   .1816837    -0.38   0.706    -.4251483    .2878154
             y80 |  -.0713053   .1827707    -0.39   0.697      -.42992    .2873093
             y82 |  -.5224842   .1724361    -3.03   0.003    -.8608214    -.184147
             y84 |  -.5451661   .1745162    -3.12   0.002    -.8875846   -.2027477
           _cons |  -7.742457   3.051767    -2.54   0.011    -13.73033   -1.754579
    ------------------------------------------------------------------------------
    
    


```python
%%stata -os
*#Year dummies are jointly significant
test y74 y76 y78 y80 y82 y84
```

    
     ( 1)  y74 = 0
     ( 2)  y76 = 0
     ( 3)  y78 = 0
     ( 4)  y80 = 0
     ( 5)  y82 = 0
     ( 6)  y84 = 0
    
           F(  6,  1111) =    5.87
                Prob > F =    0.0000
    
    

## (R)


```r
%%R
library(wooldridge)
df <- wooldridge::fertil1
model <- lm(kids ~ educ+age+agesq+black+east+northcen+west+farm+othrural+town+smcity+y74+y76+y78+y80+y82+y84, data = df)

summary(model)
```

    
    Call:
    lm(formula = kids ~ educ + age + agesq + black + east + northcen + 
        west + farm + othrural + town + smcity + y74 + y76 + y78 + 
        y80 + y82 + y84, data = df)
    
    Residuals:
        Min      1Q  Median      3Q     Max 
    -3.9878 -1.0086 -0.0767  0.9331  4.6548 
    
    Coefficients:
                 Estimate Std. Error t value Pr(>|t|)    
    (Intercept) -7.742457   3.051767  -2.537 0.011315 *  
    educ        -0.128427   0.018349  -6.999 4.44e-12 ***
    age          0.532135   0.138386   3.845 0.000127 ***
    agesq       -0.005804   0.001564  -3.710 0.000217 ***
    black        1.075658   0.173536   6.198 8.02e-10 ***
    east         0.217324   0.132788   1.637 0.101992    
    northcen     0.363114   0.120897   3.004 0.002729 ** 
    west         0.197603   0.166913   1.184 0.236719    
    farm        -0.052557   0.147190  -0.357 0.721105    
    othrural    -0.162854   0.175442  -0.928 0.353481    
    town         0.084353   0.124531   0.677 0.498314    
    smcity       0.211879   0.160296   1.322 0.186507    
    y74          0.268183   0.172716   1.553 0.120771    
    y76         -0.097379   0.179046  -0.544 0.586633    
    y78         -0.068666   0.181684  -0.378 0.705544    
    y80         -0.071305   0.182771  -0.390 0.696511    
    y82         -0.522484   0.172436  -3.030 0.002502 ** 
    y84         -0.545166   0.174516  -3.124 0.001831 ** 
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    
    Residual standard error: 1.555 on 1111 degrees of freedom
    Multiple R-squared:  0.1295,	Adjusted R-squared:  0.1162 
    F-statistic: 9.723 on 17 and 1111 DF,  p-value: < 2.2e-16
    
    


```r
%%R
#Year dummies are jointly significant
car::linearHypothesis(model, c("y74=0", "y76=0", "y78=0","y80=0", "y82=0", "y84=0"))
```

    Linear hypothesis test
    
    Hypothesis:
    y74 = 0
    y76 = 0
    y78 = 0
    y80 = 0
    y82 = 0
    y84 = 0
    
    Model 1: restricted model
    Model 2: kids ~ educ + age + agesq + black + east + northcen + west + 
        farm + othrural + town + smcity + y74 + y76 + y78 + y80 + 
        y82 + y84
    
      Res.Df    RSS Df Sum of Sq      F    Pr(>F)    
    1   1117 2771.0                                  
    2   1111 2685.9  6    85.139 5.8695 4.855e-06 ***
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    

# Example 13.2 : Changes to the Return to Education and the Gender Wage Gap

## (STATA)


```python
%%stata -os
use https://github.com/htdanil/referenced_to_github/raw/master/GF0003_wooldridge_datasets/3rd%20edition/stata/CPS78_85.DTA, clear

reg lwage y85 educ y85educ exper expersq union female y85fem
```

          Source |       SS           df       MS      Number of obs   =     1,084
    -------------+----------------------------------   F(8, 1075)      =     99.80
           Model |  135.992074         8  16.9990092   Prob > F        =    0.0000
        Residual |  183.099094     1,075  .170324738   R-squared       =    0.4262
    -------------+----------------------------------   Adj R-squared   =    0.4219
           Total |  319.091167     1,083   .29463635   Root MSE        =     .4127
    
    ------------------------------------------------------------------------------
           lwage |      Coef.   Std. Err.      t    P>|t|     [95% Conf. Interval]
    -------------+----------------------------------------------------------------
             y85 |   .1178062   .1237817     0.95   0.341     -.125075    .3606874
            educ |   .0747209   .0066764    11.19   0.000     .0616206    .0878212
         y85educ |   .0184605   .0093542     1.97   0.049      .000106     .036815
           exper |   .0295843   .0035673     8.29   0.000     .0225846     .036584
         expersq |  -.0003994   .0000775    -5.15   0.000    -.0005516   -.0002473
           union |   .2021319   .0302945     6.67   0.000     .1426888    .2615749
          female |  -.3167086   .0366215    -8.65   0.000    -.3885663    -.244851
          y85fem |    .085052    .051309     1.66   0.098    -.0156251     .185729
           _cons |   .4589329   .0934485     4.91   0.000     .2755707     .642295
    ------------------------------------------------------------------------------
    
    

## (R)


```r
%%R
library(wooldridge)
df <- wooldridge::cps78_85
model <- lm(lwage ~ y85*(educ+female) + exper + I(exper^2) + union, data = df)

summary(model)
```

    
    Call:
    lm(formula = lwage ~ y85 * (educ + female) + exper + I(exper^2) + 
        union, data = df)
    
    Residuals:
         Min       1Q   Median       3Q      Max 
    -2.56098 -0.25828  0.00864  0.26571  2.11669 
    
    Coefficients:
                  Estimate Std. Error t value Pr(>|t|)    
    (Intercept)  4.589e-01  9.345e-02   4.911 1.05e-06 ***
    y85          1.178e-01  1.238e-01   0.952   0.3415    
    educ         7.472e-02  6.676e-03  11.192  < 2e-16 ***
    female      -3.167e-01  3.662e-02  -8.648  < 2e-16 ***
    exper        2.958e-02  3.567e-03   8.293 3.27e-16 ***
    I(exper^2)  -3.994e-04  7.754e-05  -5.151 3.08e-07 ***
    union        2.021e-01  3.029e-02   6.672 4.03e-11 ***
    y85:educ     1.846e-02  9.354e-03   1.974   0.0487 *  
    y85:female   8.505e-02  5.131e-02   1.658   0.0977 .  
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    
    Residual standard error: 0.4127 on 1075 degrees of freedom
    Multiple R-squared:  0.4262,	Adjusted R-squared:  0.4219 
    F-statistic:  99.8 on 8 and 1075 DF,  p-value: < 2.2e-16
    
    
