export const SCHEMA = `
CREATE TABLE IF NOT EXISTS uid_mapping (
  folder      TEXT NOT NULL,
  source_uid  INTEGER NOT NULL,
  dest_uid    INTEGER NOT NULL,
  uidvalidity TEXT NOT NULL,
  PRIMARY KEY (folder, source_uid)
);

CREATE TABLE IF NOT EXISTS message_hash (
  folder      TEXT NOT NULL,
  source_uid  INTEGER NOT NULL,
  header_hash TEXT NOT NULL,
  uidvalidity TEXT NOT NULL,
  PRIMARY KEY (folder, source_uid)
);
`;
