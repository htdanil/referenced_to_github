import pandas as pd
import matplotlib.pyplot as plt
plt.style.use('seaborn-whitegrid')
df = pd.read_csv('output/fig_5(a).csv')

df.set_index('taus',inplace=True)
df[['qq_coef','qr_coef']].plot(kind='line', 
                                       style = ['--','-'], 
                                       linewidth = 3, 
                                       alpha = 0.7,
                                       color = ['red', 'blue'])
plt.legend(shadow=True, labels = ['QQ','QR']) #defining legend label
plt.xlabel("Quantiles", fontsize = 19); plt.ylabel("Coefficient", fontsize = 19)
plt.savefig('output/fig_5(a).svg')


df = pd.read_csv('output/fig_5(b).csv')

df.set_index('taus',inplace=True)
df[['qq_coef','qr_coef']].plot(kind='line', 
                                       style = ['--','-'], 
                                       linewidth = 3, 
                                       alpha = 0.7,
                                       color = ['red', 'blue'])
plt.legend(shadow=True, labels = ['QQ','QR']) #defining legend label
plt.xlabel("Quantiles", fontsize = 19); plt.ylabel("Coefficient", fontsize = 19)
plt.savefig('output/fig_5(b).svg')