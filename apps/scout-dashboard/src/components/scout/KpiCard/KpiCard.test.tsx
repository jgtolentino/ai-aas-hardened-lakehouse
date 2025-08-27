import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { KpiCard } from './index';

describe('KpiCard', () => {
  describe('Ready State', () => {
    it('renders with all props correctly', () => {
      render(
        <KpiCard
          title="GMV"
          value="₱100K"
          change={12.5}
          changeType="increase"
          state="ready"
        />
      );

      expect(screen.getByText('GMV')).toBeInTheDocument();
      expect(screen.getByText('₱100K')).toBeInTheDocument();
      expect(screen.getByText('12.5%')).toBeInTheDocument();
    });

    it('displays increase indicator correctly', () => {
      render(
        <KpiCard
          title="Revenue"
          value="500"
          change={10}
          changeType="increase"
        />
      );

      const changeElement = screen.getByText('10%');
      expect(changeElement).toHaveClass('text-green-600');
    });

    it('displays decrease indicator correctly', () => {
      render(
        <KpiCard
          title="Returns"
          value="50"
          change={5}
          changeType="decrease"
        />
      );

      const changeElement = screen.getByText('5%');
      expect(changeElement).toHaveClass('text-red-600');
    });

    it('renders with prefix and suffix', () => {
      render(
        <KpiCard
          title="Price"
          value="99.99"
          prefix="$"
          suffix="/mo"
        />
      );

      expect(screen.getByText('$99.99/mo')).toBeInTheDocument();
    });

    it('applies custom className', () => {
      const { container } = render(
        <KpiCard
          title="Test"
          value="100"
          className="custom-class"
        />
      );

      const card = container.querySelector('.custom-class');
      expect(card).toBeInTheDocument();
    });

    it('sets correct aria-label', () => {
      render(
        <KpiCard
          title="Sales"
          value="1000"
          change={15}
          changeType="increase"
          ariaLabel="Sales metric showing 1000 with 15% increase"
        />
      );

      const card = screen.getByLabelText('Sales metric showing 1000 with 15% increase');
      expect(card).toBeInTheDocument();
    });

    it('generates default aria-label when not provided', () => {
      render(
        <KpiCard
          title="Orders"
          value="250"
          prefix="$"
          change={8}
          changeType="decrease"
        />
      );

      const card = screen.getByLabelText('Orders: $250, decrease of 8%');
      expect(card).toBeInTheDocument();
    });
  });

  describe('Loading State', () => {
    it('renders loading skeleton', () => {
      render(
        <KpiCard
          title="GMV"
          value="0"
          state="loading"
        />
      );

      const loadingElement = screen.getByRole('status');
      expect(loadingElement).toHaveClass('animate-pulse');
      expect(loadingElement).toHaveAttribute('aria-label', 'Loading GMV');
    });

    it('does not render value when loading', () => {
      render(
        <KpiCard
          title="Test"
          value="100"
          state="loading"
        />
      );

      expect(screen.queryByText('100')).not.toBeInTheDocument();
    });
  });

  describe('Empty State', () => {
    it('renders empty state message', () => {
      render(
        <KpiCard
          title="Revenue"
          value="0"
          state="empty"
        />
      );

      expect(screen.getByText('--')).toBeInTheDocument();
      expect(screen.getByText('No data available')).toBeInTheDocument();
    });

    it('sets correct aria-label for empty state', () => {
      render(
        <KpiCard
          title="Sales"
          value="0"
          state="empty"
        />
      );

      const card = screen.getByLabelText('Sales: No data available');
      expect(card).toBeInTheDocument();
    });
  });

  describe('Error State', () => {
    it('renders error state with default message', () => {
      render(
        <KpiCard
          title="Orders"
          value="0"
          state="error"
        />
      );

      expect(screen.getByRole('alert')).toBeInTheDocument();
      expect(screen.getByText('Failed to load data')).toBeInTheDocument();
    });

    it('renders custom error message', () => {
      render(
        <KpiCard
          title="Metrics"
          value="0"
          state="error"
          errorMessage="Connection timeout. Please retry."
        />
      );

      expect(screen.getByText('Connection timeout. Please retry.')).toBeInTheDocument();
    });

    it('sets correct aria-label for error state', () => {
      render(
        <KpiCard
          title="Revenue"
          value="0"
          state="error"
        />
      );

      const alert = screen.getByRole('alert');
      expect(alert).toHaveAttribute('aria-label', 'Error loading Revenue');
    });
  });

  describe('Icons', () => {
    it('renders GMV icon', () => {
      const { container } = render(
        <KpiCard
          title="GMV"
          value="100"
          icon="gmv"
        />
      );

      const icon = container.querySelector('svg');
      expect(icon).toBeInTheDocument();
    });

    it('renders custom icon component', () => {
      const CustomIcon = () => <div data-testid="custom-icon">📊</div>;
      
      render(
        <KpiCard
          title="Custom"
          value="100"
          icon={CustomIcon}
        />
      );

      expect(screen.getByTestId('custom-icon')).toBeInTheDocument();
    });

    it('renders without icon when not provided', () => {
      const { container } = render(
        <KpiCard
          title="No Icon"
          value="100"
        />
      );

      const icon = container.querySelector('svg');
      expect(icon).not.toBeInTheDocument();
    });
  });

  describe('Accessibility', () => {
    it('has proper heading hierarchy', () => {
      render(
        <KpiCard
          title="Accessibility Test"
          value="100"
        />
      );

      const heading = screen.getByRole('heading', { level: 3 });
      expect(heading).toHaveTextContent('Accessibility Test');
    });

    it('provides meaningful status for screen readers', () => {
      render(
        <KpiCard
          title="Revenue"
          value="1.5M"
          prefix="$"
          change={25}
          changeType="increase"
        />
      );

      const card = screen.getByLabelText('Revenue: $1.5M, increase of 25%');
      expect(card).toBeInTheDocument();
    });

    it('marks error state as alert for assistive technology', () => {
      render(
        <KpiCard
          title="Failed Metric"
          value="0"
          state="error"
        />
      );

      const alert = screen.getByRole('alert');
      expect(alert).toBeInTheDocument();
    });

    it('marks loading state as status for assistive technology', () => {
      render(
        <KpiCard
          title="Loading Metric"
          value="0"
          state="loading"
        />
      );

      const status = screen.getByRole('status');
      expect(status).toBeInTheDocument();
    });
  });
});
