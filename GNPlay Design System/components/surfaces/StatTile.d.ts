/** @startingPoint section="Components" subtitle="KPI card for dashboards" viewport="700x160" */
export interface StatTileProps {
  value: string;
  label: string;
  icon?: React.ReactNode;
}
export function StatTile(props: StatTileProps): JSX.Element;