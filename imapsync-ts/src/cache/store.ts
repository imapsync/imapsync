import Database from 'better-sqlite3';
import { SCHEMA } from './schema.js';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export class CacheStore {
  private db: Database.Database;
  private stmtGetMapping: Database.Statement;
  private stmtSetMapping: Database.Statement;
  private stmtGetHash: Database.Statement;
  private stmtSetHash: Database.Statement;
  private stmtDeleteMapping: Database.Statement;
  private stmtDeleteHash: Database.Statement;
  private stmtInsertMapping: Database.Statement;

  constructor(dbPath: string) {
    mkdirSync(dirname(dbPath), { recursive: true });
    this.db = new Database(dbPath);
    this.db.pragma('journal_mode = WAL');
    this.db.exec(SCHEMA);

    this.stmtGetMapping = this.db.prepare(
      'SELECT dest_uid FROM uid_mapping WHERE folder = ? AND source_uid = ?'
    );
    this.stmtSetMapping = this.db.prepare(
      `INSERT INTO uid_mapping (folder, source_uid, dest_uid, uidvalidity)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(folder, source_uid) DO UPDATE SET dest_uid = excluded.dest_uid, uidvalidity = excluded.uidvalidity`
    );
    this.stmtGetHash = this.db.prepare(
      'SELECT header_hash FROM message_hash WHERE folder = ? AND source_uid = ?'
    );
    this.stmtSetHash = this.db.prepare(
      `INSERT INTO message_hash (folder, source_uid, header_hash, uidvalidity)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(folder, source_uid) DO UPDATE SET header_hash = excluded.header_hash, uidvalidity = excluded.uidvalidity`
    );
    this.stmtDeleteMapping = this.db.prepare(
      'DELETE FROM uid_mapping WHERE folder = ?'
    );
    this.stmtDeleteHash = this.db.prepare(
      'DELETE FROM message_hash WHERE folder = ?'
    );
    this.stmtInsertMapping = this.db.prepare(
      `INSERT INTO uid_mapping (folder, source_uid, dest_uid, uidvalidity)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(folder, source_uid) DO UPDATE SET dest_uid = excluded.dest_uid, uidvalidity = excluded.uidvalidity`
    );
  }

  open(): void {
    // Tables already created in constructor. No-op for API compatibility.
  }

  getMapping(folder: string, sourceUid: number): number | null {
    const row = this.stmtGetMapping.get(folder, sourceUid) as { dest_uid: number } | undefined;
    return row ? row.dest_uid : null;
  }

  setMapping(folder: string, sourceUid: number, destUid: number, uidValidity: string): void {
    this.stmtSetMapping.run(folder, sourceUid, destUid, uidValidity);
  }

  setMappingBatch(mappings: Array<{ folder: string; sourceUid: number; destUid: number; uidValidity: string }>): void {
    const tx = this.db.transaction(() => {
      for (const m of mappings) {
        this.stmtInsertMapping.run(m.folder, m.sourceUid, m.destUid, m.uidValidity);
      }
    });
    tx();
  }

  invalidateFolder(folder: string): void {
    this.stmtDeleteMapping.run(folder);
    this.stmtDeleteHash.run(folder);
  }

  getMessageHash(folder: string, sourceUid: number): string | null {
    const row = this.stmtGetHash.get(folder, sourceUid) as { header_hash: string } | undefined;
    return row ? row.header_hash : null;
  }

  setMessageHash(folder: string, sourceUid: number, hash: string, uidValidity: string): void {
    this.stmtSetHash.run(folder, sourceUid, hash, uidValidity);
  }

  close(): void {
    this.db.close();
  }
}
