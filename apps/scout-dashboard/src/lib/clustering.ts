import { GeographicDataPoint } from '@/hooks/useGeographicData';

export interface ClusterPoint extends GeographicDataPoint {
  cluster_id?: string;
  cluster_distance?: number;
}

export interface Cluster {
  id: string;
  center: [number, number];
  points: ClusterPoint[];
  bounds: [[number, number], [number, number]];
  total_value: number;
  average_value: number;
  point_count: number;
  radius: number;
  level: number; // Zoom level for this cluster
}

interface ClusteringOptions {
  maxClusterRadius: number;
  minPointsPerCluster: number;
  maxZoomLevel: number;
  valueWeighting: boolean;
}

/**
 * K-means clustering algorithm optimized for geographic data
 */
export class GeographicClustering {
  private options: ClusteringOptions;

  constructor(options: Partial<ClusteringOptions> = {}) {
    this.options = {
      maxClusterRadius: 50, // pixels at zoom level 10
      minPointsPerCluster: 3,
      maxZoomLevel: 14,
      valueWeighting: true,
      ...options,
    };
  }

  /**
   * Cluster geographic points based on spatial proximity and value
   */
  clusterPoints(points: GeographicDataPoint[], zoomLevel: number): Cluster[] {
    if (points.length === 0) return [];
    
    // Don't cluster at high zoom levels
    if (zoomLevel >= this.options.maxZoomLevel) {
      return points.map((point, index) => ({
        id: `single-${index}`,
        center: [point.longitude, point.latitude],
        points: [{ ...point, cluster_id: `single-${index}` }],
        bounds: this.calculateBounds([[point.longitude, point.latitude]]),
        total_value: point.value,
        average_value: point.value,
        point_count: 1,
        radius: 0,
        level: zoomLevel,
      }));
    }

    // Calculate pixel distance threshold based on zoom level
    const distanceThreshold = this.calculateDistanceThreshold(zoomLevel);
    
    // Group points by spatial proximity
    const spatialGroups = this.spatialGrouping(points, distanceThreshold);
    
    // Create clusters from groups
    const clusters = spatialGroups
      .filter(group => group.length >= this.options.minPointsPerCluster)
      .map((group, index) => this.createCluster(group, `cluster-${index}`, zoomLevel));

    // Add singleton points as individual clusters
    const singletons = spatialGroups
      .filter(group => group.length < this.options.minPointsPerCluster)
      .flat()
      .map((point, index) => this.createCluster([point], `singleton-${index}`, zoomLevel));

    return [...clusters, ...singletons];
  }

  /**
   * Hierarchical clustering for different zoom levels
   */
  hierarchicalCluster(points: GeographicDataPoint[], zoomLevels: number[]): Map<number, Cluster[]> {
    const clustersByZoom = new Map<number, Cluster[]>();

    for (const zoom of zoomLevels.sort((a, b) => b - a)) { // Start with highest zoom
      const clusters = this.clusterPoints(points, zoom);
      clustersByZoom.set(zoom, clusters);
    }

    return clustersByZoom;
  }

  /**
   * Calculate distance threshold in degrees based on zoom level
   */
  private calculateDistanceThreshold(zoomLevel: number): number {
    // Convert pixel radius to degrees (approximately)
    // At zoom level 10, 1 degree ≈ 111km ≈ 11100000 pixels at equator
    const pixelsPerDegree = Math.pow(2, zoomLevel) * 256 / 360;
    return this.options.maxClusterRadius / pixelsPerDegree;
  }

  /**
   * Group points by spatial proximity using grid-based approach
   */
  private spatialGrouping(points: GeographicDataPoint[], threshold: number): GeographicDataPoint[][] {
    const groups: GeographicDataPoint[][] = [];
    const processed = new Set<string>();

    for (const point of points) {
      if (processed.has(point.id)) continue;

      const group: GeographicDataPoint[] = [point];
      processed.add(point.id);

      // Find nearby points
      for (const otherPoint of points) {
        if (processed.has(otherPoint.id)) continue;

        const distance = this.calculateDistance(
          point.latitude,
          point.longitude,
          otherPoint.latitude,
          otherPoint.longitude
        );

        if (distance <= threshold) {
          group.push(otherPoint);
          processed.add(otherPoint.id);
        }
      }

      groups.push(group);
    }

    return groups;
  }

  /**
   * Create a cluster from a group of points
   */
  private createCluster(points: GeographicDataPoint[], clusterId: string, zoomLevel: number): Cluster {
    if (points.length === 0) {
      throw new Error('Cannot create cluster from empty points array');
    }

    // Calculate weighted center if value weighting is enabled
    const center = this.options.valueWeighting 
      ? this.calculateWeightedCenter(points)
      : this.calculateGeometricCenter(points);

    // Calculate cluster statistics
    const totalValue = points.reduce((sum, p) => sum + p.value, 0);
    const averageValue = totalValue / points.length;

    // Calculate bounds
    const coordinates = points.map(p => [p.longitude, p.latitude] as [number, number]);
    const bounds = this.calculateBounds(coordinates);

    // Calculate cluster radius
    const radius = this.calculateClusterRadius(center, points);

    // Add cluster metadata to points
    const clusteredPoints = points.map(point => ({
      ...point,
      cluster_id: clusterId,
      cluster_distance: this.calculateDistance(
        center[1], center[0], 
        point.latitude, point.longitude
      ),
    }));

    return {
      id: clusterId,
      center,
      points: clusteredPoints,
      bounds,
      total_value: totalValue,
      average_value: averageValue,
      point_count: points.length,
      radius,
      level: zoomLevel,
    };
  }

  /**
   * Calculate geometric center of points
   */
  private calculateGeometricCenter(points: GeographicDataPoint[]): [number, number] {
    const sumLng = points.reduce((sum, p) => sum + p.longitude, 0);
    const sumLat = points.reduce((sum, p) => sum + p.latitude, 0);
    return [sumLng / points.length, sumLat / points.length];
  }

  /**
   * Calculate value-weighted center of points
   */
  private calculateWeightedCenter(points: GeographicDataPoint[]): [number, number] {
    const totalValue = points.reduce((sum, p) => sum + p.value, 0);
    
    if (totalValue === 0) {
      return this.calculateGeometricCenter(points);
    }

    const weightedLng = points.reduce((sum, p) => sum + (p.longitude * p.value), 0) / totalValue;
    const weightedLat = points.reduce((sum, p) => sum + (p.latitude * p.value), 0) / totalValue;
    
    return [weightedLng, weightedLat];
  }

  /**
   * Calculate cluster radius (maximum distance from center)
   */
  private calculateClusterRadius(center: [number, number], points: GeographicDataPoint[]): number {
    return Math.max(...points.map(point => 
      this.calculateDistance(center[1], center[0], point.latitude, point.longitude)
    ));
  }

  /**
   * Calculate bounds for a set of coordinates
   */
  private calculateBounds(coordinates: [number, number][]): [[number, number], [number, number]] {
    const lngs = coordinates.map(c => c[0]);
    const lats = coordinates.map(c => c[1]);
    
    return [
      [Math.min(...lngs), Math.min(...lats)], // Southwest
      [Math.max(...lngs), Math.max(...lats)], // Northeast
    ];
  }

  /**
   * Calculate distance between two points using Haversine formula
   */
  private calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = this.degreesToRadians(lat2 - lat1);
    const dLng = this.degreesToRadians(lng2 - lng1);
    
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this.degreesToRadians(lat1)) * Math.cos(this.degreesToRadians(lat2)) *
              Math.sin(dLng / 2) * Math.sin(dLng / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Convert degrees to radians
   */
  private degreesToRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}

/**
 * Utility functions for clustering operations
 */
export const clusteringUtils = {
  /**
   * Filter clusters by minimum value threshold
   */
  filterClustersByValue: (clusters: Cluster[], minValue: number): Cluster[] => {
    return clusters.filter(cluster => cluster.total_value >= minValue);
  },

  /**
   * Sort clusters by various criteria
   */
  sortClusters: (clusters: Cluster[], criteria: 'value' | 'size' | 'density'): Cluster[] => {
    return [...clusters].sort((a, b) => {
      switch (criteria) {
        case 'value':
          return b.total_value - a.total_value;
        case 'size':
          return b.point_count - a.point_count;
        case 'density':
          const densityA = a.point_count / (a.radius || 1);
          const densityB = b.point_count / (b.radius || 1);
          return densityB - densityA;
        default:
          return 0;
      }
    });
  },

  /**
   * Get cluster statistics
   */
  getClusterStatistics: (clusters: Cluster[]) => {
    const totalPoints = clusters.reduce((sum, c) => sum + c.point_count, 0);
    const totalValue = clusters.reduce((sum, c) => sum + c.total_value, 0);
    const averageClusterSize = totalPoints / clusters.length;
    const largestCluster = Math.max(...clusters.map(c => c.point_count));
    const smallestCluster = Math.min(...clusters.map(c => c.point_count));

    return {
      clusterCount: clusters.length,
      totalPoints,
      totalValue,
      averageClusterSize,
      largestCluster,
      smallestCluster,
      compressionRatio: clusters.length / totalPoints,
    };
  },

  /**
   * Find optimal number of clusters using elbow method
   */
  findOptimalClusterCount: (points: GeographicDataPoint[], maxClusters: number = 10): number => {
    const clustering = new GeographicClustering();
    const wcss: number[] = []; // Within-cluster sum of squares

    for (let k = 1; k <= maxClusters; k++) {
      // This is a simplified approach - in practice, you'd use k-means
      const clusters = clustering.clusterPoints(points, 10); // Fixed zoom for comparison
      const clusterWcss = clusters.reduce((sum, cluster) => {
        return sum + cluster.points.reduce((pointSum, point) => {
          const distance = clustering['calculateDistance'](
            cluster.center[1], cluster.center[0],
            point.latitude, point.longitude
          );
          return pointSum + distance * distance;
        }, 0);
      }, 0);
      wcss.push(clusterWcss);
    }

    // Find elbow point (simplified)
    let optimalK = 1;
    let maxDecrease = 0;
    
    for (let i = 1; i < wcss.length - 1; i++) {
      const decrease = wcss[i - 1] - wcss[i];
      if (decrease > maxDecrease) {
        maxDecrease = decrease;
        optimalK = i + 1;
      }
    }

    return optimalK;
  },
};

export default GeographicClustering;