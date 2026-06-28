ALTER TABLE builds ADD COLUMN deadzone_version TEXT;
ALTER TABLE builds ADD COLUMN sha256 TEXT;
ALTER TABLE builds ADD COLUMN file_size TEXT;
ALTER TABLE builds ADD COLUMN changelog_url TEXT;
