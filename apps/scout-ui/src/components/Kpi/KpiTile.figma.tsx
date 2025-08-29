import { connect, figma } from "@figma/code-connect";
import { KpiTile } from "./KpiTile";

// Production Figma file - Scout Dashboard Design System
// From: https://www.figma.com/file/xyz123scout/Scout-Analytics-Dashboard?node-id=45:67
const FILE_KEY = "xyz123scout789";
const NODE_ID  = "45:67";

export default connect(KpiTile, figma.component(FILE_KEY, NODE_ID), {
  // Map Figma layer properties or tokens to props
  props: {
    label: figma.string("Label", "Revenue"),
    value: figma.string("Value", "₱1.23M"),
    delta: figma.number("Delta %", 4.2),
    hint:  figma.string("Hint", "Last 7 days"),
    state: figma.enum("State", ["default", "loading", "error", "empty"], "default"),
  },

  example: {
    label: "Revenue",
    value: "₱1.23M",
    delta: 4.2,
    hint: "Last 7 days",
    state: "default",
  },

  variants: [
    { props: { state: "loading" }, title: "Loading" },
    { props: { state: "empty" },   title: "Empty"   },
    { props: { state: "error" },   title: "Error"   }
  ],
});
