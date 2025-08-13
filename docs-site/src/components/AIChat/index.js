import React, { useState, useRef, useEffect } from 'react';
import { MessageCircle, X, Send, Sparkles, Database, Code, HelpCircle } from 'lucide-react';
import styles from './styles.module.css';

export default function AIChat() {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState([
    {
      role: 'assistant',
      content: `Hi! I'm Scout AI, your documentation and SQL assistant. I can help you:
      
• Navigate Scout documentation
• Write SQL queries for Philippine retail data
• Explain Scout schema and tables
• Generate analytics insights
• Debug query errors

What would you like to know?`,
      timestamp: new Date()
    }
  ]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const quickPrompts = [
    "Show me Scout schema overview",
    "How do I query transactions by store?",
    "Explain the medallion architecture",
    "Top performing stores SQL query"
  ];

  const handleSend = async () => {
    if (!input.trim()) return;

    const userMessage = {
      role: 'user',
      content: input,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsTyping(true);

    // Simulate AI response
    setTimeout(() => {
      const response = generateResponse(input);
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: response.content,
        sql: response.sql,
        timestamp: new Date()
      }]);
      setIsTyping(false);
    }, 1500);
  };

  const generateResponse = (query) => {
    const lowerQuery = query.toLowerCase();
    
    if (lowerQuery.includes('schema') || lowerQuery.includes('table')) {
      return {
        content: `Scout Analytics uses a dimensional model with these main schemas:

**scout** - Main analytics schema
• \`transactions\` - Sales transaction facts
• \`stores\` - Store dimension 
• \`products\` - Product catalog
• \`customers\` - Customer profiles
• \`time_dim\` - Date/time dimension

**scout_dash** - Dashboard aggregates
• \`daily_store_metrics\` - Pre-aggregated KPIs
• \`product_performance\` - Product analytics

Would you like to see the full table structure?`,
        sql: null
      };
    }
    
    if (lowerQuery.includes('top') && lowerQuery.includes('store')) {
      return {
        content: "Here's a query to find top performing stores by revenue:",
        sql: `SELECT 
  s.store_name,
  s.region,
  COUNT(DISTINCT t.transaction_id) as transaction_count,
  SUM(t.total_amount) as total_revenue,
  AVG(t.basket_size) as avg_basket_size
FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.store_id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY s.store_name, s.region
ORDER BY total_revenue DESC
LIMIT 10;`
      };
    }

    if (lowerQuery.includes('transaction') || lowerQuery.includes('query')) {
      return {
        content: "To query transactions with store information:",
        sql: `SELECT 
  t.transaction_id,
  t.transaction_date,
  s.store_name,
  t.total_amount,
  t.basket_size,
  t.payment_method
FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.store_id
WHERE t.transaction_date = CURRENT_DATE
ORDER BY t.transaction_date DESC
LIMIT 100;`
      };
    }

    return {
      content: `I can help you explore Scout Analytics data. Try asking about:
      
• Database schema and tables
• Writing SQL queries for retail analytics
• Store performance metrics
• Product sales analysis
• Customer behavior patterns

What specific information are you looking for?`,
      sql: null
    };
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <>
      {/* Floating button */}
      {!isOpen && (
        <button 
          className={styles.floatingButton}
          onClick={() => setIsOpen(true)}
          aria-label="Open AI Chat"
        >
          <Sparkles size={24} />
          <span className={styles.buttonText}>Ask Scout AI</span>
        </button>
      )}

      {/* Chat window */}
      {isOpen && (
        <div className={styles.chatWindow}>
          <div className={styles.chatHeader}>
            <div className={styles.headerLeft}>
              <Sparkles size={20} />
              <h3>Scout AI Assistant</h3>
            </div>
            <button 
              className={styles.closeButton}
              onClick={() => setIsOpen(false)}
              aria-label="Close chat"
            >
              <X size={20} />
            </button>
          </div>

          <div className={styles.messagesContainer}>
            {messages.map((message, index) => (
              <div 
                key={index} 
                className={`${styles.message} ${styles[message.role]}`}
              >
                <div className={styles.messageContent}>
                  {message.content}
                  {message.sql && (
                    <div className={styles.sqlBlock}>
                      <div className={styles.sqlHeader}>
                        <Code size={14} />
                        <span>SQL Query</span>
                      </div>
                      <pre>{message.sql}</pre>
                    </div>
                  )}
                </div>
                <div className={styles.timestamp}>
                  {message.timestamp.toLocaleTimeString([], { 
                    hour: '2-digit', 
                    minute: '2-digit' 
                  })}
                </div>
              </div>
            ))}
            {isTyping && (
              <div className={`${styles.message} ${styles.assistant}`}>
                <div className={styles.typingIndicator}>
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {messages.length === 1 && (
            <div className={styles.quickPrompts}>
              <p>Quick prompts:</p>
              <div className={styles.promptButtons}>
                {quickPrompts.map((prompt, index) => (
                  <button
                    key={index}
                    className={styles.promptButton}
                    onClick={() => setInput(prompt)}
                  >
                    {prompt}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className={styles.inputContainer}>
            <textarea
              className={styles.input}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Ask about Scout data, SQL queries, or documentation..."
              rows={1}
            />
            <button 
              className={styles.sendButton}
              onClick={handleSend}
              disabled={!input.trim() || isTyping}
            >
              <Send size={18} />
            </button>
          </div>
        </div>
      )}
    </>
  );
}