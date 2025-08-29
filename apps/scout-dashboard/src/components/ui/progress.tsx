"use client"

import * as React from "react"
import * as ProgressPrimitive from "@radix-ui/react-progress"
import { cn } from "@/lib/utils"

const Progress = React.forwardRef<
  React.ElementRef<typeof ProgressPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof ProgressPrimitive.Root> & {
    variant?: 'default' | 'success' | 'warning' | 'error'
    showValue?: boolean
  }
>(({ className, value, variant = 'default', showValue = false, ...props }, ref) => {
  const getVariantStyles = () => {
    switch (variant) {
      case 'success':
        return {
          root: 'bg-green-100',
          indicator: 'bg-green-600'
        }
      case 'warning':
        return {
          root: 'bg-yellow-100',
          indicator: 'bg-yellow-600'
        }
      case 'error':
        return {
          root: 'bg-red-100',
          indicator: 'bg-red-600'
        }
      default:
        return {
          root: 'bg-secondary',
          indicator: 'bg-primary'
        }
    }
  }

  const styles = getVariantStyles()

  return (
    <div className="relative">
      <ProgressPrimitive.Root
        ref={ref}
        className={cn(
          "relative h-4 w-full overflow-hidden rounded-full",
          styles.root,
          className
        )}
        {...props}
      >
        <ProgressPrimitive.Indicator
          className={cn(
            "h-full w-full flex-1 transition-all duration-300 ease-in-out",
            styles.indicator
          )}
          style={{ transform: `translateX(-${100 - (value || 0)}%)` }}
        />
      </ProgressPrimitive.Root>
      {showValue && (
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-xs font-medium text-foreground/70">
            {Math.round(value || 0)}%
          </span>
        </div>
      )}
    </div>
  )
})
Progress.displayName = ProgressPrimitive.Root.displayName

export { Progress }