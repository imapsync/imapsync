import { createLogger } from '../../logger/index.js';

function collectOutput(fn: () => void): string {
  const lines: string[] = [];
  const orig = console.log;
  console.log = (...args: unknown[]) => lines.push(args.join(' '));
  try { fn(); } finally { console.log = orig; }
  return lines.join('\n');
}

test('info logs with timestamp', () => {
  const logger = createLogger({ verbose: false });
  const output = collectOutput(() => logger.info('hello'));
  expect(output).toMatch(/^\[\d{2}:\d{2}:\d{2}\] hello$/);
});

test('progress logs folder count', () => {
  const logger = createLogger({ verbose: false });
  const output = collectOutput(() => logger.progress('INBOX', 1, 10));
  expect(output).toContain('INBOX');
  expect(output).toContain('1/10');
});

test('summary shows copy and skip counts', () => {
  const logger = createLogger({ verbose: false });
  const result = {
    state: {
      foldersProcessed: 5,
      messagesCopied: 100,
      messagesSkipped: 20,
      messagesDeleted: 0,
      errors: [],
      startTime: new Date(),
    },
    success: true,
    exitCode: 0,
  };
  const output = collectOutput(() => logger.summary(result));
  expect(output).toContain('100 copied');
  expect(output).toContain('20 skipped');
  expect(output).toContain('0 errors');
});

test('error logs with ERROR prefix', () => {
  const logger = createLogger({ verbose: false });
  const output = collectOutput(() => logger.error('bad thing', new Error('boom')));
  expect(output).toContain('ERROR');
  expect(output).toContain('bad thing');
});
