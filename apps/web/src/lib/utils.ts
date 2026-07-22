import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** Shared tactile press feedback for hand-rolled buttons (the shadcn `Button` gets this via buttonVariants). */
export const pressFeedback = "transition-transform duration-150 active:scale-[0.97]";
