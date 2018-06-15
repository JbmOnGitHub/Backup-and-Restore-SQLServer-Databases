# Backup-and-Restore-SQLServer-Databases
Easiest way to backup and restore all databases from a SQLServer instance

## Prerequies
The first time you need to create a stored procedure to handle the restore process.
To do this, just execute this script : [ScriptToCreate_Restore_StoredProcedure.sql](ScriptToCreate_Restore_StoredProcedure.sql)]

## 1. Backup
When you want to backup all your databases to a specific directory, you need to execute this script :  [ScriptToBackupAllDatabases.sql](ScriptToBackupAllDatabases)]
> You have to adjust your backup destination directory, like this : SET @path = 'D:\BCK_BDD\MASTER\'  

## 2 Restore
When you want to restore your previous database backups, you need to execute this script.
> You have to adjust the command : exec sp_CSS_RestoreDir 'C:\sqldb\sql_backup', 'C:\sqldb\sql_data', 'C:\sqldb\sql_log'

```sql
USE master
-- ============================================
--         ACTIVE xp_cmdshell
-- ============================================
set nocount on
-- To allow advanced options to be changed.
EXECUTE sp_configure 'show advanced options', 1
RECONFIGURE WITH OVERRIDE
GO
-- To enable the feature. 
EXECUTE sp_configure 'xp_cmdshell', '1'
RECONFIGURE WITH OVERRIDE
GO 
EXECUTE sp_configure 'show advanced options', 0
RECONFIGURE WITH OVERRIDE
GO

-- modify the command with your own values
-- exec sp_CSS_RestoreDir 'C:\sqldb\sql_backup', 'C:\sqldb\sql_data', 'C:\sqldb\sql_log'

exec sp_CSS_RestoreDir 'D:\BCK_BDD\MASTER', 'D:\BDD', 'D:\BDD'

-- ============================================
--         DESACTIVE xp_cmdshell
-- ============================================
-- To allow advanced options to be changed.
EXECUTE sp_configure 'show advanced options', 1
RECONFIGURE WITH OVERRIDE
GO
-- To enable the feature. 
EXECUTE sp_configure 'xp_cmdshell', '0'
RECONFIGURE WITH OVERRIDE
GO 
EXECUTE sp_configure 'show advanced options', 0
RECONFIGURE WITH OVERRIDE
GO
````
