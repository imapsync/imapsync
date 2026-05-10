import type { SyncConfig } from '../types/sync.js';

export function validateConfig(config: SyncConfig): void {
  if (!config.source.host) throw new Error('source host is required');
  if (!config.source.user) throw new Error('source user is required');
  if (!config.source.auth.pass && !config.source.auth.accessToken) {
    throw new Error('source password or accessToken is required');
  }
  if (!config.dest.host) throw new Error('dest host is required');
  if (!config.dest.user) throw new Error('dest user is required');
  if (!config.dest.auth.pass && !config.dest.auth.accessToken) {
    throw new Error('dest password or accessToken is required');
  }
}
