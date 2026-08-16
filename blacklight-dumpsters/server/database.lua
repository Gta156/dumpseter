--[[ ==========================================================================
     BlackLight Dumpsters — Automated Schema Installer
     --------------------------------------------------------------------------
     No .sql import is required. Every table, column and index this resource
     needs is created (idempotently) on the first server boot and re-verified
     on every subsequent restart. Nothing is ever dropped or truncated.
========================================================================== ]]

local BADGE = "[^3BlackLight^7]"

SchemaReady = false

--- Console helper with the BlackLight badge.
local function Announce(message)
    print(("%s %s"):format(BADGE, message))
end

--- Console helper for failures.
local function AnnounceFailure(message)
    print(("%s ^1%s^7"):format(BADGE, message))
end

-- --------------------------------------------------------------------------
--  SCHEMA DEFINITION
-- --------------------------------------------------------------------------

--- Every table this resource owns. CREATE TABLE IF NOT EXISTS is inherently
--- idempotent, so these can be replayed safely on every boot.
local TABLE_DEFINITIONS = {
    {
        name = "bl_scavenger_standing",
        sql = [[
            CREATE TABLE IF NOT EXISTS `bl_scavenger_standing` (
                `identifier`     VARCHAR(60) NOT NULL,
                `level`          INT NOT NULL DEFAULT 1,
                `xp`             INT NOT NULL DEFAULT 0,
                `mission_data`   LONGTEXT NULL,
                `is_king`        TINYINT(1) NOT NULL DEFAULT 0,
                `king_since`     DATETIME NULL DEFAULT NULL,
                `last_active`    DATETIME NULL DEFAULT NULL,
                `donated_drugs`  INT NOT NULL DEFAULT 0,
                `true_hobo`      TINYINT(1) NOT NULL DEFAULT 0,
                PRIMARY KEY (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = "bl_gauntlet_board",
        sql = [[
            CREATE TABLE IF NOT EXISTS `bl_gauntlet_board` (
                `identifier`     VARCHAR(60) NOT NULL,
                `player_name`    VARCHAR(255) NOT NULL,
                `kill_count`     INT NOT NULL DEFAULT 0,
                `time_survived`  INT NOT NULL DEFAULT 0,
                `date_achieved`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = "bl_derby_records",
        sql = [[
            CREATE TABLE IF NOT EXISTS `bl_derby_records` (
                `id`          INT NOT NULL AUTO_INCREMENT,
                `identifier`  VARCHAR(60) NOT NULL,
                `venue`       VARCHAR(100) NOT NULL,
                `distance`    FLOAT NOT NULL DEFAULT 0,
                `name`        VARCHAR(100) NULL,
                `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `bl_derby_identity` (`identifier`, `venue`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
}

--- Columns that must exist. MySQL's "ADD COLUMN IF NOT EXISTS" is MariaDB-only,
--- so existence is probed through information_schema first for portability.
local COLUMN_DEFINITIONS = {
    { table = "bl_scavenger_standing", column = "level",         definition = "INT NOT NULL DEFAULT 1" },
    { table = "bl_scavenger_standing", column = "xp",            definition = "INT NOT NULL DEFAULT 0" },
    { table = "bl_scavenger_standing", column = "mission_data",  definition = "LONGTEXT NULL" },
    { table = "bl_scavenger_standing", column = "is_king",       definition = "TINYINT(1) NOT NULL DEFAULT 0" },
    { table = "bl_scavenger_standing", column = "king_since",    definition = "DATETIME NULL DEFAULT NULL" },
    { table = "bl_scavenger_standing", column = "last_active",   definition = "DATETIME NULL DEFAULT NULL" },
    { table = "bl_scavenger_standing", column = "donated_drugs", definition = "INT NOT NULL DEFAULT 0" },
    { table = "bl_scavenger_standing", column = "true_hobo",     definition = "TINYINT(1) NOT NULL DEFAULT 0" },
    { table = "bl_gauntlet_board",     column = "time_survived", definition = "INT NOT NULL DEFAULT 0" },
    { table = "bl_gauntlet_board",     column = "date_achieved", definition = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
    { table = "bl_derby_records",      column = "name",          definition = "VARCHAR(100) NULL" },
    { table = "bl_derby_records",      column = "created_at",    definition = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
}

--- Secondary indexes that speed up the hot leaderboard queries.
local INDEX_DEFINITIONS = {
    { table = "bl_derby_records",      name = "bl_derby_ranking",   columns = "`venue`, `distance` DESC" },
    { table = "bl_gauntlet_board",     name = "bl_gauntlet_kills",  columns = "`kill_count` DESC" },
    { table = "bl_scavenger_standing", name = "bl_standing_throne", columns = "`is_king`, `last_active`" },
}

-- --------------------------------------------------------------------------
--  INTROSPECTION HELPERS
-- --------------------------------------------------------------------------

--- Does a column already exist on a table?
local function ColumnExists(tableName, columnName)
    local found = MySQL.scalar.await([[
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        LIMIT 1
    ]], { tableName, columnName })

    return found ~= nil
end

--- Does an index already exist on a table?
local function IndexExists(tableName, indexName)
    local found = MySQL.scalar.await([[
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?
        LIMIT 1
    ]], { tableName, indexName })

    return found ~= nil
end

-- --------------------------------------------------------------------------
--  MIGRATION FROM THE LEGACY SCHEMA
-- --------------------------------------------------------------------------

--- Does a table exist at all?
local function TableExists(tableName)
    local found = MySQL.scalar.await([[
        SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
        LIMIT 1
    ]], { tableName })

    return found ~= nil
end

--- Copies rows across from a pre-BlackLight installation, if one is present.
--- Runs only when the legacy table exists AND the new table is still empty,
--- so it can never duplicate or clobber live data.
local function MigrateLegacyRows(legacyTable, targetTable, columnList)
    if not TableExists(legacyTable) then
        return
    end

    local existingRows = MySQL.scalar.await(("SELECT COUNT(*) FROM `%s`"):format(targetTable))
    if (existingRows or 0) > 0 then
        return
    end

    local legacyRows = MySQL.scalar.await(("SELECT COUNT(*) FROM `%s`"):format(legacyTable))
    if (legacyRows or 0) == 0 then
        return
    end

    local ok = pcall(function()
        MySQL.query.await(("INSERT IGNORE INTO `%s` (%s) SELECT %s FROM `%s`"):format(
            targetTable, columnList, columnList, legacyTable
        ))
    end)

    if ok then
        Announce(("Imported %d legacy row(s) from `%s` into `%s`."):format(legacyRows, legacyTable, targetTable))
    else
        AnnounceFailure(("Could not import legacy rows from `%s`; starting `%s` fresh."):format(legacyTable, targetTable))
    end
end

-- --------------------------------------------------------------------------
--  INSTALLER
-- --------------------------------------------------------------------------

--- Creates / verifies the full schema. Safe to call repeatedly.
local function InstallSchema()
    -- 1. Tables
    for _, definition in ipairs(TABLE_DEFINITIONS) do
        local ok, err = pcall(function()
            MySQL.query.await(definition.sql)
        end)

        if not ok then
            AnnounceFailure(("Failed to verify table `%s`: %s"):format(definition.name, tostring(err)))
            return false
        end
    end

    -- 2. Columns (self-healing for installs upgraded from older builds)
    for _, definition in ipairs(COLUMN_DEFINITIONS) do
        if not ColumnExists(definition.table, definition.column) then
            local ok, err = pcall(function()
                MySQL.query.await(("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(
                    definition.table, definition.column, definition.definition
                ))
            end)

            if ok then
                Announce(("Added missing column `%s`.`%s`."):format(definition.table, definition.column))
            else
                AnnounceFailure(("Could not add column `%s`.`%s`: %s"):format(definition.table, definition.column, tostring(err)))
            end
        end
    end

    -- 3. Indexes
    for _, definition in ipairs(INDEX_DEFINITIONS) do
        if not IndexExists(definition.table, definition.name) then
            local ok = pcall(function()
                MySQL.query.await(("CREATE INDEX `%s` ON `%s` (%s)"):format(
                    definition.name, definition.table, definition.columns
                ))
            end)

            if ok then
                Announce(("Created index `%s` on `%s`."):format(definition.name, definition.table))
            end
        end
    end

    -- 4. Optional one-time import from a legacy (pre-rebrand) installation
    MigrateLegacyRows(
        "hobo_progression", "bl_scavenger_standing",
        "`identifier`, `level`, `xp`, `mission_data`, `is_king`, `king_since`, `last_active`, `donated_drugs`, `true_hobo`"
    )
    MigrateLegacyRows(
        "hobo_king_leaderboard", "bl_gauntlet_board",
        "`identifier`, `player_name`, `kill_count`, `time_survived`, `date_achieved`"
    )

    -- 5. Daily contraband allowance resets on boot (matches the original cadence)
    MySQL.query.await("UPDATE `bl_scavenger_standing` SET `donated_drugs` = 0 WHERE `donated_drugs` <> 0")

    -- 6. Strip the throne from anyone who has been away too long
    local dormantHolder = MySQL.single.await([[
        SELECT `identifier` FROM `bl_scavenger_standing`
        WHERE `is_king` = 1 AND `last_active` < DATE_SUB(NOW(), INTERVAL ? DAY)
        LIMIT 1
    ]], { Settings.Overseer.DormancyDays })

    if dormantHolder then
        MySQL.query.await("UPDATE `bl_scavenger_standing` SET `is_king` = 0 WHERE `identifier` = ?", { dormantHolder.identifier })
        Announce("Throne released — the previous holder had been dormant too long.")
    end

    return true
end

--- Blocks calling code until the schema installer has finished.
function AwaitSchema()
    local guard = 0
    while not SchemaReady do
        Wait(100)
        guard = guard + 1
        if guard > 600 then -- 60 second safety valve
            return false
        end
    end
    return true
end

-- --------------------------------------------------------------------------
--  BOOTSTRAP
-- --------------------------------------------------------------------------

local function Bootstrap()
    if GetResourceState("oxmysql") ~= "started" then
        AnnounceFailure("oxmysql is not running — BlackLight Dumpsters cannot persist any data.")
        return
    end

    Announce("Verifying database schema...")

    if InstallSchema() then
        SchemaReady = true
        Announce("^2Database schema verified. No manual .sql import is required.^7")
    else
        AnnounceFailure("Database schema verification failed. Check the errors above.")
    end
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    CreateThread(function()
        -- Give oxmysql a moment to establish its pool before probing.
        Wait(500)
        MySQL.ready(Bootstrap)
    end)
end)
