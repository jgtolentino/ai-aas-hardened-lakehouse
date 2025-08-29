#!/usr/bin/env python3
"""
MLOps Cost Monitoring and Alerting System
Analyzes AI model costs, detects anomalies, and sends alerts
"""

import os
import sys
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import psycopg2
import pandas as pd
import numpy as np
from scipy import stats
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/mlops-cost-monitor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class CostAlert:
    alert_type: str
    severity: str
    message: str
    current_value: float
    threshold_value: float
    function_name: Optional[str] = None
    metadata: Optional[Dict] = None

@dataclass
class CostMetrics:
    daily_cost: float
    monthly_cost: float
    requests_per_day: int
    cost_per_request: float
    tokens_per_request: float
    cost_per_1k_tokens: float
    trend_direction: str  # 'increasing', 'decreasing', 'stable'
    anomaly_score: float

class MLOpsCostMonitor:
    def __init__(self):
        """Initialize the cost monitoring system"""
        self.db_url = os.getenv('DATABASE_URL') or self._build_db_url()
        self.smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.smtp_port = int(os.getenv('SMTP_PORT', '587'))
        self.email_user = os.getenv('ALERT_EMAIL_USER')
        self.email_password = os.getenv('ALERT_EMAIL_PASSWORD')
        self.alert_recipients = os.getenv('ALERT_RECIPIENTS', '').split(',')
        
        # Cost thresholds (USD)
        self.daily_cost_threshold = float(os.getenv('DAILY_COST_THRESHOLD', '50'))
        self.monthly_cost_threshold = float(os.getenv('MONTHLY_COST_THRESHOLD', '1000'))
        self.cost_per_request_threshold = float(os.getenv('COST_PER_REQUEST_THRESHOLD', '0.10'))
        self.anomaly_threshold = float(os.getenv('ANOMALY_THRESHOLD', '2.5'))  # Z-score
        
        logger.info("MLOps Cost Monitor initialized")
        logger.info(f"Thresholds: Daily=${self.daily_cost_threshold}, Monthly=${self.monthly_cost_threshold}")

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

    def analyze_costs(self) -> Dict[str, CostMetrics]:
        """Analyze costs for all AI functions"""
        logger.info("Starting cost analysis...")
        
        with self.get_db_connection() as conn:
            # Get cost data for the last 30 days
            query = """
            SELECT 
                function_name,
                DATE(timestamp) as date,
                COUNT(*) as requests,
                SUM(total_cost) as daily_cost,
                SUM(total_tokens) as tokens,
                AVG(total_cost) as avg_cost_per_request
            FROM mlops.cost_tracking 
            WHERE timestamp >= NOW() - INTERVAL '30 days'
            GROUP BY function_name, DATE(timestamp)
            ORDER BY function_name, date
            """
            
            df = pd.read_sql(query, conn)
            
        if df.empty:
            logger.warning("No cost data found")
            return {}
            
        metrics = {}
        
        # Analyze each function
        for function_name in df['function_name'].unique():
            function_data = df[df['function_name'] == function_name]
            metrics[function_name] = self._calculate_function_metrics(function_data)
            
        logger.info(f"Analyzed costs for {len(metrics)} functions")
        return metrics

    def _calculate_function_metrics(self, data: pd.DataFrame) -> CostMetrics:
        """Calculate metrics for a specific function"""
        # Basic metrics
        daily_cost = data['daily_cost'].iloc[-1] if not data.empty else 0
        monthly_cost = data['daily_cost'].sum()
        requests_per_day = int(data['requests'].mean())
        cost_per_request = data['avg_cost_per_request'].mean()
        tokens_per_request = (data['tokens'] / data['requests']).mean()
        cost_per_1k_tokens = (cost_per_request / tokens_per_request) * 1000 if tokens_per_request > 0 else 0
        
        # Trend analysis (last 7 days vs previous 7 days)
        if len(data) >= 14:
            recent_avg = data['daily_cost'].tail(7).mean()
            previous_avg = data['daily_cost'].iloc[-14:-7].mean()
            
            if recent_avg > previous_avg * 1.1:
                trend_direction = 'increasing'
            elif recent_avg < previous_avg * 0.9:
                trend_direction = 'decreasing'
            else:
                trend_direction = 'stable'
        else:
            trend_direction = 'insufficient_data'
        
        # Anomaly detection (Z-score based)
        if len(data) >= 7:
            recent_costs = data['daily_cost'].values
            z_scores = np.abs(stats.zscore(recent_costs))
            anomaly_score = z_scores[-1]  # Today's anomaly score
        else:
            anomaly_score = 0.0
        
        return CostMetrics(
            daily_cost=daily_cost,
            monthly_cost=monthly_cost,
            requests_per_day=requests_per_day,
            cost_per_request=cost_per_request,
            tokens_per_request=tokens_per_request,
            cost_per_1k_tokens=cost_per_1k_tokens,
            trend_direction=trend_direction,
            anomaly_score=anomaly_score
        )

    def detect_cost_alerts(self, metrics: Dict[str, CostMetrics]) -> List[CostAlert]:
        """Detect cost-based alerts"""
        alerts = []
        
        total_daily_cost = sum(m.daily_cost for m in metrics.values())
        total_monthly_cost = sum(m.monthly_cost for m in metrics.values())
        
        # Global daily cost alert
        if total_daily_cost > self.daily_cost_threshold:
            alerts.append(CostAlert(
                alert_type='daily_cost_threshold',
                severity='high',
                message=f'Daily AI costs exceed threshold: ${total_daily_cost:.2f} > ${self.daily_cost_threshold}',
                current_value=total_daily_cost,
                threshold_value=self.daily_cost_threshold
            ))
        
        # Global monthly cost alert
        if total_monthly_cost > self.monthly_cost_threshold:
            alerts.append(CostAlert(
                alert_type='monthly_cost_threshold',
                severity='critical',
                message=f'Monthly AI costs exceed threshold: ${total_monthly_cost:.2f} > ${self.monthly_cost_threshold}',
                current_value=total_monthly_cost,
                threshold_value=self.monthly_cost_threshold
            ))
        
        # Per-function alerts
        for function_name, metric in metrics.items():
            # High cost per request
            if metric.cost_per_request > self.cost_per_request_threshold:
                alerts.append(CostAlert(
                    alert_type='cost_per_request_high',
                    severity='medium',
                    message=f'{function_name}: Cost per request is high: ${metric.cost_per_request:.4f}',
                    current_value=metric.cost_per_request,
                    threshold_value=self.cost_per_request_threshold,
                    function_name=function_name
                ))
            
            # Cost anomaly
            if metric.anomaly_score > self.anomaly_threshold:
                alerts.append(CostAlert(
                    alert_type='cost_anomaly',
                    severity='medium',
                    message=f'{function_name}: Unusual cost pattern detected (anomaly score: {metric.anomaly_score:.2f})',
                    current_value=metric.anomaly_score,
                    threshold_value=self.anomaly_threshold,
                    function_name=function_name,
                    metadata={'trend': metric.trend_direction}
                ))
            
            # Rapidly increasing costs
            if metric.trend_direction == 'increasing' and metric.daily_cost > 10:
                alerts.append(CostAlert(
                    alert_type='cost_trend_increasing',
                    severity='medium',
                    message=f'{function_name}: Costs are rapidly increasing (${metric.daily_cost:.2f}/day)',
                    current_value=metric.daily_cost,
                    threshold_value=0,
                    function_name=function_name
                ))
        
        logger.info(f"Detected {len(alerts)} cost alerts")
        return alerts

    def send_alert_email(self, alerts: List[CostAlert]) -> bool:
        """Send alert email notifications"""
        if not alerts or not self.email_user or not self.alert_recipients:
            return False
            
        try:
            # Create email content
            subject = f"MLOps Cost Alert - {len(alerts)} alerts detected"
            
            html_content = self._generate_alert_email_html(alerts)
            
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = self.email_user
            msg['To'] = ', '.join(self.alert_recipients)
            
            html_part = MIMEText(html_content, 'html')
            msg.attach(html_part)
            
            # Send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.email_user, self.email_password)
                server.send_message(msg)
            
            logger.info(f"Alert email sent to {len(self.alert_recipients)} recipients")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send alert email: {e}")
            return False

    def _generate_alert_email_html(self, alerts: List[CostAlert]) -> str:
        """Generate HTML content for alert email"""
        severity_colors = {
            'critical': '#dc3545',
            'high': '#fd7e14', 
            'medium': '#ffc107',
            'low': '#20c997'
        }
        
        html = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .header {{ background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }}
                .alert {{ margin: 10px 0; padding: 15px; border-radius: 5px; border-left: 4px solid; }}
                .alert-critical {{ background-color: #f8d7da; border-color: #dc3545; }}
                .alert-high {{ background-color: #fff3cd; border-color: #fd7e14; }}
                .alert-medium {{ background-color: #fff3cd; border-color: #ffc107; }}
                .alert-low {{ background-color: #d1ecf1; border-color: #20c997; }}
                .metrics {{ background-color: #e9ecef; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h2>MLOps Cost Alert Report</h2>
                <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
                <p><strong>{len(alerts)} alerts detected</strong></p>
            </div>
        """
        
        # Group alerts by severity
        severity_order = ['critical', 'high', 'medium', 'low']
        for severity in severity_order:
            severity_alerts = [a for a in alerts if a.severity == severity]
            if severity_alerts:
                html += f"<h3>{severity.title()} Alerts ({len(severity_alerts)})</h3>"
                
                for alert in severity_alerts:
                    html += f"""
                    <div class="alert alert-{alert.severity}">
                        <h4>{alert.alert_type.replace('_', ' ').title()}</h4>
                        <p>{alert.message}</p>
                        {f'<p><strong>Function:</strong> {alert.function_name}</p>' if alert.function_name else ''}
                        <p><strong>Current Value:</strong> {alert.current_value:.4f}</p>
                        <p><strong>Threshold:</strong> {alert.threshold_value:.4f}</p>
                    </div>
                    """
        
        html += """
            <div class="metrics">
                <h3>Recommended Actions</h3>
                <ul>
                    <li>Review high-cost functions for optimization opportunities</li>
                    <li>Consider implementing request rate limiting</li>
                    <li>Analyze cost anomalies for unusual usage patterns</li>
                    <li>Evaluate model parameter adjustments (temperature, max_tokens)</li>
                    <li>Check for potential abuse or bot traffic</li>
                </ul>
            </div>
            
            <p><small>This alert was generated automatically by the MLOps Cost Monitoring System.</small></p>
        </body>
        </html>
        """
        
        return html

    def log_alerts_to_database(self, alerts: List[CostAlert]) -> None:
        """Log alerts to the database"""
        if not alerts:
            return
            
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                for alert in alerts:
                    # Find matching rule (or create a default one)
                    cursor.execute("""
                        SELECT id FROM mlops.alert_rules 
                        WHERE rule_name LIKE %s 
                        LIMIT 1
                    """, (f"%{alert.alert_type}%",))
                    
                    result = cursor.fetchone()
                    rule_id = result[0] if result else None
                    
                    # Insert alert instance
                    cursor.execute("""
                        INSERT INTO mlops.alert_instances 
                        (rule_id, alert_message, severity, metric_value, threshold_value, 
                         function_name, additional_context)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """, (
                        rule_id,
                        alert.message,
                        alert.severity,
                        alert.current_value,
                        alert.threshold_value,
                        alert.function_name,
                        json.dumps(alert.metadata) if alert.metadata else None
                    ))
                
                conn.commit()
                logger.info(f"Logged {len(alerts)} alerts to database")
                
        except Exception as e:
            logger.error(f"Failed to log alerts to database: {e}")

    def generate_cost_report(self, metrics: Dict[str, CostMetrics]) -> str:
        """Generate detailed cost report"""
        report = []
        report.append("# MLOps Cost Analysis Report")
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Summary
        total_daily = sum(m.daily_cost for m in metrics.values())
        total_monthly = sum(m.monthly_cost for m in metrics.values())
        total_requests = sum(m.requests_per_day for m in metrics.values())
        
        report.append("## Summary")
        report.append(f"- **Total Daily Cost**: ${total_daily:.2f}")
        report.append(f"- **Total Monthly Cost**: ${total_monthly:.2f}")
        report.append(f"- **Total Daily Requests**: {total_requests}")
        report.append(f"- **Average Cost per Request**: ${(total_daily/total_requests if total_requests > 0 else 0):.4f}")
        report.append("")
        
        # Per-function breakdown
        report.append("## Function Breakdown")
        report.append("| Function | Daily Cost | Monthly Cost | Requests/Day | Cost/Request | Trend | Anomaly Score |")
        report.append("|----------|------------|--------------|--------------|---------------|-------|---------------|")
        
        for function_name, metric in metrics.items():
            trend_emoji = {"increasing": "📈", "decreasing": "📉", "stable": "➡️"}.get(metric.trend_direction, "❓")
            anomaly_flag = "⚠️" if metric.anomaly_score > 2.0 else ""
            
            report.append(f"| {function_name} | ${metric.daily_cost:.2f} | ${metric.monthly_cost:.2f} | "
                         f"{metric.requests_per_day} | ${metric.cost_per_request:.4f} | "
                         f"{trend_emoji} | {metric.anomaly_score:.2f} {anomaly_flag} |")
        
        report.append("")
        
        # Recommendations
        report.append("## Recommendations")
        
        # Find most expensive function
        if metrics:
            most_expensive = max(metrics.items(), key=lambda x: x[1].daily_cost)
            report.append(f"- **Most Expensive Function**: {most_expensive[0]} (${most_expensive[1].daily_cost:.2f}/day)")
            
            # Find highest cost per request
            highest_cost_per_req = max(metrics.items(), key=lambda x: x[1].cost_per_request)
            report.append(f"- **Highest Cost per Request**: {highest_cost_per_req[0]} (${highest_cost_per_req[1].cost_per_request:.4f})")
            
            # Functions with increasing trends
            increasing_funcs = [name for name, m in metrics.items() if m.trend_direction == 'increasing']
            if increasing_funcs:
                report.append(f"- **Functions with Increasing Costs**: {', '.join(increasing_funcs)}")
        
        return "\n".join(report)

    def run_cost_monitoring(self) -> None:
        """Main cost monitoring workflow"""
        logger.info("Starting MLOps cost monitoring cycle...")
        
        try:
            # Analyze costs
            metrics = self.analyze_costs()
            
            if not metrics:
                logger.warning("No metrics to analyze, skipping monitoring cycle")
                return
            
            # Detect alerts
            alerts = self.detect_cost_alerts(metrics)
            
            # Log alerts to database
            if alerts:
                self.log_alerts_to_database(alerts)
            
            # Send email alerts for high/critical severity
            critical_alerts = [a for a in alerts if a.severity in ['critical', 'high']]
            if critical_alerts:
                self.send_alert_email(critical_alerts)
            
            # Generate and save report
            report = self.generate_cost_report(metrics)
            report_path = f"/tmp/mlops-cost-report-{datetime.now().strftime('%Y%m%d-%H%M')}.md"
            with open(report_path, 'w') as f:
                f.write(report)
            
            logger.info(f"Cost monitoring completed. Report saved: {report_path}")
            
            # Print summary
            print(f"MLOps Cost Monitoring Summary:")
            print(f"- Functions analyzed: {len(metrics)}")
            print(f"- Alerts detected: {len(alerts)}")
            print(f"- Critical alerts: {len(critical_alerts)}")
            print(f"- Report: {report_path}")
            
        except Exception as e:
            logger.error(f"Cost monitoring failed: {e}")
            raise

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='MLOps Cost Monitoring System')
    parser.add_argument('--dry-run', action='store_true', help='Run without sending alerts')
    parser.add_argument('--report-only', action='store_true', help='Generate report only')
    args = parser.parse_args()
    
    monitor = MLOpsCostMonitor()
    
    if args.report_only:
        metrics = monitor.analyze_costs()
        report = monitor.generate_cost_report(metrics)
        print(report)
    else:
        if args.dry_run:
            logger.info("Running in dry-run mode (no alerts will be sent)")
            # Temporarily disable email sending
            monitor.alert_recipients = []
        
        monitor.run_cost_monitoring()

if __name__ == "__main__":
    main()