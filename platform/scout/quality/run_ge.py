#!/usr/bin/env python3
"""
Great Expectations runner for Scout Analytics data quality checks
"""
import os
import sys
import great_expectations as ge
from great_expectations.checkpoint import SimpleCheckpoint
from great_expectations.core.batch import BatchRequest
from great_expectations.data_context.types.base import DataContextConfig, DatasourceConfig, CheckpointConfig

def run_data_quality_checks():
    """Run Great Expectations checkpoints for Scout Analytics"""
    
    # Get database connection from environment
    pguri = os.environ.get('PGURI')
    if not pguri:
        print("ERROR: PGURI environment variable not set")
        sys.exit(1)
    
    # Initialize Data Context
    context = ge.get_context()
    
    # Create datasource if it doesn't exist
    datasource_name = "scout_postgres"
    try:
        datasource = context.get_datasource(datasource_name)
    except:
        datasource_config = {
            "name": datasource_name,
            "class_name": "Datasource",
            "execution_engine": {
                "class_name": "SqlAlchemyExecutionEngine",
                "connection_string": pguri,
            },
            "data_connectors": {
                "default_inferred_data_connector_name": {
                    "class_name": "InferredAssetSqlDataConnector",
                    "include_schema_name": True,
                }
            },
        }
        context.add_datasource(**datasource_config)
    
    # Define validation checks
    validation_results = []
    
    # Check 1: Silver transactions table exists and has data
    try:
        batch_request = BatchRequest(
            datasource_name=datasource_name,
            data_connector_name="default_inferred_data_connector_name",
            data_asset_name="scout.silver_transactions",
        )
        
        validator = context.get_validator(
            batch_request=batch_request,
            expectation_suite_name="silver_transactions_suite",
            create_if_not_exist=True,
        )
        
        # Add expectations
        validator.expect_table_row_count_to_be_between(min_value=1000)
        validator.expect_column_values_to_not_be_null("transaction_id")
        validator.expect_column_values_to_not_be_null("store_id")
        validator.expect_column_values_to_be_between("peso_value", min_value=0)
        validator.expect_column_values_to_be_between("quantity", min_value=1)
        
        # Run validation
        checkpoint = SimpleCheckpoint(
            name="silver_transactions_checkpoint",
            data_context=context,
            validator=validator,
        )
        
        result = checkpoint.run()
        validation_results.append(("silver_transactions", result.success))
        
    except Exception as e:
        print(f"ERROR validating silver_transactions: {e}")
        validation_results.append(("silver_transactions", False))
    
    # Check 2: Gold daily aggregates exist
    try:
        batch_request = BatchRequest(
            datasource_name=datasource_name,
            data_connector_name="default_inferred_data_connector_name",
            data_asset_name="scout.gold_txn_daily",
        )
        
        validator = context.get_validator(
            batch_request=batch_request,
            expectation_suite_name="gold_daily_suite",
            create_if_not_exist=True,
        )
        
        # Add expectations
        validator.expect_table_row_count_to_be_between(min_value=100)
        validator.expect_column_values_to_not_be_null("date_key")
        validator.expect_column_values_to_not_be_null("region")
        validator.expect_column_values_to_be_between("total_peso_value", min_value=0)
        
        # Run validation
        checkpoint = SimpleCheckpoint(
            name="gold_daily_checkpoint",
            data_context=context,
            validator=validator,
        )
        
        result = checkpoint.run()
        validation_results.append(("gold_txn_daily", result.success))
        
    except Exception as e:
        print(f"ERROR validating gold_txn_daily: {e}")
        validation_results.append(("gold_txn_daily", False))
    
    # Summary
    print("\n=== Data Quality Check Results ===")
    all_passed = True
    for check_name, passed in validation_results:
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{check_name}: {status}")
        if not passed:
            all_passed = False
    
    if not all_passed:
        print("\n❌ Some data quality checks failed!")
        sys.exit(1)
    else:
        print("\n✅ All data quality checks passed!")
        sys.exit(0)

if __name__ == "__main__":
    run_data_quality_checks()