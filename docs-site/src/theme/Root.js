import React from 'react';
import AIChat from '@site/src/components/AIChat';

// This component wraps the entire app
export default function Root({ children }) {
  return (
    <>
      {children}
      <AIChat />
    </>
  );
}