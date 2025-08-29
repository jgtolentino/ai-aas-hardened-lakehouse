'use client';

import { useFilterStore } from '@/store/useFilters';
import { StackedBarChart } from '@/components/charts/StackedBarChart';
import { MatrixChart } from '@/components/charts/MatrixChart';
import { useShareTime, usePositioning } from '@/data/hooks';

export default function CompetitivePage() {
  const filters = useFilterStore((state) => state.filters);
  
  const { data: shareTime, isLoading: shareLoading } = useShareTime(filters);
  const { data: positioning, isLoading: positioningLoading } = usePositioning(filters);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Competitive Analysis</h1>
      
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-7">
          <StackedBarChart
            title="Category Share Over Time"
            data={shareTime}
            loading={shareLoading}
            aiOverlay={true}
          />
        </div>
        <div className="col-span-5">
          <MatrixChart
            title="Positioning (Price × Share)"
            data={positioning}
            loading={positioningLoading}
            aiOverlay={true}
          />
        </div>
      </div>
    </div>
  );
}
