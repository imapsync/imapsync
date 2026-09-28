import { syncLabels } from '../../imap/labels.js';
import type { ImapClient } from '../../imap/connection.js';
import type { Logger } from '../../logger/index.js';

function makeClient(addLabels?: jest.Mock): { client: ImapClient; addLabels: jest.Mock } {
  const fn = addLabels ?? jest.fn().mockResolvedValue(undefined);
  const client = { addLabels: fn } as unknown as ImapClient;
  return { client, addLabels: fn };
}

function makeLogger(info?: jest.Mock): { logger: Logger; info: jest.Mock } {
  const fn = info ?? jest.fn();
  const logger = { info: fn } as unknown as Logger;
  return { logger, info: fn };
}

test('syncLabels calls addLabels with labels that differ from dest', async () => {
  const { client, addLabels } = makeClient();
  const { logger } = makeLogger();
  const srcLabels = new Set(['Important', 'Work', 'Personal']);
  const dstLabels = new Set(['Work']);

  await syncLabels(client, 'INBOX', 42, srcLabels, dstLabels, logger);

  expect(addLabels).toHaveBeenCalledTimes(1);
  expect(addLabels).toHaveBeenCalledWith('INBOX', 42, expect.arrayContaining(['Important', 'Personal']));
});

test('syncLabels is a no-op when labels are identical', async () => {
  const { client, addLabels } = makeClient();
  const { logger } = makeLogger();
  const srcLabels = new Set(['Important', 'Work']);
  const dstLabels = new Set(['Important', 'Work']);

  await syncLabels(client, 'INBOX', 10, srcLabels, dstLabels, logger);

  expect(addLabels).not.toHaveBeenCalled();
});

test('syncLabels is a no-op when source is empty and dest is non-empty', async () => {
  const { client, addLabels } = makeClient();
  const { logger } = makeLogger();
  const srcLabels = new Set<string>();
  const dstLabels = new Set(['Important', 'Work']);

  await syncLabels(client, 'INBOX', 5, srcLabels, dstLabels, logger);

  expect(addLabels).not.toHaveBeenCalled();
});

test('syncLabels adds all source labels when dest is empty', async () => {
  const { client, addLabels } = makeClient();
  const { logger } = makeLogger();
  const srcLabels = new Set(['Important', 'Work', 'Personal']);
  const dstLabels = new Set<string>();

  await syncLabels(client, 'Archive', 99, srcLabels, dstLabels, logger);

  expect(addLabels).toHaveBeenCalledTimes(1);
  expect(addLabels).toHaveBeenCalledWith('Archive', 99, expect.arrayContaining(['Important', 'Work', 'Personal']));
});

test('syncLabels calls logger.info when labels are added', async () => {
  const { client } = makeClient();
  const { logger, info } = makeLogger();
  const srcLabels = new Set(['Todo']);
  const dstLabels = new Set<string>();

  await syncLabels(client, 'INBOX', 7, srcLabels, dstLabels, logger);

  expect(info).toHaveBeenCalledTimes(1);
  expect(info).toHaveBeenCalledWith('Adding labels to INBOX uid=7: Todo');
});

test('syncLabels does not call logger.info when labels are identical', async () => {
  const { client } = makeClient();
  const { logger, info } = makeLogger();
  const srcLabels = new Set(['Important']);
  const dstLabels = new Set(['Important']);

  await syncLabels(client, 'INBOX', 3, srcLabels, dstLabels, logger);

  expect(info).not.toHaveBeenCalled();
});
