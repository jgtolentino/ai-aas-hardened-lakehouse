'use client';

import { useFilterStore } from '@/store/useFilters';
import { ParetoChart } from '@/components/charts/ParetoChart';
import { SankeyChart } from '@/components/charts/SankeyChart';
import { useParetoSkus, useSubstitution } from '@/data/hooks';

export default function MixPage() {
  const filters = useFilterStore((state) => state.filters);
  
  const { data: pareto, isLoading: paretoLoading } = useParetoSkus(filters);
  const { data: substitution, isLoading: substitutionLoading } = useSubstitution(filters);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Product Mix & SKUs</h1>
      
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-6">
          <ParetoChart
            title="Top SKUs"
            data={pareto}
            loading={paretoLoading}
            aiOverlay={true}
          />
        </div>
        <div className="col-span-6">
          <SankeyChart
            title="Substitution Flows"
            data={substitution}
            loading={substitutionLoading}
            aiOverlay={true}
          />
        </div>
      </div>
    </div>
  );
}
