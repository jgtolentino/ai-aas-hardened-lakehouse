'use client';

import { useFilterStore } from '@/store/useFilters';
import { KpiCard } from '@/components/cards/KpiCard';
import { TimeseriesChart } from '@/components/charts/TimeseriesChart';
import { HeatmapChart } from '@/components/charts/HeatmapChart';
import { useScoutKpis, useRevenueTrend, useHourWeekday } from '@/data/hooks';

export default function OverviewPage() {
  const filters = useFilterStore((state) => state.filters);
  
  const { data: kpis, isLoading: kpisLoading } = useScoutKpis(filters);
  const { data: trend, isLoading: trendLoading } = useRevenueTrend(filters);
  const { data: heatmap, isLoading: heatmapLoading } = useHourWeekday(filters);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Overview - Transaction Trends</h1>
      
      {/* KPI Row */}
      <div className="grid grid-cols-12 gap-4 mb-6">
        <div className="col-span-3">
          <KpiCard
            title="Revenue"
            value={kpis?.revenue}
            loading={kpisLoading}
            metric="revenue"
          />
        </div>
        <div className="col-span-3">
          <KpiCard
            title="Transactions"
            value={kpis?.transactions}
            loading={kpisLoading}
            metric="transactions"
          />
        </div>
        <div className="col-span-3">
          <KpiCard
            title="Basket Size"
            value={kpis?.basket_size}
            loading={kpisLoading}
            metric="basket_size"
          />
        </div>
        <div className="col-span-3">
          <KpiCard
            title="Unique Shoppers"
            value={kpis?.unique_shoppers}
            loading={kpisLoading}
            metric="unique_shoppers"
          />
        </div>
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-8">
          <TimeseriesChart
            title="Revenue Trend"
            data={trend}
            loading={trendLoading}
            aiOverlay={true}
          />
        </div>
        <div className="col-span-4">
          <HeatmapChart
            title="Hour × Weekday"
            data={heatmap}
            loading={heatmapLoading}
            aiOverlay={true}
          />
        </div>
      </div>
    </div>
  );
}
