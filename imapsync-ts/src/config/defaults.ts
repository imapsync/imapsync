import type { SyncConfig } from '../types/sync.js';
import type { ImapAccount } from '../types/account.js';
import { gmailPreset, exchangePreset, office365Preset } from './presets.js';
import { homedir } from 'node:os';
import { join } from 'node:path';

export function buildDefaultConfig(accounts: {
  source: ImapAccount;
  dest: ImapAccount;
}): SyncConfig {
  return {
    source: accounts.source,
    dest: accounts.dest,
    folders: {
      recursive: true,
    },
    messages: {
      dryRun: false,
      deleteSource: false,
      deleteDuplicates: false,
    },
    flags: {
      sync: true,
      syncAfterCopy: true,
    },
    labels: {
      sync: false,
    },
    cache: {
      enabled: true,
      path: join(homedir(), '.imapsync', 'cache.db'),
    },
    verbose: false,
  };
}

export function mergePresets(
  config: SyncConfig,
  presets: { source?: string; dest?: string },
): void {
  if (presets.source === 'gmail') Object.assign(config.source, gmailPreset());
  if (presets.source === 'exchange' || presets.source === 'office365') Object.assign(config.source, exchangePreset());
  if (presets.dest === 'gmail') Object.assign(config.dest, gmailPreset());
  if (presets.dest === 'exchange' || presets.dest === 'office365') Object.assign(config.dest, office365Preset());
}
