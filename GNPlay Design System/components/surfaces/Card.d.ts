/** @startingPoint section="Components" subtitle="Surface container, 16px radius" viewport="700x140" */
export interface CardProps {
  children: React.ReactNode;
  padding?: number;
  style?: React.CSSProperties;
}
export function Card(props: CardProps): JSX.Element;