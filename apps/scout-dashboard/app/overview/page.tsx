'use client'
import { Grid } from 'apps/scout-ui/src/components/Layout/Grid'
import { KpiTile } from 'apps/scout-ui/src/components/Kpi/KpiTile'
import { Timeseries } from 'apps/scout-ui/src/components/Chart/Timeseries'

export default function OverviewPage() {
  return (
    <div className="p-6">
      <Grid cols={12} className="mb-4">
        <div className="col-span-3"><KpiTile label="Revenue" value="₱ 12.4M" /></div>
        <div className="col-span-3"><KpiTile label="Transactions" value="482k" /></div>
        <div className="col-span-3"><KpiTile label="Basket" value="₱ 257" /></div>
        <div className="col-span-3"><KpiTile label="Shoppers" value="72k" /></div>
      </Grid>
      <Grid cols={12}>
        <div className="col-span-8"><Timeseries data={[{x:'W1',y:10},{x:'W2',y:14},{x:'W3',y:12},{x:'W4',y:18}]} /></div>
        <div className="col-span-4"><div className="rounded-sk bg-panel p-4 h-72 border border-white/10">Hour × Weekday (stub)</div></div>
      </Grid>
    </div>
  )
}