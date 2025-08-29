'use client';

import { useFilterStore } from '@/store/useFilters';
import { FunnelChart } from '@/components/charts/FunnelChart';
import { DemographicChart } from '@/components/charts/DemographicChart';
import { useRequestToPurchase, useDemographicMix } from '@/data/hooks';

export default function ConsumersPage() {
  const filters = useFilterStore((state) => state.filters);
  
  const { data: funnel, isLoading: funnelLoading } = useRequestToPurchase(filters);
  const { data: demographics, isLoading: demoLoading } = useDemographicMix(filters);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Consumer Analytics</h1>
      
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-6">
          <FunnelChart
            title="Request → Purchase"
            data={funnel}
            loading={funnelLoading}
            aiOverlay={true}
          />
        </div>
        <div className="col-span-6">
          <DemographicChart
            title="Age × Gender Mix"
            data={demographics}
            loading={demoLoading}
            aiOverlay={true}
          />
        </div>
      </div>
    </div>
  );
}
