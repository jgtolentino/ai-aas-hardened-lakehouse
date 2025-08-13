import React, { useState } from 'react';
import Layout from '@theme/Layout';
import styles from './playground.module.css';
import { BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Database, TrendingUp, DollarSign, Users, Package, MessageCircle, Activity, Brain, Zap } from 'lucide-react';

export default function Playground() {
  const [query, setQuery] = useState(`-- Scout Analytics: Philippine Retail Intelligence
SELECT 
  s.store_name,
  p.category,
  SUM(t.revenue) as total_revenue,
  COUNT(DISTINCT t.transaction_id) as transactions,
  AVG(t.basket_size) as avg_basket_size
FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.store_id
JOIN scout.products p ON t.product_id = p.product_id
WHERE t.transaction_date >= '2024-01-01'
GROUP BY s.store_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;`);
  const [results, setResults] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleExecute = async () => {
    setIsLoading(true);
    // Simulated Scout schema query results
    setTimeout(() => {
      setResults({
        columns: ['store_name', 'category', 'total_revenue', 'transactions', 'avg_basket_size'],
        rows: [
          ['SM Mall of Asia', 'Electronics', '₱2,450,000', '1,234', '₱1,987'],
          ['Robinsons Galleria', 'Fashion', '₱1,890,000', '2,456', '₱770'],
          ['Ayala Center Cebu', 'Groceries', '₱1,750,000', '5,123', '₱341'],
          ['SM North EDSA', 'Home & Living', '₱1,620,000', '987', '₱1,641'],
          ['Greenbelt Makati', 'Beauty', '₱1,480,000', '1,876', '₱789'],
        ],
        chartData: [
          { store: 'SM Mall of Asia', revenue: 2450000, footfall: 45000, conversion: 2.7 },
          { store: 'Robinsons Galleria', revenue: 1890000, footfall: 38000, conversion: 6.5 },
          { store: 'Ayala Center Cebu', revenue: 1750000, footfall: 52000, conversion: 9.9 },
          { store: 'SM North EDSA', revenue: 1620000, footfall: 41000, conversion: 2.4 },
          { store: 'Greenbelt Makati', revenue: 1480000, footfall: 28000, conversion: 6.7 }
        ],
        categoryData: [
          { category: 'Electronics', value: 35 },
          { category: 'Fashion', value: 28 },
          { category: 'Groceries', value: 20 },
          { category: 'Home & Living', value: 10 },
          { category: 'Beauty', value: 7 }
        ]
      });
      setIsLoading(false);
    }, 1000);
  };

  return (
    <Layout title="SQL Playground" description="Interactive SQL playground for Scout Analytics">
      <div className={styles.playground}>
        <div className={styles.header}>
          <h1>🚀 SQL Playground</h1>
          <p>Explore Scout Analytics data with live SQL queries</p>
        </div>

        <div className={styles.container}>
          <div className={styles.editorSection}>
            <h3>Query Editor</h3>
            <textarea
              className={styles.editor}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Enter your SQL query here..."
              spellCheck={false}
            />
            <button 
              className={styles.executeBtn}
              onClick={handleExecute}
              disabled={isLoading}
            >
              {isLoading ? 'Executing...' : 'Execute Query'}
            </button>
          </div>

          {results && (
            <>
              <div className={styles.resultsSection}>
                <h3><Database size={20} style={{verticalAlign: 'middle'}} /> Query Results</h3>
                <div className={styles.tableWrapper}>
                  <table className={styles.resultsTable}>
                    <thead>
                      <tr>
                        {results.columns.map((col, i) => (
                          <th key={i}>{col}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {results.rows.map((row, i) => (
                        <tr key={i}>
                          {row.map((cell, j) => (
                            <td key={j}>{cell}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              <div className={styles.chartsSection}>
                <h3><TrendingUp size={20} style={{verticalAlign: 'middle'}} /> Data Visualization</h3>
                <div className={styles.chartsGrid}>
                  <div className={styles.chartCard}>
                    <h4>Revenue by Store</h4>
                    <ResponsiveContainer width="100%" height={300}>
                      <BarChart data={results.chartData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="store" angle={-45} textAnchor="end" height={80} />
                        <YAxis />
                        <Tooltip formatter={(value) => `₱${value.toLocaleString()}`} />
                        <Bar dataKey="revenue" fill="#0078d4" />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                  
                  <div className={styles.chartCard}>
                    <h4>Category Distribution</h4>
                    <ResponsiveContainer width="100%" height={300}>
                      <PieChart>
                        <Pie
                          data={results.categoryData}
                          dataKey="value"
                          nameKey="category"
                          cx="50%"
                          cy="50%"
                          outerRadius={100}
                          label
                        >
                          {results.categoryData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={['#0078d4', '#40a9ff', '#69c0ff', '#91d5ff', '#bae7ff'][index % 5]} />
                          ))}
                        </Pie>
                        <Tooltip />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                </div>
              </div>
            </>
          )}

          <div className={styles.aiChat}>
            <h3><Brain size={20} style={{verticalAlign: 'middle'}} /> Ask Scout AI</h3>
            <div className={styles.chatContainer}>
              <div className={styles.chatMessages}>
                <div className={styles.message}>
                  <strong>Scout AI:</strong> Hello! I'm your Philippine retail analytics assistant. I can help you explore Scout data and generate insights. Try asking:
                  <ul>
                    <li>"Show me top performing stores by revenue"</li>
                    <li>"Which product categories have the highest conversion rates?"</li>
                    <li>"Compare footfall trends across Metro Manila stores"</li>
                    <li>"Analyze basket size patterns by store type"</li>
                  </ul>
                </div>
              </div>
              <div className={styles.chatInput}>
                <input 
                  type="text" 
                  placeholder="Ask about stores, products, transactions, or trends..."
                  className={styles.input}
                />
                <button className={styles.sendBtn}><MessageCircle size={16} /> Send</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}