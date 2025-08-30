'use client'
import React, { useState, useEffect } from 'react'
import { Grid, KpiTile } from '../index'
import { useStats, useEffect } from 'react'
import { Grid, KpiTile } from '../index'
import { Map, MapPin, TrendingUp, Users, DollarSign, Navigation, Globe, Layers } from 'lucide-react'

// Consumer Intelligence Component
export function ConsumerIntelligenceMap({ data, metric = 'revenue' }) {
  const [selectedRegion, setSelectedRegion] = useState(null)
  const [tooltipData, setTooltipData] = useState(null)
  const [tooltipPosition, setTooltipPosition] = useState({ x: 0, y: 0 })

  const metrics = {
    revenue: { label: 'Revenue', format: (v) => `₱${(v/1000).toFixed(0)}K` },
    customers: { label: 'Customers', format: (v) => `${(v/1000).toFixed(1)}K` },
    growth: { label: 'Growth', format: (v) => `${v.toFixed(1)}%` },
    satisfaction: { label: 'Satisfaction', format: (v) => `${v.toFixed(1)}%` }
  }

  const colorScale = (value, min, max) => {
    const normalized = (value - min) / (max - min)
    const hue = normalized * 120 // 0 (red) to 120 (green)
    return `hsl(${hue}, 70%, 50%)`
  }

  const regionData = data || [
    { id: 'ncr', name: 'NCR', revenue: 850000, customers: 45000, growth: 12.5, satisfaction: 88 },
    { id: 'region1', name: 'Region I', revenue: 320000, customers: 18000, growth: 8.2, satisfaction: 85 },
    { id: 'region2', name: 'Region II', revenue: 280000, customers: 15000, growth: 6.5, satisfaction: 82 },
    { id: 'region3', name: 'Region III', revenue: 450000, customers: 28000, growth: 10.3, satisfaction: 86 },
    { id: 'region4a', name: 'Region IV-A', revenue: 680000, customers: 38000, growth: 11.8, satisfaction: 87 },
    { id: 'region4b', name: 'Region IV-B', revenue: 220000, customers: 12000, growth: 5.2, satisfaction: 80 },
    { id: 'region5', name: 'Region V', revenue: 340000, customers: 20000, growth: 7.8, satisfaction: 83 },
    { id: 'region6', name: 'Region VI', revenue: 420000, customers: 25000, growth: 9.5, satisfaction: 84 },
    { id: 'region7', name: 'Region VII', revenue: 560000, customers: 32000, growth: 10.8, satisfaction: 86 },
    { id: 'region8', name: 'Region VIII', revenue: 260000, customers: 14000, growth: 5.8, satisfaction: 81 },
    { id: 'region9', name: 'Region IX', revenue: 290000, customers: 16000, growth: 6.2, satisfaction: 82 },
    { id: 'region10', name: 'Region X', revenue: 380000, customers: 22000, growth: 8.5, satisfaction: 84 },
    { id: 'region11', name: 'Region XI', revenue: 480000, customers: 27000, growth: 9.8, satisfaction: 85 },
    { id: 'region12', name: 'Region XII', revenue: 320000, customers: 18000, growth: 7.2, satisfaction: 83 },
    { id: 'region13', name: 'Region XIII', revenue: 240000, customers: 13000, growth: 5.5, satisfaction: 80 },
    { id: 