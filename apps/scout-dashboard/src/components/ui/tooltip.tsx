import React, { useState, useRef, useEffect } from 'react';
import { cn } from '@/lib/utils';

interface TooltipProps {
  content: React.ReactNode;
  children: React.ReactNode;
  side?: 'top' | 'bottom' | 'left' | 'right';
  delay?: number;
  className?: string;
  disabled?: boolean;
}

export const Tooltip: React.FC<TooltipProps> = ({
  content,
  children,
  side = 'top',
  delay = 200,
  className,
  disabled = false
}) => {
  const [isVisible, setIsVisible] = useState(false);
  const [showTimeout, setShowTimeout] = useState<NodeJS.Timeout | null>(null);
  const [hideTimeout, setHideTimeout] = useState<NodeJS.Timeout | null>(null);
  const triggerRef = useRef<HTMLDivElement>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);

  const clearTimeouts = () => {
    if (showTimeout) {
      clearTimeout(showTimeout);
      setShowTimeout(null);
    }
    if (hideTimeout) {
      clearTimeout(hideTimeout);
      setHideTimeout(null);
    }
  };

  const handleMouseEnter = () => {
    if (disabled) return;
    
    clearTimeouts();
    const timeout = setTimeout(() => {
      setIsVisible(true);
    }, delay);
    setShowTimeout(timeout);
  };

  const handleMouseLeave = () => {
    clearTimeouts();
    const timeout = setTimeout(() => {
      setIsVisible(false);
    }, 100);
    setHideTimeout(timeout);
  };

  const handleTooltipMouseEnter = () => {
    clearTimeouts();
  };

  const handleTooltipMouseLeave = () => {
    clearTimeouts();
    setIsVisible(false);
  };

  useEffect(() => {
    return () => clearTimeouts();
  }, []);

  const getTooltipPosition = () => {
    const sideClasses = {
      top: 'bottom-full left-1/2 transform -translate-x-1/2 mb-2',
      bottom: 'top-full left-1/2 transform -translate-x-1/2 mt-2',
      left: 'right-full top-1/2 transform -translate-y-1/2 mr-2',
      right: 'left-full top-1/2 transform -translate-y-1/2 ml-2'
    };

    const arrowClasses = {
      top: 'top-full left-1/2 transform -translate-x-1/2 border-l-transparent border-r-transparent border-t-gray-900 border-b-transparent',
      bottom: 'bottom-full left-1/2 transform -translate-x-1/2 border-l-transparent border-r-transparent border-b-gray-900 border-t-transparent',
      left: 'left-full top-1/2 transform -translate-y-1/2 border-t-transparent border-b-transparent border-l-gray-900 border-r-transparent',
      right: 'right-full top-1/2 transform -translate-y-1/2 border-t-transparent border-b-transparent border-r-gray-900 border-l-transparent'
    };

    return { position: sideClasses[side], arrow: arrowClasses[side] };
  };

  const { position, arrow } = getTooltipPosition();

  return (
    <div className="relative inline-block">
      <div
        ref={triggerRef}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        className="cursor-help"
      >
        {children}
      </div>
      
      {isVisible && !disabled && (
        <>
          {/* Backdrop for mobile/touch devices */}
          <div 
            className="fixed inset-0 z-40 md:hidden" 
            onClick={() => setIsVisible(false)}
          />
          
          {/* Tooltip */}
          <div
            ref={tooltipRef}
            onMouseEnter={handleTooltipMouseEnter}
            onMouseLeave={handleTooltipMouseLeave}
            className={cn(
              'absolute z-50 px-3 py-2 text-sm text-white bg-gray-900 rounded-md shadow-lg',
              'max-w-xs break-words',
              'animate-in fade-in-0 zoom-in-95',
              position,
              className
            )}
          >
            {content}
            {/* Arrow */}
            <div 
              className={cn(
                'absolute w-0 h-0 border-4',
                arrow
              )}
            />
          </div>
        </>
      )}
    </div>
  );
};

export default Tooltip;