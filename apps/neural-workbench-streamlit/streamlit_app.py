#!/usr/bin/env python3
"""
TBWA Neural Workbench v2.0 - Streamlit Application
10-minute magic: CSV → Dashboard → Share

Simplified 3-page structure:
- Explore: Data discovery and profiling
- Build: Dashboard creation and customization  
- Share: Collaboration and distribution
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import json
import os
from pathlib import Path

# Page configuration
st.set_page_config(
    page_title="TBWA Neural Workbench v2.0",
    page_icon="🧠",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for TBWA branding
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: 700;
        color: #1a1a1a;
        margin-bottom: 0.5rem;
    }
    .sub-header {
        font-size: 1.2rem;
        color: #666;
        margin-bottom: 2rem;
    }
    .metric-card {
        background: white;
        padding: 1rem;
        border-radius: 8px;
        border: 1px solid #e0e0e0;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .success-banner {
        background: linear-gradient(90deg, #00C851 0%, #007E33 100%);
        color: white;
        padding: 1rem;
        border-radius: 8px;
        margin-bottom: 1rem;
    }
    .sidebar-section {
        background: #f8f9fa;
        padding: 1rem;
        border-radius: 8px;
        margin-bottom: 1rem;
    }
</style>
""", unsafe_allow_html=True)

def init_session_state():
    """Initialize session state variables"""
    if 'current_page' not in st.session_state:
        st.session_state.current_page = 'explore'
    if 'uploaded_data' not in st.session_state:
        st.session_state.uploaded_data = None
    if 'data_profile' not in st.session_state:
        st.session_state.data_profile = None
    if 'dashboard_config' not in st.session_state:
        st.session_state.dashboard_config = {}
    if 'project_name' not in st.session_state:
        st.session_state.project_name = f"Project_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

def sidebar_navigation():
    """Render sidebar navigation"""
    st.sidebar.markdown("### 🧠 Neural Workbench v2.0")
    st.sidebar.markdown("*10-minute magic workflow*")
    
    # Navigation
    pages = {
        'explore': '🔍 Explore Data',
        'build': '🏗️ Build Dashboard', 
        'share': '🚀 Share & Collaborate'
    }
    
    for page_key, page_name in pages.items():
        if st.sidebar.button(
            page_name, 
            key=f"nav_{page_key}",
            use_container_width=True,
            type="primary" if st.session_state.current_page == page_key else "secondary"
        ):
            st.session_state.current_page = page_key
            st.rerun()
    
    st.sidebar.markdown("---")
    
    # Project info
    with st.sidebar.container():
        st.markdown("### 📊 Current Project")
        st.text_input("Project Name", value=st.session_state.project_name, key="project_name_input")
        if st.session_state.project_name_input != st.session_state.project_name:
            st.session_state.project_name = st.session_state.project_name_input
    
    # Data status
    if st.session_state.uploaded_data is not None:
        st.sidebar.success(f"✅ Data loaded: {st.session_state.uploaded_data.shape[0]:,} rows")
    else:
        st.sidebar.info("📁 No data loaded")

def explore_page():
    """Data exploration and profiling page"""
    st.markdown('<h1 class="main-header">🔍 Explore Your Data</h1>', unsafe_allow_html=True)
    st.markdown('<p class="sub-header">Upload and discover insights in your data</p>', unsafe_allow_html=True)
    
    # File upload
    uploaded_file = st.file_uploader(
        "Choose a CSV file",
        type=['csv'],
        help="Upload your data file to begin analysis"
    )
    
    if uploaded_file is not None:
        try:
            # Load data
            df = pd.read_csv(uploaded_file)
            st.session_state.uploaded_data = df
            
            # Generate data profile
            profile = generate_data_profile(df)
            st.session_state.data_profile = profile
            
            # Success banner
            st.markdown(f"""
            <div class="success-banner">
                <strong>🎉 Data loaded successfully!</strong><br>
                {df.shape[0]:,} rows × {df.shape[1]} columns
            </div>
            """, unsafe_allow_html=True)
            
            # Data overview
            col1, col2 = st.columns([2, 1])
            
            with col1:
                st.subheader("📋 Data Preview")
                st.dataframe(df.head(100), use_container_width=True)
            
            with col2:
                st.subheader("📊 Quick Stats")
                
                # Metrics
                st.metric("Total Rows", f"{df.shape[0]:,}")
                st.metric("Columns", df.shape[1])
                st.metric("Memory Usage", f"{df.memory_usage(deep=True).sum() / 1024**2:.1f} MB")
                
                # Column types
                st.markdown("**Column Types**")
                type_counts = df.dtypes.value_counts()
                for dtype, count in type_counts.items():
                    st.write(f"• {dtype}: {count} columns")
            
            # Data profiling results
            if profile:
                st.subheader("🔍 Data Profile")
                
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    st.markdown("**Numeric Columns**")
                    numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
                    if numeric_cols:
                        for col in numeric_cols[:5]:  # Show first 5
                            st.write(f"• {col}")
                            st.write(f"  Range: {df[col].min():.2f} - {df[col].max():.2f}")
                    else:
                        st.write("No numeric columns found")
                
                with col2:
                    st.markdown("**Categorical Columns**")
                    cat_cols = df.select_dtypes(include=['object']).columns.tolist()
                    if cat_cols:
                        for col in cat_cols[:5]:  # Show first 5
                            unique_vals = df[col].nunique()
                            st.write(f"• {col}")
                            st.write(f"  {unique_vals} unique values")
                    else:
                        st.write("No categorical columns found")
                
                with col3:
                    st.markdown("**Data Quality**")
                    missing_data = df.isnull().sum()
                    missing_cols = missing_data[missing_data > 0]
                    if not missing_cols.empty:
                        st.write("Missing values:")
                        for col, count in missing_cols.head(5).items():
                            pct = (count / len(df)) * 100
                            st.write(f"• {col}: {count} ({pct:.1f}%)")
                    else:
                        st.success("✅ No missing values")
            
            # Next step
            st.markdown("---")
            col1, col2, col3 = st.columns([1, 1, 1])
            with col2:
                if st.button("🏗️ Build Dashboard", use_container_width=True, type="primary"):
                    st.session_state.current_page = 'build'
                    st.rerun()
        
        except Exception as e:
            st.error(f"Error loading data: {str(e)}")
    
    elif st.session_state.uploaded_data is not None:
        # Show existing data
        df = st.session_state.uploaded_data
        st.success(f"Using previously loaded data: {df.shape[0]:,} rows × {df.shape[1]} columns")
        
        # Show data preview
        st.subheader("📋 Data Preview")
        st.dataframe(df.head(100), use_container_width=True)
        
        # Next step button
        st.markdown("---")
        col1, col2, col3 = st.columns([1, 1, 1])
        with col2:
            if st.button("🏗️ Build Dashboard", use_container_width=True, type="primary"):
                st.session_state.current_page = 'build'
                st.rerun()

def generate_data_profile(df):
    """Generate comprehensive data profile"""
    profile = {
        'shape': df.shape,
        'dtypes': df.dtypes.to_dict(),
        'missing': df.isnull().sum().to_dict(),
        'numeric_summary': {},
        'categorical_summary': {}
    }
    
    # Numeric columns summary
    numeric_cols = df.select_dtypes(include=['number']).columns
    for col in numeric_cols:
        profile['numeric_summary'][col] = {
            'min': float(df[col].min()),
            'max': float(df[col].max()),
            'mean': float(df[col].mean()),
            'median': float(df[col].median()),
            'std': float(df[col].std())
        }
    
    # Categorical columns summary
    categorical_cols = df.select_dtypes(include=['object']).columns
    for col in categorical_cols:
        profile['categorical_summary'][col] = {
            'unique_count': int(df[col].nunique()),
            'top_values': df[col].value_counts().head(10).to_dict()
        }
    
    return profile

def build_page():
    """Dashboard building page"""
    st.markdown('<h1 class="main-header">🏗️ Build Your Dashboard</h1>', unsafe_allow_html=True)
    st.markdown('<p class="sub-header">Create interactive visualizations in seconds</p>', unsafe_allow_html=True)
    
    if st.session_state.uploaded_data is None:
        st.warning("⚠️ Please upload data in the Explore page first")
        if st.button("🔍 Go to Explore"):
            st.session_state.current_page = 'explore'
            st.rerun()
        return
    
    df = st.session_state.uploaded_data
    
    # Dashboard configuration
    st.subheader("🎛️ Dashboard Configuration")
    
    col1, col2 = st.columns([1, 2])
    
    with col1:
        st.markdown("**Chart Settings**")
        
        # Chart type selection
        chart_types = {
            'line': '📈 Line Chart',
            'bar': '📊 Bar Chart', 
            'scatter': '🎯 Scatter Plot',
            'histogram': '📊 Histogram',
            'box': '📦 Box Plot',
            'heatmap': '🌡️ Heatmap'
        }
        
        selected_chart = st.selectbox("Chart Type", options=list(chart_types.keys()), 
                                    format_func=lambda x: chart_types[x])
        
        # Column selection based on chart type
        numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
        categorical_cols = df.select_dtypes(include=['object']).columns.tolist()
        all_cols = df.columns.tolist()
        
        if selected_chart in ['line', 'bar', 'scatter']:
            x_column = st.selectbox("X-axis", options=all_cols)
            y_column = st.selectbox("Y-axis", options=numeric_cols)
            color_column = st.selectbox("Color by (optional)", options=[None] + categorical_cols)
        
        elif selected_chart == 'histogram':
            x_column = st.selectbox("Column", options=numeric_cols)
            y_column = None
            color_column = st.selectbox("Color by (optional)", options=[None] + categorical_cols)
        
        elif selected_chart == 'box':
            x_column = st.selectbox("Category", options=categorical_cols)
            y_column = st.selectbox("Values", options=numeric_cols)
            color_column = None
        
        elif selected_chart == 'heatmap':
            x_column = st.selectbox("X-axis", options=all_cols)
            y_column = st.selectbox("Y-axis", options=all_cols)
            color_column = st.selectbox("Values", options=numeric_cols)
    
    with col2:
        st.markdown("**Chart Preview**")
        
        try:
            # Create chart based on selection
            fig = create_chart(df, selected_chart, x_column, y_column, color_column)
            st.plotly_chart(fig, use_container_width=True)
            
            # Save configuration
            st.session_state.dashboard_config = {
                'chart_type': selected_chart,
                'x_column': x_column,
                'y_column': y_column,
                'color_column': color_column
            }
        
        except Exception as e:
            st.error(f"Error creating chart: {str(e)}")
    
    # Dashboard insights
    st.subheader("💡 Auto-Generated Insights")
    
    if st.session_state.dashboard_config:
        insights = generate_insights(df, st.session_state.dashboard_config)
        for insight in insights:
            st.info(f"💡 {insight}")
    
    # Next step
    st.markdown("---")
    col1, col2, col3 = st.columns([1, 1, 1])
    with col2:
        if st.button("🚀 Share Dashboard", use_container_width=True, type="primary"):
            st.session_state.current_page = 'share'
            st.rerun()

def create_chart(df, chart_type, x_col, y_col, color_col):
    """Create Plotly chart based on configuration"""
    
    if chart_type == 'line':
        fig = px.line(df, x=x_col, y=y_col, color=color_col, 
                     title=f"{y_col} over {x_col}")
    
    elif chart_type == 'bar':
        if color_col:
            fig = px.bar(df, x=x_col, y=y_col, color=color_col,
                        title=f"{y_col} by {x_col}")
        else:
            # Aggregate for bar chart
            agg_df = df.groupby(x_col)[y_col].sum().reset_index()
            fig = px.bar(agg_df, x=x_col, y=y_col,
                        title=f"Total {y_col} by {x_col}")
    
    elif chart_type == 'scatter':
        fig = px.scatter(df, x=x_col, y=y_col, color=color_col,
                        title=f"{y_col} vs {x_col}")
    
    elif chart_type == 'histogram':
        fig = px.histogram(df, x=x_col, color=color_col,
                          title=f"Distribution of {x_col}")
    
    elif chart_type == 'box':
        fig = px.box(df, x=x_col, y=y_col,
                    title=f"{y_col} distribution by {x_col}")
    
    elif chart_type == 'heatmap':
        # Create correlation heatmap for numeric columns
        if df[x_col].dtype in ['object'] and df[y_col].dtype in ['object']:
            # Cross-tabulation for categorical
            ct = pd.crosstab(df[x_col], df[y_col])
            fig = px.imshow(ct, title=f"Cross-tabulation: {x_col} vs {y_col}",
                           aspect="auto")
        else:
            # Correlation matrix
            numeric_cols = df.select_dtypes(include=['number']).columns
            corr_matrix = df[numeric_cols].corr()
            fig = px.imshow(corr_matrix, title="Correlation Heatmap",
                           aspect="auto", color_continuous_scale="RdBu")
    
    # Update layout
    fig.update_layout(
        template="plotly_white",
        font=dict(family="Arial, sans-serif", size=12),
        title_font_size=16,
        margin=dict(l=40, r=40, t=60, b=40)
    )
    
    return fig

def generate_insights(df, config):
    """Generate automatic insights based on data and chart configuration"""
    insights = []
    
    chart_type = config.get('chart_type')
    x_col = config.get('x_column')
    y_col = config.get('y_column')
    
    if chart_type and x_col:
        # Data size insight
        insights.append(f"Dataset contains {df.shape[0]:,} records with {df.shape[1]} variables")
        
        # Column-specific insights
        if y_col and df[y_col].dtype in ['int64', 'float64']:
            mean_val = df[y_col].mean()
            max_val = df[y_col].max()
            min_val = df[y_col].min()
            insights.append(f"{y_col} ranges from {min_val:.2f} to {max_val:.2f} (avg: {mean_val:.2f})")
        
        # Chart-specific insights
        if chart_type == 'bar' and df[x_col].dtype == 'object':
            top_category = df[x_col].value_counts().index[0]
            insights.append(f"'{top_category}' is the most common value in {x_col}")
        
        elif chart_type == 'line':
            insights.append(f"Time series analysis showing {y_col} trends over {x_col}")
    
    return insights

def share_page():
    """Sharing and collaboration page"""
    st.markdown('<h1 class="main-header">🚀 Share & Collaborate</h1>', unsafe_allow_html=True)
    st.markdown('<p class="sub-header">Distribute your insights and enable collaboration</p>', unsafe_allow_html=True)
    
    if st.session_state.uploaded_data is None:
        st.warning("⚠️ Please create a dashboard first")
        if st.button("🏗️ Go to Build"):
            st.session_state.current_page = 'build'
            st.rerun()
        return
    
    # Dashboard summary
    st.subheader("📊 Dashboard Summary")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        # Show the current chart
        if st.session_state.dashboard_config:
            df = st.session_state.uploaded_data
            config = st.session_state.dashboard_config
            
            try:
                fig = create_chart(df, config['chart_type'], config['x_column'], 
                                 config['y_column'], config['color_column'])
                st.plotly_chart(fig, use_container_width=True)
            except:
                st.info("Create a chart in the Build page to see preview here")
    
    with col2:
        st.markdown("**Project Details**")
        st.write(f"**Name:** {st.session_state.project_name}")
        st.write(f"**Created:** {datetime.now().strftime('%Y-%m-%d %H:%M')}")
        st.write(f"**Data:** {st.session_state.uploaded_data.shape[0]:,} rows")
        
        if st.session_state.dashboard_config:
            st.write(f"**Chart:** {st.session_state.dashboard_config['chart_type'].title()}")
    
    # Sharing options
    st.subheader("🔗 Sharing Options")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("### 📁 Export")
        if st.button("📊 Download Chart (PNG)", use_container_width=True):
            st.info("Chart download functionality would be implemented here")
        
        if st.button("📋 Export Data (CSV)", use_container_width=True):
            csv = st.session_state.uploaded_data.to_csv(index=False)
            st.download_button(
                label="Download CSV",
                data=csv,
                file_name=f"{st.session_state.project_name}_data.csv",
                mime="text/csv"
            )
        
        if st.button("📄 Generate Report (PDF)", use_container_width=True):
            st.info("PDF report generation would be implemented here")
    
    with col2:
        st.markdown("### 🌐 Publish")
        
        st.text_input("Public URL (mock)", value=f"https://neural.tbwa.com/{st.session_state.project_name.lower()}", disabled=True)
        
        if st.button("🚀 Publish Dashboard", use_container_width=True, type="primary"):
            st.success("✅ Dashboard published! (Mock)")
            st.balloons()
        
        if st.button("🔒 Share Privately", use_container_width=True):
            st.info("Private sharing would generate secure links")
    
    with col3:
        st.markdown("### 👥 Collaborate")
        
        st.text_input("Invite by email", placeholder="colleague@tbwa.com")
        
        permission_level = st.selectbox("Permission Level", 
                                      ["View Only", "Comment", "Edit"])
        
        if st.button("📧 Send Invitation", use_container_width=True):
            st.success("✅ Invitation sent! (Mock)")
    
    # Success workflow completion
    st.markdown("---")
    st.markdown("""
    <div class="success-banner">
        <h3>🎉 Congratulations!</h3>
        <p>You've completed the 10-minute magic workflow:</p>
        <p>✅ <strong>Explore:</strong> Uploaded and profiled your data<br>
        ✅ <strong>Build:</strong> Created an interactive dashboard<br>
        ✅ <strong>Share:</strong> Set up collaboration and distribution</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Start new project
    col1, col2, col3 = st.columns([1, 1, 1])
    with col2:
        if st.button("🆕 Start New Project", use_container_width=True):
            # Reset session state
            for key in ['uploaded_data', 'data_profile', 'dashboard_config']:
                if key in st.session_state:
                    del st.session_state[key]
            st.session_state.project_name = f"Project_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            st.session_state.current_page = 'explore'
            st.rerun()

def main():
    """Main application entry point"""
    # Initialize session state
    init_session_state()
    
    # Sidebar navigation
    sidebar_navigation()
    
    # Route to current page
    if st.session_state.current_page == 'explore':
        explore_page()
    elif st.session_state.current_page == 'build':
        build_page()
    elif st.session_state.current_page == 'share':
        share_page()

if __name__ == "__main__":
    main()