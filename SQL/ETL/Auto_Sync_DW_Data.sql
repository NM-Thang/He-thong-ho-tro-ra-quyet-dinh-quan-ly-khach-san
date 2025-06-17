-- Cấu hình SQL Server Agent Job để đồng bộ mỗi tháng
USE msdb;
GO

-- Xóa job cũ nếu tồn tại
IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'Auto_Sync_DW_Data')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = 'Auto_Sync_DW_Data';
    PRINT 'Đã xóa job cũ Auto_Sync_DW_Data';
END
GO

-- Tạo job mới
BEGIN TRY
    DECLARE @jobId BINARY(16);
    
    -- Tạo job
    EXEC msdb.dbo.sp_add_job 
        @job_name = 'Auto_Sync_DW_Data',
        @enabled = 1,
        @description = 'Tự động đồng bộ dữ liệu từ IDBHotel sang DW_Hotel mỗi tháng vào ngày 1 lúc 3:00 AM',
        @job_id = @jobId OUTPUT;
    
    -- Thêm bước thực thi
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @jobId,
        @step_name = 'Sync_DW_Data',
        @subsystem = 'TSQL',
        @command = 'EXEC IDBHotel.dbo.sp_Sync_DW_Data;',
        @database_name = 'IDBHotel';
    
    -- Tạo lịch trình chạy mỗi tháng
    IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE name = 'Monthly_Sync_Schedule')
    BEGIN
        EXEC msdb.dbo.sp_add_schedule
            @schedule_name = 'Monthly_Sync_Schedule',
            @freq_type = 16, -- Monthly
            @freq_interval = 1, -- Ngày 1 mỗi tháng
            @freq_recurrence_factor = 1, -- Lặp lại mỗi tháng
            @active_start_date = 20250617, -- Ngày bắt đầu
            @active_end_date = 99991231, -- Ngày kết thúc
            @active_start_time = 30000; -- 3:00 AM (HHMMSS)
    END
    
    -- Gán lịch trình
    EXEC msdb.dbo.sp_attach_schedule
        @job_id = @jobId,
        @schedule_name = 'Monthly_Sync_Schedule';
    
    -- Gán job cho SQL Server Agent
    EXEC msdb.dbo.sp_add_jobserver
        @job_id = @jobId;
    
    PRINT 'Đã tạo thành công job Auto_Sync_DW_Data chạy mỗi tháng vào ngày 1 lúc 3:00 AM';
END TRY
BEGIN CATCH
    PRINT 'Lỗi khi tạo job: ' + ERROR_MESSAGE();
    IF @jobId IS NOT NULL
    BEGIN
        EXEC msdb.dbo.sp_delete_job @job_id = @jobId;
    END;
END CATCH;
GO
