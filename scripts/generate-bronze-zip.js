#!/usr/bin/env node

/**
 * Bronze Layer ZIP File Generator
 * Creates sample ZIP files for ingestion testing
 */

const fs = require('fs').promises;
const path = require('path');
const AdmZip = require('adm-zip');

// Philippines retail data generators
const stores = [
  { id: 1, name: 'SM North EDSA', region: 'NCR', city: 'Quezon City', barangay: 'North Triangle' },
  { id: 2, name: 'Robinsons Ermita', region: 'NCR', city: 'Manila', barangay: 'Ermita' },
  { id: 3, name: 'Ayala Center Cebu', region: 'Central Visayas', city: 'Cebu City', barangay: 'Business Park' },
  { id: 4, name: 'SM Davao', region: 'Davao Region', city: 'Davao City', barangay: 'Quimpo Boulevard' },
  { id: 5, name: 'Gaisano Cagayan', region: 'Northern Mindanao', city: 'Cagayan de Oro', barangay: 'Carmen' }
];

const products = [
  { id: 1, name: 'Lucky Me Pancit Canton', brand: 'Lucky Me', category: 'Noodles', unit: 'pc' },
  { id: 2, name: 'San Miguel Pale Pilsen', brand: 'San Miguel', category: 'Beverages', unit: 'bottle' },
  { id: 3, name: 'Magnolia Fresh Milk 1L', brand: 'Magnolia', category: 'Dairy', unit: 'L' },
  { id: 4, name: 'Century Tuna Flakes', brand: 'Century', category: 'Canned Goods', unit: 'can' },
  { id: 5, name: 'Kopiko 3-in-1 Coffee', brand: 'Kopiko', category: 'Beverages', unit: 'sachet' },
  { id: 6, name: 'Chippy BBQ', brand: 'Jack n Jill', category: 'Snacks', unit: 'pc' },
  { id: 7, name: 'Tide Powder 1kg', brand: 'Tide', category: 'Household', unit: 'kg' },
  { id: 8, name: 'Safeguard Soap', brand: 'Safeguard', category: 'Personal Care', unit: 'pc' },
  { id: 9, name: 'Argentina Corned Beef', brand: 'Argentina', category: 'Canned Goods', unit: 'can' },
  { id: 10, name: 'Datu Puti Vinegar 1L', brand: 'Datu Puti', category: 'Condiments', unit: 'L' }
];

const paymentMethods = ['cash', 'gcash', 'card', 'maya', 'grab_pay'];
const customerTypes = ['walk_in', 'regular', 'member'];

function generateTransactionId(date, storeId, counter) {
  const dateStr = date.toISOString().split('T')[0].replace(/-/g, '');
  return `TXN-${storeId}-${dateStr}-${String(counter).padStart(6, '0')}`;
}

function generateTransactions(date, storeId, count = 100) {
  const transactions = [];
  const startHour = 8; // 8 AM
  const endHour = 22; // 10 PM
  
  for (let i = 0; i < count; i++) {
    const hour = startHour + Math.floor(Math.random() * (endHour - startHour));
    const minute = Math.floor(Math.random() * 60);
    const second = Math.floor(Math.random() * 60);
    
    const txnTime = new Date(date);
    txnTime.setHours(hour, minute, second);
    
    const txnId = generateTransactionId(date, storeId, i);
    const itemCount = Math.floor(Math.random() * 8) + 1; // 1-8 items
    
    // Generate transaction header
    const transaction = {
      txn_id: txnId,
      device_id: `POS-${storeId}-${Math.floor(Math.random() * 3) + 1}`,
      store_id: storeId,
      timestamp: txnTime.toISOString(),
      payment_method: paymentMethods[Math.floor(Math.random() * paymentMethods.length)],
      customer_type: customerTypes[Math.floor(Math.random() * customerTypes.length)],
      items: []
    };
    
    // Generate items
    const selectedProducts = [];
    for (let j = 0; j < itemCount; j++) {
      let product;
      do {
        product = products[Math.floor(Math.random() * products.length)];
      } while (selectedProducts.includes(product.id));
      
      selectedProducts.push(product.id);
      
      const quantity = Math.floor(Math.random() * 5) + 1;
      const unitPrice = 10 + Math.floor(Math.random() * 490); // 10-500 pesos
      const discount = Math.random() > 0.8 ? Math.floor(Math.random() * 50) : 0;
      
      transaction.items.push({
        item_seq: j + 1,
        product_id: product.id,
        product_name: product.name,
        brand_name: product.brand,
        category: product.category,
        unit: product.unit,
        quantity: quantity,
        unit_price: unitPrice,
        discount: discount,
        gross_amount: unitPrice * quantity,
        net_amount: (unitPrice * quantity) - discount
      });
    }
    
    transaction.total_amount = transaction.items.reduce((sum, item) => sum + item.net_amount, 0);
    transaction.total_items = transaction.items.length;
    transaction.total_quantity = transaction.items.reduce((sum, item) => sum + item.quantity, 0);
    
    transactions.push(transaction);
  }
  
  return transactions;
}

async function generateZipFile(date, storeId, transactionCount = 100, outputDir = null) {
  const transactions = generateTransactions(date, storeId, transactionCount);
  const dateStr = date.toISOString().split('T')[0];
  const fileName = `scout-transactions-${storeId}-${dateStr}.json`;
  const zipFileName = `scout-data-${storeId}-${dateStr}.zip`;
  
  // Use provided output directory or default
  const finalOutputDir = outputDir || path.join(__dirname, '../data/bronze-samples');
  await fs.mkdir(finalOutputDir, { recursive: true });
  
  // Write JSON file
  const jsonPath = path.join(finalOutputDir, fileName);
  await fs.writeFile(jsonPath, JSON.stringify(transactions, null, 2));
  
  // Create ZIP file
  const zip = new AdmZip();
  zip.addLocalFile(jsonPath);
  
  const zipPath = path.join(finalOutputDir, zipFileName);
  zip.writeZip(zipPath);
  
  // Clean up JSON file
  await fs.unlink(jsonPath);
  
  console.log(`✅ Generated ${zipPath} with ${transactions.length} transactions`);
  
  return { zipPath, transactionCount: transactions.length };
}

async function generateCSVFormat(date, storeId, transactionCount = 50, outputDir = null) {
  const transactions = generateTransactions(date, storeId, transactionCount);
  const dateStr = date.toISOString().split('T')[0];
  const fileName = `scout-items-${storeId}-${dateStr}.csv`;
  const zipFileName = `scout-csv-${storeId}-${dateStr}.zip`;
  
  // Use provided output directory or default
  const finalOutputDir = outputDir || path.join(__dirname, '../data/bronze-samples');
  await fs.mkdir(finalOutputDir, { recursive: true });
  
  // Create CSV content
  const headers = [
    'txn_id', 'device_id', 'store_id', 'timestamp', 'payment_method',
    'item_seq', 'product_id', 'product_name', 'brand_name', 'category',
    'unit', 'quantity', 'unit_price', 'discount', 'net_amount'
  ];
  
  let csvContent = headers.join(',') + '\n';
  
  for (const txn of transactions) {
    for (const item of txn.items) {
      const row = [
        txn.txn_id,
        txn.device_id,
        txn.store_id,
        txn.timestamp,
        txn.payment_method,
        item.item_seq,
        item.product_id,
        `"${item.product_name}"`,
        item.brand_name,
        item.category,
        item.unit,
        item.quantity,
        item.unit_price,
        item.discount,
        item.net_amount
      ];
      csvContent += row.join(',') + '\n';
    }
  }
  
  // Write CSV file
  const csvPath = path.join(finalOutputDir, fileName);
  await fs.writeFile(csvPath, csvContent);
  
  // Create ZIP file
  const zip = new AdmZip();
  zip.addLocalFile(csvPath);
  
  const zipPath = path.join(finalOutputDir, zipFileName);
  zip.writeZip(zipPath);
  
  // Clean up CSV file
  await fs.unlink(csvPath);
  
  console.log(`✅ Generated ${zipPath} with ${transactions.length} transactions (CSV format)`);
  
  return { zipPath, transactionCount: transactions.length };
}

async function main() {
  console.log('🚀 Scout Analytics Bronze Layer ZIP Generator');
  console.log('==========================================\n');
  
  // Parse command line arguments
  const args = process.argv.slice(2);
  const getArg = (name, defaultValue) => {
    const index = args.indexOf(`--${name}`);
    return index >= 0 && args[index + 1] ? args[index + 1] : defaultValue;
  };
  
  const outputDir = getArg('out', 'data/bronze-samples');
  const numStores = parseInt(getArg('stores', '3'));
  const numDays = parseInt(getArg('days', '12'));
  const rowsPerFile = parseInt(getArg('rows', '100'));
  const seed = getArg('seed', null);
  
  // Set random seed for reproducibility if provided
  if (seed) {
    const seedRandom = require('seedrandom');
    Math.random = seedRandom(seed);
  }
  
  try {
    const startDate = new Date('2025-08-01');
    const endDate = new Date(startDate);
    endDate.setDate(startDate.getDate() + numDays - 1);
    
    console.log(`Configuration:`);
    console.log(`  Output: ${outputDir}`);
    console.log(`  Stores: ${numStores}`);
    console.log(`  Days: ${numDays}`);
    console.log(`  Rows per file: ${rowsPerFile}`);
    console.log(`  Seed: ${seed || 'random'}\n`);
    
    console.log('Generating sample ZIP files for Bronze ingestion...\n');
    
    let totalTransactions = 0;
    const generatedFiles = [];
    
    // Create output directory
    const fullOutputDir = path.isAbsolute(outputDir) ? outputDir : path.join(__dirname, '..', outputDir);
    await fs.mkdir(fullOutputDir, { recursive: true });
    
    // Generate files for each day and store
    for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
      for (const store of stores.slice(0, numStores)) {
        // Generate JSON format
        const jsonResult = await generateZipFile(new Date(d), store.id, rowsPerFile, fullOutputDir);
        totalTransactions += jsonResult.transactionCount;
        generatedFiles.push(jsonResult.zipPath);
        
        // Generate CSV format for some days
        if (d.getDate() % 3 === 0) {
          const csvResult = await generateCSVFormat(new Date(d), store.id, Math.floor(rowsPerFile / 2), fullOutputDir);
          totalTransactions += csvResult.transactionCount;
          generatedFiles.push(csvResult.zipPath);
        }
      }
    }
    
    console.log('\n📊 Generation Summary:');
    console.log(`Total files generated: ${generatedFiles.length}`);
    console.log(`Total transactions: ${totalTransactions}`);
    console.log(`Output directory: ${path.join(__dirname, '../data/bronze-samples')}`);
    
    console.log('\n📤 To upload files to Supabase storage:');
    console.log('1. Go to Supabase Dashboard > Storage');
    console.log('2. Create bucket "scout-ingest" if not exists');
    console.log('3. Upload ZIP files from data/bronze-samples/');
    console.log('4. Files will be automatically processed by ingest-bronze Edge Function');
    
  } catch (error) {
    console.error('❌ Generation failed:', error);
    process.exit(1);
  }
}

// Check if adm-zip is installed
try {
  require('adm-zip');
  main();
} catch (error) {
  console.log('📦 Installing required dependency: adm-zip');
  require('child_process').execSync('npm install adm-zip', { stdio: 'inherit' });
  main();
}