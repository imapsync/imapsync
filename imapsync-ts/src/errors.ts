export class ImapConnectionError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'ImapConnectionError';
  }
}

export class ImapAuthError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'ImapAuthError';
  }
}

export class MessageCopyError extends Error {
  constructor(
    message: string,
    public readonly folder: string,
    public readonly uid: number,
    public readonly cause?: Error,
  ) {
    super(message);
    this.name = 'MessageCopyError';
  }
}

export class FolderError extends Error {
  constructor(message: string, public readonly folder: string, public readonly cause?: Error) {
    super(message);
    this.name = 'FolderError';
  }
}

export class CacheError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'CacheError';
  }
}

import type { ErrorType } from './types/sync.js';

export function classifyError(err: Error): ErrorType {
  if (err instanceof ImapAuthError) return 'auth';
  if (err instanceof ImapConnectionError) return 'connection';
  if (err instanceof MessageCopyError) return 'message';
  if (err instanceof FolderError) return 'folder';
  if (err instanceof CacheError) return 'cache';
  return 'unknown';
}
