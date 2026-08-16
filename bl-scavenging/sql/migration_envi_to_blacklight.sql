-- =====================================================================
--  MIGRATION: envi-dumpsters  ->  bl-scavenging
-- =====================================================================
--  RUN THIS ONCE, BEFORE STARTING bl-scavenging FOR THE FIRST TIME,
--  IF YOU ARE UPGRADING AN EXISTING SERVER THAT ALREADY HAS PLAYER DATA.
--
--  Why this is needed
--  ------------------
--  The three tables used by the original resource were NOT prefixed with the
--  vendor name, so they have been rebranded to sit under the `bl_scav_` prefix:
--
--      hobo_progression       ->  bl_scav_progression
--      hobo_king_leaderboard  ->  bl_scav_warden_leaderboard
--      hobo_cart_leaderboards ->  bl_scav_derby_leaderboards
--
--  RENAME TABLE preserves every row, index and auto-increment value, so no
--  player loses their level, XP, bottle caps, crown or leaderboard placement.
--  Column names are deliberately UNCHANGED — the resource reads `level`, `xp`,
--  `mission_data`, `is_king`, `true_hobo`, `kill_count`, `distance`, etc. by
--  name, and renaming them would break compatibility for no benefit.
--
--  IMPORTANT
--  ---------
--  * Take a database backup first.
--  * If you skip this file the resource will simply CREATE the new tables empty
--    and all historic progression will appear to be lost (the old tables are
--    left untouched, so it is recoverable by running this migration later —
--    drop the freshly created empty tables first).
--  * This script is safe to run on a server that has already been migrated:
--    each step is guarded so it only fires when the old table still exists.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. hobo_progression -> bl_scav_progression
-- ---------------------------------------------------------------------
SET @do := (
    SELECT IF(
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hobo_progression') = 1
        AND
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bl_scav_progression') = 0,
        'RENAME TABLE `hobo_progression` TO `bl_scav_progression`',
        'SELECT "skip: hobo_progression already migrated or absent"'
    )
);
PREPARE stmt FROM @do; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
--  2. hobo_king_leaderboard -> bl_scav_warden_leaderboard
-- ---------------------------------------------------------------------
SET @do := (
    SELECT IF(
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hobo_king_leaderboard') = 1
        AND
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bl_scav_warden_leaderboard') = 0,
        'RENAME TABLE `hobo_king_leaderboard` TO `bl_scav_warden_leaderboard`',
        'SELECT "skip: hobo_king_leaderboard already migrated or absent"'
    )
);
PREPARE stmt FROM @do; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
--  3. hobo_cart_leaderboards -> bl_scav_derby_leaderboards
-- ---------------------------------------------------------------------
SET @do := (
    SELECT IF(
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hobo_cart_leaderboards') = 1
        AND
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bl_scav_derby_leaderboards') = 0,
        'RENAME TABLE `hobo_cart_leaderboards` TO `bl_scav_derby_leaderboards`',
        'SELECT "skip: hobo_cart_leaderboards already migrated or absent"'
    )
);
PREPARE stmt FROM @do; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
--  4. Backfill: ensure the derby leaderboard index exists.
--     (Older installs created the table without the composite index.)
-- ---------------------------------------------------------------------
SET @do := (
    SELECT IF(
        (SELECT COUNT(*) FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'bl_scav_derby_leaderboards'
              AND INDEX_NAME = 'idx_track_distance') = 0
        AND
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bl_scav_derby_leaderboards') = 1,
        'ALTER TABLE `bl_scav_derby_leaderboards` ADD INDEX `idx_track_distance` (`track`, `distance` DESC)',
        'SELECT "skip: idx_track_distance present or table absent"'
    )
);
PREPARE stmt FROM @do; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
--  5. Recycler stash ids: hobo_recycler_N  ->  bl_scav_reclaim_N
--
--  These stashes are NOT owned by this resource -- they live in whatever
--  inventory resource you run, because the resource only calls
--  Framework.RegisterStash("bl_scav_reclaim_" .. i, ...). Renaming the
--  stash id means the inventory would hand out a brand-new empty
--  container and anything players left inside the old one would be
--  orphaned (still on disk, just unreachable).
--
--  The statements below cover ox_inventory, which stores stashes in
--  `ox_inventory` keyed by `name`. They are wrapped in the same
--  information_schema guard as everything above, so they are skipped
--  silently when that table does not exist.
--
--  IF YOU USE A DIFFERENT INVENTORY (qb-inventory, qs-inventory,
--  origen, codem, ...) the table and column names differ -- check your
--  inventory's schema and adapt. Common equivalents:
--      qb-inventory : `stashitems`     (columns `stash`, `items`)
--      qs-inventory : `stashitems`     (columns `stash`, `items`)
--
--  This step is OPTIONAL. Skipping it costs you only whatever items were
--  sitting inside a recycler at the moment you upgraded.
-- ---------------------------------------------------------------------

-- ox_inventory
SET @do := (
    SELECT IF(
        (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ox_inventory') = 1,
        'UPDATE `ox_inventory` SET `name` = REPLACE(`name`, ''hobo_recycler_'', ''bl_scav_reclaim_'') WHERE `name` LIKE ''hobo_recycler_%'' AND NOT EXISTS (SELECT 1 FROM (SELECT `name` FROM `ox_inventory`) AS existing WHERE existing.`name` = REPLACE(`ox_inventory`.`name`, ''hobo_recycler_'', ''bl_scav_reclaim_''))',
        'SELECT "skip: ox_inventory table not present"'
    )
);
PREPARE stmt FROM @do; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- qb-inventory / qs-inventory style `stashitems`
SET @do := (
    SELECT IF(
        (SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'stashitems'
              AND COLUMN_NAME = 'stash') = 1,
        'UPDATE `stashitems` SET `stash` = REPLACE(`stash`, ''hobo_recycler_'', ''bl_scav_reclaim_'') WHERE `stash` LIKE ''hobo_recycler_%''',
        'SELECT "skip: stashitems table not present"'
    )
);
PREPARE stmt FROM @do; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
--  Done. Verify with:
--     SHOW TABLES LIKE 'bl\_scav\_%';
--     SELECT COUNT(*) FROM bl_scav_progression;
-- ---------------------------------------------------------------------
