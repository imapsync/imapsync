import type { MessageInfo } from '../types/account.js';
import type { CacheStore } from '../cache/store.js';
import { shouldSkipMessage } from './search.js';

interface MergeResult {
  toCopy: MessageInfo[];
  alreadySynced: MessageInfo[];
  duplicates: MessageInfo[];
}

export function findMessagesToCopy(
  srcMsgs: MessageInfo[],
  dstMsgs: MessageInfo[],
  cache: CacheStore | null,
  folder: string,
  flagsConfig: { sync: boolean; syncAfterCopy: boolean; skipLarge?: number; skipRegex?: RegExp[] } = { sync: true, syncAfterCopy: true },
): MergeResult {
  const toCopy: MessageInfo[] = [];
  const alreadySynced: MessageInfo[] = [];
  const duplicates: MessageInfo[] = [];

  const dstMessageIds = new Set<string>();
  for (const msg of dstMsgs) {
    const mid = msg.envelope?.messageId;
    if (mid) dstMessageIds.add(mid);
  }

  for (const msg of srcMsgs) {
    if (shouldSkipMessage(msg, { skipLarge: flagsConfig.skipLarge, skipRegex: flagsConfig.skipRegex })) {
      continue;
    }

    if (cache) {
      const mapped = cache.getMapping(folder, msg.uid);
      if (mapped !== null) {
        alreadySynced.push(msg);
        continue;
      }
    }

    const mid = msg.envelope?.messageId;
    if (mid && dstMessageIds.has(mid)) {
      duplicates.push(msg);
      continue;
    }

    toCopy.push(msg);
  }

  return { toCopy, alreadySynced, duplicates };
}
