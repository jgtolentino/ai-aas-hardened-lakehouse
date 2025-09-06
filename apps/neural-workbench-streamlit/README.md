# TBWA Neural Workbench v2.0 - Streamlit Edition

**10-minute magic: CSV → Dashboard → Share**

A simplified, user-friendly data analytics platform built with Streamlit, designed to get from data upload to shareable dashboard in under 10 minutes.

## 🌟 Features

### 📊 3-Page Workflow
1. **🔍 Explore**: Upload CSV files and get instant data profiling
2. **🏗️ Build**: Create interactive dashboards with drag-and-drop simplicity  
3. **🚀 Share**: Collaborate and distribute insights with one click

### ⚡ 10-Minute Magic
- **Upload & Profile** (2 minutes): Automatic data quality assessment
- **Build Dashboard** (5 minutes): Visual chart creation with AI suggestions
- **Share & Collaborate** (3 minutes): Export, publish, and invite teammates

### 🎯 Key Capabilities
- **Auto Data Profiling**: Instant insights on data quality, types, and distributions
- **Smart Chart Recommendations**: AI-suggested visualizations based on your data
- **Interactive Dashboards**: Plotly-powered charts with real-time interactivity
- **One-Click Sharing**: Export to PNG, CSV, PDF or publish to web
- **Collaboration Ready**: Built-in team sharing and permission management

## 🚀 Quick Start

### Prerequisites
- Python 3.8+
- pip or conda package manager

### Installation

1. **Clone and navigate**:
   ```bash
   cd /Users/tbwa/ai-aas-hardened-lakehouse/apps/neural-workbench-streamlit
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure environment** (optional):
   ```bash
   cp .env.example .env
   # Edit .env with your Supabase credentials if using database features
   ```

4. **Launch the application**:
   ```bash
   streamlit run streamlit_app.py
   ```

5. **Access the app**:
   Open your browser to `http://localhost:8501`

## 📋 Usage Guide

### Step 1: Explore Data 🔍
1. Click "Choose a CSV file" to upload your data
2. Review the automatic data profile:
   - Column types and statistics
   - Missing value analysis  
   - Data quality indicators
3. Click "🏗️ Build Dashboard" when ready

### Step 2: Build Dashboard 🏗️
1. Select your chart type from the dropdown
2. Choose X-axis, Y-axis, and optional color columns
3. Preview your chart in real-time
4. Review AI-generated insights about your data
5. Click "🚀 Share Dashboard" to continue

### Step 3: Share & Collaborate 🚀
1. Review your completed dashboard
2. Export options:
   - Download chart as PNG
   - Export data as CSV
   - Generate PDF report
3. Publishing options:
   - Get public shareable URL
   - Create private secure links
4. Collaboration:
   - Invite team members by email
   - Set permission levels (View/Comment/Edit)

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Streamlit (Python web framework)
- **Visualizations**: Plotly (interactive charts)
- **Data Processing**: Pandas + NumPy
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **Deployment**: Streamlit Cloud / Docker

### Project Structure
```
neural-workbench-streamlit/
├── streamlit_app.py          # Main application entry point
├── requirements.txt          # Python dependencies  
├── .env.example             # Environment configuration template
├── .streamlit/
│   └── config.toml          # Streamlit app configuration
├── README.md               # This file
└── pages/                  # Future: Multi-page app structure
    ├── 01_explore.py      # Data exploration page
    ├── 02_build.py        # Dashboard builder page  
    └── 03_share.py        # Sharing and collaboration page
```

## 🔧 Configuration

### Environment Variables
Copy `.env.example` to `.env` and configure:

```bash
# Supabase Integration (Optional)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# App Settings
APP_TITLE="TBWA Neural Workbench v2.0"
MAX_UPLOAD_SIZE_MB=200
AUTH_ENABLED=false
```

### Streamlit Configuration
The `.streamlit/config.toml` file contains:
- UI theme settings (TBWA brand colors)
- Upload size limits
- Server configuration
- Performance optimizations

## 🎨 Customization

### Branding
The app uses TBWA brand colors and styling:
- Primary: `#1a1a1a` (Dark text)
- Background: `#ffffff` (White)
- Secondary: `#f8f9fa` (Light gray)
- Success: `#00C851` (Green gradient)

### Adding Chart Types
To add new visualization types:

1. Update the `chart_types` dictionary in `build_page()`
2. Add the chart creation logic in `create_chart()`
3. Update column selection logic if needed

### Database Integration
The app is designed to work with Supabase for:
- Project persistence
- User authentication
- Data storage
- Collaboration features

See the Neural Workbench migration file: `supabase/migrations/07_neural_workbench_v2.sql`

## 🚀 Deployment Options

### Streamlit Cloud
1. Push code to GitHub repository
2. Connect to Streamlit Cloud
3. Configure environment variables
4. Deploy with one click

### Docker
```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8501
CMD ["streamlit", "run", "streamlit_app.py"]
```

### Heroku/Railway/Render
All support Streamlit deployments with minimal configuration.

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make changes and test locally
4. Submit a pull request

### Code Style
- Follow PEP 8 Python style guidelines
- Use type hints where appropriate
- Add docstrings for functions and classes
- Keep functions focused and testable

## 📈 Roadmap

### Phase 1: Core MVP ✅
- [x] 3-page workflow (Explore/Build/Share)
- [x] CSV upload and profiling
- [x] Basic chart types (line, bar, scatter, histogram, box, heatmap)
- [x] Export functionality
- [x] TBWA branding and styling

### Phase 2: Enhanced Features 🔄
- [ ] Database persistence (Supabase integration)
- [ ] User authentication and multi-tenancy
- [ ] Advanced chart types and customization
- [ ] Real-time collaboration
- [ ] Dashboard templates
- [ ] Scheduled reports

### Phase 3: Enterprise Features ⏳
- [ ] API integrations (REST/GraphQL)
- [ ] Advanced analytics and ML insights
- [ ] Custom branding per organization
- [ ] Audit logs and governance
- [ ] Enterprise SSO integration

## 🐛 Troubleshooting

### Common Issues

**"Module not found" error**:
```bash
pip install -r requirements.txt
```

**Upload size limit exceeded**:
- Reduce file size or increase `MAX_UPLOAD_SIZE_MB` in config

**Chart rendering issues**:
- Ensure data columns match the selected chart requirements
- Check for missing values in key columns

**Deployment issues**:
- Verify all environment variables are set
- Check Streamlit Cloud logs for specific errors

### Performance Tips
- Use data sampling for large datasets (>100k rows)
- Enable Streamlit caching for expensive operations
- Optimize column selection for better chart performance

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Search existing GitHub issues
3. Create a new issue with detailed reproduction steps

---

**Built with ❤️ by TBWA for TBWA**

*10-minute magic: Because insights shouldn't take all day.*