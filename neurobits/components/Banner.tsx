'use client';

import { useState, useEffect } from 'react';
import { X, Sparkles } from 'lucide-react';

interface BannerProps {
  message: string;
  storageKey?: string;
}

export default function Banner({ message, storageKey = 'banner-dismissed' }: BannerProps) {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const dismissed = localStorage.getItem(storageKey);
    if (!dismissed) {
      setIsVisible(true);
    }
  }, [storageKey]);

  const handleDismiss = () => {
    setIsVisible(false);
    localStorage.setItem(storageKey, 'true');
  };

  if (!isVisible) return null;

  return (
    <div
      className="fixed top-0 left-0 right-0 z-50 animate-slide-down"
      style={{
        background: 'linear-gradient(135deg, #8B5CF6 0%, #7C3AED 50%, #6D28D9 100%)',
        borderBottom: '2px solid rgba(233, 213, 255, 0.2)',
        boxShadow: '0 4px 24px rgba(124, 58, 237, 0.3)',
        pointerEvents: 'auto'
      }}
    >
      <div className="px-8 py-5 flex items-center justify-center relative">
        <div className="flex items-center justify-center gap-3">
          <div className="flex items-center justify-center w-8 h-8 rounded-full bg-white/20 backdrop-blur-sm">
            <Sparkles className="w-4 h-4 text-white" strokeWidth={2.5} />
          </div>
          <p className="text-white font-semibold text-base md:text-lg tracking-tight">
            {message}
          </p>
          <div className="flex items-center justify-center w-8 h-8 rounded-full bg-white/20 backdrop-blur-sm">
            <Sparkles className="w-4 h-4 text-white" strokeWidth={2.5} />
          </div>
        </div>
        <button
          onClick={handleDismiss}
          className="absolute right-8 flex items-center justify-center w-8 h-8 hover:bg-white/20 rounded-lg transition-all duration-200 hover:scale-105"
          aria-label="Dismiss banner"
        >
          <X className="w-5 h-5 text-white" strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
}
