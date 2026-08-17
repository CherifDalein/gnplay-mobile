import React from 'react';
export function BottomNav({ items, active }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', padding: '11px 8px 0', height: 86, boxSizing: 'border-box',
      background: 'rgba(11,11,13,.92)', backdropFilter: 'blur(14px)', borderTop: '1px solid var(--surface-1)'
    }}>
      {items.map((it, i) => (
        <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, paddingTop: 4 }}>
          {it.fab ? (
            <span style={{ width: 48, height: 48, borderRadius: '50%', background: 'var(--gradient-cta)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: -16, boxShadow: 'var(--shadow-fab)' }}>
              <span style={{ color: '#fff', fontSize: 24, fontWeight: 300, lineHeight: 1, marginTop: -2 }}>+</span>
            </span>
          ) : (
            <span style={{ width: 20, height: 20, borderRadius: 6, border: '1.7px solid ' + (it.key === active ? 'var(--accent-500)' : 'var(--text-3)') }} />
          )}
          <span style={{ fontSize: 9.5, fontWeight: 600, color: it.key === active ? 'var(--accent-500)' : 'var(--text-3)' }}>{it.label}</span>
        </div>
      ))}
    </div>
  );
}