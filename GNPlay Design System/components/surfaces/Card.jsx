import React from 'react';
export function Card({ children, padding = 14, style, ...rest }) {
  return (
    <div style={{
      background: 'var(--surface-1)', border: '1px solid var(--border-1)',
      borderRadius: 'var(--radius-lg)', padding, boxSizing: 'border-box', ...style
    }} {...rest}>{children}</div>
  );
}