import { gmailPreset, exchangePreset } from '../../config/presets.js';
import { buildDefaultConfig, mergePresets } from '../../config/defaults.js';
import { validateConfig } from '../../config/validate.js';

test('gmailPreset returns correct host and port', () => {
  const preset = gmailPreset();
  expect(preset.host).toBe('imap.gmail.com');
  expect(preset.port).toBe(993);
  expect(preset.tls).toBe(true);
});

test('exchangePreset returns correct host', () => {
  const preset = exchangePreset();
  expect(preset.host).toBe('outlook.office365.com');
  expect(preset.port).toBe(993);
});

test('buildDefaultConfig sets sensible defaults', () => {
  const config = buildDefaultConfig({
    source: { host: 's1', port: 993, user: 'u1', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(config.flags.sync).toBe(true);
  expect(config.cache.enabled).toBe(true);
  expect(config.messages.dryRun).toBe(false);
  expect(config.verbose).toBe(false);
});

test('mergePresets applies gmail preset to source', () => {
  const config = buildDefaultConfig({
    source: { host: '', port: 993, user: 'u@gmail.com', auth: { pass: 'p' }, tls: false },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  mergePresets(config, { source: 'gmail' });
  expect(config.source.host).toBe('imap.gmail.com');
  expect(config.source.tls).toBe(true);
  expect(config.source.port).toBe(993);
});

test('validateConfig rejects missing host', () => {
  const config = buildDefaultConfig({
    source: { host: '', port: 993, user: 'u1', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(() => validateConfig(config)).toThrow('source host');
});

test('validateConfig rejects missing user', () => {
  const config = buildDefaultConfig({
    source: { host: 's1', port: 993, user: '', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(() => validateConfig(config)).toThrow('source user');
});

test('validateConfig accepts valid config', () => {
  const config = buildDefaultConfig({
    source: { host: 's1', port: 993, user: 'u1', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(() => validateConfig(config)).not.toThrow();
});
