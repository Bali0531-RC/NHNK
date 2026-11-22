// NEVER log tokens, passwords, cookies or bodies. paths, statuses and counts only

declare const __DEV__: boolean;

const PREFIX = '[NHNK]';
const isDev = typeof __DEV__ !== 'undefined' ? __DEV__ : false;

function line(tag: string, msg: string): string {
  return `${PREFIX} ${tag} :: ${msg}`;
}

function errText(err: unknown): string {
  if (err instanceof Error) return `${err.name}: ${err.message}`;
  if (typeof err === 'string') return err;
  try {
    return JSON.stringify(err);
  } catch {
    return String(err);
  }
}

export const log = {
  debug(tag: string, msg: string, ...rest: unknown[]): void {
    if (isDev) console.log(line(tag, msg), ...rest);
  },
  info(tag: string, msg: string, ...rest: unknown[]): void {
    if (isDev) console.log(line(tag, msg), ...rest);
  },
  // expected failures stay in metro, no logbox spam
  warn(tag: string, msg: string, ...rest: unknown[]): void {
    if (isDev) console.log(`WARN ${line(tag, msg)}`, ...rest.map(errText));
    else console.warn(line(tag, msg), ...rest.map(errText));
  },
  error(tag: string, msg: string, err?: unknown): void {
    const detail = err === undefined ? '' : errText(err);
    if (isDev) console.log(`ERROR ${line(tag, msg)}`, detail);
    else console.error(line(tag, msg), detail);
  },
};