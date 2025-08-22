import Database from 'better-sqlite3';

export class StateRepository {
  private db: any;
  private upsertCursorStmt: any;
  private getCursorStmt: any;
  private isProcessedStmt: any;
  private markProcessedStmt: any;

  constructor() {
    this.db = new Database('bridge-state.sqlite');
    this.db.pragma('journal_mode = WAL');
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS cursor (
        chainId INTEGER PRIMARY KEY,
        lastProcessedBlock INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS processed_events (
        id TEXT PRIMARY KEY,
        ts INTEGER NOT NULL
      );
    `);
    this.upsertCursorStmt = this.db.prepare(
      `INSERT INTO cursor(chainId, lastProcessedBlock) VALUES(?,?)
       ON CONFLICT(chainId) DO UPDATE SET lastProcessedBlock=excluded.lastProcessedBlock`
    );
    this.getCursorStmt = this.db.prepare(`SELECT lastProcessedBlock FROM cursor WHERE chainId=?`);
    this.isProcessedStmt = this.db.prepare(`SELECT 1 FROM processed_events WHERE id=?`);
    this.markProcessedStmt = this.db.prepare(`INSERT OR IGNORE INTO processed_events(id, ts) VALUES(?, ?)`);
  }

  getCursor(chainId: number): number | null {
    const row = this.getCursorStmt.get(chainId) as { lastProcessedBlock: number } | undefined;
    return row ? row.lastProcessedBlock : null;
  }

  setCursor(chainId: number, block: number) {
    this.upsertCursorStmt.run(chainId, block);
  }

  isProcessed(id: string): boolean {
    return !!this.isProcessedStmt.get(id);
  }

  markProcessed(id: string) {
    this.markProcessedStmt.run(id, Math.floor(Date.now() / 1000));
  }
}
