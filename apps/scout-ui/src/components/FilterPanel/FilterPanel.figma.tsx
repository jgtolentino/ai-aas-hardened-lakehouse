import { connect, figma } from "@figma/code-connect";
import { FilterPanel } from "./FilterPanel";

// Production Figma file - Scout Dashboard Design System
// From: https://www.figma.com/file/xyz123scout/Scout-Analytics-Dashboard?node-id=156:189
const FILE_KEY = "xyz123scout789";
const NODE_ID  = "156:189";

export default connect(FilterPanel, figma.component(FILE_KEY, NODE_ID), {
  // Map Figma layer properties to props
  props: {
    title: figma.string("Panel Title", "Filters"),
    collapsed: figma.boolean("Collapsed State", false),
    filters: figma.children("Filter Items"),
  },

  example: {
    title: "Dashboard Filters",
    filters: [
      {
        key: "dateRange",
        label: "Date Range",
        type: "select",
        options: [
          { value: "last7days", label: "Last 7 days" },
          { value: "last30days", label: "Last 30 days" },
          { value: "last3months", label: "Last 3 months" },
          { value: "lastyear", label: "Last year" }
        ],
        placeholder: "Select date range"
      },
      {
        key: "department",
        label: "Department",
        type: "select", 
        options: [
          { value: "sales", label: "Sales" },
          { value: "marketing", label: "Marketing" },
          { value: "engineering", label: "Engineering" },
          { value: "design", label: "Design" }
        ],
        placeholder: "All departments"
      },
      {
        key: "search",
        label: "Search",
        type: "text",
        placeholder: "Search records..."
      }
    ],
    values: {
      dateRange: "last30days",
      department: "sales",
      search: ""
    },
    onFilterChange: (key: string, value: any) => console.log("Filter changed:", key, value),
    onApplyFilters: () => console.log("Apply filters"),
    onResetFilters: () => console.log("Reset filters"),
  },

  variants: [
    { props: { collapsed: true }, title: "Collapsed State" },
    { props: { title: "Advanced Filters" }, title: "Custom Title" }
  ],
});