/** @startingPoint section="Components" subtitle="Dot + label status badge" viewport="700x120" */
export interface StatusPillProps {
  tone?: 'success' | 'warning' | 'danger' | 'info' | 'neutral' | 'brand';
  children: React.ReactNode;
}
export function StatusPill(props: StatusPillProps): JSX.Element;