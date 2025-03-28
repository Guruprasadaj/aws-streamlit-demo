import streamlit as st
import pandas as pd
import numpy as np

def main():
    st.title("AWS Infrastructure Demo App")
    
    # Add some sample content
    st.write("Welcome to our demo application!")
    
    # Create a sample chart
    chart_data = pd.DataFrame(
        np.random.randn(20, 3),
        columns=['A', 'B', 'C']
    )
    
    st.line_chart(chart_data)
    
    # Add a simple interaction
    user_input = st.text_input("Enter your name:", "")
    if user_input:
        st.write(f"Hello, {user_input}!")

if __name__ == "__main__":
    main()
