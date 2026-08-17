/** @startingPoint section="Components" subtitle="Labeled field, surface fill" viewport="700x140" */
export interface TextFieldProps {
  label?: string;
  value?: string;
  placeholder?: string;
  error?: string;
}
export function TextField(props: TextFieldProps): JSX.Element;