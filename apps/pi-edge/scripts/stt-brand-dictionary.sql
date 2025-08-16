-- Scout Edge: STT Brand Dictionary Table
-- This creates the table structure expected by the brand universe views

create schema if not exists scout;

-- STT Brand Dictionary with variants
create table if not exists scout.stt_brand_dictionary (
  id serial primary key,
  brand text not null,
  variant text,
  category text,
  confidence numeric default 0.90,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Indexes for performance
create index if not exists idx_stt_brand on scout.stt_brand_dictionary(brand);
create index if not exists idx_stt_variant on scout.stt_brand_dictionary(variant);

-- Sample STT dictionary entries (337 variants as mentioned)
insert into scout.stt_brand_dictionary (brand, variant, category) values
-- Beverages
('COCA COLA', 'coke', 'Beverages'),
('COCA COLA', 'koka', 'Beverages'),
('COCA COLA', 'coca', 'Beverages'),
('COCA COLA', 'softdrinks', 'Beverages'),
('PEPSI', 'pepsi', 'Beverages'),
('PEPSI', 'peps', 'Beverages'),
('SPRITE', 'sprite', 'Beverages'),
('SPRITE', 'sprayts', 'Beverages'),
('ROYAL', 'royal', 'Beverages'),
('ROYAL', 'royal tru', 'Beverages'),
('MOUNTAIN DEW', 'mountain dew', 'Beverages'),
('MOUNTAIN DEW', 'dew', 'Beverages'),
('SARSI', 'sarsi', 'Beverages'),
('SARSI', 'sars', 'Beverages'),
('MIRINDA', 'mirinda', 'Beverages'),
('MIRINDA', 'miranda', 'Beverages'),
('7UP', 'seven up', 'Beverages'),
('7UP', '7 up', 'Beverages'),
('RC COLA', 'rc', 'Beverages'),
('RC COLA', 'rc cola', 'Beverages'),

-- Coffee
('NESCAFE', 'nescafe', 'Beverages'),
('NESCAFE', 'kape', 'Beverages'),
('NESCAFE', 'neskape', 'Beverages'),
('KOPIKO', 'kopiko', 'Beverages'),
('KOPIKO', 'kopiks', 'Beverages'),
('GREAT TASTE', 'great taste', 'Beverages'),
('GREAT TASTE', 'gt', 'Beverages'),
('GREAT TASTE', 'grate test', 'Beverages'),

-- Beer/Alcohol
('SAN MIGUEL', 'san mig', 'Beverages'),
('SAN MIGUEL', 'pale', 'Beverages'),
('SAN MIGUEL', 'san miguel', 'Beverages'),
('RED HORSE', 'red horse', 'Beverages'),
('RED HORSE', 'kabayo', 'Beverages'),
('RED HORSE', 'red', 'Beverages'),
('TANDUAY', 'tanduay', 'Beverages'),
('TANDUAY', 'rhum', 'Beverages'),
('EMPERADOR', 'empe', 'Beverages'),
('EMPERADOR', 'emperador', 'Beverages'),
('EMPERADOR', 'brandy', 'Beverages'),
('GINEBRA', 'gin', 'Beverages'),
('GINEBRA', 'ginebra', 'Beverages'),
('GINEBRA', 'bilog', 'Beverages'),

-- Cigarettes
('MARLBORO', 'marlboro', 'Tobacco'),
('MARLBORO', 'boro', 'Tobacco'),
('MARLBORO', 'red', 'Tobacco'),
('MARLBORO', 'yosi', 'Tobacco'),
('PHILIP MORRIS', 'philip', 'Tobacco'),
('PHILIP MORRIS', 'morris', 'Tobacco'),
('FORTUNE', 'fortune', 'Tobacco'),
('FORTUNE', 'portune', 'Tobacco'),
('HOPE', 'hope', 'Tobacco'),
('MORE', 'more', 'Tobacco'),
('MIGHTY', 'mighty', 'Tobacco'),
('MIGHTY', 'maytee', 'Tobacco'),
('WINSTON', 'winston', 'Tobacco'),
('WINSTON', 'wins', 'Tobacco'),

-- Instant Noodles
('LUCKY ME', 'lucky me', 'Instant Noodles'),
('LUCKY ME', 'lucky', 'Instant Noodles'),
('LUCKY ME', 'pancit canton', 'Instant Noodles'),
('LUCKY ME', 'canton', 'Instant Noodles'),
('NISSIN', 'nissin', 'Instant Noodles'),
('NISSIN', 'cup noodles', 'Instant Noodles'),
('NISSIN', 'yakisoba', 'Instant Noodles'),
('PAYLESS', 'payless', 'Instant Noodles'),
('PAYLESS', 'peyless', 'Instant Noodles'),
('QUICKCHOW', 'quickchow', 'Instant Noodles'),
('QUICKCHOW', 'kwik', 'Instant Noodles'),

-- Snacks
('JACK N JILL', 'jack n jill', 'Snacks'),
('JACK N JILL', 'jack', 'Snacks'),
('OISHI', 'oishi', 'Snacks'),
('OISHI', 'oyshe', 'Snacks'),
('PIATTOS', 'piattos', 'Snacks'),
('PIATTOS', 'pyatos', 'Snacks'),
('NOVA', 'nova', 'Snacks'),
('NOVA', 'noba', 'Snacks'),
('CHIPPY', 'chippy', 'Snacks'),
('CHIPPY', 'chipi', 'Snacks'),
('TORTILLOS', 'tortillos', 'Snacks'),
('TORTILLOS', 'tortilyos', 'Snacks'),
('SKYFLAKES', 'skyflakes', 'Snacks'),
('SKYFLAKES', 'sky', 'Snacks'),
('FITA', 'fita', 'Snacks'),
('REBISCO', 'rebisco', 'Snacks'),
('REBISCO', 'bisko', 'Snacks'),

-- Personal Care
('SAFEGUARD', 'safeguard', 'Personal Care'),
('SAFEGUARD', 'gard', 'Personal Care'),
('SAFEGUARD', 'sabon', 'Personal Care'),
('PALMOLIVE', 'palmolive', 'Personal Care'),
('PALMOLIVE', 'palm', 'Personal Care'),
('DOVE', 'dove', 'Personal Care'),
('DOVE', 'dov', 'Personal Care'),
('IRISH SPRING', 'irish', 'Personal Care'),
('IRISH SPRING', 'irish spring', 'Personal Care'),
('COLGATE', 'colgate', 'Personal Care'),
('COLGATE', 'toothpaste', 'Personal Care'),
('CLOSE UP', 'close up', 'Personal Care'),
('CLOSE UP', 'closeup', 'Personal Care'),
('HEAD SHOULDERS', 'head and shoulders', 'Personal Care'),
('HEAD SHOULDERS', 'h and s', 'Personal Care'),
('HEAD SHOULDERS', 'shampoo', 'Personal Care'),
('REJOICE', 'rejoice', 'Personal Care'),
('REJOICE', 'rejoys', 'Personal Care'),
('SUNSILK', 'sunsilk', 'Personal Care'),
('SUNSILK', 'silk', 'Personal Care'),
('CLEAR', 'clear', 'Personal Care'),
('CREAM SILK', 'cream silk', 'Personal Care'),
('CREAM SILK', 'creamsilk', 'Personal Care'),

-- Household
('TIDE', 'tide', 'Household'),
('TIDE', 'tayd', 'Household'),
('ARIEL', 'ariel', 'Household'),
('ARIEL', 'aryel', 'Household'),
('DOWNY', 'downy', 'Household'),
('DOWNY', 'dawny', 'Household'),
('SURF', 'surf', 'Household'),
('SURF', 'serf', 'Household'),
('BREEZE', 'breeze', 'Household'),
('BREEZE', 'briz', 'Household'),
('CHAMPION', 'champion', 'Household'),
('CHAMPION', 'champ', 'Household'),
('AJAX', 'ajax', 'Household'),
('AJAX', 'ahaks', 'Household'),
('ZONROX', 'zonrox', 'Household'),
('ZONROX', 'bleach', 'Household'),
('JOY', 'joy', 'Household'),
('JOY', 'dishwashing', 'Household'),
('SMART', 'smart', 'Household'),

-- Baby Care
('PAMPERS', 'pampers', 'Baby Care'),
('PAMPERS', 'pamper', 'Baby Care'),
('PAMPERS', 'diaper', 'Baby Care'),
('HUGGIES', 'huggies', 'Baby Care'),
('HUGGIES', 'hugis', 'Baby Care'),
('EQ', 'eq', 'Baby Care'),
('EQ', 'eq diaper', 'Baby Care'),
('JOHNSONS', 'johnsons', 'Baby Care'),
('JOHNSONS', 'johnson', 'Baby Care'),

-- Medicine
('BIOGESIC', 'biogesic', 'Medicine'),
('BIOGESIC', 'bio', 'Medicine'),
('PARACETAMOL', 'paracetamol', 'Medicine'),
('PARACETAMOL', 'para', 'Medicine'),
('NEOZEP', 'neozep', 'Medicine'),
('NEOZEP', 'neo', 'Medicine'),
('BIOFLU', 'bioflu', 'Medicine'),
('BIOFLU', 'flu', 'Medicine'),
('ALAXAN', 'alaxan', 'Medicine'),
('ALAXAN', 'alaksan', 'Medicine'),
('MEDICOL', 'medicol', 'Medicine'),
('MEDICOL', 'medikol', 'Medicine'),
('TEMPRA', 'tempra', 'Medicine'),
('SOLMUX', 'solmux', 'Medicine'),
('SOLMUX', 'sol', 'Medicine'),
('ROBITUSSIN', 'robitussin', 'Medicine'),
('ROBITUSSIN', 'ubo', 'Medicine'),

-- Dairy
('BEAR BRAND', 'bear brand', 'Dairy'),
('BEAR BRAND', 'bear', 'Dairy'),
('BEAR BRAND', 'gatas', 'Dairy'),
('ALASKA', 'alaska', 'Dairy'),
('ALASKA', 'evap', 'Dairy'),
('NESTLE', 'nestle', 'Dairy'),
('NESTLE', 'nestley', 'Dairy'),
('BIRCH TREE', 'birch tree', 'Dairy'),
('BIRCH TREE', 'birch', 'Dairy'),
('MAGNOLIA', 'magnolia', 'Dairy'),
('MAGNOLIA', 'fresh milk', 'Dairy'),

-- Telecom
('SMART', 'smart', 'Telecom'),
('SMART', 'load', 'Telecom'),
('GLOBE', 'globe', 'Telecom'),
('GLOBE', 'glowb', 'Telecom'),
('SUN', 'sun', 'Telecom'),
('SUN', 'sun cellular', 'Telecom'),
('TNT', 'tnt', 'Telecom'),
('TNT', 'ka tropa', 'Telecom'),
('TM', 'tm', 'Telecom'),
('TM', 'touch mobile', 'Telecom'),

-- Common misspellings and local terms
('ICE', 'yelo', 'Ice'),
('ICE', 'ice', 'Ice'),
('WATER', 'tubig', 'Beverages'),
('WATER', 'water', 'Beverages'),
('CANDY', 'kendi', 'Snacks'),
('CANDY', 'candy', 'Snacks'),
('BREAD', 'tinapay', 'Food'),
('BREAD', 'pan', 'Food'),
('EGGS', 'itlog', 'Food'),
('RICE', 'bigas', 'Food'),
('RICE', 'kanin', 'Food'),
('SUGAR', 'asukal', 'Food'),
('SALT', 'asin', 'Food'),
('OIL', 'mantika', 'Food'),
('VINEGAR', 'suka', 'Food'),
('SOY SAUCE', 'toyo', 'Food'),
('FISH SAUCE', 'patis', 'Food')
on conflict do nothing;

-- Add unique constraint to prevent duplicates
create unique index if not exists idx_stt_brand_variant_unique 
on scout.stt_brand_dictionary(brand, variant) 
where variant is not null;