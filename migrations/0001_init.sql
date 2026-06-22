CREATE TABLE IF NOT EXISTS builds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  build_id TEXT,
  user_id TEXT,
  user_name TEXT,
  rom_link TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  device_codename TEXT,
  device_name TEXT,
  rom_version TEXT,
  region TEXT,
  android TEXT,
  final_zip TEXT,
  drive_link TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rom_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codename TEXT NOT NULL,
  device_name TEXT,
  region TEXT,
  rom_version TEXT,
  android TEXT,
  rom_type TEXT,
  download_link TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_builds_status ON builds(status);
CREATE INDEX IF NOT EXISTS idx_builds_created_at ON builds(created_at);
CREATE INDEX IF NOT EXISTS idx_rom_cache_codename ON rom_cache(codename);
CREATE INDEX IF NOT EXISTS idx_rom_cache_codename_region ON rom_cache(codename, region);
CREATE INDEX IF NOT EXISTS idx_rom_cache_updated_at ON rom_cache(updated_at);
