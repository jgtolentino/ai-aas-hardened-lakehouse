// Isko SKU Scraper Edge Function
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { action, sources, categories } = await req.json()
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    if (action === 'scrape') {
      const scrapedData = await performScraping(sources, categories)
      
      const { data, error } = await supabase
        .from('bronze_sku_research')
        .insert(scrapedData)
        .select()

      if (error) throw error

      return new Response(
        JSON.stringify({
          success: true,
          message: `Scraped ${scrapedData.length} SKUs`,
          records: data
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Invalid action' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

async function performScraping(sources: string[], categories: string[]) {
  const mockData = []
  
  for (const source of sources) {
    for (const category of categories) {
      mockData.push({
        brand: getBrandForCategory(category),
        sku: generateSKU(category),
        data_source: source,
        raw_json: {
          sku: generateSKU(category),
          brand: getBrandForCategory(category),
          product_name: getProductName(category),
          category: category,
          price: Math.floor(Math.random() * 200) + 10,
          units_7d: Math.floor(Math.random() * 5000) + 100,
          revenue_7d: Math.floor(Math.random() * 100000) + 1000,
          regions: getRandomRegions()
        }
      })
    }
  }
  
  return mockData
}

function getBrandForCategory(category: string): string {
  const brandMap: Record<string, string[]> = {
    'cigarettes': ['Philip Morris', 'JTI', 'BAT'],
    'beverages': ['Coca-Cola', 'Pepsi', 'RC Cola'],
    'snacks': ['Oishi', 'Jack n Jill', 'Piattos'],
    'personal_care': ['Unilever', 'P&G', 'Colgate']
  }
  const brands = brandMap[category] || ['Generic']
  return brands[Math.floor(Math.random() * brands.length)]
}

function generateSKU(category: string): string {
  const prefix = category.substring(0, 3).toUpperCase()
  const random = Math.floor(Math.random() * 10000)
  return `${prefix}_${random}`
}

function getProductName(category: string): string {
  const products: Record<string, string[]> = {
    'cigarettes': ['Red 20s', 'Blue 10s', 'Menthol 20s'],
    'beverages': ['Cola 1.5L', 'Sprite 500ml', 'Water 1L'],
    'snacks': ['Prawn Crackers 60g', 'Potato Chips 100g', 'Corn Chips 80g'],
    'personal_care': ['Shampoo 200ml', 'Soap 135g', 'Toothpaste 150g']
  }
  const items = products[category] || ['Generic Product']
  return items[Math.floor(Math.random() * items.length)]
}

function getRandomRegions(): string[] {
  const allRegions = ['NCR', 'Region I', 'Region II', 'Region III', 'Region IV-A', 
                      'Region IV-B', 'Region V', 'Region VI', 'Region VII']
  const count = Math.floor(Math.random() * 5) + 2
  return allRegions.sort(() => 0.5 - Math.random()).slice(0, count)
}
