/** @startingPoint section="Components" subtitle="On/off switch, bordeaux when active" viewport="700x100" */
export interface ToggleSwitchProps {
  on: boolean;
  onChange?: (next: boolean) => void;
  size?: 'sm' | 'md';
}
export function ToggleSwitch(props: ToggleSwitchProps): JSX.Element;