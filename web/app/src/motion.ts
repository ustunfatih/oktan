/** True when the phone asks for less motion (Settings → Accessibility → Reduce Motion). */
export const reduceMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches;
