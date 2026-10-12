import type { MessageInfo } from '../types/account.js';

export function shouldSkipMessage(
  msg: MessageInfo,
  opts: { skipLarge?: number; skipRegex?: RegExp[] },
): boolean {
  if (opts.skipLarge && msg.size > opts.skipLarge) return true;
  if (opts.skipRegex && opts.skipRegex.length > 0) {
    const subject = msg.envelope?.subject ?? '';
    const from = msg.envelope?.from.map(a => a.address).join(', ') ?? '';
    if (opts.skipRegex.some(re => re.test(subject) || re.test(from))) return true;
  }
  return false;
}
