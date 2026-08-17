import React from 'react';
export function StatTile({ value, label, icon }) {
  return (
    <div style={{ background: 'var(--surface-1)', border: '1px solid var(--border-1)', borderRadius: 'var(--radius-lg)', padding: 14 }}>
      {icon && (
        <div style={{ width: 26, height: 26, borderRadius: 8, background: 'rgba(168,18,59,.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {icon}
        </div>
      )}
      <div style={{ font: 'var(--text-display-md)', color: '#fff', marginTop: 10, fontSize: 22 }}>{value}</div>
      <div style={{ fontSize: 11.5, color: 'var(--text-3)', marginTop: 4 }}>{label}</div>
    </div>
  );
}