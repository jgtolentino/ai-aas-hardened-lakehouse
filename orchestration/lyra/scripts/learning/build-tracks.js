#!/usr/bin/env node
/**
 * W8: Learning Paths - Build role-based learning tracks
 * Gate: All samples run locally with mock JWT
 */

import fs from 'fs';
import path from 'path';

console.log('🎓 Building Learning Paths and tracks...');

const learningTracks = {
  analyst: {
    title: "Data Analyst Learning Path",
    description: "Master Scout analytics for business insights",
    estimated_hours: 12,
    tracks: [
      {
        id: "scout-basics",
        title: "Scout Analytics Basics",
        duration_hours: 2,
        lessons: [
          {
            id: "intro-to-scout",
            title: "Introduction to Scout Dashboard",
            type: "tutorial",
            content: "Learn the Scout interface and navigation"
          },
          {
            id: "basic-queries",
            title: "Writing Basic SQL Queries", 
            type: "hands-on",
            content: "Practice SELECT statements on Scout data"
          },
          {
            id: "first-visualization",
            title: "Creating Your First Chart",
            type: "project",
            content: "Build a bar chart showing top brands"
          }
        ]
      },
      {
        id: "advanced-analytics",
        title: "Advanced Analytics Techniques",
        duration_hours: 4,
        lessons: [
          {
            id: "joins-aggregations",
            title: "Complex Joins and Aggregations",
            type: "tutorial",
            content: "Master multi-table queries and grouping"
          },
          {
            id: "time-series",
            title: "Time Series Analysis",
            type: "hands-on", 
            content: "Analyze trends over time with Scout data"
          },
          {
            id: "cohort-analysis",
            title: "Customer Cohort Analysis",
            type: "project",
            content: "Build cohort retention analysis"
          }
        ]
      }
    ]
  },
  developer: {
    title: "Developer Integration Path",
    description: "Integrate Scout APIs into applications",
    estimated_hours: 16,
    tracks: [
      {
        id: "api-fundamentals",
        title: "Scout API Fundamentals",
        duration_hours: 3,
        lessons: [
          {
            id: "rest-api-basics",
            title: "REST API Authentication",
            type: "tutorial",
            content: "Learn JWT authentication and tenant headers"
          },
          {
            id: "postman-collection",
            title: "Using Postman with Scout APIs",
            type: "hands-on",
            content: "Import and test Scout API collection"
          },
          {
            id: "first-integration",
            title: "Your First API Integration",
            type: "project", 
            content: "Fetch and display Scout data in a web page"
          }
        ]
      },
      {
        id: "sdk-mastery",
        title: "Multi-Language SDK Usage",
        duration_hours: 6,
        lessons: [
          {
            id: "javascript-sdk",
            title: "JavaScript/TypeScript SDK",
            type: "tutorial",
            content: "Use Scout client library in Node.js and browsers"
          },
          {
            id: "python-sdk", 
            title: "Python SDK for Data Science",
            type: "hands-on",
            content: "Integrate Scout with Pandas and Jupyter"
          },
          {
            id: "java-csharp-sdks",
            title: "Java and C# Enterprise SDKs",
            type: "tutorial",
            content: "Use Scout in enterprise applications"
          }
        ]
      }
    ]
  },
  admin: {
    title: "Platform Administration",
    description: "Manage Scout platform and users",
    estimated_hours: 8,
    tracks: [
      {
        id: "user-management",
        title: "User and Tenant Management",
        duration_hours: 2,
        lessons: [
          {
            id: "rbac-setup",
            title: "Role-Based Access Control",
            type: "tutorial",
            content: "Configure user roles and permissions"
          },
          {
            id: "tenant-isolation",
            title: "Multi-Tenant Data Isolation", 
            type: "hands-on",
            content: "Ensure proper data segregation"
          }
        ]
      },
      {
        id: "monitoring-ops",
        title: "Monitoring and Operations",
        duration_hours: 3,
        lessons: [
          {
            id: "health-monitoring",
            title: "System Health Monitoring",
            type: "tutorial",
            content: "Set up alerts and dashboards"
          },
          {
            id: "performance-tuning",
            title: "Query Performance Optimization",
            type: "hands-on",
            content: "Optimize slow queries and indexes"
          }
        ]
      }
    ]
  }
};

// Sample code templates for different SDKs
const sampleCodes = {
  javascript: {
    basic_query: `
// Scout JavaScript SDK Example
import { ScoutClient } from '@scout/client';

const scout = new ScoutClient({
  url: process.env.SUPABASE_URL,
  key: process.env.SUPABASE_ANON_KEY,
  tenant: 'your-tenant-id'
});

// Basic query example
async function getTopBrands() {
  const { data, error } = await scout
    .from('gold_brand_performance')
    .select('brand_name, revenue, growth_rate')
    .order('revenue', { ascending: false })
    .limit(10);
    
  if (error) {
    console.error('Query failed:', error);
    return;
  }
  
  console.log('Top 10 brands:', data);
  return data;
}

// Run the example
getTopBrands();
`,
    chart_creation: `
// Creating charts with Scout data
import { ScoutChart } from '@scout/charts';

async function createBrandChart() {
  const brands = await getTopBrands();
  
  const chart = new ScoutChart({
    type: 'bar',
    data: {
      labels: brands.map(b => b.brand_name),
      datasets: [{
        label: 'Revenue',
        data: brands.map(b => b.revenue),
        backgroundColor: '#0078d4'
      }]
    },
    options: {
      responsive: true,
      plugins: {
        title: {
          display: true,
          text: 'Top Brands by Revenue'
        }
      }
    }
  });
  
  chart.render('#chart-container');
}
`
  },
  python: {
    basic_query: `
# Scout Python SDK Example
import os
from scout_client import ScoutClient
import pandas as pd

# Initialize Scout client
scout = ScoutClient(
    url=os.getenv('SUPABASE_URL'),
    key=os.getenv('SUPABASE_ANON_KEY'),
    tenant='your-tenant-id'
)

def get_top_brands():
    """Fetch top performing brands"""
    try:
        result = scout.table('gold_brand_performance') \\
                      .select('brand_name, revenue, growth_rate') \\
                      .order('revenue', desc=True) \\
                      .limit(10) \\
                      .execute()
        
        # Convert to pandas DataFrame
        df = pd.DataFrame(result.data)
        print(f"Retrieved {len(df)} brands")
        return df
        
    except Exception as e:
        print(f"Query failed: {e}")
        return pd.DataFrame()

# Run the example
if __name__ == "__main__":
    brands_df = get_top_brands()
    print(brands_df.head())
`,
    data_analysis: `
# Advanced analytics with Scout and Pandas
import matplotlib.pyplot as plt
import seaborn as sns

def analyze_brand_performance():
    """Comprehensive brand performance analysis"""
    
    # Get brand data
    brands = get_top_brands()
    
    if brands.empty:
        return
    
    # Create visualizations
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    
    # Revenue distribution
    brands['revenue'].hist(bins=20, ax=axes[0,0])
    axes[0,0].set_title('Revenue Distribution')
    
    # Growth rate scatter
    axes[0,1].scatter(brands['revenue'], brands['growth_rate'])
    axes[0,1].set_xlabel('Revenue')
    axes[0,1].set_ylabel('Growth Rate')
    axes[0,1].set_title('Revenue vs Growth Rate')
    
    # Top 10 brands bar chart
    top_10 = brands.head(10)
    axes[1,0].barh(top_10['brand_name'], top_10['revenue'])
    axes[1,0].set_title('Top 10 Brands by Revenue')
    
    # Growth rate histogram
    brands['growth_rate'].hist(bins=15, ax=axes[1,1])
    axes[1,1].set_title('Growth Rate Distribution')
    
    plt.tight_layout()
    plt.show()
    
    return brands

# Run analysis
analyze_brand_performance()
`
  },
  java: {
    basic_query: `
// Scout Java SDK Example
package com.example.scout;

import com.scout.client.ScoutClient;
import com.scout.client.ScoutQuery;
import com.scout.client.ScoutResponse;
import java.util.List;
import java.util.Map;

public class ScoutExample {
    private static final ScoutClient scout = new ScoutClient.Builder()
            .url(System.getenv("SUPABASE_URL"))
            .key(System.getenv("SUPABASE_ANON_KEY"))
            .tenant("your-tenant-id")
            .build();
    
    public static List<Map<String, Object>> getTopBrands() {
        try {
            ScoutResponse response = scout.from("gold_brand_performance")
                    .select("brand_name, revenue, growth_rate")
                    .order("revenue", ScoutQuery.Order.DESC)
                    .limit(10)
                    .execute();
            
            if (response.isSuccess()) {
                System.out.println("Retrieved " + response.getData().size() + " brands");
                return response.getData();
            } else {
                System.err.println("Query failed: " + response.getError());
                return List.of();
            }
        } catch (Exception e) {
            System.err.println("Exception: " + e.getMessage());
            return List.of();
        }
    }
    
    public static void main(String[] args) {
        List<Map<String, Object>> brands = getTopBrands();
        brands.forEach(brand -> 
            System.out.println(brand.get("brand_name") + ": $" + brand.get("revenue"))
        );
    }
}
`,
    spring_integration: `
// Spring Boot integration with Scout
package com.example.scout.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import com.scout.client.ScoutClient;

@Service
public class ScoutService {
    
    private final ScoutClient scout;
    
    public ScoutService(
            @Value("\${scout.url}") String url,
            @Value("\${scout.key}") String key,
            @Value("\${scout.tenant}") String tenant) {
        
        this.scout = new ScoutClient.Builder()
                .url(url)
                .key(key)  
                .tenant(tenant)
                .build();
    }
    
    @Cacheable("brand-performance")
    public List<BrandPerformance> getTopBrands() {
        return scout.from("gold_brand_performance")
                .select("*")
                .order("revenue", ScoutQuery.Order.DESC)
                .limit(10)
                .executeAs(BrandPerformance.class);
    }
}
`
  },
  csharp: {
    basic_query: `
// Scout C# SDK Example
using Scout.Client;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ScoutExample
{
    public class Program
    {
        private static readonly ScoutClient scout = new ScoutClient(
            Environment.GetEnvironmentVariable("SUPABASE_URL"),
            Environment.GetEnvironmentVariable("SUPABASE_ANON_KEY"),
            "your-tenant-id"
        );
        
        public static async Task<List<dynamic>> GetTopBrandsAsync()
        {
            try 
            {
                var response = await scout
                    .From("gold_brand_performance")
                    .Select("brand_name, revenue, growth_rate")
                    .Order("revenue", ascending: false)
                    .Limit(10)
                    .ExecuteAsync();
                
                if (response.Success)
                {
                    Console.WriteLine($"Retrieved {response.Data.Count} brands");
                    return response.Data;
                }
                else
                {
                    Console.WriteLine($"Query failed: {response.Error}");
                    return new List<dynamic>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Exception: {ex.Message}");
                return new List<dynamic>();
            }
        }
        
        public static async Task Main(string[] args)
        {
            var brands = await GetTopBrandsAsync();
            
            foreach (dynamic brand in brands)
            {
                Console.WriteLine($"{brand.brand_name}: ${brand.revenue}");
            }
        }
    }
}
`
  }
};

try {
  // Create learning paths directory structure
  const basePath = './orchestration/lyra/scripts/learning';
  fs.mkdirSync(`${basePath}/tracks`, { recursive: true });
  fs.mkdirSync(`${basePath}/samples`, { recursive: true });
  
  // Write learning tracks configuration
  const tracksPath = `${basePath}/tracks/learning-tracks.json`;
  fs.writeFileSync(tracksPath, JSON.stringify(learningTracks, null, 2));
  console.log(`✅ Learning tracks: ${tracksPath}`);
  
  // Write sample code files
  Object.entries(sampleCodes).forEach(([language, samples]) => {
    const langDir = `${basePath}/samples/${language}`;
    fs.mkdirSync(langDir, { recursive: true });
    
    Object.entries(samples).forEach(([sampleName, code]) => {
      const extension = language === 'csharp' ? 'cs' : 
                      language === 'java' ? 'java' : 
                      language === 'python' ? 'py' : 'js';
      
      const samplePath = `${langDir}/${sampleName}.${extension}`;
      fs.writeFileSync(samplePath, code.trim());
      console.log(`📝 Sample code: ${samplePath}`);
    });
  });
  
  // Create learning path API endpoint
  const learningApiFunction = `
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tenant-id',
};

const learningTracks = ${JSON.stringify(learningTracks, null, 2)};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const role = url.searchParams.get('role');
    const trackId = url.searchParams.get('track');
    
    if (role && learningTracks[role]) {
      if (trackId) {
        // Return specific track
        const track = learningTracks[role].tracks.find(t => t.id === trackId);
        if (!track) {
          throw new Error(\`Track not found: \${trackId}\`);
        }
        
        return new Response(JSON.stringify(track), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      } else {
        // Return role-based learning path
        return new Response(JSON.stringify(learningTracks[role]), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }
    
    // Return all learning paths
    return new Response(JSON.stringify({
      available_roles: Object.keys(learningTracks),
      learning_tracks: learningTracks,
      total_tracks: Object.values(learningTracks).reduce((sum, role) => sum + role.tracks.length, 0)
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return new Response(JSON.stringify({
      error: error.message,
      type: 'learning_path_error'
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
`;
  
  const learningFunctionPath = './supabase/functions/learning-paths/index.ts';
  fs.mkdirSync(path.dirname(learningFunctionPath), { recursive: true });
  fs.writeFileSync(learningFunctionPath, learningApiFunction);
  console.log(`✅ Learning paths API: ${learningFunctionPath}`);
  
  console.log('🎓 Learning Paths and tracks built successfully');
  process.exit(0);
  
} catch (error) {
  console.error('❌ Error building Learning Paths:', error.message);
  process.exit(1);
}