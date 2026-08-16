-- =====================================================================
--  BlackLight Scavenging — schema
--  Resource: bl-scavenging
-- =====================================================================
--  The resource creates these tables automatically on first start
--  (see server/progression.lua). This file is provided so operators can
--  provision the schema up front, review it, or restore it manually.
--
--  Engine/charset are left to the server default so this works on both
--  MySQL 5.7 and MariaDB.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `bl_scav_progression` (
    `identifier`    VARCHAR(60) PRIMARY KEY,
    `level`         INT DEFAULT 1,
    `xp`            INT DEFAULT 0,
    `mission_data`  JSON DEFAULT '{}',
    `is_king`       BOOLEAN DEFAULT 0,
    `king_since`    DATETIME,
    `last_active`   DATETIME,
    `donated_drugs` INT DEFAULT 0,
    `true_hobo`     BOOLEAN DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `bl_scav_warden_leaderboard` (
    `identifier`    VARCHAR(255) PRIMARY KEY,
    `player_name`   VARCHAR(255) NOT NULL,
    `kill_count`    INT NOT NULL DEFAULT 0,
    `date_achieved` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `time_survived` INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `bl_scav_derby_leaderboards` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60),
    `track`      VARCHAR(100),
    `distance`   FLOAT,
    `name`       VARCHAR(100),
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_track_distance` (`track`, `distance` DESC)
);
