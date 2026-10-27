/** The phone's side of fill-up reminders: permission, the push subscription, and what this browser supports. */

export const pushSupported = () => "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;

/** On the iPhone, web push only works for an app added to the Home Screen. */
export const needsHomeScreen = () => /iPhone|iPad|iPod/.test(navigator.userAgent) && !(matchMedia("(display-mode: standalone)").matches || (navigator as { standalone?: boolean }).standalone === true);

const fromB64u = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

export async function currentSubscription(): Promise<PushSubscription | null> {
  if (!pushSupported()) return null;
  const reg = await navigator.serviceWorker.ready;
  return reg.pushManager.getSubscription();
}

/** Asks for permission, then subscribes this phone. Throws with a sentence the user can act on. */
export async function subscribeThisPhone(publicKey: string): Promise<PushSubscription> {
  const permission = await Notification.requestPermission();
  if (permission !== "granted") throw new Error("Notifications are off for Oktan. Allow them in your phone's settings, then try again.");
  const reg = await navigator.serviceWorker.ready;
  return reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: fromB64u(publicKey) });
}

export async function unsubscribeThisPhone(): Promise<string | null> {
  const sub = await currentSubscription();
  if (!sub) return null;
  const endpoint = sub.endpoint;
  await sub.unsubscribe();
  return endpoint;
}
