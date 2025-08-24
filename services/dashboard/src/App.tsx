import { useState, useEffect } from 'react'
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import axios from 'axios'
import './App.css'

interface MLMetrics {
  model_name: string
  accuracy: number
  ece: number
  predictions_count: number
}

interface TransactionConfidence {
  transaction_id: string
  top_brand: string
  confidence_final: number
  items_analyzed: number
}

interface SRPData {
  brand: string
  product: string
  srp: number
  last_updated: string
}

function App() {
  const [mlMetrics, setMlMetrics] = useState<MLMetrics[]>([])
  const [txConfidence, setTxConfidence] = useState<TransactionConfidence[]>([])
  const [srpPrices, setSrpPrices] = useState<SRPData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchData()
    const interval = setInterval(fetchData, 30000) // Refresh every 30s
    return () => clearInterval(interval)
  }, [])

  const fetchData = async () => {
    try {
      // Fetch ML metrics
      const mlResponse = await axios.get('/api/ml/metrics/daily')
      setMlMetrics(mlResponse.data.metrics || [])

      // Fetch recent transaction confidences
      const txResponse = await axios.get('/api/transactions/recent-confidences')
      setTxConfidence(txResponse.data.transactions || [])

      // Fetch SRP prices
      const srpResponse = await axios.get('/api/srp/catalog')
      setSrpPrices(srpResponse.data.prices || [])

      setLoading(false)
    } catch (error) {
      console.error('Failed to fetch data:', error)
      setLoading(false)
    }
  }

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8']

  if (loading) {
    return <div className="loading">Loading dashboard data...</div>
  }

  return (
    <div className="app">
      <h1>AI-AAS Hardened Lakehouse Dashboard</h1>
      
      <div className="dashboard-grid">
        {/* ML Model Performance */}
        <div className="card">
          <h2>ML Model Performance</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={mlMetrics}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="model_name" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="accuracy" fill="#8884d8" name="Accuracy" />
              <Bar dataKey="ece" fill="#82ca9d" name="ECE" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Transaction Confidence Distribution */}
        <div className="card">
          <h2>Transaction Confidence Scores</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={txConfidence.slice(0, 20)}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="transaction_id" />
              <YAxis domain={[0, 1]} />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="confidence_final" stroke="#8884d8" name="Confidence" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Brand Distribution */}
        <div className="card">
          <h2>Brand Distribution</h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={getBrandDistribution(txConfidence)}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={renderCustomizedLabel}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {getBrandDistribution(txConfidence).map((_, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* SRP Price Monitoring */}
        <div className="card">
          <h2>SRP Price Catalog</h2>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Brand</th>
                  <th>Product</th>
                  <th>SRP (PHP)</th>
                  <th>Last Updated</th>
                </tr>
              </thead>
              <tbody>
                {srpPrices.slice(0, 10).map((item, index) => (
                  <tr key={index}>
                    <td>{item.brand}</td>
                    <td>{item.product}</td>
                    <td>₱{item.srp.toFixed(2)}</td>
                    <td>{new Date(item.last_updated).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* System Metrics */}
        <div className="card">
          <h2>System Metrics</h2>
          <div className="metrics-grid">
            <div className="metric">
              <h3>Total Predictions</h3>
              <p className="metric-value">{mlMetrics.reduce((sum, m) => sum + m.predictions_count, 0).toLocaleString()}</p>
            </div>
            <div className="metric">
              <h3>Avg Accuracy</h3>
              <p className="metric-value">{(mlMetrics.reduce((sum, m) => sum + m.accuracy, 0) / mlMetrics.length * 100).toFixed(1)}%</p>
            </div>
            <div className="metric">
              <h3>Active Models</h3>
              <p className="metric-value">{mlMetrics.length}</p>
            </div>
            <div className="metric">
              <h3>SRP Entries</h3>
              <p className="metric-value">{srpPrices.length}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function getBrandDistribution(data: TransactionConfidence[]) {
  const brandCounts: Record<string, number> = {}
  data.forEach(item => {
    brandCounts[item.top_brand] = (brandCounts[item.top_brand] || 0) + 1
  })
  
  return Object.entries(brandCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, value]) => ({ name, value }))
}

const renderCustomizedLabel = ({ cx, cy, midAngle, innerRadius, outerRadius, percent }: any) => {
  const radius = innerRadius + (outerRadius - innerRadius) * 0.5
  const x = cx + radius * Math.cos(-midAngle * Math.PI / 180)
  const y = cy + radius * Math.sin(-midAngle * Math.PI / 180)

  return (
    <text x={x} y={y} fill="white" textAnchor={x > cx ? 'start' : 'end'} dominantBaseline="central">
      {`${(percent * 100).toFixed(0)}%`}
    </text>
  )
}

export default App