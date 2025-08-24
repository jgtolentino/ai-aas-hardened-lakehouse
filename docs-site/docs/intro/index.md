---
title: Scout Analytics Platform
sidebar_label: Overview
sidebar_position: 1
---

# Scout Analytics Platform v5.2

**Real-time Retail Intelligence for the Philippines**

## 🎯 What is Scout?

Scout is an enterprise-grade analytics platform that transforms retail data from thousands of sari-sari stores into actionable insights for FMCG brands, distributors, and retailers across the Philippines.

## 🚀 Key Features

### 📊 Five Core Dashboards

1. **Executive Dashboard** - C-suite KPIs and strategic metrics
2. **Analytics Dashboard** - Deep-dive analysis and exploration
3. **Regional Dashboard** - Geographic performance tracking
4. **Product Dashboard** - SKU-level insights and trends
5. **Agent Dashboard** - AI-powered recommendations and alerts

### 🏗️ Medallion Architecture

Scout implements a robust data pipeline following the Medallion Architecture:

- **Bronze Layer** - Raw data ingestion from edge devices, APIs, and uploads
- **Silver Layer** - Cleansed and validated transactional data
- **Gold Layer** - Business-ready aggregations and analytics views
- **Platinum Layer** - AI-enhanced insights and predictive analytics

### 🤖 AI-Powered Agents

Scout leverages specialized AI agents for intelligent automation:

- **Suqi** - Predictive analytics and forecasting
- **WrenAI** - Natural language to SQL translation
- **Savage** - Data summarization and insights
- **Jason** - OCR and receipt processing
- **Isko** - SKU scraping and catalog management
- **Fully** - SQL pipeline automation

## 📈 Platform Capabilities

### Data Processing
- Process **1M+ transactions daily** from 10,000+ stores
- Sub-second query performance on aggregated data
- Real-time streaming from IoT edge devices
- Batch uploads via CSV, Excel, and API

### Analytics Features
- Brand penetration and market share analysis
- Customer segmentation and behavior tracking
- Geographic heat maps and regional performance
- Product substitution and affinity analysis
- Revenue forecasting with confidence bands
- Anomaly detection and alerting

### Integration Points
- **Supabase** - PostgreSQL database with RLS
- **Vercel** - Edge Functions and API hosting
- **pgvector** - Semantic search and embeddings
- **MCP** - Agent orchestration framework
- **Recharts** - Interactive visualizations
- **Mapbox** - Geographic visualization

## 🎨 Target Users

### Primary Users
- **FMCG Brand Managers** - Track brand performance and market share
- **Regional Managers** - Monitor territory performance
- **Data Analysts** - Explore trends and patterns
- **Field Operations** - Track store-level metrics

### Use Cases
- Brand health monitoring
- Competitive intelligence
- Distribution optimization
- Pricing strategy
- Promotion effectiveness
- Inventory management

## 🔒 Security & Compliance

- **Row-Level Security (RLS)** - Data isolation by tenant
- **Role-Based Access Control (RBAC)** - Granular permissions
- **End-to-End Encryption** - Data protection in transit and at rest
- **Audit Logging** - Complete activity tracking
- **GDPR Compliant** - Privacy by design

## 📚 Documentation Structure

This documentation is organized into the following sections:

- **[System Architecture](/docs/system/architecture)** - Technical architecture and infrastructure
- **[Schema Reference](/docs/schema/overview)** - Database tables and views
- **[API Documentation](/docs/api/overview)** - REST endpoints and Edge Functions
- **[DAL Guide](/docs/dal/overview)** - Data Abstraction Layer usage
- **[AI Agents](/docs/ai-agents/overview)** - Agent capabilities and integration
- **[Playbooks](/docs/playbooks/overview)** - Step-by-step usage guides
- **[Integration](/docs/integration/overview)** - External system connections
- **[FAQ](/docs/faq/common-issues)** - Frequently asked questions

## 🚦 Getting Started

1. **[Quick Start Guide](/docs/playbooks/quickstart)** - Get up and running in 5 minutes
2. **[Authentication Setup](/docs/system/authentication)** - Configure access credentials
3. **[Your First Query](/docs/dal/first-query)** - Make your first DAL call
4. **[Dashboard Walkthrough](/docs/playbooks/dashboard-tour)** - Explore the UI

## 📞 Support

- **Documentation**: You are here! 
- **GitHub Issues**: [ai-aas-hardened-lakehouse](https://github.com/jgtolentino/ai-aas-hardened-lakehouse)
- **Email Support**: scout-support@insightpulse.ai
- **Slack Channel**: #scout-platform

---

*Scout v5.2 - Built with ❤️ by TBWA Data Collective*
