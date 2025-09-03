// ============================================================================
// Knowledge Graph Schema for Scout Analytics
// Neo4j/Cypher format for competitive intelligence and agent knowledge
// ============================================================================

// Create constraints and indexes
CREATE CONSTRAINT IF NOT EXISTS FOR (a:Agent) REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (b:Brand) REQUIRE b.name IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (c:Campaign) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (m:Metric) REQUIRE (m.type, m.name) IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (i:Insight) REQUIRE i.id IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (t:Template) REQUIRE t.id IS UNIQUE;

// Vector search indexes for semantic queries
CREATE VECTOR INDEX entity_embeddings FOR (e:Entity) ON (e.embedding)
OPTIONS {indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}};

CREATE VECTOR INDEX insight_embeddings FOR (i:Insight) ON (i.embedding)
OPTIONS {indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}};

// ============================================================================
// AGENT NODES AND RELATIONSHIPS
// ============================================================================

// Agent Performance Node
CREATE (cesai:Agent {
  id: 'CESAI',
  name: 'Creative Effectiveness AI',
  type: 'creative_analyzer',
  status: 'active',
  created_at: datetime(),
  capabilities: ['creative_scoring', 'benchmark_analysis', 'trend_detection'],
  performance_weight: {
    accuracy: 1.2,
    reliability: 1.1,
    efficiency: 1.0,
    taskCompletion: 1.0
  }
});

CREATE (claudia:Agent {
  id: 'Claudia',
  name: 'Orchestration Agent',
  type: 'workflow_orchestrator', 
  status: 'active',
  created_at: datetime(),
  capabilities: ['flow_management', 'task_delegation', 'quality_assurance'],
  performance_weight: {
    taskCompletion: 1.3,
    reliability: 1.2,
    efficiency: 1.0,
    accuracy: 1.0
  }
});

CREATE (echo:Agent {
  id: 'Echo',
  name: 'Data Extraction Agent',
  type: 'data_processor',
  status: 'active',
  created_at: datetime(),
  capabilities: ['data_extraction', 'processing_speed', 'completeness_check'],
  performance_weight: {
    efficiency: 1.2,
    accuracy: 1.1,
    reliability: 1.0,
    taskCompletion: 1.0
  }
});

// ============================================================================
// KNOWLEDGE ENTITIES
// ============================================================================

// Brand Intelligence
CREATE (p_and_g:Brand {
  id: 'pg_global',
  name: 'Procter & Gamble',
  industry: 'FMCG',
  region: 'Global',
  market_position: 'Leader',
  creative_style: ['emotional', 'family_focused', 'premium'],
  embedding: null // Will be populated by vector sync
});

CREATE (unilever:Brand {
  id: 'unilever_global',
  name: 'Unilever',
  industry: 'FMCG', 
  region: 'Global',
  market_position: 'Leader',
  creative_style: ['sustainable', 'purpose_driven', 'inclusive'],
  embedding: null
});

CREATE (nestle:Brand {
  id: 'nestle_global',
  name: 'Nestlé',
  industry: 'Food_Beverage',
  region: 'Global', 
  market_position: 'Leader',
  creative_style: ['nutritional', 'family_wellness', 'heritage'],
  embedding: null
});

// Campaign Templates from Figma Deep Benchmark
CREATE (template_emotional:Template {
  id: 'figma_emotional_appeal',
  name: 'Emotional Appeal Framework',
  type: 'creative_template',
  source: 'figma_deep_benchmark',
  components: ['hero_visual', 'emotional_hook', 'brand_resolution'],
  effectiveness_score: 8.5,
  usage_frequency: 'high',
  embedding: null
});

CREATE (template_problem_solution:Template {
  id: 'figma_problem_solution',
  name: 'Problem-Solution Structure',
  type: 'creative_template', 
  source: 'figma_deep_benchmark',
  components: ['problem_setup', 'product_demonstration', 'resolution_payoff'],
  effectiveness_score: 7.8,
  usage_frequency: 'medium',
  embedding: null
});

// Competitive Intelligence Entities
CREATE (warc_benchmark:Entity {
  id: 'warc_effectiveness_db',
  name: 'WARC Effectiveness Database',
  type: 'benchmark_source',
  data_quality: 'high',
  update_frequency: 'monthly',
  coverage: ['global_campaigns', 'effectiveness_scores', 'category_insights'],
  embedding: null
});

CREATE (cannes_lions:Entity {
  id: 'cannes_lions_archive',
  name: 'Cannes Lions Award Archive', 
  type: 'creative_benchmark',
  data_quality: 'premium',
  update_frequency: 'annual',
  coverage: ['winning_campaigns', 'creative_categories', 'jury_insights'],
  embedding: null
});

// ============================================================================
// PERFORMANCE METRICS AND INSIGHTS
// ============================================================================

// Agent Performance Metrics
CREATE (reliability_metric:Metric {
  type: 'agent_performance',
  name: 'Reliability',
  description: 'Success rate of agent task completion',
  calculation_method: 'successful_tasks / total_tasks * 100',
  threshold_excellent: 95.0,
  threshold_good: 85.0,
  threshold_fair: 70.0
});

CREATE (efficiency_metric:Metric {
  type: 'agent_performance', 
  name: 'Efficiency',
  description: 'Execution time performance relative to baseline',
  calculation_method: 'baseline_time / actual_time * 100',
  threshold_excellent: 120.0,
  threshold_good: 100.0,
  threshold_fair: 80.0
});

CREATE (accuracy_metric:Metric {
  type: 'agent_performance',
  name: 'Accuracy',
  description: 'Quality and correctness of agent outputs',
  calculation_method: 'weighted_accuracy_score',
  threshold_excellent: 90.0,
  threshold_good: 80.0,
  threshold_fair: 70.0
});

// Creative Effectiveness Insights
CREATE (emotional_effectiveness:Insight {
  id: 'emotional_ads_outperform',
  title: 'Emotional Creative Approaches Drive 23% Higher Recall',
  type: 'effectiveness_pattern',
  confidence: 0.92,
  source: 'warc_meta_analysis',
  evidence: 'Analysis of 1,200+ campaigns across FMCG categories',
  actionable_recommendation: 'Prioritize emotional storytelling over rational benefits',
  created_at: datetime(),
  embedding: null
});

CREATE (mobile_optimization:Insight {
  id: 'mobile_first_creative_lift',
  title: 'Mobile-First Creative Design Increases Engagement by 34%',
  type: 'platform_optimization',
  confidence: 0.87,
  source: 'cross_platform_analysis',
  evidence: 'Comparative study of desktop vs mobile-optimized creative',
  actionable_recommendation: 'Design creative assets with mobile-first approach',
  created_at: datetime(),
  embedding: null
});

// ============================================================================
// RELATIONSHIPS AND KNOWLEDGE CONNECTIONS
// ============================================================================

// Agent Specialization Relationships
MATCH (cesai:Agent {id: 'CESAI'}), (emotional_effectiveness:Insight)
CREATE (cesai)-[:SPECIALIZES_IN {strength: 0.95, primary_focus: true}]->(emotional_effectiveness);

MATCH (cesai:Agent {id: 'CESAI'}), (warc_benchmark:Entity)
CREATE (cesai)-[:ANALYZES {frequency: 'daily', depth: 'comprehensive'}]->(warc_benchmark);

MATCH (echo:Agent {id: 'Echo'}), (cannes_lions:Entity)
CREATE (echo)-[:EXTRACTS_FROM {method: 'automated_scraping', reliability: 0.98}]->(cannes_lions);

MATCH (claudia:Agent {id: 'Claudia'}), (cesai:Agent {id: 'CESAI'})
CREATE (claudia)-[:ORCHESTRATES {priority: 1, delegation_weight: 0.8}]->(cesai);

MATCH (claudia:Agent {id: 'Claudia'}), (echo:Agent {id: 'Echo'})
CREATE (claudia)-[:ORCHESTRATES {priority: 2, delegation_weight: 0.7}]->(echo);

// Brand-Template Relationships
MATCH (p_and_g:Brand), (template_emotional:Template)
CREATE (p_and_g)-[:FREQUENTLY_USES {usage_rate: 0.78, effectiveness: 8.2}]->(template_emotional);

MATCH (unilever:Brand), (template_problem_solution:Template)
CREATE (unilever)-[:FREQUENTLY_USES {usage_rate: 0.65, effectiveness: 7.9}]->(template_problem_solution);

// Competitive Intelligence Relationships
MATCH (p_and_g:Brand), (unilever:Brand)
CREATE (p_and_g)-[:COMPETES_WITH {intensity: 'high', overlap_categories: ['personal_care', 'home_care']}]->(unilever);

MATCH (nestle:Brand), (p_and_g:Brand)
CREATE (nestle)-[:COMPETES_WITH {intensity: 'medium', overlap_categories: ['baby_care', 'health_nutrition']}]->(p_and_g);

// Template Effectiveness Relationships
MATCH (template_emotional:Template), (emotional_effectiveness:Insight)
CREATE (template_emotional)-[:SUPPORTS_INSIGHT {evidence_strength: 0.89}]->(emotional_effectiveness);

// Agent Performance Tracking
MATCH (cesai:Agent), (reliability_metric:Metric)
CREATE (cesai)-[:MEASURED_BY {current_score: 94.2, trend: 'improving'}]->(reliability_metric);

MATCH (echo:Agent), (efficiency_metric:Metric)
CREATE (echo)-[:MEASURED_BY {current_score: 112.5, trend: 'stable'}]->(efficiency_metric);

MATCH (claudia:Agent), (accuracy_metric:Metric)
CREATE (claudia)-[:MEASURED_BY {current_score: 87.8, trend: 'improving'}]->(accuracy_metric);

// ============================================================================
// KNOWLEDGE GRAPH QUERIES FOR COMMON USE CASES
// ============================================================================

// Example Query 1: Find agents specialized in specific insight types
// MATCH (a:Agent)-[r:SPECIALIZES_IN]->(i:Insight {type: 'effectiveness_pattern'})
// RETURN a.name, i.title, r.strength
// ORDER BY r.strength DESC;

// Example Query 2: Brand competitive analysis with template overlap
// MATCH (b1:Brand)-[:COMPETES_WITH]-(b2:Brand)
// MATCH (b1)-[u1:FREQUENTLY_USES]->(t:Template)<-[u2:FREQUENTLY_USES]-(b2)
// RETURN b1.name, b2.name, t.name, u1.effectiveness, u2.effectiveness;

// Example Query 3: Agent performance correlation analysis
// MATCH (a:Agent)-[m:MEASURED_BY]->(metric:Metric)
// WHERE metric.name IN ['Reliability', 'Efficiency', 'Accuracy']
// RETURN a.name, 
//        collect({metric: metric.name, score: m.current_score, trend: m.trend}) as performance_profile
// ORDER BY a.name;

// Example Query 4: Vector similarity search for insights (requires embedding population)
// CALL db.index.vector.queryNodes('insight_embeddings', 5, $queryEmbedding)
// YIELD node, score
// MATCH (node:Insight)
// RETURN node.title, node.actionable_recommendation, score
// ORDER BY score DESC;

// ============================================================================
// DATA POPULATION TRIGGERS
// ============================================================================

// Trigger for auto-embedding generation when new insights are added
// CREATE OR REPLACE TRIGGER generate_insight_embedding
// AFTER INSERT ON agentdash.knowledge_entities
// FOR EACH ROW
// WHEN NEW.entity_type = 'insight'
// EXECUTE FUNCTION agentdash.generate_embedding_for_entity();

// ============================================================================
// EXPORT AND MAINTENANCE COMMANDS
// ============================================================================

// Export to GraphML format for visualization tools
// CALL apoc.export.graphml.all("knowledge_graph_export.graphml", {});

// Export specific subgraph for agent performance analysis
// MATCH path = (a:Agent)-[*1..2]-(connected)
// CALL apoc.export.graphml.graph([a] + nodes(path), relationships(path), 
//      "agent_performance_subgraph.graphml", {});

// Periodic maintenance: Update embedding vectors
// MATCH (e:Entity) WHERE e.embedding IS NULL
// CALL agentdash.generate_embeddings(collect(e))
// RETURN count(*) as entities_updated;

// Performance optimization: Create additional indexes as needed
// CREATE INDEX agent_status_idx FOR (a:Agent) ON (a.status);
// CREATE INDEX insight_confidence_idx FOR (i:Insight) ON (i.confidence);
// CREATE INDEX template_effectiveness_idx FOR (t:Template) ON (t.effectiveness_score);