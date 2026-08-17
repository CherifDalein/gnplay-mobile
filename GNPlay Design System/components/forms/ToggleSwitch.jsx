import React from 'react';
export function ToggleSwitch({ on, onChange, size = 'md' }) {
  const dims = size === 'sm' ? { w: 44, h: 25, k: 19 } : { w: 46, h: 26, k: 20 };
  return (
    <button onClick={() => onChange && onChange(!on)} style={{
      all: 'unset', cursor: 'pointer', width: dims.w, height: dims.h, borderRadius: 'var(--radius-pill)',
      position: 'relative', transition: 'background .18s', background: on ? 'var(--brand-600)' : 'var(--border-1)'
    }}>
      <span style={{
        position: 'absolute', top: 3, width: dims.k, height: dims.k, borderRadius: '50%', background: '#fff',
        transition: 'left .18s', left: on ? (dims.w - dims.k - 3) : 3
      }} />
    </button>
  );
}