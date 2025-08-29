import React from 'react';

interface SkeletonProps {
  className?: string;
  animate?: boolean;
}

export const Skeleton: React.FC<SkeletonProps> = ({
  className = '',
  animate = true,
}) => {
  const animationClass = animate ? 'animate-pulse' : '';
  
  return (
    <div
      className={`bg-gray-200 rounded ${animationClass} ${className}`}
      aria-hidden="true"
    />
  );
};

export default Skeleton;
