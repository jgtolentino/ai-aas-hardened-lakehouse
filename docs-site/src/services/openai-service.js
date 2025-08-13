/**
 * OpenAI Service for Scout Analytics AI Chat
 * Provides natural language interface for retail data queries
 */

class OpenAIService {
  constructor() {
    this.apiKey = process.env.REACT_APP_OPENAI_API_KEY || '';
    this.baseURL = 'https://api.openai.com/v1';
    this.model = 'gpt-4';
    
    // Scout-specific context for better responses
    this.systemPrompt = `You are Scout AI, an expert retail analytics assistant for Philippine retail data. You help users understand their retail performance, customer behavior, and business insights.

Context about the retail data:
- Store locations: SM Mall of Asia, Robinsons Galleria, Ayala Center Cebu, SM North EDSA, Greenbelt Makati
- Product categories: Electronics (35%), Fashion (28%), Groceries (20%), Home & Living (10%), Beauty (7%)
- Key metrics: Revenue (₱5.59M current), Transactions (12,676), Conversion Rate (3.4%)
- Regions: NCR (National Capital Region), Visayas, Mindanao
- Currency: Philippine Peso (₱)

When users ask about:
- Revenue: Focus on growth trends, store comparisons, category performance
- Stores: Compare performance by location, efficiency metrics, regional insights
- Customers: Behavior patterns, demographics, loyalty trends
- Products: Category performance, inventory insights, seasonal trends
- Forecasting: Use historical data to predict trends

Always provide specific, actionable insights with Philippine retail context.`;
  }

  /**
   * Send a chat message to OpenAI and get a response
   * @param {string} message - User's message
   * @param {Array} conversationHistory - Previous messages for context
   * @returns {Promise<string>} AI response
   */
  async sendMessage(message, conversationHistory = []) {
    try {
      // If no API key, provide simulated responses
      if (!this.apiKey) {
        return this.getSimulatedResponse(message);
      }

      const messages = [
        { role: 'system', content: this.systemPrompt },
        ...conversationHistory.map(msg => ({
          role: msg.type === 'user' ? 'user' : 'assistant',
          content: msg.message
        })),
        { role: 'user', content: message }
      ];

      const response = await fetch(`${this.baseURL}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        body: JSON.stringify({
          model: this.model,
          messages: messages,
          max_tokens: 500,
          temperature: 0.7,
          stream: false
        })
      });

      if (!response.ok) {
        throw new Error(`OpenAI API error: ${response.status}`);
      }

      const data = await response.json();
      return data.choices[0].message.content;

    } catch (error) {
      console.error('OpenAI Service Error:', error);
      return this.getSimulatedResponse(message);
    }
  }

  /**
   * Generate SQL queries based on natural language
   * @param {string} query - Natural language query
   * @returns {Promise<Object>} SQL query and explanation
   */
  async generateSQL(query) {
    const sqlPrompt = `Convert this natural language query to SQL for Philippine retail analytics:

Available tables:
- scout_transactions (transaction_id, customer_id, timestamp, total_amount, store_id)
- customers (customer_id, full_name, age_group, gender, region, city)
- stores (store_id, store_name, region, city, status)
- products (product_id, category, name, price)

Query: "${query}"

Return a JSON object with:
- sql: the SQL query
- explanation: brief explanation of what the query does
- visualization: suggested chart type (bar, line, pie, table)`;

    try {
      const response = await this.sendMessage(sqlPrompt);
      
      // Try to parse as JSON, fallback to simulated response
      try {
        return JSON.parse(response);
      } catch {
        return this.getSimulatedSQLResponse(query);
      }
    } catch (error) {
      return this.getSimulatedSQLResponse(query);
    }
  }

  /**
   * Get simulated responses when OpenAI API is not available
   * @param {string} message - User's message
   * @returns {string} Simulated AI response
   */
  getSimulatedResponse(message) {
    const lowerMessage = message.toLowerCase();
    
    // Revenue-related queries
    if (lowerMessage.includes('revenue') || lowerMessage.includes('sales')) {
      return `📊 **Revenue Analysis:**

Current revenue is **₱5.59M** with a strong **+12.3% growth** vs last period.

**Top Performers:**
• SM Mall of Asia: ₱2.45M (+15.2%)
• Robinsons Galleria: ₱1.89M (-5.3%)
• Ayala Center Cebu: ₱1.75M (+22.1%)

**Key Insights:**
✅ Electronics category driving 35% of revenue
⚠️ Robinsons Galleria needs attention (declining performance)
🚀 Cebu showing exceptional growth - consider expansion

Would you like me to analyze specific stores or categories?`;
    }

    // Store-related queries
    if (lowerMessage.includes('store') || lowerMessage.includes('location')) {
      return `🏪 **Store Performance Overview:**

**Best Performing:**
1. **SM Mall of Asia** - ₱2.45M revenue, 94% efficiency
2. **Ayala Center Cebu** - ₱1.75M revenue, 91% efficiency

**Needs Attention:**
⚠️ **Robinsons Galleria** - 87% efficiency, -5.3% growth

**Regional Insights:**
• **NCR (Metro Manila)**: 4 stores, mixed performance
• **Visayas**: 1 store, excellent growth (+22.1%)
• **Mindanao**: Expansion opportunity

**Recommendation:** Investigate operational issues at Robinsons Galleria and consider Mindanao expansion based on Cebu success.`;
    }

    // Customer-related queries
    if (lowerMessage.includes('customer') || lowerMessage.includes('conversion')) {
      return `👥 **Customer Analytics:**

**Current Metrics:**
• Active Customers: **8,429** (+15.4% growth)
• Conversion Rate: **3.4%** (+2.1% improvement)
• Average Basket: **₱441** (+3.2% growth)

**Insights:**
✅ Strong customer acquisition trend
📈 Improving conversion efficiency
💡 Opportunity: Electronics buyers show highest loyalty

**Recommendations:**
1. Target Electronics customers for cross-selling
2. Implement loyalty program for ₱500+ baskets
3. Focus acquisition in Visayas region (proven growth)`;
    }

    // Category/product queries
    if (lowerMessage.includes('category') || lowerMessage.includes('product') || lowerMessage.includes('electronics') || lowerMessage.includes('fashion')) {
      return `📦 **Category Performance:**

**Revenue Distribution:**
1. **Electronics** - 35% (₱1.95M) 🔥
2. **Fashion** - 28% (₱1.57M) 👗
3. **Groceries** - 20% (₱1.12M) 🛒
4. **Home & Living** - 10% (₱559K) 🏠
5. **Beauty** - 7% (₱391K) 💄

**Strategic Insights:**
✅ Electronics dominant across all stores
📈 Fashion growing in Makati/BGC locations
⚡ Opportunity: Expand Electronics inventory
💡 Cross-sell Beauty with Fashion purchases

**Next Steps:** Increase Electronics SKUs and test Beauty-Fashion bundles.`;
    }

    // Forecasting queries
    if (lowerMessage.includes('forecast') || lowerMessage.includes('predict') || lowerMessage.includes('trend')) {
      return `🔮 **Revenue Forecast & Trends:**

**6-Month Projection:**
• **Q1 2024**: ₱6.2M (predicted +11% growth)
• **Peak Season**: December expected ₱8.5M
• **Growth Driver**: Electronics + Cebu expansion

**Key Trends:**
📈 **Upward:** Mobile Electronics, Beauty products
📊 **Stable:** Groceries, Home essentials  
⚠️ **Watch:** Fashion (seasonal variance)

**AI Recommendations:**
1. **Inventory**: Boost Electronics stock before Q4
2. **Expansion**: Cebu model replication in Davao
3. **Marketing**: Target 25-35 age group in Electronics

**Risk Factors:** Monitor Robinsons Galleria performance closely.`;
    }

    // Default response
    return `🤖 **Scout AI Assistant:**

I can help you analyze your Philippine retail data! Try asking about:

📊 **Revenue & Sales**: "How's our revenue performing?"
🏪 **Store Performance**: "Which stores are top performers?"
👥 **Customer Insights**: "What's our conversion rate?"
📦 **Product Categories**: "How are Electronics performing?"
🔮 **Forecasting**: "What's our revenue forecast?"

**Quick Stats:**
• Total Revenue: ₱5.59M (+12.3%)
• Active Customers: 8,429 (+15.4%)
• Best Store: SM Mall of Asia (₱2.45M)
• Top Category: Electronics (35% share)

What would you like to explore?`;
    }
  }

  /**
   * Get simulated SQL responses
   * @param {string} query - User's query
   * @returns {Object} Simulated SQL response
   */
  getSimulatedSQLResponse(query) {
    const lowerQuery = query.toLowerCase();

    if (lowerQuery.includes('revenue') || lowerQuery.includes('sales')) {
      return {
        sql: `SELECT 
  store_name, 
  SUM(total_amount) as revenue,
  COUNT(*) as transactions
FROM scout_transactions st
JOIN stores s ON st.store_id = s.store_id
WHERE timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY store_name
ORDER BY revenue DESC;`,
        explanation: "This query calculates total revenue and transaction count by store for the last 30 days",
        visualization: "bar"
      };
    }

    if (lowerQuery.includes('customer') || lowerQuery.includes('demographic')) {
      return {
        sql: `SELECT 
  age_group,
  gender,
  region,
  COUNT(*) as customer_count,
  AVG(total_amount) as avg_spend
FROM customers c
JOIN scout_transactions st ON c.customer_id = st.customer_id
GROUP BY age_group, gender, region
ORDER BY customer_count DESC;`,
        explanation: "This query analyzes customer demographics and spending patterns",
        visualization: "table"
      };
    }

    // Default SQL response
    return {
      sql: `SELECT 
  DATE(timestamp) as date,
  SUM(total_amount) as daily_revenue,
  COUNT(*) as daily_transactions
FROM scout_transactions
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(timestamp)
ORDER BY date;`,
      explanation: "This query shows daily revenue and transaction trends for the past week",
      visualization: "line"
    };
  }

  /**
   * Analyze retail data and provide insights
   * @param {Object} data - Retail data object
   * @returns {Promise<Array>} Array of insights
   */
  async analyzeRetailData(data) {
    const insights = [];

    // Revenue analysis
    if (data.revenue) {
      const growth = data.revenue.growth || 0;
      if (growth > 10) {
        insights.push({
          type: 'success',
          title: 'Strong Revenue Growth',
          message: `Revenue is up ${growth}% - excellent performance!`,
          action: 'Consider expanding successful strategies'
        });
      } else if (growth < 0) {
        insights.push({
          type: 'warning',
          title: 'Revenue Decline',
          message: `Revenue is down ${Math.abs(growth)}% - needs attention`,
          action: 'Investigate operational issues and market factors'
        });
      }
    }

    // Store performance analysis
    if (data.stores && Array.isArray(data.stores)) {
      const topStore = data.stores.reduce((max, store) => 
        store.revenue > max.revenue ? store : max
      );
      
      insights.push({
        type: 'info',
        title: 'Top Performing Store',
        message: `${topStore.name} leads with ₱${(topStore.revenue/1000000).toFixed(2)}M`,
        action: 'Analyze and replicate success factors'
      });

      const underperforming = data.stores.filter(store => store.growth < 0);
      if (underperforming.length > 0) {
        insights.push({
          type: 'warning',
          title: 'Underperforming Stores',
          message: `${underperforming.length} store(s) showing negative growth`,
          action: 'Implement performance improvement plans'
        });
      }
    }

    return insights;
  }
}

// Export singleton instance
export default new OpenAIService();