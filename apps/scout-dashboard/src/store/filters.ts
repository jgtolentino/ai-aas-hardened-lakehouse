import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';
import { persist } from 'zustand/middleware';

// Global filter types
export interface DateRange {
  start: string;
  end: string;
  preset?: 'last_7_days' | 'last_30_days' | 'last_90_days' | 'ytd' | 'custom';
}

export interface FilterState {
  // Global filters
  dateRange: DateRange;
  region: string[];
  storeFormat: string[];
  category: string[];
  
  // Active tab
  activeTab: string;
  
  // Contextual filters by tab
  contextualFilters: {
    overview: {
      personaView: string;
      comparisonPeriod: string;
    };
    mix: {
      categoryLevel: string;
      brandFilter: string[];
    };
    competitive: {
      competitorSet: string[];
      priceSegment: string;
    };
    geography: {
      mapLevel: 'country' | 'region' | 'city' | 'store';
      storeType: string[];
    };
    consumers: {
      demographicSegment: string[];
      behaviorType: string;
    };
    ai: {
      insightType: string[];
      confidenceLevel: 'high' | 'medium' | 'low';
    };
  };
  
  // Filter presets
  savedPresets: FilterPreset[];
  activePreset: string | null;
}

export interface FilterPreset {
  id: string;
  name: string;
  description?: string;
  filters: Partial<FilterState>;
  createdAt: string;
  isSystem: boolean;
}

interface FilterActions {
  // Global filter actions
  setDateRange: (dateRange: DateRange) => void;
  setRegion: (region: string[]) => void;
  setStoreFormat: (storeFormat: string[]) => void;
  setCategory: (category: string[]) => void;
  
  // Tab management
  setActiveTab: (tab: string) => void;
  
  // Contextual filter actions
  setContextualFilter: <T extends keyof FilterState['contextualFilters']>(
    tab: T,
    key: keyof FilterState['contextualFilters'][T],
    value: any
  ) => void;
  
  // Preset management
  savePreset: (name: string, description?: string) => void;
  loadPreset: (presetId: string) => void;
  deletePreset: (presetId: string) => void;
  
  // Utility actions
  resetFilters: () => void;
  resetContextualFilters: (tab?: string) => void;
  
  // Computed getters
  getActiveFilters: () => Partial<FilterState>;
  hasActiveFilters: () => boolean;
}

// Default filter state
const defaultFilters: FilterState = {
  dateRange: {
    start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0],
    preset: 'last_30_days'
  },
  region: ['all'],
  storeFormat: ['all'],
  category: ['all'],
  activeTab: 'overview',
  contextualFilters: {
    overview: {
      personaView: 'regional_manager',
      comparisonPeriod: 'previous_period'
    },
    mix: {
      categoryLevel: 'category',
      brandFilter: []
    },
    competitive: {
      competitorSet: [],
      priceSegment: 'all'
    },
    geography: {
      mapLevel: 'region',
      storeType: []
    },
    consumers: {
      demographicSegment: [],
      behaviorType: 'all'
    },
    ai: {
      insightType: ['all'],
      confidenceLevel: 'medium'
    }
  },
  savedPresets: [
    {
      id: 'system_default',
      name: 'Default View',
      description: 'Standard regional manager view with 30-day range',
      filters: {},
      createdAt: new Date().toISOString(),
      isSystem: true
    },
    {
      id: 'system_executive',
      name: 'Executive Summary',
      description: 'High-level overview for executive reporting',
      filters: {
        dateRange: { 
          start: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          end: new Date().toISOString().split('T')[0],
          preset: 'last_90_days'
        },
        contextualFilters: {
          overview: { personaView: 'regional_manager', comparisonPeriod: 'year_over_year' }
        }
      },
      createdAt: new Date().toISOString(),
      isSystem: true
    }
  ],
  activePreset: null
};

// Create the store with persistence and subscriptions
export const useFiltersStore = create<FilterState & FilterActions>()(
  subscribeWithSelector(
    persist(
      (set, get) => ({
        ...defaultFilters,
        
        // Global filter actions
        setDateRange: (dateRange) => set({ dateRange }),
        
        setRegion: (region) => set({ region }),
        
        setStoreFormat: (storeFormat) => set({ storeFormat }),
        
        setCategory: (category) => set({ category }),
        
        // Tab management
        setActiveTab: (activeTab) => set({ activeTab }),
        
        // Contextual filter actions
        setContextualFilter: (tab, key, value) => set((state) => ({
          contextualFilters: {
            ...state.contextualFilters,
            [tab]: {
              ...state.contextualFilters[tab],
              [key]: value
            }
          }
        })),
        
        // Preset management
        savePreset: (name, description) => {
          const state = get();
          const preset: FilterPreset = {
            id: `user_${Date.now()}`,
            name,
            description,
            filters: {
              dateRange: state.dateRange,
              region: state.region,
              storeFormat: state.storeFormat,
              category: state.category,
              contextualFilters: state.contextualFilters
            },
            createdAt: new Date().toISOString(),
            isSystem: false
          };
          
          set((state) => ({
            savedPresets: [...state.savedPresets, preset],
            activePreset: preset.id
          }));
        },
        
        loadPreset: (presetId) => {
          const state = get();
          const preset = state.savedPresets.find(p => p.id === presetId);
          if (preset) {
            set({
              ...preset.filters,
              activePreset: presetId
            });
          }
        },
        
        deletePreset: (presetId) => set((state) => ({
          savedPresets: state.savedPresets.filter(p => p.id !== presetId && !p.isSystem),
          activePreset: state.activePreset === presetId ? null : state.activePreset
        })),
        
        // Utility actions
        resetFilters: () => set({
          ...defaultFilters,
          activeTab: get().activeTab,
          savedPresets: get().savedPresets,
          activePreset: null
        }),
        
        resetContextualFilters: (tab) => {
          if (tab) {
            set((state) => ({
              contextualFilters: {
                ...state.contextualFilters,
                [tab]: defaultFilters.contextualFilters[tab as keyof typeof defaultFilters.contextualFilters]
              }
            }));
          } else {
            set({ contextualFilters: defaultFilters.contextualFilters });
          }
        },
        
        // Computed getters
        getActiveFilters: () => {
          const state = get();
          const activeFilters: Partial<FilterState> = {};
          
          // Only include non-default global filters
          if (state.dateRange.preset !== 'last_30_days') {
            activeFilters.dateRange = state.dateRange;
          }
          if (!state.region.includes('all') || state.region.length > 1) {
            activeFilters.region = state.region;
          }
          if (!state.storeFormat.includes('all') || state.storeFormat.length > 1) {
            activeFilters.storeFormat = state.storeFormat;
          }
          if (!state.category.includes('all') || state.category.length > 1) {
            activeFilters.category = state.category;
          }
          
          // Include active contextual filters for current tab
          const tabFilters = state.contextualFilters[state.activeTab as keyof typeof state.contextualFilters];
          if (tabFilters && Object.keys(tabFilters).length > 0) {
            activeFilters.contextualFilters = { [state.activeTab]: tabFilters };
          }
          
          return activeFilters;
        },
        
        hasActiveFilters: () => {
          const activeFilters = get().getActiveFilters();
          return Object.keys(activeFilters).length > 0;
        }
      }),
      {
        name: 'scout-dashboard-filters',
        partialize: (state) => ({
          dateRange: state.dateRange,
          region: state.region,
          storeFormat: state.storeFormat,
          category: state.category,
          contextualFilters: state.contextualFilters,
          savedPresets: state.savedPresets,
          activePreset: state.activePreset
        })
      }
    )
  )
);

// Selector hooks for optimized re-renders
export const useGlobalFilters = () => useFiltersStore(state => ({
  dateRange: state.dateRange,
  region: state.region,
  storeFormat: state.storeFormat,
  category: state.category
}));

export const useActiveTab = () => useFiltersStore(state => state.activeTab);

export const useContextualFilters = (tab: string) => 
  useFiltersStore(state => state.contextualFilters[tab as keyof typeof state.contextualFilters]);

export const useFilterPresets = () => useFiltersStore(state => ({
  presets: state.savedPresets,
  activePreset: state.activePreset
}));

// Filter utility functions
export const formatDateRange = (dateRange: DateRange): string => {
  if (dateRange.preset && dateRange.preset !== 'custom') {
    const presetLabels = {
      last_7_days: 'Last 7 Days',
      last_30_days: 'Last 30 Days',
      last_90_days: 'Last 90 Days',
      ytd: 'Year to Date'
    };
    return presetLabels[dateRange.preset];
  }
  
  const start = new Date(dateRange.start).toLocaleDateString();
  const end = new Date(dateRange.end).toLocaleDateString();
  return `${start} - ${end}`;
};

export const getFilterDisplayValue = (filterKey: string, value: any): string => {
  if (Array.isArray(value)) {
    if (value.includes('all') || value.length === 0) return 'All';
    if (value.length === 1) return value[0];
    return `${value.length} selected`;
  }
  
  if (filterKey === 'dateRange') {
    return formatDateRange(value as DateRange);
  }
  
  return String(value);
};

// Filter validation
export const validateFilters = (filters: Partial<FilterState>): { valid: boolean; errors: string[] } => {
  const errors: string[] = [];
  
  if (filters.dateRange) {
    const start = new Date(filters.dateRange.start);
    const end = new Date(filters.dateRange.end);
    
    if (start > end) {
      errors.push('Start date must be before end date');
    }
    
    if (end > new Date()) {
      errors.push('End date cannot be in the future');
    }
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
};