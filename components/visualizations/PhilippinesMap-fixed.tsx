import React from 'react';
import * as topojson from 'topojson-client';
import { philippinesTopology } from '@/data/philippines-topology';
import { philippinesRegionData } from '@/data/philippines-regions';

interface PhilippinesMapProps {
  width?: number;
  height?: number;
  data?: any[];
}

export const PhilippinesMap: React.FC<PhilippinesMapProps> = ({ 
  width = 800, 
  height = 600,
  data = philippinesRegionData 
}) => {
  // Ensure topology is loaded
  if (!philippinesTopology || !philippinesTopology.objects) {
    return (
      <div className="flex items-center justify-center" style={{ width, height }}>
        <p className="text-gray-500">Loading map data...</p>
      </div>
    );
  }

  // Get the correct object key from topology
  const objectKey = Object.keys(philippinesTopology.objects)[0];
  if (!objectKey) {
    return (
      <div className="flex items-center justify-center" style={{ width, height }}>
        <p className="text-red-500">Map topology data is invalid</p>
      </div>
    );
  }

  try {
    // Convert topology to features
    const philippines = topojson.feature(
      philippinesTopology, 
      philippinesTopology.objects[objectKey]
    ) as any;

    // Create value scale for coloring based on GDP
    const maxValue = data && data.length > 0 
      ? Math.max(...data.map(d => d.gdp || 0))
      : 1000000;

    // Rest of your component code...
    return (
      <svg width={width} height={height}>
        {/* Your SVG content */}
        <g>
          {philippines.features.map((feature: any, index: number) => {
            const regionData = data.find(d => d.region === feature.properties.name);
            const value = regionData?.gdp || 0;
            const fillOpacity = value / maxValue;
            
            return (
              <path
                key={index}
                d={/* path data */}
                fill="#4F46E5"
                fillOpacity={fillOpacity}
                stroke="#E5E7EB"
                strokeWidth={1}
              />
            );
          })}
        </g>
      </svg>
    );
  } catch (error) {
    console.error('Error rendering map:', error);
    return (
      <div className="flex items-center justify-center" style={{ width, height }}>
        <p className="text-red-500">Error rendering map</p>
      </div>
    );
  }
};

export default PhilippinesMap;