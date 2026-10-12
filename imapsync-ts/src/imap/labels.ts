import type { ImapClient } from './connection.js';
import type { Logger } from '../logger/index.js';
import { diffFlags } from './flags.js';

export async function syncLabels(
  client: ImapClient,
  folder: string,
  uid: number,
  srcLabels: Set<string>,
  dstLabels: Set<string>,
  logger: Logger,
): Promise<void> {
  const diff = diffFlags(srcLabels, dstLabels);
  if (diff.toAdd.length > 0) {
    logger.info(`Adding labels to ${folder} uid=${uid}: ${diff.toAdd.join(', ')}`);
    await client.addLabels(folder, uid, diff.toAdd);
  }
}
