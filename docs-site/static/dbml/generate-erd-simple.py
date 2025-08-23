#!/usr/bin/env python3
"""
Simple ERD generator for Scout v3 DBML
Generates a PlantUML diagram from DBML file
"""

import re
import sys

def parse_dbml(filename):
    """Parse DBML file and extract tables and relationships"""
    with open(filename, 'r') as f:
        content = f.read()
    
    # Extract tables
    tables = {}
    table_pattern = r'Table\s+(\S+)\s*\{([^}]+)\}'
    for match in re.finditer(table_pattern, content, re.DOTALL):
        table_name = match.group(1)
        table_content = match.group(2)
        
        # Extract columns
        columns = []
        column_pattern = r'(\w+)\s+(\w+)(?:\s*\[([^\]]+)\])?'
        for col_match in re.finditer(column_pattern, table_content):
            col_name = col_match.group(1)
            col_type = col_match.group(2)
            col_attrs = col_match.group(3) or ''
            
            is_pk = 'pk' in col_attrs
            is_fk = 'ref:' in col_attrs
            
            columns.append({
                'name': col_name,
                'type': col_type,
                'is_pk': is_pk,
                'is_fk': is_fk
            })
        
        tables[table_name] = columns
    
    # Extract relationships
    relationships = []
    ref_pattern = r'Ref:\s*(\S+)\.(\w+)\s*>\s*(\S+)\.(\w+)'
    for match in re.finditer(ref_pattern, content):
        relationships.append({
            'from_table': match.group(1),
            'from_col': match.group(2),
            'to_table': match.group(3),
            'to_col': match.group(4)
        })
    
    return tables, relationships

def generate_plantuml(tables, relationships, output_file):
    """Generate PlantUML ERD"""
    with open(output_file, 'w') as f:
        f.write("@startuml scout-v3-erd\n")
        f.write("!theme aws-orange\n")
        f.write("skinparam linetype ortho\n")
        f.write("skinparam backgroundColor #FEFEFE\n")
        f.write("skinparam classFontSize 10\n")
        f.write("title Scout Analytics v3.0 - Entity Relationship Diagram\\n\n")
        
        # Group tables by schema
        schemas = {}
        for table_name in tables:
            schema = table_name.split('.')[0] if '.' in table_name else 'default'
            if schema not in schemas:
                schemas[schema] = []
            schemas[schema].append(table_name)
        
        # Generate entities by schema
        for schema, schema_tables in sorted(schemas.items()):
            f.write(f"\npackage {schema} #DDDDDD {{\n")
            
            for table_name in sorted(schema_tables):
                columns = tables[table_name]
                short_name = table_name.split('.')[-1]
                
                f.write(f"  entity {short_name} {{\n")
                
                # Primary keys first
                for col in columns:
                    if col['is_pk']:
                        f.write(f"    * {col['name']} : {col['type']}\n")
                
                f.write("    --\n")
                
                # Then other columns
                for col in columns:
                    if not col['is_pk']:
                        prefix = "+ " if col['is_fk'] else "  "
                        f.write(f"    {prefix}{col['name']} : {col['type']}\n")
                
                f.write("  }\n")
            
            f.write("}\n")
        
        # Generate relationships
        f.write("\n' Relationships\n")
        for rel in relationships:
            from_table = rel['from_table'].split('.')[-1]
            to_table = rel['to_table'].split('.')[-1]
            f.write(f"{from_table} ||--o{{ {to_table} : {rel['from_col']}\n")
        
        f.write("\n@enduml\n")

def generate_summary(tables, output_file):
    """Generate markdown summary"""
    with open(output_file, 'w') as f:
        f.write("# Scout v3 Schema Summary\n\n")
        f.write(f"Total tables: {len(tables)}\n\n")
        
        # Group by schema
        schemas = {}
        for table_name in tables:
            schema = table_name.split('.')[0] if '.' in table_name else 'default'
            if schema not in schemas:
                schemas[schema] = []
            schemas[schema].append(table_name)
        
        f.write("## Tables by Schema\n\n")
        for schema, schema_tables in sorted(schemas.items()):
            f.write(f"### {schema} ({len(schema_tables)} tables)\n\n")
            for table in sorted(schema_tables):
                col_count = len(tables[table])
                f.write(f"- **{table}** ({col_count} columns)\n")
            f.write("\n")

if __name__ == "__main__":
    dbml_file = sys.argv[1] if len(sys.argv) > 1 else "scout-schema-v3.dbml"
    
    print(f"Parsing {dbml_file}...")
    tables, relationships = parse_dbml(dbml_file)
    
    print(f"Found {len(tables)} tables and {len(relationships)} relationships")
    
    # Generate outputs
    generate_plantuml(tables, relationships, "generated/scout-v3-erd.puml")
    print("✓ Generated: generated/scout-v3-erd.puml")
    
    generate_summary(tables, "generated/scout-v3-summary.md")
    print("✓ Generated: generated/scout-v3-summary.md")
    
    print("\nTo generate PNG diagram:")
    print("  plantuml generated/scout-v3-erd.puml")
    print("\nOr upload scout-v3-for-dbdiagram.dbml to https://dbdiagram.io/")