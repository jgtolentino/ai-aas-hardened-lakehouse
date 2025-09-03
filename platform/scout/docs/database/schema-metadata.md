# Scout Platform Schema Metadata

**Last Updated**: 2025-09-03 18:13:41  
**Generated**: Automatically by schema sync system

## Schema Overview

This document provides metadata about the Scout Platform database schema, including table statistics, column definitions, and relationship mappings.

### Medallion Architecture Layers

| Layer | Schema | Purpose | Access Level |
|-------|--------|---------|--------------|
| 🥉 Bronze | `scout_bronze` | Raw data ingestion | Internal |
| 🥈 Silver | `scout_silver` | Cleaned transactional data | Internal |
| 🥇 Gold | `scout_gold` | Business analytics (PUBLIC) | RLS Protected |
| 💎 Platinum | `scout_platinum` | ML/AI predictions (PUBLIC) | RLS Protected |
| 🏛️ Governance | `scout` | Metadata & audit | Internal |

### Schema Statistics

*Note: Connect to database to generate live statistics*

```sql
-- Query to generate schema statistics
SELECT 
    schemaname,
    COUNT(*) as table_count,
    SUM(n_tup_ins) as total_inserts,
    SUM(n_tup_upd) as total_updates,
    SUM(n_tup_del) as total_deletes
FROM pg_stat_user_tables 
WHERE schemaname IN ('scout', 'scout_bronze', 'scout_silver', 'scout_gold', 'scout_platinum')
GROUP BY schemaname
ORDER BY schemaname;
```

### Core Business Entities

#### Transactional Data Flow
```
Raw Data (Bronze) → Cleaned Data (Silver) → Analytics (Gold) → ML Predictions (Platinum)
```

#### Key Relationships
- **Transactions** 1:N **Transaction Items**
- **Stores** 1:N **Transactions**  
- **Customers** 1:N **Transactions**
- **Products** 1:N **Transaction Items**

### Data Governance

#### Row Level Security (RLS)
- **Enabled**: All Gold and Platinum schema tables
- **Policy Type**: Organization-based data isolation
- **Enforcement**: Automatic via Supabase auth context

#### Audit Trail
- **Scope**: All data modifications tracked
- **Storage**: `scout.audit_log` table
- **Retention**: Configurable via governance policies

### Philippine Market Specifics

#### Geographic Data
- **PSGC Integration**: Complete Philippine Standard Geographic Code support
- **Regional Breakdown**: NCR, Luzon, Visayas, Mindanao
- **City/Municipality**: Full hierarchy with barangay-level detail

#### Payment Methods
- **Traditional**: Cash, Credit/Debit Cards
- **Digital**: GCash, PayMaya, GrabPay
- **Alternative**: Installments, Corporate Accounts

#### Localization
- **Languages**: English (primary), Filipino, Cebuano, Ilocano, Waray
- **Currency**: Philippine Peso (PHP) with centavo precision
- **Date Format**: International standard with timezone awareness

---

*This metadata is automatically generated. For the most current information, query the database directly or regenerate this document.*
