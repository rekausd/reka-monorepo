import { getLiff } from './liffClient';

/**
 * Share text via LINE's share target picker
 * Requires LIFF Action Button to be enabled in settings
 */
export async function shareText(text: string) {
  const lf = getLiff();
  if (lf.isApiAvailable('shareTargetPicker')) {
    await lf.shareTargetPicker([{ type: 'text', text }]);
  } else {
    console.warn('Share target picker is not available');
  }
}

/**
 * Share URL via LINE's share target picker
 */
export async function shareUrl(url: string, title?: string) {
  const lf = getLiff();
  if (lf.isApiAvailable('shareTargetPicker')) {
    await lf.shareTargetPicker([{
      type: 'flex',
      altText: title || 'Check this out!',
      contents: {
        type: 'bubble',
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [{
            type: 'button',
            action: {
              type: 'uri',
              label: title || 'Open Link',
              uri: url
            }
          }]
        }
      }
    }]);
  } else {
    console.warn('Share target picker is not available');
  }
}

/**
 * Minimize the LIFF webview
 * Requires LIFF Minimization to be enabled
 */
export function minimizeWebview() {
  const lf = getLiff() as any;
  if (lf.liffWindow?.minimize) {
    lf.liffWindow.minimize();
  } else {
    console.warn('LIFF minimize is not available');
  }
}

/**
 * Refresh the webview
 */
export function refreshWebview() {
  window.location.reload();
}

/**
 * Close the LIFF app
 */
export function closeLiffApp() {
  const lf = getLiff();
  lf.closeWindow();
}