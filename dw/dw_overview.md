## 📊 Data Warehouse Overview

### Facts
| Table | Records | Status |
|-------|---------|--------|
| `fact_transactions` | - | ❌ Empty |
| `fact_transaction_items` | - | ❌ Empty |
| `fact_monthly_performance` | - | ❌ Empty |

### Dimensions
| Table | Records | Status |
|-------|---------|--------|
| `dim_date` | 4,018 | ✅ Active |
| `dim_time` | 1,440 | ✅ Active |
| `dim_store` | - | ❌ Empty |
| `dim_product` | - | ❌ Empty |
| `dim_customer` | - | ❌ Empty |
| `dim_payment_method` | - | ❌ Empty |

### Bridges
| Table | Records | Status |
|-------|---------|--------|
| `bridge_product_bundle` | - | ❌ Empty |

_Generated: 2025-08-18 20:58:20_
