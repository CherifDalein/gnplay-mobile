import React from 'react';
export function TextField({ label, value, placeholder, error, ...rest }) {
  return (
    <div>
      <div style={{
        background: 'var(--surface-1)', border: '1px solid ' + (error ? 'var(--danger)' : 'var(--border-1)'),
        borderRadius: 'var(--radius-md)', padding: '11px 14px'
      }}>
        {label && <div style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{label}</div>}
        <div style={{ fontSize: 14, color: value ? 'var(--text-1)' : 'var(--text-3)', marginTop: label ? 4 : 0 }} {...rest}>
          {value || placeholder}
        </div>
      </div>
      {error && <div style={{ marginTop: 8, fontSize: 11.5, color: 'var(--danger)' }}>{error}</div>}
    </div>
  );
}