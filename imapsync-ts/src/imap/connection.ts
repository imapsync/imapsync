import { ImapFlow } from 'imapflow';
import type { ImapAccount, FolderInfo, FolderStatus, AppendResult } from '../types/account.js';
import { ImapConnectionError, ImapAuthError } from '../errors.js';

export class ImapClient {
  private client: ImapFlow;
  private connected = false;

  constructor(account: ImapAccount) {
    this.client = new ImapFlow({
      host: account.host,
      port: account.port,
      secure: account.tls,
      auth: {
        user: account.user,
        pass: account.auth.pass ?? '',
        accessToken: account.auth.accessToken,
      },
      logger: false,
    });
  }

  async connect(): Promise<void> {
    try {
      await this.client.connect();
      this.connected = true;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.toLowerCase().includes('auth') || msg.toLowerCase().includes('login') || msg.toLowerCase().includes('credential')) {
        throw new ImapAuthError(msg, err instanceof Error ? err : undefined);
      }
      throw new ImapConnectionError(msg, err instanceof Error ? err : undefined);
    }
  }

  async logout(): Promise<void> {
    try {
      await this.client.logout();
    } catch {
      // Best-effort logout
    }
    this.connected = false;
  }

  async ensureConnected(): Promise<void> {
    if (this.connected && this.client.usable) return;
    await this.connect();
  }

  async listFolders(): Promise<FolderInfo[]> {
    const mailboxes = await this.client.list();
    return mailboxes.map((mb) => ({
      path: mb.path,
      delimiter: mb.delimiter,
      specialUse: mb.specialUse,
      subscribed: mb.subscribed,
    }));
  }

  async ensureFolder(path: string): Promise<void> {
    const result = await this.client.mailboxCreate(path);
    if (!result.created) {
      // Folder already exists, that's fine
    }
  }

  async folderStatus(folder: string): Promise<FolderStatus> {
    const status = await this.client.status(folder, {
      messages: true,
      uidValidity: true,
      uidNext: true,
      highestModseq: true,
    });
    return {
      path: folder,
      exists: status.messages ?? 0,
      uidValidity: String(status.uidValidity ?? ''),
      uidNext: status.uidNext ?? 0,
      highestModseq: status.highestModseq ? String(status.highestModseq) : undefined,
    };
  }

  async appendMessage(
    folder: string,
    raw: Buffer,
    flags: string[],
    date: Date,
  ): Promise<AppendResult> {
    const result = await this.client.append(folder, raw, flags, date);
    if (!result) {
      throw new Error(`Failed to append message to ${folder}`);
    }
    return {
      destination: result.destination,
      uid: result.uid ?? 0,
      uidValidity: String(result.uidValidity ?? ''),
    };
  }

  async fetchMessageSource(uid: number, folder: string): Promise<Buffer> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      const msg = await this.client.fetchOne(String(uid), { source: true }, { uid: true });
      if (!msg || !msg.source) throw new Error(`Message ${uid} not found in ${folder}`);
      return Buffer.from(msg.source);
    } finally {
      lock.release();
    }
  }

  async addFlags(folder: string, uid: number, flags: string[]): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageFlagsAdd(String(uid), flags, { uid: true });
    } finally {
      lock.release();
    }
  }

  async setFlags(folder: string, uid: number, flags: string[]): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageFlagsSet(String(uid), flags, { uid: true });
    } finally {
      lock.release();
    }
  }

  async addLabels(folder: string, uid: number, labels: string[]): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageFlagsAdd(String(uid), labels, { uid: true, useLabels: true });
    } finally {
      lock.release();
    }
  }

  async deleteMessage(folder: string, uid: number): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageDelete(String(uid), { uid: true });
    } finally {
      lock.release();
    }
  }

  getClient(): ImapFlow {
    return this.client;
  }
}
