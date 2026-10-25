/**
 * Service worker registration (production builds only): offline play, the COOP/COEP headers
 * on hosts that cannot send them, and update notices.
 */

type UpdateListener = (apply: () => void) => void;

const RELOAD_FLAG = "shogi.sw-reload";
const updateListeners: UpdateListener[] = [];
let pendingUpdate: (() => void) | null = null;

/** Called when a new version has been downloaded; `apply` switches to it (reloading the page). */
export function onUpdateAvailable(listener: UpdateListener): void {
  updateListeners.push(listener);
  if (pendingUpdate) listener(pendingUpdate);
}

function announce(worker: ServiceWorker): void {
  pendingUpdate = () => {
    navigator.serviceWorker.addEventListener("controllerchange", () => location.reload(), { once: true });
    worker.postMessage({ type: "skip-waiting" });
  };
  for (const listener of updateListeners) listener(pendingUpdate);
}

/**
 * An update is only worth announcing when the page is already run by this app's service worker.
 * (When it replaces the coi-serviceworker of older versions, it takes over by itself.)
 */
function isUpdate(): boolean {
  return navigator.serviceWorker.controller?.scriptURL.endsWith("/sw.js") ?? false;
}

function watchForUpdates(registration: ServiceWorkerRegistration): void {
  if (registration.waiting && isUpdate()) announce(registration.waiting);
  registration.addEventListener("updatefound", () => {
    const worker = registration.installing;
    worker?.addEventListener("statechange", () => {
      // "installed" with an existing controller = an update is waiting (not the first install).
      if (worker.state === "installed" && isUpdate()) announce(worker);
    });
  });
  // Look for a new version whenever the player comes back to the app.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") void registration.update().catch(() => undefined);
  });
}

function waitForController(timeoutMs: number): Promise<boolean> {
  if (navigator.serviceWorker.controller) return Promise.resolve(true);
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(false), timeoutMs);
    navigator.serviceWorker.addEventListener(
      "controllerchange",
      () => {
        clearTimeout(timer);
        resolve(true);
      },
      { once: true },
    );
  });
}

function sessionFlag(set?: boolean): boolean {
  try {
    if (set) sessionStorage.setItem(RELOAD_FLAG, "1");
    return sessionStorage.getItem(RELOAD_FLAG) === "1";
  } catch {
    return true; // without sessionStorage we cannot guard against reload loops, so never reload
  }
}

/**
 * Registers the service worker. Resolves when the game can start. On the first visit to a host
 * without COOP/COEP headers, the page is reloaded once under the service worker so the AI can
 * run; if that is not possible (service workers blocked), the game starts without the AI.
 */
export async function setupServiceWorker(): Promise<void> {
  if (!import.meta.env.PROD || !("serviceWorker" in navigator) || !self.isSecureContext) return;
  let registration: ServiceWorkerRegistration | undefined;
  try {
    // Where service workers are blocked the registration may never settle, so do not wait forever.
    const timeout = new Promise<never>((_, reject) => setTimeout(() => reject(new Error("timeout")), 5000));
    registration = await Promise.race([navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`), timeout]);
  } catch {
    return;
  }
  if (!registration) return; // blocked by the browser or an extension
  watchForUpdates(registration);
  if (self.crossOriginIsolated || sessionFlag()) return;
  if (await waitForController(8000)) {
    sessionFlag(true);
    location.reload();
    await new Promise(() => undefined); // the page is going away
  }
}

// ---------------------------------------------------------------- install button

/** Chrome/Edge/Android event offering to install the app (not in the standard DOM typings). */
interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

type InstallListener = (install: (() => Promise<void>) | null) => void;

let installEvent: BeforeInstallPromptEvent | null = null;
const installListeners: InstallListener[] = [];

function notifyInstall(): void {
  const install = installEvent
    ? async () => {
        const event = installEvent!;
        installEvent = null;
        notifyInstall();
        await event.prompt();
      }
    : null;
  for (const listener of installListeners) listener(install);
}

// Registered at module load: the browser may fire the event before the game screen exists.
window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  installEvent = event as BeforeInstallPromptEvent;
  notifyInstall();
});
window.addEventListener("appinstalled", () => {
  installEvent = null;
  notifyInstall();
});

/** Called with an `install` function while the browser offers installation, null otherwise. */
export function onInstallAvailable(listener: InstallListener): void {
  installListeners.push(listener);
  notifyInstall();
}
