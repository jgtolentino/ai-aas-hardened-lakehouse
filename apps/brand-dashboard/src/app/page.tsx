'use client'

import { useState } from 'react'
import axios from 'axios'

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'

interface PredictionResult {
  brand: string
  confidence: number
  model_version: string
  dictionary_version: string
  timestamp: string
}

export default function Home() {
  const [text, setText] = useState('')
  const [prediction, setPrediction] = useState<PredictionResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handlePredict = async () => {
    if (!text.trim()) return

    setLoading(true)
    setError('')
    
    try {
      const response = await axios.post(`${API_URL}/predict`, {
        text: text,
        context: {}
      })
      
      setPrediction(response.data)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Prediction failed')
    } finally {
      setLoading(false)
    }
  }

  const handleHealthCheck = async () => {
    try {
      const response = await axios.get(`${API_URL}/healthz`)
      alert(`API Health: ${response.data.status}`)
    } catch (err) {
      alert('API Health Check Failed')
    }
  }

  return (
    <div className="min-h-screen bg-gray-100 py-6 flex flex-col justify-center sm:py-12">
      <div className="relative py-3 sm:max-w-xl sm:mx-auto">
        <div className="absolute inset-0 bg-gradient-to-r from-cyan-400 to-light-blue-500 shadow-lg transform -skew-y-6 sm:skew-y-0 sm:-rotate-6 sm:rounded-3xl"></div>
        <div className="relative px-4 py-10 bg-white shadow-lg sm:rounded-3xl sm:p-20">
          <div className="max-w-md mx-auto">
            <div>
              <h1 className="text-2xl font-semibold text-center mb-8">Brand Detection Dashboard</h1>
            </div>
            
            <div className="divide-y divide-gray-200">
              <div className="py-8 text-base leading-6 space-y-4 text-gray-700 sm:text-lg sm:leading-7">
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Enter text to detect brands:
                    </label>
                    <textarea
                      className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                      rows={4}
                      value={text}
                      onChange={(e) => setText(e.target.value)}
                      placeholder="e.g., I love drinking Coca-Cola with my lunch"
                    />
                  </div>
                  
                  <button
                    onClick={handlePredict}
                    disabled={loading || !text.trim()}
                    className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:bg-gray-400"
                  >
                    {loading ? 'Detecting...' : 'Detect Brand'}
                  </button>
                </div>
                
                {error && (
                  <div className="mt-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded">
                    {error}
                  </div>
                )}
                
                {prediction && (
                  <div className="mt-6 p-4 bg-green-100 border border-green-400 rounded">
                    <h3 className="text-lg font-medium text-green-800">Prediction Result</h3>
                    <div className="mt-2 space-y-1 text-sm text-green-700">
                      <p><strong>Brand:</strong> {prediction.brand}</p>
                      <p><strong>Confidence:</strong> {(prediction.confidence * 100).toFixed(1)}%</p>
                      <p><strong>Model Version:</strong> {prediction.model_version}</p>
                      <p><strong>Dictionary Version:</strong> {prediction.dictionary_version}</p>
                      <p><strong>Timestamp:</strong> {new Date(prediction.timestamp).toLocaleString()}</p>
                    </div>
                  </div>
                )}
              </div>
              
              <div className="pt-6 text-base leading-6 font-bold sm:text-lg sm:leading-7">
                <div className="space-y-2">
                  <a
                    href={`${API_URL}/docs`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="block text-center py-2 px-4 bg-blue-500 text-white rounded hover:bg-blue-600"
                  >
                    View API Documentation
                  </a>
                  
                  <a
                    href={`${API_URL}/metrics`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="block text-center py-2 px-4 bg-green-500 text-white rounded hover:bg-green-600"
                  >
                    View Metrics
                  </a>
                  
                  <button
                    onClick={handleHealthCheck}
                    className="w-full py-2 px-4 bg-gray-500 text-white rounded hover:bg-gray-600"
                  >
                    Check API Health
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}