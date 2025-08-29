import { connect, figma } from "@figma/code-connect";
import { DataTable } from "./DataTable";

// Production Figma file - Scout Dashboard Design System
// From: https://www.figma.com/file/xyz123scout/Scout-Analytics-Dashboard?node-id=78:91
const FILE_KEY = "xyz123scout789";
const NODE_ID  = "78:91";

export default connect(DataTable, figma.component(FILE_KEY, NODE_ID), {
  // Map Figma layer properties to props
  props: {
    data: figma.children("Data Rows"),
    columns: figma.children("Column Headers"),
    loading: figma.boolean("Loading State", false),
    searchable: figma.boolean("Show Search", true),
    pagination: figma.boolean("Show Pagination", true),
    pageSize: figma.number("Page Size", 10),
  },

  example: {
    data: [
      { id: 1, name: "John Doe", role: "Developer", status: "Active" },
      { id: 2, name: "Jane Smith", role: "Designer", status: "Active" },
      { id: 3, name: "Bob Johnson", role: "Manager", status: "Inactive" }
    ],
    columns: [
      { key: "name", label: "Name", sortable: true },
      { key: "role", label: "Role", sortable: true },
      { key: "status", label: "Status" }
    ],
    searchable: true,
    pagination: true,
    pageSize: 10,
  },

  variants: [
    { props: { loading: true }, title: "Loading State" },
    { props: { searchable: false }, title: "No Search" },
    { props: { pagination: false }, title: "No Pagination" }
  ],
});