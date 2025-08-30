import React from 'react'
type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & { tone?: 'primary' | 'neutral' }
export function Button({ tone = 'primary', className = '', ...rest }: Props) {
  const base = 'rounded-sk px-3 py-2 text-sm border'
  const styles = tone === 'primary'
    ? 'bg-accent/10 text-text border-accent/40 hover:bg-accent/20'
    : 'bg-panel text-text border-white/10 hover:bg-white/5'
  return <button className={`${base} ${styles} ${className}`} {...rest} />
}