import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

export interface FilterState {
  dateRange: string[];
  region: string[];
  barangay: string[];
  category: string[];
  brand: string[];
  channel: string[];
}

interface FilterStore {
  filters: FilterState;
  setFilter: <K extends keyof FilterState>(key: K, value: FilterState[K]) => void;
  setFilters: (filters: Partial<FilterState>) => void;
  resetFilters: () => void;
  contextOverrides: Record<string, Partial<FilterState>>;
  setContextOverride: (moduleId: string, filters: Partial<FilterState>) => void;
  clearContextOverride: (moduleId: string) => void;
}

const defaultFilters: FilterState = {
  dateRange: ['last_28d'],
  region: ['ALL'],
  barangay: [],
  category: [],
  brand: [],
  channel: [],
};

export const useFilterStore = create<FilterStore>()(
  persist(
    immer((set) => ({
      filters: defaultFilters,
      
      setFilter: (key, value) =>
        set((state) => {
          state.filters[key] = value;
        }),
      
      setFilters: (filters) =>
        set((state) => {
          Object.assign(state.filters, filters);
        }),
      
      resetFilters: () =>
        set((state) => {
          state.filters = defaultFilters;
        }),
      
      contextOverrides: {},
      
      setContextOverride: (moduleId, filters) =>
        set((state) => {
          state.contextOverrides[moduleId] = filters;
        }),
      
      clearContextOverride: (moduleId) =>
        set((state) => {
          delete state.contextOverrides[moduleId];
        }),
    })),
    {
      name: 'scout-filters',
      storage: createJSONStorage(() => sessionStorage),
      partialize: (state) => ({ filters: state.filters }),
    }
  )
);

// URL sync helper
export function syncFiltersToUrl(filters: FilterState) {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (Array.isArray(value) && value.length > 0) {
      params.set(key, value.join(','));
    }
  });
  window.history.replaceState({}, '', `?${params.toString()}`);
}

// Parse filters from URL
export function parseFiltersFromUrl(): Partial<FilterState> {
  const params = new URLSearchParams(window.location.search);
  const filters: Partial<FilterState> = {};
  
  params.forEach((value, key) => {
    if (key in defaultFilters) {
      filters[key as keyof FilterState] = value.split(',');
    }
  });
  
  return filters;
}
