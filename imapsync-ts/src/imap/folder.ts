import type { FolderInfo } from '../types/account.js';
import type { FolderPair } from '../types/sync.js';

export function filterFolders(
  folders: FolderInfo[],
  opts: { include?: RegExp[]; exclude?: RegExp[] },
): FolderInfo[] {
  let result = folders;
  if (opts.include && opts.include.length > 0) {
    result = result.filter(f => opts.include!.some(re => re.test(f.path)));
  }
  if (opts.exclude && opts.exclude.length > 0) {
    result = result.filter(f => !opts.exclude!.some(re => re.test(f.path)));
  }
  return result;
}

export function mapFolderName(path: string, srcDelimiter: string, dstDelimiter: string): string {
  if (srcDelimiter === dstDelimiter) return path;
  return path.split(srcDelimiter).join(dstDelimiter);
}

export async function resolveFolderPairs(
  sourceFolders: FolderInfo[],
  destFolders: FolderInfo[],
  opts: { include?: RegExp[]; exclude?: RegExp[] },
): Promise<FolderPair[]> {
  const filtered = filterFolders(sourceFolders, opts);
  const destPaths = new Set(destFolders.map(f => f.path));

  return filtered.map(src => {
    const dest = destPaths.has(src.path)
      ? destFolders.find(f => f.path === src.path)!
      : { ...src, subscribed: false };
    return { source: src, dest };
  });
}
