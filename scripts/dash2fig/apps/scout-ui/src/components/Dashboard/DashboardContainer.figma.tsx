import { connect, figma } from "@figma/code-connect";
import { DashboardContainer } from "./DashboardContainer";

// Generated from superset dashboard: Scout Analytics Dashboard
const FILE_KEY = "dashboard-superset-key";
const NODE_ID = "dashboard-container-node";

export default connect(DashboardContainer, figma.component(FILE_KEY, NODE_ID), {
  props: {
    title: figma.string("Dashboard Title", "Scout Analytics Dashboard"),
    loading: figma.boolean("Loading State", false),
    data: figma.children("Dashboard Data"),
    filters: figma.children("Filter Values")
  },

  example: {
    title: "Scout Analytics Dashboard",
    loading: false,
    data: {
      
      "chart_101": [{ 
        value: "Sample Value", 
        label: "Revenue Trend" 
      }],
      "chart_102": [{ 
        value: "Sample Value", 
        label: "Campaign Performance" 
      }],
      "chart_103": [{ 
        value: "Sample Value", 
        label: "Customer Satisfaction" 
      }],
      "chart_104": [{ 
        value: "Sample Value", 
        label: "Regional Performance" 
      }]
    },
    filters: {},
    onFilterChange: (key, value) => console.log("Filter changed:", key, value)
  },

  variants: [
    { props: { loading: true }, title: "Loading State" },
    { props: { title: "Custom Dashboard" }, title: "Custom Title" }
  ],
});