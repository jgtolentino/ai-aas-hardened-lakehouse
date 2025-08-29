import mapboxgl from 'mapbox-gl';

// Mapbox configuration constants
export const MAPBOX_CONFIG = {
  STYLES: {
    LIGHT: 'mapbox://styles/mapbox/light-v11',
    DARK: 'mapbox://styles/mapbox/dark-v11',
    STREETS: 'mapbox://styles/mapbox/streets-v12',
    SATELLITE: 'mapbox://styles/mapbox/satellite-streets-v12',
    OUTDOORS: 'mapbox://styles/mapbox/outdoors-v12',
  },
  PHILIPPINES: {
    CENTER: [121.0244, 14.6507] as [number, number], // Manila
    BOUNDS: [
      [116.9283, 4.2259], // Southwest
      [126.6043, 21.1214], // Northeast
    ] as [[number, number], [number, number]],
    ZOOM: {
      COUNTRY: 6,
      REGION: 8,
      CITY: 10,
      BARANGAY: 14,
    },
  },
  LAYER_IDS: {
    BARANGAY_BOUNDARIES: 'barangay-boundaries',
    BARANGAY_FILL: 'barangay-fill',
    BARANGAY_LABELS: 'barangay-labels',
    STORE_LOCATIONS: 'store-locations',
    HEATMAP: 'sales-heatmap',
    CLUSTERS: 'store-clusters',
  },
} as const;

// Initialize Mapbox with API key
export const initializeMapbox = (apiKey: string): boolean => {
  if (!apiKey) {
    console.error('Mapbox API key is required');
    return false;
  }

  try {
    mapboxgl.accessToken = apiKey;
    return true;
  } catch (error) {
    console.error('Failed to initialize Mapbox:', error);
    return false;
  }
};

// Utility functions for map operations
export const mapUtils = {
  /**
   * Check if coordinates are within Philippines bounds
   */
  isWithinPhilippinesBounds: (lng: number, lat: number): boolean => {
    const [[swLng, swLat], [neLng, neLat]] = MAPBOX_CONFIG.PHILIPPINES.BOUNDS;
    return lng >= swLng && lng <= neLng && lat >= swLat && lat <= neLat;
  },

  /**
   * Calculate appropriate zoom level based on data density
   */
  calculateZoom: (dataPoints: number, baseZoom = 8): number => {
    if (dataPoints > 1000) return Math.max(baseZoom - 1, 5);
    if (dataPoints > 100) return baseZoom;
    if (dataPoints > 10) return Math.min(baseZoom + 1, 12);
    return Math.min(baseZoom + 2, 14);
  },

  /**
   * Create bounds from array of coordinates
   */
  createBounds: (coordinates: [number, number][]): mapboxgl.LngLatBounds => {
    const bounds = new mapboxgl.LngLatBounds();
    coordinates.forEach(coord => bounds.extend(coord));
    return bounds;
  },

  /**
   * Format coordinates for display
   */
  formatCoordinates: (lng: number, lat: number): string => {
    const lngDir = lng >= 0 ? 'E' : 'W';
    const latDir = lat >= 0 ? 'N' : 'S';
    return `${Math.abs(lat).toFixed(4)}°${latDir}, ${Math.abs(lng).toFixed(4)}°${lngDir}`;
  },
};

// Color schemes for different data visualizations
export const COLOR_SCHEMES = {
  SALES_HEATMAP: [
    '#f7fbff', '#deebf7', '#c6dbef', '#9ecae1',
    '#6baed6', '#4292c6', '#2171b5', '#084594'
  ],
  CATEGORICAL: [
    '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728',
    '#9467bd', '#8c564b', '#e377c2', '#7f7f7f'
  ],
  DIVERGING: [
    '#d73027', '#f46d43', '#fdae61', '#fee090',
    '#e0f3f8', '#abd9e9', '#74add1', '#4575b4'
  ],
} as const;

// Common layer styles
export const LAYER_STYLES = {
  BARANGAY_FILL: {
    'fill-color': [
      'case',
      ['!=', ['feature-state', 'value'], null],
      [
        'interpolate',
        ['linear'],
        ['feature-state', 'value'],
        0, COLOR_SCHEMES.SALES_HEATMAP[0],
        100, COLOR_SCHEMES.SALES_HEATMAP[7],
      ],
      'rgba(0, 0, 0, 0.1)'
    ],
    'fill-opacity': 0.7,
    'fill-outline-color': '#ffffff',
  },
  BARANGAY_STROKE: {
    'line-color': '#ffffff',
    'line-width': 1,
    'line-opacity': 0.8,
  },
  STORE_MARKERS: {
    'circle-radius': [
      'interpolate',
      ['linear'],
      ['zoom'],
      6, 4,
      14, 8
    ],
    'circle-color': '#2563eb',
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 2,
    'circle-opacity': 0.8,
  },
} as const;

// Performance optimization utilities
export const performanceUtils = {
  /**
   * Debounce function for map events
   */
  debounce: <T extends (...args: any[]) => any>(func: T, wait: number): T => {
    let timeout: NodeJS.Timeout;
    return ((...args: any[]) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => func(...args), wait);
    }) as T;
  },

  /**
   * Check if WebGL is supported
   */
  isWebGLSupported: (): boolean => {
    try {
      const canvas = document.createElement('canvas');
      return !!(
        canvas.getContext('webgl') ||
        canvas.getContext('experimental-webgl')
      );
    } catch (e) {
      return false;
    }
  },

  /**
   * Estimate optimal tile loading strategy
   */
  getOptimalTileSize: (devicePixelRatio = window.devicePixelRatio): number => {
    if (devicePixelRatio > 2) return 512; // High DPI displays
    if (devicePixelRatio > 1) return 256; // Retina displays
    return 256; // Standard displays
  },
};

export default {
  MAPBOX_CONFIG,
  initializeMapbox,
  mapUtils,
  COLOR_SCHEMES,
  LAYER_STYLES,
  performanceUtils,
};