#!/usr/bin/env python3
"""
MLOps Data Drift Detection System
Monitors input data distributions and detects drift in ML model inputs
"""

import os
import sys
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
import psycopg2
import pandas as pd
import numpy as np
from scipy import stats
from scipy.spatial.distance import jensenshannon
from sklearn.metrics import jensen_shannon_divergence
import matplotlib.pyplot as plt
import seaborn as sns

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class DriftResult:
    feature_name: str
    detection_type: str
    drift_score: float
    p_value: Optional[float]
    threshold: float
    drift_detected: bool
    reference_stats: Dict[str, Any]
    current_stats: Dict[str, Any]
    recommendations: List[str]

class DataDriftDetector:
    def __init__(self):
        """Initialize the drift detection system"""
        self.db_url = os.getenv('DATABASE_URL') or self._build_db_url()
        self.drift_threshold = float(os.getenv('DRIFT_THRESHOLD', '0.05'))
        self.min_sample_size = int(os.getenv('MIN_SAMPLE_SIZE', '100'))
        
        logger.info(f"Data Drift Detector initialized (threshold: {self.drift_threshold})")

    def _build_db_url(self) -> str:
        """Build database URL from environment variables"""
        host = os.getenv('SUPABASE_DB_HOST', 'db.cxzllzyxwpyptfretryc.supabase.co')
        port = os.getenv('SUPABASE_DB_PORT', '5432')
        db = os.getenv('SUPABASE_DB_NAME', 'postgres')
        user = os.getenv('SUPABASE_DB_USER', 'postgres')
        password = os.getenv('SUPABASE_DB_PASSWORD')
        
        if not password:
            raise ValueError("SUPABASE_DB_PASSWORD environment variable is required")
            
        return f"postgresql://{user}:{password}@{host}:{port}/{db}"

    def get_db_connection(self):
        """Get database connection"""
        try:
            return psycopg2.connect(self.db_url)
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise

    def detect_query_length_drift(self) -> DriftResult:
        """Detect drift in query length distribution"""
        logger.info("Detecting query length drift...")
        
        with self.get_db_connection() as conn:
            # Get reference data (1-2 weeks ago)
            reference_query = """
            SELECT query_length
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
            AND query_length IS NOT NULL
            AND success = true
            ORDER BY created_at
            """
            reference_df = pd.read_sql(reference_query, conn)
            
            # Get current data (last 7 days)
            current_query = """
            SELECT query_length
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at >= NOW() - INTERVAL '7 days'
            AND query_length IS NOT NULL
            AND success = true
            ORDER BY created_at
            """
            current_df = pd.read_sql(current_query, conn)

        if len(reference_df) < self.min_sample_size or len(current_df) < self.min_sample_size:
            logger.warning(f"Insufficient data for drift detection (ref: {len(reference_df)}, curr: {len(current_df)})")
            return DriftResult(
                feature_name='query_length',
                detection_type='statistical',
                drift_score=0.0,
                p_value=None,
                threshold=self.drift_threshold,
                drift_detected=False,
                reference_stats={},
                current_stats={},
                recommendations=['Collect more data for drift detection']
            )

        # Perform Kolmogorov-Smirnov test
        ks_statistic, p_value = stats.ks_2samp(reference_df['query_length'], current_df['query_length'])
        
        # Calculate descriptive statistics
        reference_stats = {
            'mean': float(reference_df['query_length'].mean()),
            'std': float(reference_df['query_length'].std()),
            'median': float(reference_df['query_length'].median()),
            'min': float(reference_df['query_length'].min()),
            'max': float(reference_df['query_length'].max()),
            'sample_size': len(reference_df)
        }
        
        current_stats = {
            'mean': float(current_df['query_length'].mean()),
            'std': float(current_df['query_length'].std()),
            'median': float(current_df['query_length'].median()),
            'min': float(current_df['query_length'].min()),
            'max': float(current_df['query_length'].max()),
            'sample_size': len(current_df)
        }
        
        # Determine if drift is detected
        drift_detected = p_value < self.drift_threshold
        
        # Generate recommendations
        recommendations = []
        if drift_detected:
            mean_change = (current_stats['mean'] - reference_stats['mean']) / reference_stats['mean'] * 100
            if abs(mean_change) > 20:
                recommendations.append(f"Query length changed by {mean_change:.1f}% - investigate user behavior changes")
            if current_stats['std'] > reference_stats['std'] * 1.5:
                recommendations.append("Query length variance increased significantly - check for bot traffic")
            recommendations.append("Review recent queries for unusual patterns")
            recommendations.append("Consider adjusting input validation or rate limiting")
        else:
            recommendations.append("No significant drift detected - continue monitoring")
        
        return DriftResult(
            feature_name='query_length',
            detection_type='statistical',
            drift_score=ks_statistic,
            p_value=p_value,
            threshold=self.drift_threshold,
            drift_detected=drift_detected,
            reference_stats=reference_stats,
            current_stats=current_stats,
            recommendations=recommendations
        )

    def detect_latency_drift(self) -> DriftResult:
        """Detect drift in response latency distribution"""
        logger.info("Detecting latency drift...")
        
        with self.get_db_connection() as conn:
            # Get reference latency data
            reference_query = """
            SELECT latency_ms
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
            AND latency_ms IS NOT NULL
            AND success = true
            ORDER BY created_at
            """
            reference_df = pd.read_sql(reference_query, conn)
            
            # Get current latency data
            current_query = """
            SELECT latency_ms
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at >= NOW() - INTERVAL '7 days'
            AND latency_ms IS NOT NULL
            AND success = true
            ORDER BY created_at
            """
            current_df = pd.read_sql(current_query, conn)

        if len(reference_df) < self.min_sample_size or len(current_df) < self.min_sample_size:
            return DriftResult(
                feature_name='latency_ms',
                detection_type='statistical',
                drift_score=0.0,
                p_value=None,
                threshold=self.drift_threshold,
                drift_detected=False,
                reference_stats={},
                current_stats={},
                recommendations=['Insufficient data for latency drift detection']
            )

        # Use Mann-Whitney U test for non-parametric comparison
        statistic, p_value = stats.mannwhitneyu(
            reference_df['latency_ms'], 
            current_df['latency_ms'], 
            alternative='two-sided'
        )
        
        # Convert to a normalized drift score (0-1)
        n1, n2 = len(reference_df), len(current_df)
        u_normalized = statistic / (n1 * n2)  # Normalize to 0-1
        drift_score = abs(0.5 - u_normalized) * 2  # Distance from 0.5, scaled to 0-1
        
        # Calculate percentile-based statistics (more robust for latency)
        reference_stats = {
            'p50': float(reference_df['latency_ms'].quantile(0.5)),
            'p95': float(reference_df['latency_ms'].quantile(0.95)),
            'p99': float(reference_df['latency_ms'].quantile(0.99)),
            'mean': float(reference_df['latency_ms'].mean()),
            'sample_size': len(reference_df)
        }
        
        current_stats = {
            'p50': float(current_df['latency_ms'].quantile(0.5)),
            'p95': float(current_df['latency_ms'].quantile(0.95)),
            'p99': float(current_df['latency_ms'].quantile(0.99)),
            'mean': float(current_df['latency_ms'].mean()),
            'sample_size': len(current_df)
        }
        
        drift_detected = p_value < self.drift_threshold
        
        # Generate recommendations
        recommendations = []
        if drift_detected:
            p95_change = (current_stats['p95'] - reference_stats['p95']) / reference_stats['p95'] * 100
            if p95_change > 50:
                recommendations.append(f"P95 latency increased by {p95_change:.1f}% - investigate performance degradation")
            if current_stats['p99'] > 10000:  # 10 seconds
                recommendations.append("P99 latency exceeds 10s - check for timeout issues")
            recommendations.append("Review recent system changes and resource utilization")
            recommendations.append("Consider scaling infrastructure or optimizing queries")
        else:
            recommendations.append("No significant latency drift detected")
        
        return DriftResult(
            feature_name='latency_ms',
            detection_type='statistical',
            drift_score=drift_score,
            p_value=p_value,
            threshold=self.drift_threshold,
            drift_detected=drift_detected,
            reference_stats=reference_stats,
            current_stats=current_stats,
            recommendations=recommendations
        )

    def detect_confidence_drift(self) -> DriftResult:
        """Detect drift in model confidence scores"""
        logger.info("Detecting confidence score drift...")
        
        with self.get_db_connection() as conn:
            # Get reference confidence data
            reference_query = """
            SELECT confidence_score
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
            AND confidence_score IS NOT NULL
            AND success = true
            ORDER BY created_at
            """
            reference_df = pd.read_sql(reference_query, conn)
            
            # Get current confidence data
            current_query = """
            SELECT confidence_score
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at >= NOW() - INTERVAL '7 days'
            AND confidence_score IS NOT NULL
            AND success = true
            ORDER BY created_at
            """
            current_df = pd.read_sql(current_query, conn)

        if len(reference_df) < self.min_sample_size or len(current_df) < self.min_sample_size:
            return DriftResult(
                feature_name='confidence_score',
                detection_type='statistical',
                drift_score=0.0,
                p_value=None,
                threshold=self.drift_threshold,
                drift_detected=False,
                reference_stats={},
                current_stats={},
                recommendations=['Insufficient data for confidence drift detection']
            )

        # Use Anderson-Darling test for goodness of fit
        try:
            ad_statistic, critical_values, significance_level = stats.anderson_ksamp([
                reference_df['confidence_score'].values,
                current_df['confidence_score'].values
            ])
            
            # Convert to p-value approximation
            p_value = 1.0 / (1.0 + ad_statistic)  # Rough approximation
            drift_score = ad_statistic / 10.0  # Normalize roughly
            
        except Exception:
            # Fallback to KS test
            ks_statistic, p_value = stats.ks_2samp(
                reference_df['confidence_score'], 
                current_df['confidence_score']
            )
            drift_score = ks_statistic
        
        # Calculate confidence-specific statistics
        reference_stats = {
            'mean': float(reference_df['confidence_score'].mean()),
            'std': float(reference_df['confidence_score'].std()),
            'low_confidence_pct': float((reference_df['confidence_score'] < 0.3).mean() * 100),
            'high_confidence_pct': float((reference_df['confidence_score'] > 0.8).mean() * 100),
            'sample_size': len(reference_df)
        }
        
        current_stats = {
            'mean': float(current_df['confidence_score'].mean()),
            'std': float(current_df['confidence_score'].std()),
            'low_confidence_pct': float((current_df['confidence_score'] < 0.3).mean() * 100),
            'high_confidence_pct': float((current_df['confidence_score'] > 0.8).mean() * 100),
            'sample_size': len(current_df)
        }
        
        drift_detected = p_value < self.drift_threshold
        
        # Generate recommendations
        recommendations = []
        if drift_detected:
            confidence_change = (current_stats['mean'] - reference_stats['mean']) * 100
            if confidence_change < -10:
                recommendations.append(f"Average confidence decreased by {abs(confidence_change):.1f}% - model may be degrading")
                recommendations.append("Review recent training data quality and model performance")
            if current_stats['low_confidence_pct'] > reference_stats['low_confidence_pct'] + 10:
                recommendations.append("Increase in low-confidence responses - investigate input quality")
            recommendations.append("Consider model retraining or prompt optimization")
        else:
            recommendations.append("Confidence scores remain stable")
        
        return DriftResult(
            feature_name='confidence_score',
            detection_type='statistical',
            drift_score=drift_score,
            p_value=p_value,
            threshold=self.drift_threshold,
            drift_detected=drift_detected,
            reference_stats=reference_stats,
            current_stats=current_stats,
            recommendations=recommendations
        )

    def detect_error_rate_drift(self) -> DriftResult:
        """Detect drift in error rates"""
        logger.info("Detecting error rate drift...")
        
        with self.get_db_connection() as conn:
            # Get daily error rates for reference period
            reference_query = """
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as total_requests,
                COUNT(*) FILTER (WHERE success = false) as errors,
                (COUNT(*) FILTER (WHERE success = false))::float / COUNT(*) as error_rate
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
            GROUP BY DATE(created_at)
            ORDER BY date
            """
            reference_df = pd.read_sql(reference_query, conn)
            
            # Get daily error rates for current period
            current_query = """
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as total_requests,
                COUNT(*) FILTER (WHERE success = false) as errors,
                (COUNT(*) FILTER (WHERE success = false))::float / COUNT(*) as error_rate
            FROM mlops.model_performance 
            WHERE function_name = 'ai-generate-insight'
            AND created_at >= NOW() - INTERVAL '7 days'
            GROUP BY DATE(created_at)
            ORDER BY date
            """
            current_df = pd.read_sql(current_query, conn)

        if len(reference_df) < 3 or len(current_df) < 3:
            return DriftResult(
                feature_name='error_rate',
                detection_type='statistical',
                drift_score=0.0,
                p_value=None,
                threshold=self.drift_threshold,
                drift_detected=False,
                reference_stats={},
                current_stats={},
                recommendations=['Insufficient data for error rate drift detection']
            )

        # Use Welch's t-test for comparing error rates
        t_statistic, p_value = stats.ttest_ind(
            reference_df['error_rate'].fillna(0), 
            current_df['error_rate'].fillna(0),
            equal_var=False
        )
        
        drift_score = abs(t_statistic) / 10.0  # Normalize roughly
        
        # Calculate error rate statistics
        reference_stats = {
            'mean_error_rate': float(reference_df['error_rate'].mean()),
            'max_error_rate': float(reference_df['error_rate'].max()),
            'total_errors': int(reference_df['errors'].sum()),
            'total_requests': int(reference_df['total_requests'].sum()),
            'sample_size': len(reference_df)
        }
        
        current_stats = {
            'mean_error_rate': float(current_df['error_rate'].mean()),
            'max_error_rate': float(current_df['error_rate'].max()),
            'total_errors': int(current_df['errors'].sum()),
            'total_requests': int(current_df['total_requests'].sum()),
            'sample_size': len(current_df)
        }
        
        drift_detected = p_value < self.drift_threshold and current_stats['mean_error_rate'] > reference_stats['mean_error_rate']
        
        # Generate recommendations
        recommendations = []
        if drift_detected:
            error_increase = (current_stats['mean_error_rate'] - reference_stats['mean_error_rate']) * 100
            recommendations.append(f"Error rate increased by {error_increase:.2f}% - investigate recent failures")
            if current_stats['max_error_rate'] > 0.1:  # 10% error rate on any day
                recommendations.append("High error rate detected - check system health and logs")
            recommendations.append("Review error messages and failure patterns")
            recommendations.append("Consider implementing circuit breakers or retry logic")
        else:
            recommendations.append("Error rates remain within normal bounds")
        
        return DriftResult(
            feature_name='error_rate',
            detection_type='statistical',
            drift_score=drift_score,
            p_value=p_value,
            threshold=self.drift_threshold,
            drift_detected=drift_detected,
            reference_stats=reference_stats,
            current_stats=current_stats,
            recommendations=recommendations
        )

    def log_drift_results(self, results: List[DriftResult]) -> None:
        """Log drift detection results to database"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                for result in results:
                    cursor.execute("""
                        INSERT INTO mlops.drift_detection (
                            feature_name, detection_type, drift_score, p_value, threshold,
                            reference_period_start, reference_period_end,
                            current_period_start, current_period_end,
                            drift_details
                        ) VALUES (
                            %s, %s, %s, %s, %s,
                            NOW() - INTERVAL '14 days', NOW() - INTERVAL '7 days',
                            NOW() - INTERVAL '7 days', NOW(),
                            %s
                        )
                    """, (
                        result.feature_name,
                        result.detection_type,
                        result.drift_score,
                        result.p_value,
                        result.threshold,
                        json.dumps({
                            'reference_stats': result.reference_stats,
                            'current_stats': result.current_stats,
                            'recommendations': result.recommendations,
                            'drift_detected': result.drift_detected
                        })
                    ))
                
                conn.commit()
                logger.info(f"Logged {len(results)} drift detection results")
                
        except Exception as e:
            logger.error(f"Failed to log drift results: {e}")

    def generate_drift_report(self, results: List[DriftResult]) -> str:
        """Generate comprehensive drift detection report"""
        report = []
        report.append("# MLOps Data Drift Detection Report")
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Summary
        drift_detected_count = sum(1 for r in results if r.drift_detected)
        report.append("## Summary")
        report.append(f"- **Features Analyzed**: {len(results)}")
        report.append(f"- **Drift Detected**: {drift_detected_count}")
        report.append(f"- **Detection Threshold**: {self.drift_threshold}")
        report.append("")
        
        # Detailed results
        report.append("## Drift Analysis Results")
        
        for result in results:
            status = "🚨 **DRIFT DETECTED**" if result.drift_detected else "✅ **NO DRIFT**"
            report.append(f"### {result.feature_name.title().replace('_', ' ')} - {status}")
            report.append("")
            
            # Statistics
            report.append("**Statistics:**")
            report.append(f"- Drift Score: {result.drift_score:.4f}")
            if result.p_value is not None:
                report.append(f"- P-Value: {result.p_value:.4f}")
            report.append(f"- Detection Type: {result.detection_type}")
            report.append("")
            
            # Comparison
            report.append("**Reference vs Current:**")
            if result.reference_stats and result.current_stats:
                for key in result.reference_stats.keys():
                    if key in result.current_stats:
                        ref_val = result.reference_stats[key]
                        curr_val = result.current_stats[key]
                        
                        # Format based on key type
                        if isinstance(ref_val, float):
                            if 'pct' in key or 'rate' in key:
                                report.append(f"- {key}: {ref_val:.2f}% → {curr_val:.2f}%")
                            else:
                                report.append(f"- {key}: {ref_val:.3f} → {curr_val:.3f}")
                        else:
                            report.append(f"- {key}: {ref_val} → {curr_val}")
            report.append("")
            
            # Recommendations
            if result.recommendations:
                report.append("**Recommendations:**")
                for rec in result.recommendations:
                    report.append(f"- {rec}")
                report.append("")
        
        # Overall recommendations
        if drift_detected_count > 0:
            report.append("## Overall Recommendations")
            report.append("- **Immediate Actions:**")
            report.append("  - Review recent system changes and deployments")
            report.append("  - Check data pipeline health and data quality")
            report.append("  - Monitor error logs for unusual patterns")
            report.append("")
            report.append("- **Medium-term Actions:**")
            report.append("  - Consider model retraining if performance drift is confirmed")
            report.append("  - Implement automated data validation checks")
            report.append("  - Set up real-time drift monitoring alerts")
            report.append("")
        
        return "\n".join(report)

    def run_drift_detection(self) -> List[DriftResult]:
        """Main drift detection workflow"""
        logger.info("Starting MLOps drift detection cycle...")
        
        results = []
        
        try:
            # Run all drift detection methods
            detection_methods = [
                self.detect_query_length_drift,
                self.detect_latency_drift,
                self.detect_confidence_drift,
                self.detect_error_rate_drift
            ]
            
            for method in detection_methods:
                try:
                    result = method()
                    results.append(result)
                    logger.info(f"Completed {result.feature_name} drift detection: {'DRIFT' if result.drift_detected else 'OK'}")
                except Exception as e:
                    logger.error(f"Drift detection failed for {method.__name__}: {e}")
            
            # Log results to database
            if results:
                self.log_drift_results(results)
            
            # Generate report
            report = self.generate_drift_report(results)
            report_path = f"/tmp/mlops-drift-report-{datetime.now().strftime('%Y%m%d-%H%M')}.md"
            with open(report_path, 'w') as f:
                f.write(report)
            
            logger.info(f"Drift detection completed. Report saved: {report_path}")
            
            # Print summary
            drift_count = sum(1 for r in results if r.drift_detected)
            print(f"MLOps Drift Detection Summary:")
            print(f"- Features analyzed: {len(results)}")
            print(f"- Drift detected: {drift_count}")
            print(f"- Report: {report_path}")
            
            return results
            
        except Exception as e:
            logger.error(f"Drift detection workflow failed: {e}")
            raise

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='MLOps Data Drift Detection System')
    parser.add_argument('--feature', choices=['query_length', 'latency', 'confidence', 'error_rate'], 
                       help='Detect drift for specific feature only')
    parser.add_argument('--threshold', type=float, default=0.05, help='Drift detection threshold (p-value)')
    args = parser.parse_args()
    
    detector = DataDriftDetector()
    
    if args.threshold != 0.05:
        detector.drift_threshold = args.threshold
        logger.info(f"Using custom drift threshold: {args.threshold}")
    
    if args.feature:
        # Run specific feature detection
        method_map = {
            'query_length': detector.detect_query_length_drift,
            'latency': detector.detect_latency_drift,
            'confidence': detector.detect_confidence_drift,
            'error_rate': detector.detect_error_rate_drift
        }
        
        result = method_map[args.feature]()
        print(f"Drift Detection Result for {args.feature}:")
        print(f"- Drift Score: {result.drift_score:.4f}")
        print(f"- P-Value: {result.p_value}")
        print(f"- Drift Detected: {result.drift_detected}")
        
        if result.recommendations:
            print("- Recommendations:")
            for rec in result.recommendations:
                print(f"  • {rec}")
    else:
        # Run full drift detection
        detector.run_drift_detection()

if __name__ == "__main__":
    main()