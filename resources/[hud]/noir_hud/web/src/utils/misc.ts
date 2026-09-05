/* eslint-disable @typescript-eslint/no-explicit-any */
// Will return whether the current environment is in a regular browser
// and not CEF
export const isEnvBrowser = (): boolean => !(window as any).invokeNative;
export const isDevPreview = (): boolean => import.meta.env.DEV && isEnvBrowser();

export const noop = () => {};
