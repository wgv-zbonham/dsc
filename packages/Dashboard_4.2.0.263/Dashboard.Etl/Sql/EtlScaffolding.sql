declare @table_name nvarchar(MAX) = '$(TableName)'
declare @action nvarchar(max) = '$(Action)'
declare @debug bit = 0

set nocount on;

declare @dynSQL nvarchar(max) = ''
declare @HashColumnList nvarchar(max) = ''
declare @columnList nvarchar(max) = ''
declare @source_schema nvarchar(128) = (select top 1 TABLE_SCHEMA from INFORMATION_SCHEMA.tables where TABLE_SCHEMA <> 'ETL' and TABLE_NAME = @table_name)
declare @primary_key nvarchar(128) 
declare @data_type nvarchar(128) 
declare @tableType nvarchar(max) = (select TABLE_TYPE from INFORMATION_SCHEMA.tables where TABLE_NAME = @table_name and TABLE_SCHEMA <> 'ETL')

if(@tableType = 'view')
begin
	select @primary_key = c.COLUMN_NAME, @data_type = c.DATA_TYPE from INFORMATION_SCHEMA.COLUMNS c where c.TABLE_SCHEMA <> 'ETL' and TABLE_NAME = @table_name and COLUMN_NAME = 'ID'
end

declare @sprocUpdateSchemaTableName nvarchar(max) = 'ETL.Update'+@table_name+'StagingStatus'
declare @viewSchemaTableName nvarchar(max) = 'ETL.'+@TABLE_NAME+'View'
declare @SchemaTableName nvarchar(max) = 'ETL.'+@TABLE_NAME
declare @sprocGetSchemaTableName nvarchar(max) = 'ETL.Get'+@TABLE_NAME+'Batch'
declare @sprocUpdateBadBatchSchemaTableName nvarchar(max) = 'ETL.Update'+@TABLE_NAME+'BadBatch'

if(@tableType <> 'view')
begin
	select 
		@primary_key = c.COLUMN_NAME,
		@data_type = cl.DATA_TYPE
	from 
		INFORMATION_SCHEMA.TABLE_CONSTRAINTS t
			inner join INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE c on 
				t.TABLE_NAME = c.TABLE_NAME and
				t.TABLE_SCHEMA = c.TABLE_SCHEMA and
				t.CONSTRAINT_NAME = c.CONSTRAINT_NAME
			inner join INFORMATION_SCHEMA.COLUMNS cl on
				t.TABLE_NAME = cl.TABLE_NAME and
				t.TABLE_SCHEMA = cl.TABLE_SCHEMA and
				c.COLUMN_NAME = cl.COLUMN_NAME
	where
		t.TABLE_SCHEMA <> 'ETL' and
		t.TABLE_SCHEMA = @source_schema and
		t.TABLE_NAME = @table_name and
		CONSTRAINT_TYPE = 'Primary key'
end	

	
PRINT '-- ' + @action + ' ' + @table_name + ' SCAFFOLDING'
print ''

if (@action = 'DropCreate' and @debug = 0)
begin
	if object_id(@sprocGetSchemaTableName,'P') is not null exec('drop proc '+ @sprocGetSchemaTableName)
	if object_id(@sprocUpdateBadBatchSchemaTableName,'P') is not null exec('drop proc '+ @sprocUpdateBadBatchSchemaTableName)
	if object_id(@sprocUpdateSchemaTableName,'P') is not null exec('drop proc '+ @sprocUpdateSchemaTableName)
	if object_id(@viewSchemaTableName) is not null exec('drop view ' + @viewSchemaTableName)
	if object_id(@SchemaTableName) is not null exec('drop table ' + @SchemaTableName)
end


set @dynSQL = 'CREATE SCHEMA ETL' 
print(@dynSQL)
if (SELECT count(*) FROM SYS.schemas WHERE NAME = 'ETL') < 1
begin
	if (@debug = 0) 
	begin
		exec(@dynSQL)
		print '//'+ @dynSQL
	end
end
ELSE PRINT '-- SCHEMA ETL ALREADY EXISTS'
print ''

set @dynSQL = 
'create table '+@SchemaTableName+' (
	ID bigint identity(1,1) primary key,
	BatchID uniqueidentifier null,
	SourceID '+QUOTENAME(@data_type)+' not null,
	StagingStatus varchar(1) null,
	[MD5RowHash] varbinary(25) null,
	DateCreated datetime not null default getutcdate(),
	DateCompleted datetime null
)'
print(@dynSQL)

if OBJECT_ID(@SchemaTableName) is null 
begin
	if (@debug = 0) 
	begin
		exec(@dynSQL)
		print '-- CREATED ' + @SchemaTableName
	end
end
ELSE PRINT @SchemaTableName + ' ALREADY EXISTS'
print ''

set @dynSQL = 
'create view '+@viewSchemaTableName+' as 
select
	ID,
	SourceID,
	StagingStatus,
	MD5RowHash,
	DateCreated,
	DateCompleted
from
	(
select
	ID,
	SourceID,
	StagingStatus,
	MD5RowHash,
	DateCreated,
	DateCompleted,
	RowOrder = ROW_NUMBER() over(partition by sourceID order by  DateCreated desc, coalesce(DateCompleted,getutcdate() + 1) desc)
from
	'+@SchemaTableName+'
	) as d1
where RowOrder = 1'
print(@dynSQL)

if OBJECT_ID(@viewSchemaTableName) is null 
begin
		if (@debug = 0) 
	begin
		exec(@dynSQL)
		print '-- CREATED VIEW ' + @viewSchemaTableName
	end
end
ELSE PRINT '-- '+@viewSchemaTableName+' ALREADY EXISTS'
print ''


set @columnList = (
	select
		's.'+quotename(COLUMN_NAME) + ','
	from
		INFORMATION_SCHEMA.COLUMNS
	where
		TABLE_SCHEMA = @source_schema and
		TABLE_NAME = @table_name 
for xml path(''))

set @columnList = SUBSTRING(@columnList,1,len(@columnList)-1)


set @HashColumnList = (
	select
		'coalesce(cast(s.'+quotename(COLUMN_NAME)+'as nvarchar(max)),'''') '+' + '
	from
		INFORMATION_SCHEMA.COLUMNS
	where
		TABLE_SCHEMA = @source_schema and
		TABLE_NAME = @table_name 
for xml path(''))

set @HashColumnList = SUBSTRING(@HashColumnList,1,len(@HashColumnList)-1)
SET @HashColumnList = 'Hashbytes(''MD5'','+@HashColumnList+')'

set @dynSQL =
'CREATE PROC '+@sprocUpdateSchemaTableName+' (@TTLMinutes int = 60, @debug bit = 0) as 
begin
	update '+@SchemaTableName+'
	set BatchID = null
	where 
		BatchID is not null and
		DateCompleted is null and
		datediff(mi,DateCreated,GETUTCDATE()) >= @TTLMinutes

	--INSERT NEW DATA
	insert into '+@SchemaTableName+' (SourceID,StagingStatus,MD5RowHash)
	select
		s.'+QUOTENAME(@primary_key)+' as SourceID,
		''I'' as StagingStatus,
		MD5RowHash = '+@HashColumnList+'
	from
		'+@source_schema+'.'+@table_name+' s
			left join '+@viewSchemaTableName+' t on s.ID = t.SourceID
	where
		t.SourceID is null

	--UPDATE EXISTING DATA
	insert into '+@SchemaTableName+' (SourceID,StagingStatus,MD5RowHash)
	select
		s.'+QUOTENAME(@primary_key)+' as SourceID,
		''U'' as StagingStatus,
		MD5RowHash = '+@HashColumnList+'
	from
		'+@viewSchemaTableName+' t
			inner join '+@source_schema+'.'+@table_name+' s on t.SourceID = s.'+QUOTENAME(@primary_key)+'
	where
		t.MD5RowHash <> '+@HashColumnList+'


	--MARKED AS DELETED REMOVED DATA
	insert into '+@SchemaTableName+' (SourceID,StagingStatus,MD5RowHash)
	select
		t.SourceID,
		''D'' as StagingStatus,
		t.MD5RowHash
	from 
		'+@viewSchemaTableName+' t
			left join '+@source_schema+'.'+@table_name+' s on s.'+QUOTENAME(@primary_key)+' = t.SourceID
	where
		t.StagingStatus <> ''D'' and
		s.'+QUOTENAME(@primary_key)+' is null

	if(@debug = 1)
	begin
		select
			StagingStatus,
			count(*) as TotalRows
		from
			'+@viewSchemaTableName+'
		group by
			StagingStatus
	end
end'
print(@dynSQL)
if OBJECT_ID(@sprocUpdateSchemaTableName,'P') is null
begin
	if (@debug = 0) 
	begin
		exec(@dynSQL)
		print '-- CREATED ' + @sprocUpdateSchemaTableName
	end
end
ELSE PRINT '-- '+@sprocUpdateSchemaTableName+' ALREADY EXISTS'
print ''


set @dynSQL =
'create proc '+@sprocGetSchemaTableName+'(@batchSize int) as
begin
	declare @newBatchID uniqueidentifier = newid()

	update top (@batchSize) f
	set BatchID = @newBatchID 
	from
		'+@SchemaTableName+' f
			inner join '+@viewSchemaTableName+' v on f.ID = v.ID
	where
		v.DateCompleted is null and
		f.BatchID is null

	select
		f.[ID] as StagingID,
		f.[BatchID],
		f.[SourceID],
		f.[StagingStatus],
		f.[MD5RowHash],
		'+@columnList+'
	from
		'+@SchemaTableName+' f
			left join '+@source_schema+'.'+@table_name+' s on s.'+QUOTENAME(@primary_key)+' = f.SourceID
	where
		f.BatchID = @newBatchID
end'
print(@dynSQL)
if OBJECT_ID(@sprocGetSchemaTableName,'P') is null
begin
	if (@debug = 0) 
	begin
		exec(@dynSQL)
		print '-- CREATED ' + @sprocGetSchemaTableName
	end
end
ELSE PRINT '-- '+@sprocGetSchemaTableName+' ALREADY EXISTS'
print ''







/*****************************************************************************************************************************/
/** HAS TO EXISTS IN SOURCE SYSTEM BELOW *************************************************************************************/
/*****************************************************************************************************************************/

if (SELECT count(*) FROM SYS.schemas WHERE NAME = 'ETL') < 1
begin
	exec ('create schema ETL')
end


if object_id('[Audit].[DeviceCheckout]') is null
begin
	exec ('

CREATE TABLE [Audit].[DeviceCheckout](
       [ID] [uniqueidentifier] NOT NULL,
       [DeviceID] [uniqueidentifier] NOT NULL,
       [CheckedOut] [datetime] NOT NULL,
       [OfficerID] [int] NOT NULL,
       [AssignmentID] [uniqueidentifier] NOT NULL,
       [AuditID] [uniqueidentifier] ROWGUIDCOL  NOT NULL CONSTRAINT [DF_DeviceCheckout_AuditID]  DEFAULT (newid())
) ON [PRIMARY]
	')
end

if object_id('[Management].[AuditDeviceCheckout]') is null
begin
	exec ('

	CREATE TRIGGER [Management].[AuditDeviceCheckout] 
	   ON  [Management].[DeviceCheckout]
	   AFTER INSERT, UPDATE
	AS 
	BEGIN
	  -- SET NOCOUNT ON added to prevent extra result sets from
	  -- interfering with SELECT statements.
	  SET NOCOUNT ON;
 
	INSERT INTO Audit.DeviceCheckout ([ID], [DeviceID], [CheckedOut], [OfficerID], [AssignmentID]  )
		SELECT a.[ID], a.[DeviceID], a.[CheckedOut], a.[OfficerID], a.[AssignmentID]
		FROM [Management].[DeviceCheckout] a
		INNER JOIN inserted i
				  on a.ID = i.ID 
	END
	
	')
end




if object_id('ETL.AllSequence') is null
begin
	exec('create table ETL.AllSequence (
		  SeqID int identity(1,1) primary key,
		  SeqVal varchar(1)
	)')
end

if object_id('ETL.GetNewSeqVal_AllSequence','P') is null
begin
	exec('create procedure ETL.GetNewSeqVal_AllSequence
	as
	begin
		  declare @NewSeqValue int
		  set NOCOUNT ON
		  insert into ETL.AllSequence (SeqVal) values (''a'')
     
		  set @NewSeqValue = scope_identity()
     
		  delete from ETL.AllSequence WITH (READPAST)

		  if(@NewSeqValue = 9999) truncate table ETL.AllSequence

	return @NewSeqValue
	end')
end
print ''

if object_id('ETL.GenerateStagingTable','P') is null
begin
	exec ('

create proc ETL.GenerateStagingTable (
@tableName nvarchar(max),
@debug bit = 0
) as
begin

	set nocount on;

	Declare @NumRange as varchar(50) = ''%[^0-9]%''
	declare @dateString varchar(50) = convert(varchar,getutcdate(),121)
	Declare @NewSeqVal int = 0

	Exec @NewSeqVal =  ETL.GetNewSeqVal_AllSequence

	While PatIndex(@NumRange, @dateString) > 0
	begin
		Set @dateString = Stuff(@dateString, PatIndex(@NumRange, @dateString), 1, '''')
	end

	declare @dynSQL nvarchar(max) = ''''
	declare @stagingTable nvarchar(max) = N''staging_'' + @tableName + N''_''+ @dateString + N''_''+ right(N''0000'' + cast( @NewSeqVal as nvarchar(max)),4)
	declare @createColumns nvarchar(max) = ''''
	declare @columnList nvarchar(max) = ''''
	declare @columnParams nvarchar(max) = ''''
	declare @sourceSchema nvarchar(128) = (select top 1 TABLE_SCHEMA from INFORMATION_SCHEMA.tables where TABLE_SCHEMA <> ''ETL'' and TABLE_NAME = @tableName)
	declare @primaryKey nvarchar(max)
	declare @dataType nvarchar(max)
	declare @tableType nvarchar(max) = (select TABLE_TYPE from INFORMATION_SCHEMA.tables where TABLE_NAME = @tableName and TABLE_SCHEMA <> ''ETL'')

	if(@tableType = ''view'')
	begin
		select @primaryKey = c.COLUMN_NAME, @dataType = c.DATA_TYPE from INFORMATION_SCHEMA.COLUMNS c where c.TABLE_SCHEMA <> ''ETL'' and TABLE_NAME = @tableName and COLUMN_NAME = ''ID''
	end

	set @createColumns = (
		select top (2147483647)
			quotename(COLUMN_NAME) + '' '' + 
			quotename(data_type) + '''' + 
			case 
				when CHARACTER_MAXIMUM_LENGTH = -1 then ''(max)'' 
				when CHARACTER_MAXIMUM_LENGTH is not null then ''(''+cast(CHARACTER_MAXIMUM_LENGTH as nvarchar(max)) + '')'' 
				else '''' 
			end + '',''
		from
			INFORMATION_SCHEMA.COLUMNS
		where
			TABLE_SCHEMA = @sourceSchema and
			TABLE_NAME = @tableName 
		order by ORDINAL_POSITION
	for xml path(''''))
	set @createColumns = SUBSTRING(@createColumns,1,len(@createColumns)-1)

	set @columnList = (
		select top (2147483647)
			quotename(COLUMN_NAME) + '',''
		from
			INFORMATION_SCHEMA.COLUMNS
		where
			TABLE_SCHEMA = @sourceSchema and
			TABLE_NAME = @tableName 
		order by ORDINAL_POSITION
	for xml path(''''))
	set @columnList = SUBSTRING(@columnList,1,len(@columnList)-1)

	set @columnParams = (
		select top (2147483647)
			''@''+COLUMN_NAME + '',''
		from
			INFORMATION_SCHEMA.COLUMNS
		where
			TABLE_SCHEMA = @sourceSchema and
			TABLE_NAME = @tableName 
		order by ORDINAL_POSITION
	for xml path(''''))
	set @columnParams = SUBSTRING(@columnParams,1,len(@columnParams)-1)

	if(@tableType <> ''view'')
	begin
		select 
			@primaryKey = c.COLUMN_NAME,
			@dataType = cl.DATA_TYPE
		from 
			INFORMATION_SCHEMA.TABLE_CONSTRAINTS t
				inner join INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE c on 
					t.TABLE_NAME = c.TABLE_NAME and
					t.TABLE_SCHEMA = c.TABLE_SCHEMA and
					t.CONSTRAINT_NAME = c.CONSTRAINT_NAME
				inner join INFORMATION_SCHEMA.COLUMNS cl on
					t.TABLE_NAME = cl.TABLE_NAME and
					t.TABLE_SCHEMA = cl.TABLE_SCHEMA and
					c.COLUMN_NAME = cl.COLUMN_NAME
		where
			t.TABLE_SCHEMA <> ''ETL'' and
			t.TABLE_SCHEMA = @sourceSchema and
			t.TABLE_NAME = @tableName and
			CONSTRAINT_TYPE = ''Primary key''
	end


	set @dynSQL = 
	''exec sp_executesql N''''create table ''+@stagingTable+'' (
		StagingID bigint primary key,
		BatchID uniqueidentifier not null,
		SourceID ''+QUOTENAME(@dataType)+'' not null,
		StagingStatus varchar(1) null,
		[MD5RowHash] varbinary(25) null,
		''+@createColumns+'',
		DateCreated datetime not null default getutcdate(),
		DateCompleted datetime null
	)''''''
	print(@dynSQL)

	declare @createStagingTableScript nvarchar(max) = @dynSQL

	set @dynSQL = ''insert into ''+@stagingTable+'' (StagingID, BatchID, SourceID, StagingStatus, MD5RowHash,''+@columnList+'') values(@StagingID, @BatchID, @SourceID, @StagingStatus, @MD5RowHash,''+@columnParams+'')''
	declare @insertStagingTableScript nvarchar(max) = @dynSQL

	select
		@stagingTable as [StagingTable],
		@createStagingTableScript as [CreateStagingTable],
		@insertStagingTableScript as [InsertStagingTable]
	
end

	
	')
end



if object_id('ETLDeviceView') is null
begin
	exec ('
create view ETLDeviceView as
select
	[ID],
	[Name],
	[SerialNumber],
	[VehicleID],
	[IPAddress],
	[MACAddress],
	[SoftwareVersion],
	[ConfigurationVersion]
from
	(
	select
		[ID]
		  ,[SerialNumber] as [Name]
		  ,[SerialNumber]
		  ,'''' as [VehicleID]
		  ,'''' as [IPAddress]
		  ,'''' as [MACAddress]
		  ,'''' as [SoftwareVersion]
		  ,'''' as [ConfigurationVersion]
	from
		Management.Vista
	union all
	select
		[ID]
		,coalesce([VehicleID],'''') as [Name]
		,coalesce([SerialNumber],'''') as [SerialNumber]
		,coalesce([VehicleID],'''') as [VehicleID]
		,coalesce(DeviceIPAddress,'''') as [IPAddress]
		,coalesce([MACAddress],'''') as [MACAddress]
		,coalesce([SoftwareVersion],'''') as [SoftwareVersion]
		,coalesce([ConfigurationVersion],'''') as [ConfigurationVersion]
	from
		dbo.Vehicles
	) as d2')
end

if object_id('ETLRecordingEventGPSView') is null
begin
	exec ('
	create view ETLRecordingEventGPSView 
	WITH SCHEMABINDING
	as
	SELECT
		mmd.ID,
		r.id as RecordingEventID,
		mmd.TID,
		mmd.value as GPS
	FROM 
	dbo.RecordingEvent r
		inner join dbo.MediaMetaData mmd on r.ID= mmd.MID
		inner join dbo.MetaDataType me on mmd.MetaDataTypeID=me.ID
		inner join dbo.MetaDataEventType mdet on me.MetaDataEventTypeID=mdet.ID
	where 
		mdet.ID in (12) --GPS Data --select * from MetaDataEventType where id = 12
		and (mmd.Value <> ''94:1'' and mmd.Value <> ''94:0'')
	')

	exec ('
	CREATE UNIQUE CLUSTERED INDEX CIX_RecordingEventGPSView
	ON ETLRecordingEventGPSView (ID,RecordingEventID, TID, GPS);
	')

end

if object_id('ETLRecordingEventView') is null
begin
	exec ('

create view [dbo].[ETLRecordingEventView] as 
select 
	r.[ID]
	,r.[OfficerID]
	,coalesce(ar.AvduStorageID,-1) as [StorageID]
	,coalesce(r.DeviceId,''00000000-0000-0000-0000-000000000000'') as DeviceID
	,coalesce(r.[ImportReasonID],-1) as [ImportReasonID]
	,[RecordStartID] = case when convert(varchar,r.[RecordStart],112) between ''20000101'' and ''20501231'' then convert(varchar,r.[RecordStart],112) else -1 end
	,[DateCreatedID] = case when convert(varchar,r.Created ,112) between ''20000101'' and ''20501231'' then convert(varchar,r.Created ,112) else -1 end
	,[DateImportedID] = case when convert(varchar,r.Imported,112) between ''20000101'' and ''20501231'' then convert(varchar,r.Imported,112) else -1 end
	,r.[Duration] / 10000000 as [DurationSeconds] --CONVERTS TICKS TO SECONDS
	,coalesce(r.[Restricted],'''') as [Restricted]
	,coalesce(r.[DVRCleared],'''') as [DVRCleared]
	,coalesce(r.[REID],'''') as [REID]
	,coalesce(r.[PreEvent],'''') as [PreEvent]
	,coalesce(r.[RecordStart],'''') as [RecordStart]
	,coalesce(r.[RecordStop],'''') as [RecordStop]
	,coalesce(r.[PostEvent],'''') as [PostEvent]
	,coalesce(r.[ImportSource],'''') as [ImportSource]
	,coalesce(r.Created,'''') as Created
	,coalesce(r.Imported,'''') as Imported
	,coalesce(r.[LastUsed],'''') as [LastUsed]
	,coalesce(r.[Archived],'''') as [Archived]
	,coalesce(r.[SubstationID],'''') as [SubstationID]
	,coalesce(r.[SoftwareVersion],'''') as [SoftwareVersion]
	,coalesce(gps.MinGPS,'''') as MinGPS
	,coalesce(gps.MaxGPS,'''') as MaxGPS
	,0 as [MinSpeed]
	,0 as [MaxSpeed]
	,Size = coalesce((select coalesce(sum(res.size),0) from RecordingEventStream res where res.RecordEventID = r.ID),0)
	,coalesce(r.[Note],'''') as [Note]
	,coalesce(r.[SplitEventGroupId],'''') as [GroupId]
	,coalesce(r.[Part],'''') as [Part]
	,coalesce(r.[TotalParts],'''') as [TotalParts] 
	,coalesce(r.[LinkChecked],'''') as [LinkChecked]
from
	dbo.RecordingEvent r
		left join [Storage].[Avdu_XR_Title] ar on r.ID = ar.ItemID --HAS UNIQUE CONSTRAINT ON ItemID
		left join (
			select
				RecordingEventID,
				coalesce(max(MinGPS),max(MaxGPS)) as MinGPS,
				coalesce(max(MaxGPS),max(MinGPS)) as MaxGPS
			from
				(
				select	
					ID,RecordingEventID, GPS,
					case	
						when ROW_NUMBER() over (partition by RecordingEventID order by TID) = 1 then ''MinGPS''
						when ROW_NUMBER() over (partition by RecordingEventID order by TID desc) = 1 then ''MaxGPS''
					end
						as GPSPosition
				from
					ETLRecordingEventGPSView 
				) as d1
			pivot(max(GPS) for GPSPosition in ([MinGPS],[MaxGPS])) as d2
			where
				[MinGPS] is not null or
				[MaxGPS] is not null
			group by RecordingEventID		
		) as gps on r.ID = gps.RecordingEventID
	
	')
end


if object_id('ETLDeviceCheckoutView') is null
begin
	exec ('
		create view [dbo].[ETLDeviceCheckoutView] as
		select
			[AuditID] as ID,
			DeviceID,
			CheckedOut,
			OfficerID,
			AssignmentID,
			AuditID
		from
			[Audit].DeviceCheckout
	')
end


if object_id('ETLRecordingEventActivityView') is null
begin
	exec ('
create view [dbo].[ETLRecordingEventActivityView] as 
select
	ae.AuditEventId as ID,	
	re.ID as RecordingEventID,
	re.EventStatus,
	ae.AuditActivity,
	ae.AuditType,
	re.Modified,
	ae.OccurredAt
from
	dbo.RecordingEvent re
		inner join [Audit].AuditEvent ae on re.ID = ae.ForeignId
	')
end


if object_id('ETLEventCategoryRecordingEventView') is null
begin
	exec ('

	create view ETLEventCategoryRecordingEventView as 
	select
		ti.ID,
		ti.ID as MetaDataEventTagItemID,
		reti.RecordingEventID,
		coalesce(ta.ID,-1) as EventCategoryID,
		ti.Value as EventCategory,
		coalesce(cast(rp.Interval as nvarchar(max)),''Infinity'') as RetentionDays,
		coalesce(ta.Critical,0) as Critical
	from
		MetaDataEventTagType tt
			inner join MetaDataEventTagItem ti on tt.MetaDataEventTypeID = ti.MetaDataEventTagTypeID
			left join MetaDataEventTagAnswer ta on tt.MetaDataEventTypeID = ta.MetaDataEventTagTypeID and ti.Value = coalesce(ta.Caption,''Unknown'')
			left join RecordingEvent_XR_MetaDataEventTagItem reti on ti.ID = reti.MetaDataEventTagItemID
			left join MetaDataEventTagAnswerWithRetentionPolicy tarp on tarp.MetaDataEventTagAnswerID = ta.ID
			left join RetentionPolicy rp on rp.ID = tarp.RetentionPolicyID
	where
		tt.MetaDataEventTypeID = 21
	
	')
end

if object_id('ETLEventCategoryView') is null
begin
	exec ('

create view ETLEventCategoryView as 
select 
	ta.ID,
	ta.ID as EventCategoryID,
	ta.Caption as Name,
	ta.DisplayIndex,
	rp.Interval as RetentionDays,
	coalesce(ta.Critical,0) as Critical
from
	MetaDataEventTagType tt
		inner join MetaDataEventTagAnswer ta on tt.MetaDataEventTypeID = ta.MetaDataEventTagTypeID
		left join MetaDataEventTagAnswerWithRetentionPolicy tarp on tarp.MetaDataEventTagAnswerID = ta.ID
		left join RetentionPolicy rp on rp.ID = tarp.RetentionPolicyID
where
	tt.MetaDataEventTypeID = 21 

	
	')
end

if object_id('ETLStorageView') is null
begin
	exec ('

		create view ETLStorageView as 
		select
			ID,
			Name,
			[Path],
			0 as Size
		from
			Storage.AvduStorage
	
	')
end


if object_id('ETLCaseItemInfoView') is null
begin
	exec ('
create view ETLCaseItemInfoView as
select
	ci.ID,
	c.ID as CaseID,
	c.Created as CaseCreated,
	ci.Name as CaseItemInfoName,
	ci.Category as CaseItemInfoCategory,
	ci.Created as CaseItemInfoCreated,
	cast(0 as bigint) as CaseItemInfoStorageReferenceID,
	ci.SizeInBytes as CaseItemInfoSizeInBytes,
	ci.Modified as CaseItemInfoModified
from
	[Case] c
		inner join [CaseItemInfo] ci on c.ID = ci.CaseID
where
	ci.RecordingEventID <> ''00000000-0000-0000-0000-000000000000''
	
	')
end



if object_id('ETLCaseItemInfoRecordingEventView') is null
begin
	exec ('
create view ETLCaseItemInfoRecordingEventView as
select
	ci.ID,
	ci.RecordingEventID
from
	[CaseItemInfo] ci
where
	ci.RecordingEventID <> ''00000000-0000-0000-0000-000000000000''
	
	')
end


if object_id('PurgeETLTables') is null
begin
	exec ('
		create proc [dbo].PurgeETLTables as
		begin
			declare @dynSQL nvarchar(max) = ''''

			select
				@dynSQL += ''
				delete from
					ETL.''+c.TABLE_NAME+''
				where
					id not in (
					select
						v.ID
					from
						ETL.''+c.TABLE_NAME+''View v)	

				delete from ETL.''+c.TABLE_NAME+''
				WHERE StagingStatus = ''''D''''
				''+char(10)
			from
				INFORMATION_SCHEMA.COLUMNS c
					inner join INFORMATION_SCHEMA.TABLES t on c.TABLE_NAME = t.TABLE_NAME and c.TABLE_SCHEMA = t.TABLE_SCHEMA
			where
				t.TABLE_TYPE = ''BASE TABLE'' and 
				c.TABLE_SCHEMA = ''etl'' and
				c.COLUMN_NAME = ''StagingStatus''


			print @dynSQL
			exec (@dynSQL)

		end
	
	')
end