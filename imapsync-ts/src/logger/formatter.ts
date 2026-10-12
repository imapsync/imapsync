export function formatTimestamp(): string {
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, '0');
  const mm = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');
  return `[${hh}:${mm}:${ss}]`;
}

export function formatProgress(folder: string, current: number, total: number): string {
  return `[${current}/${total}] ${folder}`;
}

export function formatSummary(data: {
  copied: number;
  skipped: number;
  deleted: number;
  errors: number;
  elapsedMs: number;
}): string {
  const elapsed = (data.elapsedMs / 1000).toFixed(1);
  return `Sync complete: ${data.copied} copied, ${data.skipped} skipped, ${data.deleted} deleted, ${data.errors} errors (${elapsed}s)`;
}
