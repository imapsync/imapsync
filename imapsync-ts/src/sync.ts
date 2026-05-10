import type { SyncConfig, SyncState, SyncResult, FolderPair } from './types/sync.js';
import type { MessageInfo } from './types/account.js';
import { ImapClient } from './imap/connection.js';
import { resolveFolderPairs, mapFolderName } from './imap/folder.js';
import { findMessagesToCopy } from './imap/message.js';
import { diffFlags } from './imap/flags.js';
import { syncLabels } from './imap/labels.js';
import { CacheStore } from './cache/store.js';
import { createLogger, type Logger } from './logger/index.js';
import { createSyncState, buildResult } from './types/sync.js';
import { MessageCopyError, FolderError, CacheError, classifyError } from './errors.js';
import type { ErrorRecord } from './types/sync.js';

export async function runSync(config: SyncConfig): Promise<SyncResult> {
  const state = createSyncState();
  const logger = createLogger({ verbose: config.verbose });

  // 1. Connect to both IMAP servers
  logger.info(`Connecting to ${config.source.host}:${config.source.port} ...`);
  const source = new ImapClient(config.source);
  try {
    await source.connect();
    logger.info(`Connected to source.`);
  } catch (err) {
    logger.error('Source connection failed', err instanceof Error ? err : undefined);
    recordError(state, err, logger);
    return buildResult(state);
  }

  logger.info(`Connecting to ${config.dest.host}:${config.dest.port} ...`);
  const dest = new ImapClient(config.dest);
  try {
    await dest.connect();
    logger.info(`Connected to dest.`);
  } catch (err) {
    logger.error('Dest connection failed', err instanceof Error ? err : undefined);
    recordError(state, err, logger);
    await source.logout();
    return buildResult(state);
  }

  // 2. Enumerate and map folders
  let folderPairs: FolderPair[] = [];
  try {
    const srcFolders = await source.listFolders();
    const dstFolders = await dest.listFolders();
    folderPairs = await resolveFolderPairs(srcFolders, dstFolders, config.folders);
    logger.info(`Found ${srcFolders.length} source folders, ${folderPairs.length} to sync after filters`);
  } catch (err) {
    logger.error('Folder enumeration failed', err instanceof Error ? err : undefined);
    recordError(state, err, logger);
    await source.logout();
    await dest.logout();
    return buildResult(state);
  }

  // 3. Initialize cache
  let cache: CacheStore | null = null;
  if (config.cache.enabled) {
    try {
      cache = new CacheStore(config.cache.path);
      cache.open();
    } catch (err) {
      logger.warn('Cache initialization failed, continuing without cache');
      cache = null;
      recordError(state, new CacheError('Cache init failed', err instanceof Error ? err : undefined), logger);
    }
  }

  // 4. Sync each folder
  let folderIndex = 0;
  for (const pair of folderPairs) {
    folderIndex++;
    logger.progress(pair.source.path, folderIndex, folderPairs.length);
    try {
      await syncFolder(pair, source, dest, cache, config, state, logger);
    } catch (err) {
      if (err instanceof FolderError) {
        logger.warn(`Skipping folder ${err.folder}: ${err.message}`);
        recordError(state, err, logger);
      } else {
        logger.error(`Folder sync failed: ${pair.source.path}`, err instanceof Error ? err : undefined);
        recordError(state, err, logger);
      }
    }
  }

  // 5. Summary + cleanup
  const result = buildResult(state);
  logger.summary(result);
  if (cache) cache.close();
  await source.logout();
  await dest.logout();
  return result;
}

async function syncFolder(
  pair: FolderPair,
  source: ImapClient,
  dest: ImapClient,
  cache: CacheStore | null,
  config: SyncConfig,
  state: SyncState,
  logger: Logger,
): Promise<void> {
  const srcPath = pair.source.path;
  const dstPath = pair.dest.path;

  // Map folder name if delimiters differ
  const mappedDstPath = pair.source.delimiter !== pair.dest.delimiter
    ? mapFolderName(srcPath, pair.source.delimiter, pair.dest.delimiter)
    : dstPath;

  // Ensure destination folder exists
  try {
    await dest.ensureFolder(mappedDstPath);
  } catch (err) {
    throw new FolderError(`Cannot create folder ${mappedDstPath}`, mappedDstPath, err instanceof Error ? err : undefined);
  }

  // Get folder status for uidValidity
  let srcStatus: { uidValidity: string };
  try {
    srcStatus = await source.folderStatus(srcPath);
  } catch (err) {
    throw new FolderError(`Cannot get status for ${srcPath}`, srcPath, err instanceof Error ? err : undefined);
  }

  // List messages on both sides
  const srcMsgs = await listFolderMessages(source, srcPath);
  const dstMsgs = await listFolderMessages(dest, mappedDstPath);

  logger.info(`${srcPath}: ${srcMsgs.length} source, ${dstMsgs.length} dest`);

  // Determine which messages to copy
  const merge = findMessagesToCopy(srcMsgs, dstMsgs, cache, srcPath, {
    sync: config.flags.sync,
    syncAfterCopy: config.flags.syncAfterCopy,
    skipLarge: config.messages.skipLarge,
    skipRegex: config.messages.skipRegex,
  });

  logger.info(`${srcPath}: ${merge.toCopy.length} to copy, ${merge.alreadySynced.length} already synced, ${merge.duplicates.length} duplicates`);

  // Copy messages
  for (const msg of merge.toCopy) {
    try {
      if (config.messages.dryRun) {
        logger.info(`[DRY] Would copy uid=${msg.uid} from ${srcPath}`);
        state.messagesCopied++;
        continue;
      }

      const raw = await source.fetchMessageSource(msg.uid, srcPath);
      const flags = Array.from(msg.flags);
      const result = await dest.appendMessage(mappedDstPath, raw, flags, msg.internalDate);

      // Update cache
      if (cache && result.uid) {
        cache.setMapping(srcPath, msg.uid, result.uid, srcStatus.uidValidity);
        if (msg.envelope?.messageId) {
          cache.setMessageHash(srcPath, msg.uid, msg.envelope.messageId, srcStatus.uidValidity);
        }
      }

      // Sync flags after copy
      if (config.flags.syncAfterCopy) {
        const dstMsg = dstMsgs.find(m => m.uid === result.uid);
        if (dstMsg) {
          const flagDiff = diffFlags(msg.flags, dstMsg.flags);
          if (flagDiff.toAdd.length > 0) {
            await dest.addFlags(mappedDstPath, result.uid, flagDiff.toAdd);
          }
        }
      }

      // Sync labels after copy (Gmail)
      if (config.labels.sync && msg.labels) {
        const dstMsg = dstMsgs.find(m => m.uid === result.uid);
        if (dstMsg && dstMsg.labels) {
          await syncLabels(dest, mappedDstPath, result.uid, msg.labels, dstMsg.labels, logger);
        }
      }

      state.messagesCopied++;
    } catch (err) {
      const copyErr = new MessageCopyError(
        err instanceof Error ? err.message : String(err),
        srcPath,
        msg.uid,
        err instanceof Error ? err : undefined,
      );
      logger.warn(`Failed to copy uid=${msg.uid} from ${srcPath}: ${copyErr.message}`);
      recordError(state, copyErr, logger);
    }
  }

  state.messagesSkipped += merge.alreadySynced.length + merge.duplicates.length;

  // Handle deletes
  if (config.messages.deleteSource && !config.messages.dryRun) {
    for (const msg of merge.alreadySynced) {
      try {
        await source.deleteMessage(srcPath, msg.uid);
        state.messagesDeleted++;
      } catch (err) {
        logger.warn(`Failed to delete uid=${msg.uid} from ${srcPath}`);
        recordError(state, err, logger);
      }
    }
  }

  if (config.messages.deleteDuplicates && !config.messages.dryRun) {
    for (const msg of merge.duplicates) {
      const dstUid = cache?.getMapping(srcPath, msg.uid);
      if (dstUid) {
        try {
          await dest.deleteMessage(mappedDstPath, dstUid);
          state.messagesDeleted++;
        } catch (err) {
          logger.warn(`Failed to delete duplicate uid=${dstUid} from ${mappedDstPath}`);
          recordError(state, err, logger);
        }
      }
    }
  }

  state.foldersProcessed++;
}

async function listFolderMessages(client: ImapClient, folder: string): Promise<MessageInfo[]> {
  const imapFlowClient = client.getClient();
  const lock = await imapFlowClient.getMailboxLock(folder);
  try {
    const messages: MessageInfo[] = [];
    for await (const msg of imapFlowClient.fetch('1:*', {
      uid: true,
      flags: true,
      internalDate: true,
      size: true,
      envelope: true,
      labels: true,
    })) {
      messages.push({
        uid: msg.uid!,
        flags: msg.flags ?? new Set(),
        internalDate: msg.internalDate instanceof Date ? msg.internalDate : new Date(),
        size: msg.size ?? 0,
        envelope: msg.envelope ? {
          subject: msg.envelope.subject ?? '',
          from: (msg.envelope.from ?? []).map(a => ({ address: a.address ?? '' })),
          date: msg.envelope.date ?? new Date(),
          messageId: msg.envelope.messageId,
        } : undefined,
        labels: msg.labels,
      });
    }
    return messages;
  } finally {
    lock.release();
  }
}

function recordError(state: SyncState, err: unknown, _logger: Logger): void {
  const error = err instanceof Error ? err : new Error(String(err));
  state.errors.push({
    type: classifyError(error),
    message: error.message,
    timestamp: new Date(),
  });
}
