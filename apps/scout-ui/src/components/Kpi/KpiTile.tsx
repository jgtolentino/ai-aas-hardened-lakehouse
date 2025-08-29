import React from "react";

export type KpiTileProps = {
  label: string;
  value: string | number;
  delta?: number;           // positive/negative drives state color
  hint?: string;            // secondary text
  state?: "default" | "loading" | "error" | "empty";
  onClick?: () => void;
};

export const KpiTile: React.FC<KpiTileProps> = ({
  label, value, delta, hint, state = "default", onClick
}) => {
  const isPos = typeof delta === "number" && delta >= 0;
  const tint =
    state === "error" ? "text-red-600"
  : state === "loading" ? "text-gray-400"
  : state === "empty"   ? "text-gray-500"
  : isPos               ? "text-emerald-600"
  :                       "text-rose-600";

  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full text-left rounded-lg border border-gray-200 bg-white p-4 shadow-sm hover:shadow-md focus:outline-none focus:ring-2 focus:ring-brand-turquoise/60 transition"
      aria-busy={state === "loading"}
      aria-disabled={state === "loading" || state === "empty"}
    >
      <div className="text-sm text-gray-600">{label}</div>
      <div className="mt-1 text-3xl font-semibold text-gray-900">{value}</div>
      {typeof delta === "number" && (
        <div className={`mt-1 text-sm ${tint}`}>
          {isPos ? "▲" : "▼"} {Math.abs(delta).toFixed(1)}%
        </div>
      )}
      {hint && <div className="mt-2 text-xs text-gray-500">{hint}</div>}
    </button>
  );
};
