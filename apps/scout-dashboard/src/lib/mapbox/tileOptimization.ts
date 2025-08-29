import mapboxgl from 'mapbox-gl';

/**
 * Tile optimization utilities for improved map performance
 */

export interface TileOptimizationConfig {
  maxZoom?: number;
  minZoom?: number;
  tileSize?: 256 | 512;
  retina?: boolean;
  preload?: number;
  maxTileCache?: number;
  renderWorldCopies?: boolean;
  optimizeForMobile?: boolean;
}

export interface TileLoadingState {
  loading: boolean;
  progress: number;
  errors: string[];
  tilesLoaded: number;
  totalTiles: number;
}

export class TileOptimizer {
  private map: mapboxgl.Map;
  private config: Required<TileOptimizationConfig>;
  private loadingState: TileLoadingState = {
    loading: false,
    progress: 0,
    errors: [],
    tilesLoaded: 0,
    totalTiles: 0,
  };
  private loadingListeners: ((state: TileLoadingState) => void)[] = [];

  constructor(map: mapboxgl.Map, config: TileOptimizationConfig = {}) {
    this.map = map;
    this.config = {
      maxZoom: config.maxZoom ?? 18,
      minZoom: config.minZoom ?? 5,
      tileSize: config.tileSize ?? 512,
      retina: config.retina ?? window.devicePixelRatio > 1,
      preload: config.preload ?? 1,
      maxTileCache: config.maxTileCache ?? 50,
      renderWorldCopies: config.renderWorldCopies ?? false,
      optimizeForMobile: config.optimizeForMobile ?? this.isMobileDevice(),
    };

    this.initializeOptimizations();
    this.setupTileLoadingMonitoring();
  }

  private isMobileDevice(): boolean {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    ) || window.innerWidth < 768;
  }

  private initializeOptimizations(): void {
    // Configure map for optimal tile loading
    this.map.setMaxZoom(this.config.maxZoom);
    this.map.setMinZoom(this.config.minZoom);
    this.map.setRenderWorldCopies(this.config.renderWorldCopies);

    // Set tile cache size
    if (this.map._controls) {
      // Access internal tile cache settings if available
      const canvas = this.map.getCanvas();
      if (canvas) {
        canvas.style.imageRendering = this.config.optimizeForMobile 
          ? 'pixelated' 
          : 'auto';
      }
    }

    // Preload nearby tiles
    this.setupTilePreloading();

    // Mobile optimizations
    if (this.config.optimizeForMobile) {
      this.applyMobileOptimizations();
    }

    // Retina display optimizations
    if (this.config.retina) {
      this.applyRetinaOptimizations();
    }
  }

  private setupTileLoadingMonitoring(): void {
    let pendingTiles = new Set<string>();

    // Monitor tile loading start
    this.map.on('dataloading', (e) => {
      if (e.dataType === 'source' && e.sourceDataType === 'content') {
        this.loadingState.loading = true;
        this.loadingState.errors = [];
        pendingTiles.add(e.sourceId);
        this.updateLoadingProgress();
      }
    });

    // Monitor tile loading completion
    this.map.on('data', (e) => {
      if (e.dataType === 'source' && e.sourceDataType === 'content') {
        pendingTiles.delete(e.sourceId);
        this.loadingState.tilesLoaded++;
        
        if (pendingTiles.size === 0) {
          this.loadingState.loading = false;
          this.loadingState.progress = 100;
        }
        
        this.updateLoadingProgress();
      }
    });

    // Monitor tile loading errors
    this.map.on('error', (e) => {
      this.loadingState.errors.push(e.error?.message || 'Unknown tile loading error');
      this.updateLoadingProgress();
    });

    // Monitor source data loading
    this.map.on('sourcedata', (e) => {
      if (e.dataType === 'metadata') {
        this.loadingState.totalTiles = this.estimateTileCount();
        this.updateLoadingProgress();
      }
    });
  }

  private updateLoadingProgress(): void {
    if (this.loadingState.totalTiles > 0) {
      this.loadingState.progress = Math.min(
        100,
        (this.loadingState.tilesLoaded / this.loadingState.totalTiles) * 100
      );
    }

    this.loadingListeners.forEach(listener => {
      listener({ ...this.loadingState });
    });
  }

  private estimateTileCount(): number {
    const bounds = this.map.getBounds();
    const zoom = this.map.getZoom();
    
    // Rough estimation based on visible area and zoom level
    const latDiff = bounds.getNorth() - bounds.getSouth();
    const lngDiff = bounds.getEast() - bounds.getWest();
    const tileSize = this.config.tileSize;
    
    const tilesX = Math.ceil((lngDiff * Math.pow(2, zoom) * tileSize) / 360);
    const tilesY = Math.ceil((latDiff * Math.pow(2, zoom) * tileSize) / 180);
    
    return Math.max(1, tilesX * tilesY);
  }

  private setupTilePreloading(): void {
    const preloadTiles = () => {
      const center = this.map.getCenter();
      const zoom = this.map.getZoom();
      const bearing = this.map.getBearing();
      const pitch = this.map.getPitch();

      // Preload tiles in the direction of movement
      const preloadDistance = 0.01 * this.config.preload;
      const preloadBounds = new mapboxgl.LngLatBounds()
        .extend([center.lng - preloadDistance, center.lat - preloadDistance])
        .extend([center.lng + preloadDistance, center.lat + preloadDistance]);

      // This would ideally trigger preloading, but Mapbox doesn't expose
      // direct tile preloading API. We simulate by briefly setting bounds.
      // In practice, this optimization happens automatically in Mapbox GL JS.
    };

    // Preload on move end
    this.map.on('moveend', preloadTiles);
  }

  private applyMobileOptimizations(): void {
    // Reduce precision for mobile devices
    this.map.setPadding({ top: 0, bottom: 0, left: 0, right: 0 });
    
    // Optimize rendering for mobile
    const canvas = this.map.getCanvas();
    if (canvas) {
      canvas.style.touchAction = 'pan-x pan-y';
    }

    // Reduce animation duration for better performance
    this.map.easeTo = (options) => {
      return mapboxgl.Map.prototype.easeTo.call(this.map, {
        ...options,
        duration: Math.min(options?.duration || 1000, 300),
      });
    };
  }

  private applyRetinaOptimizations(): void {
    // Configure for high DPI displays
    const canvas = this.map.getCanvas();
    if (canvas) {
      canvas.style.imageRendering = 'auto';
    }

    // Use higher resolution tiles if available
    this.map.on('style.load', () => {
      const style = this.map.getStyle();
      if (style.sources) {
        Object.keys(style.sources).forEach(sourceId => {
          const source = style.sources[sourceId];
          if (source.type === 'raster' && source.tileSize) {
            source.tileSize = this.config.tileSize;
          }
        });
      }
    });
  }

  /**
   * Add a listener for tile loading state changes
   */
  onLoadingStateChange(listener: (state: TileLoadingState) => void): void {
    this.loadingListeners.push(listener);
  }

  /**
   * Remove a tile loading state listener
   */
  removeLoadingStateListener(listener: (state: TileLoadingState) => void): void {
    const index = this.loadingListeners.indexOf(listener);
    if (index > -1) {
      this.loadingListeners.splice(index, 1);
    }
  }

  /**
   * Get current tile loading state
   */
  getLoadingState(): TileLoadingState {
    return { ...this.loadingState };
  }

  /**
   * Optimize map style for faster loading
   */
  optimizeMapStyle(styleUrl: string): string {
    if (this.config.optimizeForMobile) {
      // Use lightweight styles for mobile
      if (styleUrl.includes('satellite')) {
        return 'mapbox://styles/mapbox/light-v11';
      }
    }

    return styleUrl;
  }

  /**
   * Clear tile cache to free memory
   */
  clearTileCache(): void {
    // Trigger garbage collection by zooming out and back in
    const currentZoom = this.map.getZoom();
    this.map.setZoom(Math.max(this.config.minZoom, currentZoom - 2));
    setTimeout(() => {
      this.map.setZoom(currentZoom);
    }, 100);
  }

  /**
   * Get performance metrics
   */
  getPerformanceMetrics(): {
    tilesLoaded: number;
    totalTiles: number;
    errorCount: number;
    cacheEfficiency: number;
  } {
    return {
      tilesLoaded: this.loadingState.tilesLoaded,
      totalTiles: this.loadingState.totalTiles,
      errorCount: this.loadingState.errors.length,
      cacheEfficiency: this.loadingState.totalTiles > 0 
        ? (this.loadingState.tilesLoaded / this.loadingState.totalTiles) * 100 
        : 0,
    };
  }

  /**
   * Dispose of the tile optimizer
   */
  dispose(): void {
    this.loadingListeners.length = 0;
    // Remove event listeners
    this.map.off('dataloading', this.setupTileLoadingMonitoring);
    this.map.off('data', this.setupTileLoadingMonitoring);
    this.map.off('error', this.setupTileLoadingMonitoring);
    this.map.off('sourcedata', this.setupTileLoadingMonitoring);
  }
}

/**
 * Create tile loading progress indicator
 */
export const createTileLoadingIndicator = (
  container: HTMLElement,
  optimizer: TileOptimizer
): (() => void) => {
  const indicator = document.createElement('div');
  indicator.className = 'tile-loading-indicator';
  indicator.innerHTML = `
    <div class="loading-bar">
      <div class="loading-progress"></div>
    </div>
    <div class="loading-text">Loading map tiles...</div>
  `;

  // Add styles
  const style = document.createElement('style');
  style.textContent = `
    .tile-loading-indicator {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: rgba(255, 255, 255, 0.95);
      border-radius: 8px;
      padding: 16px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      z-index: 1000;
      min-width: 200px;
      text-align: center;
    }
    
    .loading-bar {
      width: 100%;
      height: 4px;
      background: #e5e7eb;
      border-radius: 2px;
      overflow: hidden;
      margin-bottom: 8px;
    }
    
    .loading-progress {
      height: 100%;
      background: #3b82f6;
      border-radius: 2px;
      transition: width 0.3s ease;
      width: 0%;
    }
    
    .loading-text {
      font-size: 14px;
      color: #6b7280;
      font-weight: 500;
    }
  `;

  document.head.appendChild(style);
  container.appendChild(indicator);

  const updateProgress = (state: TileLoadingState) => {
    const progressBar = indicator.querySelector('.loading-progress') as HTMLElement;
    const loadingText = indicator.querySelector('.loading-text') as HTMLElement;

    if (progressBar) {
      progressBar.style.width = `${state.progress}%`;
    }

    if (loadingText) {
      if (state.loading) {
        loadingText.textContent = `Loading map tiles... ${Math.round(state.progress)}%`;
      } else if (state.errors.length > 0) {
        loadingText.textContent = 'Some tiles failed to load';
      } else {
        loadingText.textContent = 'Map loaded successfully';
      }
    }

    // Hide indicator when loading is complete
    if (!state.loading && state.errors.length === 0) {
      setTimeout(() => {
        indicator.style.opacity = '0';
        setTimeout(() => {
          if (indicator.parentNode) {
            indicator.parentNode.removeChild(indicator);
          }
        }, 300);
      }, 1000);
    }
  };

  optimizer.onLoadingStateChange(updateProgress);

  // Return cleanup function
  return () => {
    optimizer.removeLoadingStateListener(updateProgress);
    if (indicator.parentNode) {
      indicator.parentNode.removeChild(indicator);
    }
    if (style.parentNode) {
      style.parentNode.removeChild(style);
    }
  };
};