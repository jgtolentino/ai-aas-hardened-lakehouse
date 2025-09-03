#!/usr/bin/env python3
"""Convert DBML to Mermaid ERD format"""

import re
import sys
from pathlib import Path

def parse_dbml_to_mermaid(dbml_content):
    """Convert DBML content to Mermaid ERD format"""
    
    # Extract tables with their columns
    tables = {}
    current_table = None
    
    lines = dbml_content.split('\n')
    for line in lines:
        line = line.strip()
        
        # Table definition
        table_match = re.match(r'Table\s+([\w_.]+)\s*{', line)
        if table_match:
            table_name = table_match.group(1)
            current_table = table_name
            tables[current_table] = {
                'columns': [],
                'keys': [],
                'relationships': []
            }
            continue
        
        # Column definition within table
        if current_table and line and not line.startswith('//') and not line.startswith('Note:'):
            # Parse column line: column_name type [constraints]
            column_match = re.match(r'(\w+)\s+(\w+)(?:\[([^\]]+)\])?', line)
            if column_match:
                col_name = column_match.group(1)
                col_type = column_match.group(2)
                constraints = column_match.group(3) or ''
                
                # Determine key type
                key_type = ''
                if 'pk' in constraints:
                    key_type = 'PK'
                elif 'unique' in constraints:
                    key_type = 'UK'
                elif 'ref:' in constraints:
                    key_type = 'FK'
                
                tables[current_table]['columns'].append({
                    'name': col_name,
                    'type': col_type,
                    'key': key_type
                })
        
        # End of table
        if current_table and line == '}':
            current_table = None
    
    # Generate Mermaid ERD
    mermaid_content = ["erDiagram"]
    
    # Add tables with columns
    for table_name, table_data in tables.items():
        # Clean table name for Mermaid (remove schema prefixes for readability)
        clean_name = table_name.split('.')[-1]
        mermaid_content.append(f"    {clean_name} {{")
        
        for col in table_data['columns']:
            key_suffix = f" {col['key']}" if col['key'] else ""
            mermaid_content.append(f"        {col['type']} {col['name']}{key_suffix}")
        
        mermaid_content.append("    }")
    
    # Add relationships (simplified - extract from ref: constraints)
    relationship_pattern = r'(\w+)\s+\w+\s*\[ref:\s*([><=]+)\s*([\w_.]+)\.(\w+)\]'
    for line in lines:
        match = re.search(relationship_pattern, line)
        if match:
            # This is a basic implementation - real relationships would need more parsing
            pass
    
    return '\n'.join(mermaid_content)

def generate_layer_specific_erds(dbml_content):
    """Generate separate ERDs for each medallion layer"""
    
    layers = {
        'bronze': ['scout_bronze'],
        'silver': ['scout_silver'],
        'gold': ['scout_gold'],
        'platinum': ['scout_platinum'],
        'governance': ['scout']
    }
    
    layer_erds = {}
    
    for layer_name, schemas in layers.items():
        # Filter tables for this layer
        layer_tables = {}
        current_table = None
        
        lines = dbml_content.split('\n')
        for line in lines:
            line = line.strip()
            
            table_match = re.match(r'Table\s+([\w_.]+)\s*{', line)
            if table_match:
                table_name = table_match.group(1)
                schema = table_name.split('.')[0] if '.' in table_name else 'scout'
                
                if schema in schemas:
                    current_table = table_name
                    layer_tables[current_table] = []
                else:
                    current_table = None
                continue
            
            if current_table and line and not line.startswith('//'):
                layer_tables[current_table].append(line)
            
            if current_table and line == '}':
                current_table = None
        
        # Generate Mermaid for this layer
        if layer_tables:
            mermaid_lines = [f"erDiagram"]
            mermaid_lines.append(f"    %% {layer_name.upper()} LAYER - Scout Analytics Platform")
            
            for table_name, columns in layer_tables.items():
                clean_name = table_name.split('.')[-1]
                mermaid_lines.append(f"    {clean_name} {{")
                
                for col_line in columns:
                    if col_line.strip() and not col_line.strip().startswith('Note:'):
                        # Basic column parsing
                        col_match = re.match(r'(\w+)\s+(\w+)', col_line.strip())
                        if col_match:
                            col_name = col_match.group(1)
                            col_type = col_match.group(2)
                            mermaid_lines.append(f"        {col_type} {col_name}")
                
                mermaid_lines.append("    }")
            
            layer_erds[layer_name] = '\n'.join(mermaid_lines)
    
    return layer_erds

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python convert_dbml_to_mermaid.py <dbml_file>")
        sys.exit(1)
    
    dbml_file = Path(sys.argv[1])
    if not dbml_file.exists():
        print(f"Error: DBML file {dbml_file} not found")
        sys.exit(1)
    
    # Read DBML content
    dbml_content = dbml_file.read_text()
    
    # Generate complete ERD
    complete_erd = parse_dbml_to_mermaid(dbml_content)
    
    # Write complete ERD
    output_dir = dbml_file.parent / "erd" / "mermaid"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    (output_dir / "complete-erd.mmd").write_text(complete_erd)
    print(f"✅ Complete ERD generated: {output_dir}/complete-erd.mmd")
    
    # Generate layer-specific ERDs
    layer_erds = generate_layer_specific_erds(dbml_content)
    
    for layer_name, erd_content in layer_erds.items():
        layer_file = output_dir / f"{layer_name}-layer.mmd"
        layer_file.write_text(erd_content)
        print(f"✅ {layer_name.capitalize()} layer ERD: {layer_file}")
    
    print(f"🎯 All Mermaid ERDs generated in: {output_dir}")
