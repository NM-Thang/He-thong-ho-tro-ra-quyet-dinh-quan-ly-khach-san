USE msdb;
GO

-- Xóa job cũ nếu tồn tại
IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'Auto_Sync_Hotel_Data')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = 'Auto_Sync_Hotel_Data';
    PRINT 'Đã xóa job cũ Auto_Sync_Hotel_Data';
END
GO

-- Tạo job mới
BEGIN TRY
    DECLARE @jobId BINARY(16);
    
    -- Tạo job
    EXEC msdb.dbo.sp_add_job 
        @job_name = 'Auto_Sync_Hotel_Data',
        @enabled = 1,
        @description = 'Tự động đồng bộ dữ liệu khách sạn từ Customer và Hotel sang IDBHotel hàng ngày lúc 2:00 AM',
        @job_id = @jobId OUTPUT;
    
    -- Thêm bước thực thi
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @jobId,
        @step_name = 'Sync_Hotel_Data',
        @subsystem = 'TSQL',
        @command = 'EXEC IDBHotel.dbo.sp_Sync_Hotel_Data;',
        @database_name = 'IDBHotel';
    
    -- Tạo lịch trình 2:00 AM
    IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE name = 'Daily_Sync_Schedule')
    BEGIN
        EXEC msdb.dbo.sp_add_schedule
            @schedule_name = 'Daily_Sync_Schedule',
            @freq_type = 4, -- Daily
            @freq_interval = 1, -- Mỗi ngày
            --@freq_subday_type = 2, -- Theo giây, neu theo phut thì để là 4
            --@freq_subday_interval = 60, -- Mỗi 60 giây (1 phút)
            @freq_recurrence_factor = 1,
            @active_start_date = 20250617, -- Ngày bắt đầu
            @active_end_date = 99991231, -- Ngày kết thúc
            @active_start_time = 20000; -- 2:00 AM  -- HH:MM:SS (2:00 AM là 20000)
    END
    
    -- Gán lịch trình
    EXEC msdb.dbo.sp_attach_schedule
        @job_id = @jobId,
        @schedule_name = 'Daily_Sync_Schedule';
    
    -- Gán job cho SQL Server Agent
    EXEC msdb.dbo.sp_add_jobserver
        @job_id = @jobId;
    
    PRINT 'Đã tạo thành công job Auto_Sync_Hotel_Data sẽ chạy hàng ngày lúc 2:00 AM';
END TRY
BEGIN CATCH
    PRINT 'Lỗi khi tạo job: ' + ERROR_MESSAGE();
    IF @jobId IS NOT NULL
    BEGIN
        EXEC msdb.dbo.sp_delete_job @job_id = @jobId;
    END;
END CATCH;
GO