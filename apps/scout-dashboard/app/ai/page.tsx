'use client';

import { useState } from 'react';
import { AiChatPanel } from '@/components/ai/AiChatPanel';

export default function AiPage() {
  const [messages, setMessages] = useState<Array<{ role: string; content: string }>>([]);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">AI Assistant</h1>
      
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-12">
          <AiChatPanel
            title="Ask Scout"
            messages={messages}
            onSendMessage={(message) => {
              setMessages(prev => [...prev, { role: 'user', content: message }]);
              // MCP router integration here
            }}
          />
        </div>
      </div>
    </div>
  );
}
