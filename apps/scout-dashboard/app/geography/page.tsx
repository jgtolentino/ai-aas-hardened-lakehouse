'use client';

import { useFilterStore } from '@/store/useFilters';
import { ChoroplethMap } from '@/components/maps/ChoroplethMap';
import { useGeoSummary } from '@/data/hooks';

export default function GeographyPage() {
  const filters = useFilterStore((state) => state.filters);
  
  const { data: geoData, isLoading } = useGeoSummary(filters);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Geography Analysis</h1>
      
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-12">
          <ChoroplethMap
            title="Revenue by Region"
            data={geoData}
            loading={isLoading}
            aiOverlay={true}
          />
        </div>
      </div>
    </div>
  );
}
