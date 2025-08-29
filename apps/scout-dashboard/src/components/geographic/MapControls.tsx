import React from 'react';
import { useMapbox } from './MapboxProvider';
import { cn } from '@/lib/utils';

interface MapControlsProps {
  className?: string;
  showFullscreen?: boolean;
  showResetView?: boolean;
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
}

interface ZoomControlsProps {
  className?: string;
}

const ZoomControls: React.FC<ZoomControlsProps> = ({ className }) => {
  const { map } = useMapbox();

  const handleZoomIn = () => {
    if (!map) return;
    map.zoomIn({ duration: 300 });
  };

  const handleZoomOut = () => {
    if (!map) return;
    map.zoomOut({ duration: 300 });
  };

  const getCurrentZoom = (): number => {
    return map?.getZoom() || 8;
  };

  return (
    <div className={cn(
      "bg-white rounded-lg shadow-lg border divide-y",
      className
    )}>
      <button
        onClick={handleZoomIn}
        disabled={!map || getCurrentZoom() >= 18}
        className="p-2 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed rounded-t-lg"
        aria-label="Zoom in"
        title="Zoom in"
      >
        <svg 
          className="w-4 h-4 text-gray-700" 
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
        </svg>
      </button>
      <button
        onClick={handleZoomOut}
        disabled={!map || getCurrentZoom() <= 3}
        className="p-2 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed rounded-b-lg"
        aria-label="Zoom out"
        title="Zoom out"
      >
        <svg 
          className="w-4 h-4 text-gray-700" 
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18 12H6" />
        </svg>
      </button>
    </div>
  );
};

interface FullscreenControlProps {
  className?: string;
}

const FullscreenControl: React.FC<FullscreenControlProps> = ({ className }) => {
  const [isFullscreen, setIsFullscreen] = React.useState(false);

  const handleFullscreenToggle = () => {
    if (!document.fullscreenEnabled) return;

    if (isFullscreen) {
      document.exitFullscreen();
    } else {
      const mapContainer = document.querySelector('.mapbox-container') as HTMLElement;
      if (mapContainer) {
        mapContainer.requestFullscreen();
      }
    }
  };

  React.useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };

    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => {
      document.removeEventListener('fullscreenchange', handleFullscreenChange);
    };
  }, []);

  return (
    <button
      onClick={handleFullscreenToggle}
      className={cn(
        "bg-white rounded-lg shadow-lg border p-2 hover:bg-gray-50",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        className
      )}
      disabled={!document.fullscreenEnabled}
      aria-label={isFullscreen ? "Exit fullscreen" : "Enter fullscreen"}
      title={isFullscreen ? "Exit fullscreen" : "Enter fullscreen"}
    >
      <svg 
        className="w-4 h-4 text-gray-700" 
        fill="none" 
        stroke="currentColor" 
        viewBox="0 0 24 24"
      >
        {isFullscreen ? (
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M15 15v4.5M15 15h4.5M15 15l5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M9 15H4.5M9 15v4.5M9 15l-5.25 5.25" />
        ) : (
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
        )}
      </svg>
    </button>
  );
};

interface ResetViewControlProps {
  className?: string;
}

const ResetViewControl: React.FC<ResetViewControlProps> = ({ className }) => {
  const { map, initialCenter, initialZoom } = useMapbox();

  const handleResetView = () => {
    if (!map || !initialCenter) return;
    
    map.flyTo({
      center: initialCenter,
      zoom: initialZoom || 8,
      duration: 1000,
      essential: true
    });
  };

  return (
    <button
      onClick={handleResetView}
      disabled={!map}
      className={cn(
        "bg-white rounded-lg shadow-lg border p-2 hover:bg-gray-50",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        className
      )}
      aria-label="Reset map view"
      title="Reset to initial view"
    >
      <svg 
        className="w-4 h-4 text-gray-700" 
        fill="none" 
        stroke="currentColor" 
        viewBox="0 0 24 24"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
      </svg>
    </button>
  );
};

export const MapControls: React.FC<MapControlsProps> = ({
  className,
  showFullscreen = true,
  showResetView = true,
  position = 'top-right'
}) => {
  const positionClasses = {
    'top-left': 'top-4 left-4',
    'top-right': 'top-4 right-4',
    'bottom-left': 'bottom-4 left-4',
    'bottom-right': 'bottom-4 right-4',
  };

  return (
    <div className={cn(
      "absolute z-10 flex flex-col space-y-2",
      positionClasses[position],
      className
    )}>
      <ZoomControls />
      {showFullscreen && <FullscreenControl />}
      {showResetView && <ResetViewControl />}
    </div>
  );
};

export { ZoomControls, FullscreenControl, ResetViewControl };
export default MapControls;