import type { SyncResult } from '../types/sync.js';
import { formatTimestamp, formatProgress, formatSummary } from './formatter.js';

export interface Logger {
  info(msg: string): void;
  warn(msg: string): void;
  error(msg: string, err?: Error): void;
  progress(folder: string, current: number, total: number): void;
  summary(result: SyncResult): void;
}

export function createLogger(_opts: { verbose: boolean }): Logger {
  return {
    info(msg: string) {
      console.log(`${formatTimestamp()} ${msg}`);
    },
    warn(msg: string) {
      console.log(`${formatTimestamp()} WARN: ${msg}`);
    },
    error(msg: string, err?: Error) {
      const detail = err ? `: ${err.message}` : '';
      console.log(`${formatTimestamp()} ERROR: ${msg}${detail}`);
    },
    progress(folder, current, total) {
      console.log(`${formatTimestamp()} ${formatProgress(folder, current, total)}`);
    },
    summary(result) {
      const elapsed = Date.now() - result.state.startTime.getTime();
      console.log(
        `${formatTimestamp()} ${formatSummary({
          copied: result.state.messagesCopied,
          skipped: result.state.messagesSkipped,
          deleted: result.state.messagesDeleted,
          errors: result.state.errors.length,
          elapsedMs: elapsed,
        })}`
      );
    },
  };
}
