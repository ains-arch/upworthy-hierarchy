import os
import numpy as np
import pandas as pd

def load_and_prepare_data(filepath):
    """
    Load and prepare data for hierarchical model.
    
    Args:
        filepath (str): Path to the CSV file
    
    Returns:
        pd.DataFrame: Prepared dataset
    """
    # Read the data
    data = pd.read_csv(filepath, low_memory=False)
    
    # Comprehensive filtering
    data = data[
        # Remove rows with zero or NA impressions or clicks
        (data['impressions'] > 0) & 
        (data['clicks'] >= 0) & 
        (~data['impressions'].isna()) & 
        (~data['clicks'].isna()) &
        (~data['clickability_test_id'].isna())
    ]
    
    return data

def create_story_headline_matrices(data):
    """
    Create matrices structured for R hierarchical model.
    
    Args:
        data (pd.DataFrame): Prepared dataset
    
    Returns:
        tuple: y matrix, n matrix, story levels
    """
    # Group by story and get unique stories
    grouped = data.groupby('clickability_test_id')
    
    # Get unique stories and max number of headlines per story
    story_levels = list(grouped.groups.keys())
    I = len(story_levels)
    J = grouped.size().max()
    
    # Initialize matrices with zeros (instead of NaN)
    y = np.zeros((I, J))
    n = np.zeros((I, J))
    
    # Create mapping of story to index
    story_to_index = {story: idx for idx, story in enumerate(story_levels)}
    
    # Fill matrices
    for story, group in grouped:
        i = story_to_index[story]
        
        # Sort headlines to ensure consistent ordering
        # Use total clicks as sorting criterion
        sorted_group = group.sort_values('clicks', ascending=False)
        
        # Fill matrices for this story
        for j, (_, row) in enumerate(sorted_group.iterrows()):
            if j < J:
                # Ensure non-negative values
                y[i, j] = max(0, row['clicks'])
                n[i, j] = max(0, row['impressions'])
    
    return y, n, story_levels

def main():
    # Set working directory 
    os.chdir(os.path.expanduser("~/Documents/School/stats/final"))
    
    # File path
    filepath = "upworthy-archive-datasets/upworthy-archive-exploratory-packages-03.12.2020.csv"
    
    # Load and prepare data
    data = load_and_prepare_data(filepath)
    
    # Create matrices
    y, n, story_levels = create_story_headline_matrices(data)
    
    # Diagnostics
    print(f"y matrix shape: {y.shape}")
    print(f"n matrix shape: {n.shape}")
    print("\nFirst few y values:\n", y[:5, :5])
    print("\nFirst few n values:\n", n[:5, :5])
    
    # Save to CSV for R
    y_df = pd.DataFrame(y, index=story_levels)
    n_df = pd.DataFrame(n, index=story_levels)
    
    y_df.to_csv('y_matrix.csv')
    n_df.to_csv('n_matrix.csv')
    
    # Additional diagnostics
    print("\nNumber of stories:", y.shape[0])
    print("Max headlines per story:", y.shape[1])
    print("Non-zero entries in y:", np.count_nonzero(y))
    
    # Verify no NaNs or negative values
    print("\nMin y value:", y.min())
    print("Min n value:", n.min())
    print("Any NaNs in y:", np.isnan(y).any())
    print("Any NaNs in n:", np.isnan(n).any())

if __name__ == "__main__":
    main()
