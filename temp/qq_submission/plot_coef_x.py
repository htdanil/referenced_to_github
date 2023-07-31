import matplotlib.pyplot as plt
from matplotlib import colors
import numpy as np
import pandas as pd
import seaborn as sns
import sys
import pickle

df = pd.read_csv('output/{}.csv'.format(sys.argv[3]))
del df['Unnamed: 0']

X = Y = xy_range = np.arange(0.05, 1, 0.05) #creating 1D array of X and Y axis
X,Y = np.meshgrid(X,Y) #creating 2D array from X and Y axis variables
Z = df.to_numpy() #converting the dataframe to numpy array

fig = plt.figure(figsize=(10,6))
ax1 = fig.add_subplot(111, projection='3d')
ax1.set_zlim(np.min(Z),np.max(Z))
divnorm = colors.TwoSlopeNorm(vmin = -np.max(np.abs(Z)), vcenter = 0, vmax = np.max(np.abs(Z)))
cmap = "seismic"
surf1 = ax1.plot_surface(X, Y, Z, cmap=cmap, norm = divnorm)
fig.colorbar(surf1, ax=ax1, shrink=0.5, aspect=6)
ax1.invert_xaxis()
ax1.set_title("")
ax1.set_ylabel(sys.argv[2])
ax1.set_xlabel(sys.argv[1])
plt.savefig('output/{}_3d.svg'.format(sys.argv[3]), bbox_inches='tight')

#################################################################################################
f, ax = plt.subplots(figsize=(16, 9))
sns.set(font_scale=1.2)
sns.heatmap(df, annot=False, fmt='.2f', linewidths=0.5, ax=ax, cmap=cmap, norm=divnorm, linewidth=1)
ax.set_ylabel(sys.argv[2], fontsize = 25)
ax.set_xlabel(sys.argv[1], fontsize = 25)
ax.invert_yaxis()
ax.invert_xaxis()
ax.set_xticklabels(list(np.round(xy_range,2)), fontsize = 18)
ax.set_yticklabels(list(np.round(xy_range,2)), fontsize = 18)
plt.yticks(rotation=0)
plt.savefig('output/{}_heatmap.svg'.format(sys.argv[3]), bbox_inches='tight')