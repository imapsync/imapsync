import type { ImapAccount, FolderInfo } from './account.js';

export interface SyncConfig {
  source: ImapAccount;
  dest: ImapAccount;
  folders: {
    include?: RegExp[];
    exclude?: RegExp[];
    recursive?: boolean;
  };
  messages: {
    skipLarge?: number;
    skipRegex?: RegExp[];
    dryRun?: boolean;
    deleteSource?: boolean;
    deleteDuplicates?: boolean;
  };
  flags: {
    sync: boolean;
    syncAfterCopy: boolean;
  };
  labels: {
    sync: boolean;
  };
  cache: {
    enabled: boolean;
    path: string;
  };
  verbose: boolean;
}

export interface ErrorRecord {
  type: ErrorType;
  message: string;
  folder?: string;
  uid?: number;
  timestamp: Date;
}

export type ErrorType = 'connection' | 'auth' | 'message' | 'folder' | 'cache' | 'unknown';

export interface SyncState {
  foldersProcessed: number;
  messagesCopied: number;
  messagesSkipped: number;
  messagesDeleted: number;
  errors: ErrorRecord[];
  startTime: Date;
}

export interface SyncResult {
  state: SyncState;
  success: boolean;
  exitCode: number;
}

export interface FolderPair {
  source: FolderInfo;
  dest: FolderInfo;
}

export function createSyncState(): SyncState {
  return {
    foldersProcessed: 0,
    messagesCopied: 0,
    messagesSkipped: 0,
    messagesDeleted: 0,
    errors: [],
    startTime: new Date(),
  };
}

export function buildResult(state: SyncState): SyncResult {
  return {
    state,
    success: state.errors.filter(e => e.type === 'connection' || e.type === 'auth').length === 0,
    exitCode: state.errors.filter(e => e.type === 'connection' || e.type === 'auth').length > 0
      ? state.errors.some(e => e.type === 'auth') ? 2 : 1
      : 0,
  };
}
