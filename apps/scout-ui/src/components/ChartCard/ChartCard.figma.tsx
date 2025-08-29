import { connect, figma } from "@figma/code-connect";
import { ChartCard } from "./ChartCard";

// Production Figma file - Scout Dashboard Design System  
// From: https://www.figma.com/file/xyz123scout/Scout-Analytics-Dashboard?node-id=102:134
const FILE_KEY = "xyz123scout789";
const NODE_ID  = "102:134";

export default connect(ChartCard, figma.component(FILE_KEY, NODE_ID), {
  // Map Figma layer properties to props
  props: {
    title: figma.string("Chart Title", "Revenue Trends"),
    subtitle: figma.string("Chart Subtitle", "Last 12 months"),
    chartType: figma.enum("Chart Type", {
      "Line Chart": "line",
      "Bar Chart": "bar", 
      "Pie Chart": "pie",
      "Area Chart": "area"
    }, "line"),
    loading: figma.boolean("Loading State", false),
    error: figma.string("Error Message", ""),
    height: figma.number("Height", 300),
    showLegend: figma.boolean("Show Legend", true),
  },

  example: {
    title: "Revenue Trends",
    subtitle: "Last 12 months", 
    chartType: "line",
    data: [
      { month: "Jan", revenue: 45000 },
      { month: "Feb", revenue: 52000 },
      { month: "Mar", revenue: 48000 },
      { month: "Apr", revenue: 61000 },
      { month: "May", revenue: 55000 },
      { month: "Jun", revenue: 67000 }
    ],
    height: 300,
    showLegend: true,
  },

  variants: [
    { props: { loading: true }, title: "Loading State" },
    { props: { error: "Failed to load data" }, title: "Error State" },
    { props: { chartType: "bar" }, title: "Bar Chart" },
    { props: { chartType: "pie" }, title: "Pie Chart" },
    { props: { showLegend: false }, title: "No Legend" }
  ],
});