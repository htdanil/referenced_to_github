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
use https://github.com/htdanil/referenced_to_github/raw/master/GF0003_wooldridge_datasets/3rd%20edition/stata/FERTIL1.DTA
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
df_fertil1 <- wooldridge::fertil1
model <- lm(kids ~ educ+age+agesq+black+east+northcen+west+farm+othrural+town+smcity+y74+y76+y78+y80+y82+y84, data = df_fertil1)

summary(model)
```

    
    Call:
    lm(formula = kids ~ educ + age + agesq + black + east + northcen + 
        west + farm + othrural + town + smcity + y74 + y76 + y78 + 
        y80 + y82 + y84, data = df_fertil1)
    
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
    
