import React from 'react';
export function Button({ variant = 'primary', size = 'md', disabled, children, style, ...rest }) {
  const sizes = { sm: { h: 40, fs: 12.5, px: 14 }, md: { h: 52, fs: 15, px: 18 }, lg: { h: 54, fs: 15, px: 22 } };
  const s = sizes[size] || sizes.md;
  const variants = {
    primary: { background: disabled ? '#1f1f25' : 'var(--accent-500)', color: disabled ? 'var(--text-3)' : 'var(--text-inverse)', border: 'none' },
    secondary: { background: 'transparent', color: 'var(--text-1)', border: '1px solid var(--brand-700)' },
    ghost: { background: 'var(--surface-1)', color: 'var(--text-1)', border: '1px solid var(--border-1)' },
    danger: { background: 'transparent', color: 'var(--danger)', border: '1px solid rgba(255,90,95,.35)' }
  };
  const v = variants[variant] || variants.primary;
  return (
    <button disabled={disabled} style={{
      all: 'unset', cursor: disabled ? 'default' : 'pointer', boxSizing: 'border-box',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      height: s.h, padding: '0 ' + s.px + 'px', borderRadius: 'var(--radius-md)',
      fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: s.fs,
      opacity: disabled ? .7 : 1, ...v, ...style
    }} {...rest}>{children}</button>
  );
}