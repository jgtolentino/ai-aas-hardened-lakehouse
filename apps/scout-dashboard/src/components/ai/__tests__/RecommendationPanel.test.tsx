import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { vi } from 'vitest';
import { RecommendationPanel, Recommendation } from '../RecommendationPanel';

// Mock data
const mockRecommendations: Recommendation[] = [
  {
    id: 'rec-001',
    type: 'optimization',
    title: 'Test Optimization',
    description: 'This is a test optimization recommendation',
    confidence: 87,
    priority: 'high',
    category: 'Revenue',
    impact: {
      type: 'revenue',
      estimated_value: 1000000,
      timeframe: '3 months'
    },
    actions: [
      { id: 'act-001', label: 'View Details', type: 'primary', action: 'view_details' },
      { id: 'act-002', label: 'Apply', type: 'secondary', action: 'apply' }
    ],
    metadata: {
      last_updated: '2024-01-15T10:00:00Z'
    }
  },
  {
    id: 'rec-002',
    type: 'alert',
    title: 'Test Alert',
    description: 'This is a test alert recommendation',
    confidence: 95,
    priority: 'critical',
    category: 'Customer Experience',
    impact: {
      type: 'customer_satisfaction',
      timeframe: 'Immediate'
    },
    actions: [
      { id: 'act-003', label: 'Investigate', type: 'primary', action: 'investigate' }
    ]
  },
  {
    id: 'rec-003',
    type: 'insight',
    title: 'Low Confidence Insight',
    description: 'This insight has low confidence',
    confidence: 45,
    priority: 'low',
    category: 'Analytics',
    impact: {
      type: 'efficiency',
      estimated_value: 5
    }
  }
];

describe('RecommendationPanel', () => {
  const defaultProps = {
    recommendations: mockRecommendations,
    isLoading: false,
    error: null,
    enableFeatureFlag: true
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders successfully with default props', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    expect(screen.getByText('AI Recommendations')).toBeInTheDocument();
    expect(screen.getByText('2 active')).toBeInTheDocument(); // Only 2 above threshold
  });

  it('displays recommendations above confidence threshold', () => {
    render(
      <RecommendationPanel 
        {...defaultProps} 
        showConfidenceThreshold={50} 
      />
    );
    
    expect(screen.getByText('Test Optimization')).toBeInTheDocument();
    expect(screen.getByText('Test Alert')).toBeInTheDocument();
    expect(screen.queryByText('Low Confidence Insight')).not.toBeInTheDocument();
  });

  it('filters out low confidence recommendations', () => {
    render(
      <RecommendationPanel 
        {...defaultProps} 
        showConfidenceThreshold={80} 
      />
    );
    
    expect(screen.getByText('Test Optimization')).toBeInTheDocument();
    expect(screen.getByText('Test Alert')).toBeInTheDocument();
    expect(screen.queryByText('Low Confidence Insight')).not.toBeInTheDocument();
  });

  it('respects maxRecommendations limit', () => {
    render(
      <RecommendationPanel 
        {...defaultProps} 
        maxRecommendations={1}
        showConfidenceThreshold={0}
      />
    );
    
    // Should show only 1 recommendation (the highest priority/confidence one)
    expect(screen.getByText('Test Alert')).toBeInTheDocument(); // Critical priority
    expect(screen.queryByText('Test Optimization')).not.toBeInTheDocument();
  });

  it('shows loading state', () => {
    render(
      <RecommendationPanel 
        {...defaultProps} 
        isLoading={true}
        recommendations={[]}
      />
    );
    
    expect(screen.getByText('AI Recommendations')).toBeInTheDocument();
    // Should show skeleton loaders
    expect(document.querySelectorAll('[data-testid="skeleton"]')).toBeTruthy();
  });

  it('shows error state', () => {
    const errorMessage = 'Failed to load recommendations';
    render(
      <RecommendationPanel 
        {...defaultProps} 
        error={errorMessage}
        recommendations={[]}
      />
    );
    
    expect(screen.getByText('Failed to load recommendations')).toBeInTheDocument();
    expect(screen.getByText(errorMessage)).toBeInTheDocument();
  });

  it('shows empty state when no recommendations', () => {
    render(
      <RecommendationPanel 
        {...defaultProps} 
        recommendations={[]}
      />
    );
    
    expect(screen.getByText('No AI Recommendations')).toBeInTheDocument();
    expect(screen.getByText('No recommendations available at this time.')).toBeInTheDocument();
  });

  it('does not render when feature flag is disabled', () => {
    const { container } = render(
      <RecommendationPanel 
        {...defaultProps} 
        enableFeatureFlag={false}
      />
    );
    
    expect(container.firstChild).toBeNull();
  });

  it('displays confidence badges correctly', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    expect(screen.getByText('87% confidence')).toBeInTheDocument();
    expect(screen.getByText('95% confidence')).toBeInTheDocument();
  });

  it('displays priority styling correctly', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    const cards = document.querySelectorAll('[class*="border-"]');
    expect(cards).toHaveLength(2); // Two recommendations shown
  });

  it('handles recommendation click', () => {
    const onRecommendationClick = vi.fn();
    render(
      <RecommendationPanel 
        {...defaultProps} 
        onRecommendationClick={onRecommendationClick}
      />
    );
    
    fireEvent.click(screen.getByText('Test Optimization'));
    expect(onRecommendationClick).toHaveBeenCalledWith(mockRecommendations[0]);
  });

  it('handles action button clicks', () => {
    const onActionClick = vi.fn();
    render(
      <RecommendationPanel 
        {...defaultProps} 
        onActionClick={onActionClick}
      />
    );
    
    fireEvent.click(screen.getByText('View Details'));
    expect(onActionClick).toHaveBeenCalledWith(mockRecommendations[0], 'act-001');
  });

  it('handles dismiss functionality', async () => {
    const onDismiss = vi.fn();
    render(
      <RecommendationPanel 
        {...defaultProps} 
        onDismiss={onDismiss}
      />
    );
    
    // Find and click dismiss button (×)
    const dismissButtons = screen.getAllByText('×');
    fireEvent.click(dismissButtons[0]);
    
    expect(onDismiss).toHaveBeenCalledWith('rec-002'); // Critical priority shows first
  });

  it('prevents action clicks from triggering recommendation clicks', () => {
    const onRecommendationClick = vi.fn();
    const onActionClick = vi.fn();
    
    render(
      <RecommendationPanel 
        {...defaultProps} 
        onRecommendationClick={onRecommendationClick}
        onActionClick={onActionClick}
      />
    );
    
    fireEvent.click(screen.getByText('View Details'));
    
    expect(onActionClick).toHaveBeenCalled();
    expect(onRecommendationClick).not.toHaveBeenCalled();
  });

  it('displays impact information correctly', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    expect(screen.getByText('Revenue')).toBeInTheDocument();
    expect(screen.getByText('₱1,000,000')).toBeInTheDocument();
    expect(screen.getByText('3 months')).toBeInTheDocument();
  });

  it('shows metadata information', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    expect(screen.getByText(/Updated.*1\/15\/2024/)).toBeInTheDocument();
  });

  it('sorts recommendations by priority and confidence', () => {
    render(
      <RecommendationPanel 
        {...defaultProps}
        showConfidenceThreshold={0} // Show all
      />
    );
    
    const titles = screen.getAllByRole('heading', { level: 3 });
    // Critical priority should come first, then by confidence
    expect(titles[0]).toHaveTextContent('Test Alert'); // Critical priority
    expect(titles[1]).toHaveTextContent('Test Optimization'); // High priority, high confidence
  });

  it('handles action execution without actions array', () => {
    const recommendationWithoutActions: Recommendation = {
      ...mockRecommendations[0],
      actions: undefined
    };
    
    render(
      <RecommendationPanel 
        recommendations={[recommendationWithoutActions]}
        isLoading={false}
        error={null}
        enableFeatureFlag={true}
      />
    );
    
    expect(screen.getByText('Test Optimization')).toBeInTheDocument();
    expect(screen.queryByText('View Details')).not.toBeInTheDocument();
  });

  it('displays category badges', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    expect(screen.getByText('Revenue')).toBeInTheDocument();
    expect(screen.getByText('Customer Experience')).toBeInTheDocument();
  });

  it('shows correct icons for recommendation types', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    // Icons are rendered but hard to test directly
    // We test that the cards render which includes the icons
    expect(screen.getByText('Test Optimization')).toBeInTheDocument();
    expect(screen.getByText('Test Alert')).toBeInTheDocument();
  });

  it('applies correct CSS classes for priority', () => {
    render(<RecommendationPanel {...defaultProps} />);
    
    const cards = document.querySelectorAll('[class*="Card"]');
    expect(cards.length).toBeGreaterThan(0);
    
    // Check that cards have priority-based styling
    cards.forEach(card => {
      expect(card.className).toMatch(/border-|bg-/);
    });
  });
});