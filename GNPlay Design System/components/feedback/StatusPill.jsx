import React from 'react';
const TONES = {
  success: { bg: 'var(--success-bg)', fg: 'var(--success)' },
  warning: { bg: 'var(--warning-bg)', fg: 'var(--warning)' },
  danger: { bg: 'var(--danger-bg)', fg: 'var(--danger)' },
  info: { bg: 'var(--info-bg)', fg: 'var(--info)' },
  neutral: { bg: '#22222a', fg: 'var(--text-2)' },
  brand: { bg: 'rgba(168,18,59,.22)', fg: 'var(--accent-300)' }
};
export function StatusPill({ tone = 'neutral', children }) {
  const t = TONES[tone] || TONES.neutral;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '2.5px 8px', borderRadius: 'var(--radius-pill)', background: t.bg }}>
      <span style={{ width: 5, height: 5, borderRadius: '50%', background: t.fg }} />
      <span style={{ fontSize: 10, fontWeight: 600, color: t.fg, letterSpacing: '.02em' }}>{children}</span>
    </span>
  );
}