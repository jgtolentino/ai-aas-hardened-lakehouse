'use client'

import React from 'react'

interface AiChatPanelProps {
  className?: string
}

export const AiChatPanel: React.FC<AiChatPanelProps> = ({ className = '' }) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">AI Chat Assistant</h3>
      <div className="space-y-4">
        <div className="bg-gray-50 p-4 rounded-lg">
          <p className="text-sm text-gray-600">
            Chat functionality will be implemented in the next release.
          </p>
        </div>
        <div className="flex gap-2">
          <input 
            type="text" 
            placeholder="Ask me anything about your data..." 
            className="flex-1 p-2 border rounded-md"
            disabled
          />
          <button 
            className="px-4 py-2 bg-blue-600 text-white rounded-md disabled:opacity-50"
            disabled
          >
            Send
          </button>
        </div>
      </div>
    </div>
  )
}

export default AiChatPanel