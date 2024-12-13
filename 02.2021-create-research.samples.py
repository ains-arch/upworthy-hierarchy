#!/usr/bin/env python
# coding: utf-8

# # Create Research Samples for the Upworthy Archive
# [J. Nathan Matias](https://natematias.com) and Max Klein
# 
# March 2020
# 
# * 15% exploratory
# * 70% confirmatory
# * 15% holdout
# * Undeployed packages (added Jan 2020)
# 
# Requirements:
# * Create buckets of weeks
# * Randomly sample 15%, 70%, and 15% of tests from each week into non-overlapping samples
# * aggregate into three final datasets

# In[1]:


import codecs, csv, pandas, os
from dateutil import parser
from collections import defaultdict, Counter
import nltk
import matplotlib. pyplot as plt
import seaborn as sns
import random
import pandas as pd
import numpy as np

get_ipython().run_line_magic('matplotlib', 'inline')


# ### Load the Upworthy Archive

# In[3]:


data_dir = "ENTER FOLDER HERE"
filename = "data-1558638985054-received-05.24.2019.csv"

## data produced by "Summary Stats of Upworthy Research Archive for CODEMIT.ipynb"
## note: valid packages may not have been fielded
#filename = "upworthy_archive_valid_packages_01.05.2020.csv"

def test_object():
    return {"id":None, "created":None, "packages":[]}

tests = defaultdict(test_object)
valid_packages = []

all_dates = set()
created_2019 = set()

total_packages_available = 0 
total_packages_loaded = 0

undeployed_packages = []

## TODO: Decide if you want to query only tests that were published
## and if so, implement the appropriate filters
with codecs.open(os.path.join(data_dir, filename)) as f:
    for row in csv.DictReader(f):
        
        total_packages_available += 1
        
        ## omit all packages that were not deployed
        ## and prepare to save them in a list of undeployed tests
        if(row['impressions'] == '' or int(row['impressions']) ==0 or
           row['clickability_test_id'] == ''):
            undeployed_packages.append(row)
            continue
        
        package = row
        #for key in ['created_at', 'headline', 'excerpt', 'clickability_test_id']:
        #    package[key] = row[key]
        package['created'] = parser.parse(package['created_at'])
        package['test_week'] = package['created'].strftime("%Y%U")
        
        test_id = package['clickability_test_id']
        
        tests[test_id]['id'] = test_id
        tests[test_id]['packages'].append(package)
        tests[test_id]['created'] = package['created']
        tests[test_id]['week'] = package['created'].strftime("%Y%U")
        all_dates.add(package['created'].date())
        
        if(package['created'].year == 2019):
            created_2019.add(package['created_at'])
        
        valid_packages.append(package)
        
        total_packages_loaded += 1
        
print("{0} total packages available.".format(total_packages_available))
print("{0} total packages loaded.".format(total_packages_loaded))
print("{0} total tests loaded.".format(len(tests)))
print("{0} undeployted packages loaded".format(len(undeployed_packages)))


# # Create a Test - Week Dataframe
# For each test, get the week of the earliest date among the arms in the test.

# In[4]:


test_df = pd.DataFrame.from_dict(tests, orient="index")
del test_df['packages']


# # Generate Random Seed
# 
# Random seed for creating the sample is [documented publicly at Brooklyn Integers](https://www.brooklynintegers.com/int/1712367175/) (created on March 3, 2020).

# In[5]:


np.random.seed(1712367176)


# # Generate Random Samples

# In[6]:


exploratory_dfs = list()
confirmatory_dfs = list()
holdout_dfs = list()

## important: these need to add up to 1.0
exploratory_prop  = 0.15
confirmatory_prop = 0.7
holdout_prop      = 0.15


# In[7]:


def slice_week(df):
    exploratory_count  = round(len(df) * exploratory_prop)
    confirmatory_count = round(len(df) * confirmatory_prop)
    holdout_count      = len(df) - exploratory_count - confirmatory_count

    exploratory_df = df.sample(n=exploratory_count)

    df = df.drop(exploratory_df.index)
    confirmatory_df = df.sample(n=confirmatory_count)

    df = df.drop(confirmatory_df.index)
    holdout_df = df
    
    assert len(holdout_df) == holdout_count
    
    ## append to the lists of dfs
    exploratory_dfs.append(exploratory_df)
    confirmatory_dfs.append(confirmatory_df)
    holdout_dfs.append(holdout_df)


# ### Create Week Groups

# In[8]:


test_weeks = test_df.groupby('week')


# In[9]:


for name, test_week in test_weeks:
    print("{0}: {1}".format(name, len(test_week)))
    slice_week(test_week)


# In[10]:


exploratory_df  = pd.concat(exploratory_dfs)
confirmatory_df = pd.concat(confirmatory_dfs)
holdout_df      = pd.concat(holdout_dfs)


# In[11]:


exploratory_count_df = pd.DataFrame(exploratory_df['week'].value_counts()).rename(columns={"week":"week_exploratory"})

confirmatory_count_df = pd.DataFrame(confirmatory_df['week'].value_counts()).rename(columns={"week":"week_confirmatory"})

holdout_count_df = pd.DataFrame(holdout_df['week'].value_counts()).rename(columns={"week":"week_holdout"})
                                
week_counts_df = holdout_count_df.join(exploratory_count_df.join(confirmatory_count_df))
week_counts_df['total'] = week_counts_df.sum(axis=1)


# In[12]:


week_counts_df['exploratory_prop'] = week_counts_df['week_exploratory'] / week_counts_df['total']
week_counts_df['confirmatory_prop'] = week_counts_df['week_confirmatory'] / week_counts_df['total']
week_counts_df['holdout_prop'] = week_counts_df['week_holdout'] / week_counts_df['total']
week_counts_df.head()


# In[13]:


week_counts_df.plot(y='exploratory_prop', x='total', kind="scatter")
plt.title("Exploratory Proportions")
plt.show()

week_counts_df.plot(y='confirmatory_prop', x='total', kind="scatter")
plt.title("Confirmatory Proportions")
plt.show()

week_counts_df.plot(y='holdout_prop', x='total', kind="scatter")
plt.title("Holdout Proportions")
plt.show()


# # Using Test IDs, Create Final Dataframes of Packages for Output

# In[14]:


packages_df = pd.DataFrame(valid_packages)


# In[15]:


packages_df.head()


# In[16]:


exploratory_packages_df = packages_df[packages_df['clickability_test_id'].apply(
    lambda x: x in exploratory_df.id)]

confirmatory_packages_df = packages_df[packages_df['clickability_test_id'].apply(
    lambda x: x in confirmatory_df.id)]

holdout_packages_df = packages_df[packages_df['clickability_test_id'].apply(
    lambda x: x in holdout_df.id)]


# #### Confirm The Selection of Packages
# * Confirm that all exploratory_df indexes are present in the exploratory_packages_df
# * Confirm that no indexes are present in exploratory_packages_df that aren't in exploratory_df

# In[17]:


def assert_index_overlap(tests_df, package_df, name):
    tests_df_indexes = set(tests_df.id)
    package_df_indexes = set(package_df['clickability_test_id'])
    set_intersection = tests_df_indexes.intersection(package_df_indexes)
    assert len(set_intersection) == len(tests_df_indexes) == len(package_df_indexes)
    print("{0} packages successfully excerpted".format(name))


# In[18]:


assert_index_overlap(exploratory_df, exploratory_packages_df, "exploratory")
assert_index_overlap(confirmatory_df, confirmatory_packages_df, "confirmatory")
assert_index_overlap(holdout_df, holdout_packages_df, "holdout")


# In[19]:


del exploratory_packages_df['_id']
del exploratory_packages_df['created']
del confirmatory_packages_df['_id']
del confirmatory_packages_df['created']
del holdout_packages_df['_id']
del holdout_packages_df['created']


# In[ ]:


exploratory_packages_df.to_csv("output/upworthy-archive-exploratory-packages-03.12.2020.csv")
confirmatory_packages_df.to_csv("output/upworthy-archive-confirmatory-packages-03.12.2020.csv")
holdout_packages_df.to_csv("output/upworthy-archive-holdout-packages-03.12.2020.csv")


# ### Process and Output Undeployed Packages to a File
# Rather than processing these files in the same way as the others, we are presenting them in their full original form.

# In[21]:


undeployed_packages_df = pd.DataFrame(undeployed_packages).to_csv("output/upworthy-archive-undeployed-packages-01-12-2021.csv", index=False)


# # LICENSE
# Copyright 2020 Cornell University
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
