const Database = require('better-sqlite3');
const path = require('path');
const db = new Database(require('path').resolve('data/nanoclaw.db'));

db.exec(`
  CREATE TABLE IF NOT EXISTS registered_groups (
    chatJid TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    additionalMounts TEXT DEFAULT '[]',
    isMain INTEGER DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chatJid TEXT NOT NULL,
    sessionId TEXT NOT NULL UNIQUE,
    startedAt TEXT NOT NULL,
    lastActivityAt TEXT NOT NULL,
    fullPath TEXT NOT NULL DEFAULT ''
  );
  CREATE TABLE IF NOT EXISTS chat_metadata (
    chatJid TEXT PRIMARY KEY,
    name TEXT,
    trigger TEXT,
    extraPrompt TEXT,
    scheduledTaskPrompt TEXT
  );
  CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chatJid TEXT NOT NULL,
    messageId TEXT NOT NULL UNIQUE,
    senderId TEXT NOT NULL,
    senderName TEXT,
    text TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    isFromBot INTEGER DEFAULT 0,
    isRead INTEGER DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS router_state (
    chatJid TEXT PRIMARY KEY,
    status TEXT DEFAULT 'idle',
    sessionId TEXT,
    containerId TEXT,
    startedAt TEXT,
    lastOutputAt TEXT
  );
  CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chatJid TEXT NOT NULL,
    schedule TEXT NOT NULL,
    prompt TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    lastRun TEXT,
    name TEXT
  );
`);

// Register main channel
db.prepare('INSERT OR REPLACE INTO registered_groups (chatJid, name, isMain) VALUES (?, ?, ?)')
  .run('main@s.whatsapp.net', 'main', 1);

// Register ShinobiPets group with mount
db.prepare('INSERT OR REPLACE INTO registered_groups (chatJid, name, additionalMounts) VALUES (?, ?, ?)')
  .run('shinobipets@group', 'shinobipets', JSON.stringify([
    { source: 'C:/Users/danie/Projects/shinobipets', target: '/workspace/extra/shinobipets', readonly: false }
  ]));

console.log('DB initialized, groups registered');
db.close();
