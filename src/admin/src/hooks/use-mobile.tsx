import * as React from "react";

const MOBILE_BREAKPOINT = 768;
const QUERY = `(max-width: ${MOBILE_BREAKPOINT - 1}px)`;

/**
 * useSyncExternalStore, not useState + useEffect — matchMedia is an external
 * source. The effect-based variant first rendered a placeholder value and then
 * immediately set the real one, producing a cascade of renders (react-hooks
 * reports this as set-state-in-effect).
 */
function subscribe(onChange: () => void) {
  const mql = window.matchMedia(QUERY);
  mql.addEventListener("change", onChange);
  return () => mql.removeEventListener("change", onChange);
}

const getSnapshot = () => window.matchMedia(QUERY).matches;

export function useIsMobile() {
  return React.useSyncExternalStore(subscribe, getSnapshot);
}
