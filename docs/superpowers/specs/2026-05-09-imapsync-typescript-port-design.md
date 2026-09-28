# imapsync TypeScript 移植设计

## 目标

将 imapsync（Perl）的核心 IMAP 同步逻辑移植为生产可用的 TypeScript CLI 工具，保留核心同步流程 + Gmail 标签 + 测试体系，用现代化架构替代全局变量和单体文件结构。

## 功能范围

**包含**：
- 核心 IMAP 同步流程（连接、文件夹枚举/映射/创建、消息复制、标志同步、缓存、删除）
- Gmail 标签同步（X-GM-LABELS）
- OAuth2 认证
- SQLite 缓存（替代原版纯文本缓存）
- 预设配置（Gmail/Exchange/Office365）
- CLI 接口
- 测试体系（单元测试 + 集成测试）

**不包含**：
- CGI Web 界面
- 邮件报告通知
- 内存监控/压力检测
- Docker 检测
- PID 文件管理
- 信号处理/abort 机制

## 架构：模块化管道

按职责拆成独立模块，编排层串联同步流程。每个模块封装一个子系统，通过函数参数传递状态，不使用全局变量。

## 项目结构

```
imapsync-ts/
  src/
    cli.ts              — 命令行入口，参数解析
    sync.ts             — 核心编排：文件夹循环 + 消息循环
    imap/
      connection.ts     — 连接/认证/重连（封装 imapflow）
      folder.ts         — 文件夹枚举/映射/创建/删除
      message.ts        — 消息获取/复制/追加
      flags.ts          — 标志同步
      labels.ts         — Gmail 标签同步
      search.ts         — 消息搜索/过滤
    cache/
      store.ts          — SQLite 缓存接口
      schema.ts         — 表结构定义
    auth/
      oauth2.ts         — OAuth2 token 获取/刷新
    config/
      presets.ts        — Gmail/Exchange/Office365 预设
      defaults.ts       — 默认值
    logger/
      index.ts          — 日志输出 + 进度显示
    types/
      sync.ts           — SyncConfig, SyncState, SyncResult
      account.ts        — ImapAccount, FolderInfo, MessageInfo
      cache.ts          — CacheEntry
    __tests__/
      integration/      — 集成测试（需真实 IMAP 服务器）
      unit/             — 单元测试（mock IMAP）
```

## 类型系统

用类型替代原版 ~60 个全局变量，状态通过参数传递：

```typescript
// types/account.ts
interface ImapAccount {
  host: string;
  port: number;
  user: string;
  auth: { pass?: string; accessToken?: string };
  tls: boolean;
}

// types/sync.ts
interface SyncConfig {
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
}

interface SyncState {
  foldersProcessed: number;
  messagesCopied: number;
  messagesSkipped: number;
  errors: ErrorRecord[];
  startTime: Date;
}

interface SyncResult {
  state: SyncState;
  success: boolean;
  exitCode: number;
}
```

## 核心同步流程

```typescript
// sync.ts — 核心编排
export async function runSync(config: SyncConfig): Promise<SyncResult> {
  const state = createSyncState();
  const logger = createLogger(config);

  // 1. 连接两侧 IMAP 服务器
  const source = await connectImap(config.source, logger);
  const dest = await connectImap(config.dest, logger);

  // 2. 枚举 + 映射文件夹
  const folderPairs = await resolveFolderPairs(source, dest, config, logger);

  // 3. 初始化缓存
  const cache = config.cache.enabled
    ? await openCache(config.cache.path)
    : null;

  // 4. 逐文件夹同步
  for (const pair of folderPairs) {
    await syncFolder(pair, source, dest, cache, config, state, logger);
  }

  // 5. 收尾：统计 + 关闭
  const result = buildResult(state);
  await cache?.close();
  await source.logout();
  await dest.logout();

  return result;
}

// 单个文件夹同步
async function syncFolder(
  pair: FolderPair,
  source: ImapClient,
  dest: ImapClient,
  cache: CacheStore | null,
  config: SyncConfig,
  state: SyncState,
  logger: Logger,
) {
  const srcFolder = pair.source;
  const dstFolder = pair.dest;

  await ensureFolder(dest, dstFolder, logger);

  const srcMsgs = await listMessages(source, srcFolder, config, logger);
  const dstMsgs = await listMessages(dest, dstFolder, config, logger);

  const toCopy = await findMessagesToCopy(
    srcMsgs, dstMsgs, cache, srcFolder, config, logger
  );

  for (const msg of toCopy) {
    await copyMessage(msg, source, dest, srcFolder, dstFolder, config, logger);
    if (config.flags.syncAfterCopy) {
      await syncFlags(msg, dest, dstFolder, logger);
    }
    state.messagesCopied++;
  }

  if (config.messages.deleteSource || config.messages.deleteDuplicates) {
    await handleDeletes(source, dest, srcMsgs, dstMsgs, config, logger);
  }

  state.foldersProcessed++;
}
```

### 与原版的关键差异

- 原版 ~60 个全局变量 → 全部通过 config / state 参数传递
- 原版 copy_message 有 1,000+ 行 → 拆成 findMessagesToCopy + copyMessage 两步
- 原版文件夹循环和消息循环混在 single_sync 里 → 独立函数，职责单一
- imapflow 的 getMailboxLock 替代原版手动的 select/examine 管理

## IMAP 连接层

薄封装 imapflow，暴露领域级 API，调用者不需要了解 imapflow 细节：

```typescript
// imap/connection.ts
export class ImapClient {
  private client: ImapFlow;

  constructor(account: ImapAccount) { /* ... */ }
  async connect(): Promise<void> { /* 连接 + 错误处理 */ }
  async logout(): Promise<void> { /* 登出 */ }
  async ensureConnected(): Promise<void> { /* 重连逻辑 */ }

  async listFolders(): Promise<FolderInfo[]> { /* ... */ }
  async ensureFolder(path: string): Promise<void> { /* ... */ }
  async listMessages(folder: string, criteria: SearchCriteria): Promise<MessageInfo[]> { /* ... */ }
  async fetchMessage(uid: number, folder: string): Promise<Buffer> { /* ... */ }
  async appendMessage(folder: string, raw: Buffer, flags: string[], date: Date): Promise<AppendResult> { /* ... */ }
  async syncFlags(folder: string, uid: number, flags: Set<string>): Promise<void> { /* ... */ }
  async syncLabels(folder: string, uid: number, labels: Set<string>): Promise<void> { /* ... */ }
  async deleteMessage(folder: string, uid: number): Promise<void> { /* ... */ }
  async folderStatus(folder: string): Promise<FolderStatus> { /* ... */ }
}
```

## SQLite 缓存层

替代原版的纯文本 UID 映射文件，用 better-sqlite3：

```typescript
// cache/store.ts
export class CacheStore {
  private db: Database;

  static async open(path: string): Promise<CacheStore>;
  async close(): Promise<void>;

  async getMapping(folder: string, sourceUid: number): Promise<number | null>;
  async setMapping(folder: string, sourceUid: number, destUid: number): Promise<void>;
  async invalidateFolder(folder: string): Promise<void>;

  async getMessageHash(folder: string, sourceUid: number): Promise<string | null>;
  async setMessageHash(folder: string, sourceUid: number, hash: string): Promise<void>;
}
```

```sql
CREATE TABLE IF NOT EXISTS uid_mapping (
  folder      TEXT NOT NULL,
  source_uid  INTEGER NOT NULL,
  dest_uid    INTEGER NOT NULL,
  uidvalidity INTEGER NOT NULL,
  PRIMARY KEY (folder, source_uid)
);

CREATE TABLE IF NOT EXISTS message_hash (
  folder      TEXT NOT NULL,
  source_uid  INTEGER NOT NULL,
  header_hash TEXT NOT NULL,
  uidvalidity INTEGER NOT NULL,
  PRIMARY KEY (folder, source_uid)
);
```

### 与原版的关键差异

- 原版每个文件夹一个纯文本缓存文件 → 单个 SQLite 文件，事务安全
- 原版 UIDVALIDITY 变化时需要手动删缓存文件 → invalidateFolder() 一条 SQL
- 原版直接暴露 Mail::IMAPClient → 我们的 ImapClient 封装了领域级 API

## 测试体系

```
src/__tests__/
  unit/
    cache.test.ts         — SQLite 缓存逻辑
    message-merge.test.ts — 消息去重/比较逻辑
    folder-mapping.test.ts — 文件夹名称映射/正则变换
    config.test.ts        — 预设配置合并、参数校验
    flags.test.ts         — 标志差异计算
  integration/
    sync.test.ts          — 完整同步流程
    folder.test.ts        — 文件夹创建/映射/ACL
    message.test.ts       — 消息复制/追加
    labels.test.ts        — Gmail 标签同步
```

- **单元测试**：用 mock 的 ImapClient，纯逻辑可离线运行，`npm test`
- **集成测试**：需要真实 IMAP 服务器（环境变量配置），`npm run test:integration`
- **框架**：Jest
- **可选**：提供 docker-compose 起本地 Dovecot 测试服务器

### 与原版的改进

- 原版 230 个测试函数混杂在主代码里 → 独立测试目录
- 原版没有 mock，所有测试必须在线 → 核心逻辑可离线单元测试
- 原版测试没有分类 → unit / integration 分层

## CLI 接口

用 commander，兼容原版核心参数：

```
--host1, --user1, --password1     源 IMAP 服务器
--host2, --user2, --password2     目标 IMAP 服务器
--port1, --port2                  端口（默认 993）
--ssl1, --ssl2                    启用 SSL
--oauth2                          OAuth2 认证
--folder, --folderrec, --exclude  文件夹过滤
--delete1, --delete2duplicates    删除选项
--maxsize, --skipmess             消息过滤
--dry                             试运行
--gmail1, --gmail2                Gmail 预设
--syncflagsaftercopy              复制后同步标志
--synclabels                      同步 Gmail 标签
--nocache, --cachefile            缓存控制
--verbose                         详细输出
```

## 日志

结构化输出，格式统一：

```
[12:34:56] Connecting to imap.gmail.com:993 ...
[12:34:57] Connected. Server: Gmail IMAP
[12:34:58] Found 42 folders, 38 to sync after filters
[12:34:59] [1/38] INBOX: 1,234 source, 1,200 dest → 34 to copy
[12:35:12] [1/38] INBOX: copied 34 messages (2 skipped, 0 errors)
[12:42:00] Sync complete: 156 copied, 12 skipped, 0 errors
```

## 错误处理

| 错误类型 | 处理方式 | 退出码 |
|---|---|---|
| 连接失败 | 终止 | 1 |
| 认证失败 | 终止 | 2 |
| 单消息复制失败 | 记录错误，继续下一条 | 0（记录到 state.errors） |
| 文件夹操作失败 | 跳过该文件夹，继续下一个 | 0（记录到 state.errors） |
| 缓存读写失败 | 降级为无缓存模式，继续 | 0（记录到 state.errors） |

```typescript
function classifyError(err: Error): ErrorType {
  if (err instanceof ImapAuthError) return 'auth';
  if (err instanceof ImapConnectionError) return 'connection';
  if (err instanceof MessageCopyError) return 'message';
  if (err instanceof FolderError) return 'folder';
  if (err instanceof CacheError) return 'cache';
  return 'unknown';
}
```

## 技术选型

| 组件 | 选择 | 理由 |
|---|---|---|
| 运行时 | Node.js 20+ | imapflow 是 Node 库 |
| 语言 | TypeScript 5.x strict | 类型安全 |
| IMAP 客户端 | imapflow | 最成熟的 Node IMAP 库，支持 OAuth2/UID/Gmail 标签 |
| 缓存 | better-sqlite3 | 同步 API、无需外部服务、性能好 |
| CLI 框架 | commander | 轻量、成熟 |
| 测试框架 | Jest | 生态最全 |
| 构建 | tsup | 简单、支持 ESM+CJS |

## 原版架构参考

imapsync (Perl) 是一个 21,984 行的单文件脚本，包含：
- 667 个子函数（其中 230 个是内联测试）
- ~60 个全局变量（正在迁移到 $sync/$acc1/$acc2 哈希，但未完成）
- 主函数 single_sync 有 1,700 行
- 526 个集成测试在 tests.sh（7,733 行）
- 核心依赖：Mail::IMAPClient (Perl)

子系统分解：
- 主流程 (3) / 测试 (230) / 工具函数 (85) / 选项配置 (34) / IMAP连接 (24)
- 输出日志 (18) / 文件夹操作 (17) / 错误处理 (17) / 信号中断 (16)
- 内存管理 (15) / 邮件报告 (15) / 文件夹映射 (9) / 文件夹大小 (11)
- 标志同步 (9) / 缓存 (9) / 头部解析 (9) / 消息复制 (4) / 认证 (5)
- CGI/Web (5) / Gmail标签 (6) / 其他 (~30)
