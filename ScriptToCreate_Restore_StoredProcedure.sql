USE master
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_CSS_RestoreDir]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_CSS_RestoreDir]
GO

/***************************************************************************************/
-- Procedure Name:    sp_CSS_RestoreDir
-- Purpose:           Restore one or many database backups from a single directory.  This script reads all 
--         database backups that are found in the @restoreFromDir parameter.
--         Any database backup that matches the form %_db_% will be restored to
--         the file locations specified in the RestoreTo... parameter(s).  The database
--         will be restored to a database name that is based on the database backup
--         file name.  For  example Insurance_db_200305212302.BAK will be restored to
--         a database named Insurance.  The characters preceeding the '_db_' text determines
--         the name.
--
-- Input Parameters: @restoreFromDir - The directory where the database backups are located
--         @restoreToDataDir - The directory where the data files (i.e. MDF) will be restored to
--         @restoreToLogDir - The directory where the log files (i.e. LDF) will be restored to.  If
--            this parameter is not provided then the log files are restored to @restoreToDataDir.
--                   @MatchFileList - set to 'Y' to restore to same directory structure contained in the backup,
--                           also allows for secondary data files 'ndf' to to be in a different dir than mdf files
--                   @DBName - restore just this one database - selects the latest bak file
--            
-- Output Parameters: None
--
-- Return Values:     
--
-- Written By:        Chris Gallelli -- 8/22/03
-- Modified By:       
-- Modifications:     JB Marchal France -- 10/20/2003
--                       Increase database name length
--                    Bruce Canaday -- 10/20/2003
--                       Added optional parameters @MatchFileList and @DBName
--                    Bruce Canaday -- 10/24/2003
--                       Get the db name as the characters LEFT of the right most '_db_' in the bak filenaame
--                       This is to handle databases such as ALIS_DB
--                    Bruce Canaday -- 10/28/2003
--                       When using @MatchFileList = 'Y' attempt to create any directory that doesn't exist
--                    Bruce Canaday -- 11/04/2003
--                       Allow spaces in the @restoreFromDir directory name
--                 paul Wegmann -- 07/11/2012
--                   Chnaged the create table to allow more feilds to support SQL Server 2008r2 and SQl Server 2012
-- create table #filelist (LogicalName varchar(255), PhysicalName varchar(255), Type varchar(20), FileGroupName varchar(255), Size varchar(20), MaxSize varchar(20),
--                                   FileId int,CreateLSN bit, DropLSN bit, UniqueID varchar(255),ReadOnlyLSn bit, ReadWriteLSN bit, backupSizeInBytes varchar(50), SourceBlockSize int,
--                                    FileGroupid Int, LogGroupGUID varchar(255),DifferentialBaseLSN varchar(255),DifferentialBaseGUID  varchar(255),isReadOnly bit, IsPresent bit,TDEThumbprint varchar(255) )
--                 Paul Wegmann -- 07/11/2012 changed from stored proc to set
--                               declare    @restoreFromDir varchar(255),   
--                                        @restoreToDataDir varchar(255),
--                                       @restoreToLogDir varchar(255) ,
--                                        @MatchFileList char(1) ,
--                                       @OneDBName varchar(255) 
--
--                                       set  @restoreFromDir = 'location of directory where your backup exist'
--                                       set  @restoreToDataDir = 'location where your data files will be restored too'
--                                       set  @restoreToLogDir = 'location of LDF files needs to be restored too'
--                                       set  @MatchFileList = 'N'
--                                       set  @OneDBName = null
--
-- Sample Execution: exec sp_CSS_RestoreDir 'C:\sqldb\sql_backup', 'C:\sqldb\sql_data', 'C:\sqldb\sql_log' (if you use declare/set option then you don't have to use this command to restore) 
--
-- Alternate Execution: exec sp_CSS_RestoreDir 'C:\sqldb\sql_backup', @MatchFileList = 'Y' (if you use declare/set option then you don't have to use this command to restore) 
--
-- Reviewed By:   Anoar Hassan  
-- 
/***************************************************************************************/

CREATE proc sp_CSS_RestoreDir 
    @restoreFromDir varchar(255),
   @restoreToDataDir varchar(255)= null,
   @restoreToLogDir varchar(255) = null,
    @MatchFileList char(1) = 'N',
    @OneDBName varchar(255) = null
as

-- to use delare/set option, use the following code and commond -- the create proc SP_CSS_RestoreDir 
--      declare     @restoreFromDir varchar(255),   
--                @restoreToDataDir varchar(255),
--               @restoreToLogDir varchar(255) ,
--                @MatchFileList char(1) ,
--                @OneDBName varchar(255) 
--
--               set  @restoreFromDir = 'M:\WEBQA2008R2'
--               set  @restoreToDataDir = 'J:\MSSQL10_50.WEBQASQL2008R2\MSSQL\DATA'
--               set  @restoreToLogDir = 'J:\MSSQL10_50.WEBQASQL2008R2\MSSQL\Log'
--               set  @MatchFileList = 'N'
--               set  @OneDBName = null

--If a directory for the Log file is not supplied then use the data directory
If @restoreToLogDir is null
   set @restoreToLogDir = @restoreToDataDir

set nocount on

declare @filename         varchar(60),
    @cmd              varchar(500), 
    @cmd2             varchar(500), 
        @DataName         varchar (255),
    @LogName          varchar (255),
        @LogicalName      varchar(255), 
    @PhysicalName     varchar(255), 
    @Type             varchar(20), 
    @FileGroupName    varchar(255), 
    @Size             varchar(20), 
    @MaxSize          varchar(20),
    @restoreToDir     varchar(255),
        @searchName       varchar(255),
    @DBName           varchar(255),
        @PhysicalFileName varchar(255) 

create table #dirList (filename varchar(100))
--edited by Anoar 
create table #filelist (LogicalName varchar(255), PhysicalName varchar(255), Type varchar(20), FileGroupName varchar(255), Size varchar(50), MaxSize varchar(50),
                                    FileId int,CreateLSN bit, DropLSN bit, UniqueID varchar(255),ReadOnlyLSn bit, ReadWriteLSN bit, backupSizeInBytes varchar(50), SourceBlockSize int,
                                    FileGroupid Int, LogGroupGUID varchar(255),DifferentialBaseLSN varchar(255),DifferentialBaseGUID  varchar(255),isReadOnly bit, IsPresent bit,TDEThumbprint varchar(255) )


--Get the list of database backups that are in the restoreFromDir directory
if @OneDBName is null 
   select @cmd = 'dir /b /on "' +@restoreFromDir+ '"'
else
   select @cmd = 'dir /b /o-d /o-g "' +@restoreFromDir+ '"'

insert #dirList exec master..xp_cmdshell @cmd  

select * from #dirList where filename like '%_db_%' --order by filename

if @OneDBName is null 
   declare BakFile_csr cursor for 
     select * from #dirList where filename like '%_db_%bak' order by filename
else
   begin  -- single db, don't order by filename, take default latest date /o-d parm in dir command above
     select @searchName = @OneDBName + '_db_%bak'
     declare BakFile_csr cursor for 
      select top 1 * from #dirList where filename like @searchName
   end

open BakFile_csr
fetch BakFile_csr into @filename

while @@fetch_status = 0
   begin
       select @cmd = "RESTORE FILELISTONLY FROM disk = '" + @restoreFromDir + "\" + @filename + "'" 

       insert #filelist exec ( @cmd )

       if @OneDBName is null 
          select @dbName = left(@filename,datalength(@filename) - patindex('%_bd_%',reverse(@filename))-3)
       else
      select @dbName = @OneDBName

       select @cmd = "RESTORE DATABASE " + @dbName + 
      " FROM DISK = '" + @restoreFromDir + "\" + @filename + "' WITH " 

       PRINT '' 
       PRINT 'RESTORING DATABASE ' + @dbName

       declare DataFileCursor cursor for  
      select LogicalName, PhysicalName, Type, FileGroupName, Size, MaxSize
      from #filelist

   open DataFileCursor
       fetch DataFileCursor into @LogicalName, @PhysicalName, @Type, @FileGroupName, @Size, @MaxSize

       while @@fetch_status = 0
          begin
              if @MatchFileList != 'Y'
                 begin  -- RESTORE with MOVE option 
             select @PhysicalFileName = reverse(substring(reverse(rtrim(@PhysicalName)),1,patindex('%\%',reverse(rtrim(@PhysicalName)))-1 )) 

             if @Type = 'L'
                select @restoreToDir = @restoreToLogDir
             else
                select @restoreToDir = @restoreToDataDir
       
             select @cmd = @cmd + 
                  " MOVE '" + @LogicalName + "' TO '" + @restoreToDir + "\" + @PhysicalFileName + "', " 
                 end
              else
                 begin  -- Match the file list, attempt to create any missing directory
                     select @restoreToDir = left(@PhysicalName,datalength(@PhysicalName) - patindex('%\%',reverse(@PhysicalName)) )
                     select @cmd2 = "if not exist " +@restoreToDir+ " md " +@restoreToDir
                     exec master..xp_cmdshell  @cmd2
                 end

              fetch DataFileCursor into @LogicalName, @PhysicalName, @Type, @FileGroupName, @Size, @MaxSize

          end  -- DataFileCursor loop

   close DataFileCursor
       deallocate DataFileCursor

       select @cmd = @cmd + ' REPLACE'
       --select @cmd 'command'
       EXEC (@CMD)

       truncate table #filelist

       fetch BakFile_csr into @filename

   end -- BakFile_csr loop

close BakFile_csr
deallocate BakFile_csr

drop table #dirList

return
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
