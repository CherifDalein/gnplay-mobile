/** @startingPoint section="Components" subtitle="5-tab bar with center FAB" viewport="700x120" */
export interface BottomNavItem { key: string; label: string; fab?: boolean; }
export interface BottomNavProps {
  items: BottomNavItem[];
  active?: string;
}
export function BottomNav(props: BottomNavProps): JSX.Element;