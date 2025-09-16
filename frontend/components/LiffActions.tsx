"use client";
import { useState } from 'react';
import { liffService } from '@/lib/line/liff-service';

export function LiffActionsBar() {
  const [isSharing, setIsSharing] = useState(false);

  // Only show if we're in LINE Mini App
  if (typeof window === 'undefined' || !liffService.isInLiff()) {
    return null;
  }

  const handleShare = async () => {
    setIsSharing(true);
    try {
      await liffService.shareMessage([{
        type: 'text',
        text: 'Check out this amazing Mini Dapp on LINE! 🚀'
      }]);
    } catch (err) {
      console.error('Share failed:', err);
    } finally {
      setIsSharing(false);
    }
  };

  const handleMinimize = () => {
    liffService.minimizeWindow();
  };

  const handleRefresh = () => {
    window.location.reload();
  };

  return (
    <div className="fixed bottom-20 right-4 flex flex-col gap-2 z-50">
      <button
        onClick={handleShare}
        disabled={isSharing}
        className="p-3 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-800 rounded-full shadow-lg transition-all"
        aria-label="Share"
      >
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path d="M15 8a3 3 0 10-2.977-2.63l-4.94 2.47a3 3 0 100 4.319l4.94 2.47a3 3 0 10.895-1.789l-4.94-2.47a3.027 3.027 0 000-.74l4.94-2.47C13.456 7.68 14.19 8 15 8z" />
        </svg>
      </button>

      <button
        onClick={handleMinimize}
        className="p-3 bg-gray-700 hover:bg-gray-600 rounded-full shadow-lg transition-all"
        aria-label="Minimize"
      >
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clipRule="evenodd" />
        </svg>
      </button>

      <button
        onClick={handleRefresh}
        className="p-3 bg-gray-700 hover:bg-gray-600 rounded-full shadow-lg transition-all"
        aria-label="Refresh"
      >
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
        </svg>
      </button>
    </div>
  );
}