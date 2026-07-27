import { Command } from 'commander';
import { runSync } from './sync.js';
import { buildDefaultConfig, mergePresets } from './config/defaults.js';
import { validateConfig } from './config/validate.js';

function collect(value: string, previous: string[]): string[] {
  return [...previous, value];
}

const program = new Command();

program
  .name('imapsync-ts')
  .description('IMAP mailbox synchronizer — TypeScript port of imapsync')
  .version('0.1.0')
  .requiredOption('--host1 <host>', 'Source IMAP host')
  .requiredOption('--user1 <user>', 'Source username')
  .option('--password1 <pass>', 'Source password')
  .requiredOption('--host2 <host>', 'Destination IMAP host')
  .requiredOption('--user2 <user>', 'Destination username')
  .option('--password2 <pass>', 'Destination password')
  .option('--port1 <port>', 'Source port', '993')
  .option('--port2 <port>', 'Destination port', '993')
  .option('--ssl1', 'Use TLS for source', true)
  .option('--no-ssl1', 'Disable TLS for source')
  .option('--ssl2', 'Use TLS for destination', true)
  .option('--no-ssl2', 'Disable TLS for destination')
  .option('--oauth2', 'Use OAuth2 authentication')
  .option('--folder <name>', 'Sync specific folder (repeatable)', collect, [])
  .option('--folderrec <pattern>', 'Include folders matching pattern (repeatable)', collect, [])
  .option('--exclude <pattern>', 'Exclude folders matching pattern (repeatable)', collect, [])
  .option('--delete1', 'Delete source messages after copy', false)
  .option('--delete2duplicates', 'Delete duplicates on destination', false)
  .option('--maxsize <bytes>', 'Skip messages larger than N bytes')
  .option('--skipmess <regex>', 'Skip messages matching regex (repeatable)', collect, [])
  .option('--dry', 'Dry run — no actual changes', false)
  .option('--gmail1', 'Use Gmail presets for source')
  .option('--gmail2', 'Use Gmail presets for destination')
  .option('--exchange1', 'Use Exchange presets for source')
  .option('--exchange2', 'Use Exchange presets for destination')
  .option('--syncflagsaftercopy', 'Sync flags after copying', true)
  .option('--synclabels', 'Sync Gmail labels', false)
  .option('--nocache', 'Disable cache', false)
  .option('--cachefile <path>', 'Cache file path')
  .option('--verbose', 'Verbose output', false);

program.parse();

const opts = program.opts();

async function main(): Promise<void> {
  const config = buildDefaultConfig({
    source: {
      host: opts.host1,
      port: parseInt(opts.port1, 10),
      user: opts.user1,
      auth: { pass: opts.password1 },
      tls: opts.ssl1,
    },
    dest: {
      host: opts.host2,
      port: parseInt(opts.port2, 10),
      user: opts.user2,
      auth: { pass: opts.password2 },
      tls: opts.ssl2,
    },
  });

  // Apply presets
  mergePresets(config, {
    source: opts.gmail1 ? 'gmail' : opts.exchange1 ? 'exchange' : undefined,
    dest: opts.gmail2 ? 'gmail' : opts.exchange2 ? 'exchange' : undefined,
  });

  // Apply folder filters
  if (opts.folder.length > 0) {
    config.folders.include = opts.folder.map((f: string) => new RegExp(`^${escapeRegex(f)}$`));
  }
  if (opts.folderrec.length > 0) {
    config.folders.include = [
      ...(config.folders.include ?? []),
      ...opts.folderrec.map((f: string) => new RegExp(f)),
    ];
  }
  if (opts.exclude.length > 0) {
    config.folders.exclude = opts.exclude.map((f: string) => new RegExp(f));
  }

  // Apply message options
  if (opts.maxsize) config.messages.skipLarge = parseInt(opts.maxsize, 10);
  if (opts.skipmess.length > 0) config.messages.skipRegex = opts.skipmess.map((r: string) => new RegExp(r));
  if (opts.dry) config.messages.dryRun = true;
  if (opts.delete1) config.messages.deleteSource = true;
  if (opts.delete2duplicates) config.messages.deleteDuplicates = true;

  // Apply flag/label options
  config.flags.syncAfterCopy = opts.syncflagsaftercopy;
  config.labels.sync = opts.synclabels;

  // Apply cache options
  if (opts.nocache) config.cache.enabled = false;
  if (opts.cachefile) config.cache.path = opts.cachefile;

  // Apply verbose
  config.verbose = opts.verbose;

  // OAuth2
  if (opts.oauth2) {
    if (config.source.auth.pass) {
      config.source.auth.accessToken = config.source.auth.pass;
      config.source.auth.pass = undefined;
    }
    if (config.dest.auth.pass) {
      config.dest.auth.accessToken = config.dest.auth.pass;
      config.dest.auth.pass = undefined;
    }
  }

  // Validate
  try {
    validateConfig(config);
  } catch (err) {
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  }

  // Run sync
  const result = await runSync(config);
  process.exit(result.exitCode);
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
