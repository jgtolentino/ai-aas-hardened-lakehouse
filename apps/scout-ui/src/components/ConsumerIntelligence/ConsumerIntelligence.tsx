'use client'
import React, { useState } from 'react'
import { Grid, KpiTile, Button, FilterPanel } from '../index'
import { 
  Clock, MapPin, Package, TrendingUp, Users, 
  BarChart3, PieChart, Map, Brain, Activity,
  ShoppingBag, DollarSign, Timer, Layers
} from 'lucide-react'
import { 
  LineChart, Line, BarChart, Bar, XAxis, YAxis, 
  CartesianGrid, Tooltip, ResponsiveContainer, 
  PieChart as RePieChart, Pie, Cell, Sankey,
  Treemap, Funnel, FunnelChart, LabelList,
  RadarChart, PolarGrid, PolarAngleAxis, Radar,
  AreaChart, Area, ComposedChart, Legend
} from 'recharts'

// Transaction Trends Panel Component
export function TransactionTrendsPanel() {
  const [toggles, setToggles] = useState({
    timeOfDay: 'all',
    barangay: 'all',
    category: 'all',
    weekType: 'all',
    location: 'all'
  })

  const timeSeriesData = [
    { time: '6AM', volume: 45, value: 2150 },
    { time: '9AM', volume: 120, value: 5800 },
    { time: '12PM', volume: 180, value: 8900 },
    { time: '3PM', volume: 150, value: 7200 },
    { time: '6PM', volume: 220, value: 12500 },
    { time: '9PM', volume: 95, value: 4200 }
  ]

  const heatmapData = [
    { hour: '6AM', mon: 45, tue: 52, wed: 48, thu: 51, fri: 68, sat: 85, sun: 72 },
    { hour: '9AM', mon: 120, tue: 115, wed: 125, thu: 118, fri: 135, sat: 145, sun: 95 },
    { hour: '12PM', mon: 180, tue: 175, wed: 185, thu: 170, fri: 195, sat: 210, sun: 165 },
    { hour: '3PM', mon: 150, tue: 145, wed: 155, thu: 140, fri: 165, sat: 180, sun: 135 },
    { hour: '6PM', mon: 220, tue: 210, wed: 225, thu: 205, fri: 245, sat: 185, sun: 195 },
    { hour: '9PM', mon: 95, tue: 85, wed: 90, thu: 88, fri: 125, sat: 145, sun: 110 }
  ]

  const boxPlotData = {
    min: 50,
    q1: 150,
    median: 250,
    q3: 450,
    max: 1200,
    outliers: [1500, 1800, 2100]
  }

  return (
    <div className="bg-panel rounded-sk p-6 border border-white/10">
      <div className="mb-6">
        <h2 className="text-xl font-bold text-text mb-2 flex items-center gap-2">
          <Activity className="w-5 h-5 text-accent" />
          Transaction Trends
        </h2>
        <p className="text-sm text-muted">Understand transaction dynamics and patterns by dimension</p>
      </div>

      {/* What it includes */}
      <div className="mb-6 p-4 bg-bg rounded-sk">
        <h3 className="text-sm font-semibold text-text mb-3">What it includes:</h3>
        <ul className="space-y-2 text-sm text-muted">
          <li className="flex items-center gap-2">
            <Clock className="w-4 h-4" />
            Volume of transactions by time of day & location
          </li>
          <li className="flex items-center gap-2">
            <DollarSign className="w-4 h-4" />
            Peso value distribution
          </li>
          <li className="flex items-center gap-2">
            <Timer className="w-4 h-4" />
            Duration of transaction
          </li>
          <li className="flex items-center gap-2">
            <Package className="w-4 h-4" />
            Units per transaction
          </li>
          <li className="flex items-center gap-2">
            <Layers className="w-4 h-4" />
            Brand and category
          </li>
          <li className="flex items-center gap-2">
            <TrendingUp className="w-4 h-4" />
            Average value per transaction
          </li>
        </ul>
      </div>

      {/* Toggles */}
      <div className="mb-6">
        <h3 className="text-sm font-semibold text-text mb-3">Toggles:</h3>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <select 
            value={toggles.timeOfDay}
            onChange={(e) => setToggles({...toggles, timeOfDay: e.target.value})}
            className="px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text"
          >
            <option value="all">All Times</option>
            <option value="morning">Morning (6AM-12PM)</option>
            <option value="afternoon">Afternoon (12PM-6PM)</option>
            <option value="evening">Evening (6PM-12AM)</option>
          </select>
          <select 
            value={toggles.barangay}
            onChange={(e) => setToggles({...toggles, barangay: e.target.value})}
            className="px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text"
          >
            <option value="all">All Barangays</option>
            <option value="poblacion">Poblacion</option>
            <option value="san-jose">San Jose</option>
            <option value="santo-nino">Santo Niño</option>
          </select>
          <select 
            value={toggles.category}
            onChange={(e) => setToggles({...toggles, category: e.target.value})}
            className="px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text"
          >
            <option value="all">All Categories</option>
            <option value="yosi">Yosi</option>
            <option value="haircare">Haircare</option>
            <option value="snacks">Snacks</option>
            <option value="beverages">Beverages</option>
          </select>
          <select 
            value={toggles.weekType}
            onChange={(e) => setToggles({...toggles, weekType: e.target.value})}
            className="px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text"
          >
            <option value="all">All Days</option>
            <option value="weekday">Weekdays</option>
            <option value="weekend">Weekends</option>
          </select>
          <select 
            value={toggles.location}
            onChange={(e) => setToggles({...toggles, location: e.target.value})}
            className="px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text"
          >
            <option value="all">All Locations</option>
            <option value="urban">Urban</option>
            <option value="rural">Rural</option>
          </select>
        </div>
      </div>

      {/* Visualizations */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Time Series Chart */}
        <div className="bg-bg rounded-sk p-4">
          <h4 className="text-sm font-medium text-text mb-3">Transaction Volume by Time</h4>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={timeSeriesData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#333" />
              <XAxis dataKey="time" stroke="#9aa3b2" />
              <YAxis stroke="#9aa3b2" />
              <Tooltip contentStyle={{ backgroundColor: '#121622', border: '1px solid #333' }} />
              <Line type="monotone" dataKey="volume" stroke="#0057ff" strokeWidth={2} />
              <Line type="monotone" dataKey="value" stroke="#2ecc71" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Heatmap */}
        <div className="bg-bg rounded-sk p-4">
          <h4 className="text-sm font-medium text-text mb-3">Transaction Heatmap (Hour x Day)</h4>
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-muted">
                  <th className="p-1">Hour</th>
                  <th className="p-1">Mon</th>
                  <th className="p-1">Tue</th>
                  <th className="p-1">Wed</th>
                  <th className="p-1">Thu</th>
                  <th className="p-1">Fri</th>
                  <th className="p-1">Sat</th>
                  <th className="p-1">Sun</th>
                </tr>
              </thead>
              <tbody>
                {heatmapData.map((row) => (
                  <tr key={row.hour}>
                    <td className="p-1 text-muted">{row.hour}</td>
                    {['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((day) => {
                      const value = row[day]
                      const intensity = Math.min(value / 250, 1)
                      return (
                        <td 
                          key={day}
                          className="p-1 text-center"
                          style={{ 
                            backgroundColor: `rgba(0, 87, 255, ${intensity})`,
                            color: intensity > 0.5 ? '#fff' : '#9aa3b2'
                          }}
                        >
                          {value}
                        </td>
                      )
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Box Plot */}
        <div className="bg-bg rounded-sk p-4 lg:col-span-2">
          <h4 className="text-sm font-medium text-text mb-3">Transaction Value Distribution (Box Plot)</h4>
          <div className="flex items-center justify-center h-32">
            <svg width="100%" height="80" viewBox="0 0 600 80">
              {/* Box plot visualization */}
              <line x1="50" y1="40" x2="550" y2="40" stroke="#333" strokeWidth="1" />
              {/* Min line */}
              <line x1="100" y1="30" x2="100" y2="50" stroke="#9aa3b2" strokeWidth="2" />
              {/* Box */}
              <rect x="200" y="20" width="200" height="40" fill="#0057ff" fillOpacity="0.3" stroke="#0057ff" strokeWidth="2" />
              {/* Median line */}
              <line x1="300" y1="20" x2="300" y2="60" stroke="#fff" strokeWidth="2" />
              {/* Max line */}
              <line x1="500" y1="30" x2="500" y2="50" stroke="#9aa3b2" strokeWidth="2" />
              {/* Whiskers */}
              <line x1="100" y1="40" x2="200" y2="40" stroke="#9aa3b2" strokeWidth="1" strokeDasharray="2 2" />
              <line x1="400" y1="40" x2="500" y2="40" stroke="#9aa3b2" strokeWidth="1" strokeDasharray="2 2" />
              {/* Labels */}
              <text x="100" y="70" fill="#9aa3b2" fontSize="10" textAnchor="middle">₱50</text>
              <text x="200" y="70" fill="#9aa3b2" fontSize="10" textAnchor="middle">₱150</text>
              <text x="300" y="70" fill="#9aa3b2" fontSize="10" textAnchor="middle">₱250</text>
              <text x="400" y="70" fill="#9aa3b2" fontSize="10" textAnchor="middle">₱450</text>
              <text x="500" y="70" fill="#9aa3b2" fontSize="10" textAnchor="middle">₱1200</text>
            </svg>
          </div>
        </div>
      </div>

      {/* Goal */}
      <div className="mt-6 p-4 bg-accent/10 rounded-sk border border-accent/30">
        <p className="text-sm text-text">
          <span className="font-semibold">🎯 Goal:</span> Understand transaction dynamics and patterns by dimension
        </p>
      </div>
    </div>
  )
}