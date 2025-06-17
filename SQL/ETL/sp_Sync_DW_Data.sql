-- Sử dụng cơ sở dữ liệu IDBHotel để tạo stored procedure
USE IDBHotel;
GO

-- Stored procedure đồng bộ dữ liệu từ IDBHotel sang DW_Hotel
CREATE OR ALTER PROCEDURE [dbo].[sp_Sync_DW_Data]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BatchSize INT = 10000;
    DECLARE @Offset INT = 0;
    DECLARE @StartTime DATETIME = GETDATE();
    
    BEGIN TRY
        -- Ghi nhật ký bắt đầu
        INSERT INTO SyncLog (Message) 
        VALUES ('Bắt đầu đồng bộ dữ liệu từ IDBHotel sang DW_Hotel.');

        -- 1. Dim_Time
        -- Trích xuất và tạo dữ liệu thời gian từ IDBHotel
        -- Bước 1: Lấy thời gian bắt đầu (tháng tiếp theo sau time_key lớn nhất)
        DECLARE @startYear INT, @startMonth INT;
        SELECT 
            @startYear = CASE 
                            WHEN MAX(time_key) IS NULL THEN YEAR(GETDATE())
                            ELSE (MAX(time_key) / 100) + CASE WHEN (MAX(time_key) % 100 = 12) THEN 1 ELSE 0 END
                        END,
            @startMonth = CASE 
                            WHEN MAX(time_key) IS NULL THEN MONTH(GETDATE())
                            ELSE CASE WHEN (MAX(time_key) % 100 = 12) THEN 1 ELSE (MAX(time_key) % 100 + 1) END
                        END
        FROM DW_Hotel.dbo.Dim_Time;

        -- Bước 2: Lấy thời gian kết thúc là tháng/năm lớn nhất từ các bảng giao dịch
        DECLARE @endDate DATE = (
            SELECT MAX(maxDate)
            FROM (
                SELECT MAX(checkInDate) AS maxDate FROM IDBHotel.dbo.BookedRoom
                UNION
                SELECT MAX(checkOutDate) FROM IDBHotel.dbo.BookedRoom
                UNION
                SELECT MAX(serviceTime) FROM IDBHotel.dbo.ServiceUsage
                UNION
                SELECT MAX(reviewTime) FROM IDBHotel.dbo.Review
            ) AS combinedMax
        );

        DECLARE @endYear INT = YEAR(@endDate);
        DECLARE @endMonth INT = MONTH(@endDate);

        -- Bước 3: Tạo bảng tạm lưu danh sách các time_key cần thêm
        WITH MonthSequence AS (
            SELECT 
                CAST(CONCAT(@startYear, RIGHT('00' + CAST(@startMonth AS VARCHAR(2)), 2)) AS INT) AS time_key,
                @startMonth AS month,
                @startYear AS year
            UNION ALL
            SELECT 
                CAST(CONCAT(
                    CASE WHEN month = 12 THEN year + 1 ELSE year END,
                    RIGHT('00' + CAST(CASE WHEN month = 12 THEN 1 ELSE month + 1 END AS VARCHAR(2)), 2)
                ) AS INT),
                CASE WHEN month = 12 THEN 1 ELSE month + 1 END,
                CASE WHEN month = 12 THEN year + 1 ELSE year END
            FROM MonthSequence
            WHERE (year < @endYear) OR (year = @endYear AND month < @endMonth)
        )

        -- Bước 4: Chèn vào bảng Dim_Time nếu chưa có
        INSERT INTO DW_Hotel.dbo.Dim_Time (time_key, month, quarter, year)
        SELECT 
            time_key,
            month,
            ((month - 1) / 3) + 1 AS quarter,
            year
        FROM MonthSequence
        WHERE NOT EXISTS (
            SELECT 1 FROM DW_Hotel.dbo.Dim_Time dt
            WHERE dt.time_key = MonthSequence.time_key
        )


        INSERT INTO DW_Hotel.dbo.Dim_Time (time_key, month, quarter, year)
        SELECT DISTINCT 
            (YEAR(date) * 100 + MONTH(date)) AS time_key,
            MONTH(date) AS month,
            (MONTH(date) - 1) / 3 + 1 AS quarter,
            YEAR(date) AS year
        FROM (
            SELECT checkInDate AS date FROM IDBHotel.dbo.BookedRoom
            UNION
            SELECT checkOutDate AS date FROM IDBHotel.dbo.BookedRoom
            UNION
            SELECT serviceTime FROM IDBHotel.dbo.ServiceUsage
            UNION
            SELECT reviewTime FROM IDBHotel.dbo.Review
        ) AS dates
        WHERE NOT EXISTS (
            SELECT 1 FROM DW_Hotel.dbo.Dim_Time dt 
            WHERE dt.time_key = (YEAR(dates.date) * 100 + MONTH(dates.date))
        );

        -- 2. Dim_Location
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM IDBHotel.dbo.Hotel
            ORDER BY hotelId
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT 
                    h.hotelId,
                    h.hotelName,
                    l.cityId,
                    l.cityName,
                    l.region
                FROM IDBHotel.dbo.Hotel h
                INNER JOIN IDBHotel.dbo.Location l ON h.cityId = l.cityId
                ORDER BY h.hotelId
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO DW_Hotel.dbo.Dim_Location AS target
            USING SourceData AS source
            ON target.hotel_id = source.hotelId and target.cityId = source.cityId
            WHEN NOT MATCHED THEN
                INSERT (hotel_id, hotelName, cityId, cityName, region)
                VALUES (source.hotelId, source.hotelName, source.cityId, source.cityName, source.region);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 3. Dim_Room
        MERGE INTO DW_Hotel.dbo.Dim_Room AS target
        USING (
            SELECT DISTINCT roomType
            FROM IDBHotel.dbo.Room
        ) AS source
        ON target.roomType = source.roomType
        WHEN NOT MATCHED THEN
            INSERT (roomType)
            VALUES (source.roomType);

        -- 4. Dim_Service
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM IDBHotel.dbo.Service
            ORDER BY serviceId
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT 
                    serviceId AS service_key,
                    serviceType,
                    serviceName
                FROM IDBHotel.dbo.Service
                ORDER BY serviceId
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO DW_Hotel.dbo.Dim_Service AS target
            USING SourceData AS source
            ON target.service_key = source.service_key
            WHEN NOT MATCHED THEN
                INSERT (service_key, serviceType, serviceName)
                VALUES (source.service_key, source.serviceType, source.serviceName);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 5. Dim_Customer
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM IDBHotel.dbo.Customer
            ORDER BY customerId
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT 
                    customerId AS customer_key,
                    fullName AS customerName,
                    customerType,
                    nationality
                FROM IDBHotel.dbo.Customer
                ORDER BY customerId
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO DW_Hotel.dbo.Dim_Customer AS target
            USING SourceData AS source
            ON target.customer_key = source.customer_key
            WHEN NOT MATCHED THEN
                INSERT (customer_key, customerName, customerType, nationality)
                VALUES (source.customer_key, source.customerName, source.customerType, source.nationality);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 6. Fact_Room
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM IDBHotel.dbo.BookedRoom
            ORDER BY bookedRoomId
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT 
                    (YEAR(br.checkOutDate) * 100 + MONTH(br.checkOutDate)) AS time_key,
                    dl.location_key,
                    dr.room_key,
                    dc.customer_key,
                    SUM(br.totalRoomPrice) AS roomRevenue,
                    COUNT(*) AS roomBookingCount,
                    AVG(CAST(r.ratingScore AS DECIMAL(3,2))) AS avgRating
                FROM IDBHotel.dbo.BookedRoom br
                INNER JOIN IDBHotel.dbo.Room rm ON br.roomId = rm.roomId
                INNER JOIN IDBHotel.dbo.Hotel h ON rm.hotelId = h.hotelId
                INNER JOIN DW_Hotel.dbo.Dim_Location dl ON h.hotelId = dl.hotel_id
                INNER JOIN DW_Hotel.dbo.Dim_Room dr ON rm.roomType = dr.roomType
                INNER JOIN IDBHotel.dbo.Booking b ON br.bookingId = b.bookingId
                INNER JOIN IDBHotel.dbo.Customer c ON b.customerId = c.customerId
                INNER JOIN DW_Hotel.dbo.Dim_Customer dc ON c.customerId = dc.customer_key
                LEFT JOIN IDBHotel.dbo.Review r ON br.bookedRoomId = r.bookedRoomId
                WHERE br.checkOutDate >= DATEADD(MONTH, -1, GETDATE())
                GROUP BY 
                    (YEAR(br.checkOutDate) * 100 + MONTH(br.checkOutDate)),
                    dl.location_key,
                    dr.room_key,
                    dc.customer_key
                ORDER BY dl.location_key
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO DW_Hotel.dbo.Fact_Room AS target
            USING SourceData AS source
            ON target.time_key = source.time_key
            AND target.location_key = source.location_key
            AND target.room_key = source.room_key
            AND target.customer_key = source.customer_key
            WHEN MATCHED THEN
                UPDATE SET
                    roomRevenue = source.roomRevenue,
                    roomBookingCount = source.roomBookingCount,
                    avgRating = source.avgRating
            WHEN NOT MATCHED THEN
                INSERT (time_key, location_key, room_key, customer_key, roomRevenue, roomBookingCount, avgRating)
                VALUES (source.time_key, source.location_key, source.room_key, source.customer_key, source.roomRevenue, source.roomBookingCount, source.avgRating);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 7. Fact_Service
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM IDBHotel.dbo.ServiceUsage
            ORDER BY serviceUsageId
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT 
                    (YEAR(su.serviceTime) * 100 + MONTH(su.serviceTime)) AS time_key,
                    dl.location_key,
                    ds.service_key,
                    dc.customer_key,
                    SUM(su.totalServicePrice) AS serviceRevenue,
                    SUM(su.quantity) AS serviceCount
                FROM IDBHotel.dbo.ServiceUsage su
                INNER JOIN IDBHotel.dbo.Service s ON su.serviceId = s.serviceId
                INNER JOIN IDBHotel.dbo.BookedRoom br ON su.bookedRoomId = br.bookedRoomId
                INNER JOIN IDBHotel.dbo.Room rm ON br.roomId = rm.roomId
                INNER JOIN IDBHotel.dbo.Hotel h ON rm.hotelId = h.hotelId
                INNER JOIN DW_Hotel.dbo.Dim_Location dl ON h.hotelId = dl.hotel_id
                INNER JOIN DW_Hotel.dbo.Dim_Service ds ON s.serviceId = ds.service_key
                INNER JOIN IDBHotel.dbo.Booking b ON br.bookingId = b.bookingId
                INNER JOIN IDBHotel.dbo.Customer c ON b.customerId = c.customerId
                INNER JOIN DW_Hotel.dbo.Dim_Customer dc ON c.customerId = dc.customer_key
                WHERE su.serviceTime >= DATEADD(MONTH, -1, GETDATE())
                GROUP BY 
                    (YEAR(su.serviceTime) * 100 + MONTH(su.serviceTime)),
                    dl.location_key,
                    ds.service_key,
                    dc.customer_key
                ORDER BY dl.location_key
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO DW_Hotel.dbo.Fact_Service AS target
            USING SourceData AS source
            ON target.time_key = source.time_key
            AND target.location_key = source.location_key
            AND target.service_key = source.service_key
            AND target.customer_key = source.customer_key
            WHEN MATCHED THEN
                UPDATE SET
                    serviceRevenue = source.serviceRevenue,
                    serviceCount = source.serviceCount
            WHEN NOT MATCHED THEN
                INSERT (time_key, location_key, service_key, customer_key, serviceRevenue, serviceCount)
                VALUES (source.time_key, source.location_key, source.service_key, source.customer_key, source.serviceRevenue, source.serviceCount);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 8. Fact_Revenue
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM IDBHotel.dbo.BookedRoom
            ORDER BY bookedRoomId
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT 
                    (YEAR(br.checkOutDate) * 100 + MONTH(br.checkOutDate)) AS time_key,
                    dl.location_key,
                    dc.customer_key,
                    SUM(br.totalRoomPrice + ISNULL(su.totalServicePrice, 0)) AS totalRevenue
                FROM IDBHotel.dbo.BookedRoom br
                INNER JOIN IDBHotel.dbo.Room rm ON br.roomId = rm.roomId
                INNER JOIN IDBHotel.dbo.Hotel h ON rm.hotelId = h.hotelId
                INNER JOIN DW_Hotel.dbo.Dim_Location dl ON h.hotelId = dl.hotel_id
                INNER JOIN IDBHotel.dbo.Booking b ON br.bookingId = b.bookingId
                INNER JOIN IDBHotel.dbo.Customer c ON b.customerId = c.customerId
                INNER JOIN DW_Hotel.dbo.Dim_Customer dc ON c.customerId = dc.customer_key
                LEFT JOIN IDBHotel.dbo.ServiceUsage su ON br.bookedRoomId = su.bookedRoomId
                WHERE br.checkOutDate >= DATEADD(MONTH, -1, GETDATE())
                GROUP BY 
                    (YEAR(br.checkOutDate) * 100 + MONTH(br.checkOutDate)),
                    dl.location_key,
                    dc.customer_key
                ORDER BY dl.location_key
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO DW_Hotel.dbo.Fact_Revenue AS target
            USING SourceData AS source
            ON target.time_key = source.time_key
            AND target.location_key = source.location_key
            AND target.customer_key = source.customer_key
            WHEN MATCHED THEN
                UPDATE SET
                    totalRevenue = source.totalRevenue
            WHEN NOT MATCHED THEN
                INSERT (time_key, location_key, customer_key, totalRevenue)
                VALUES (source.time_key, source.location_key, source.customer_key, source.totalRevenue);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- Ghi nhật ký thành công
        INSERT INTO SyncLog (Message) 
        VALUES ('Đồng bộ dữ liệu từ IDBHotel sang DW_Hotel thành công. Thời gian: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS NVARCHAR(50)) + ' giây.');
    END TRY
    BEGIN CATCH
        -- Ghi nhật ký lỗi
        DECLARE @ErrorMsg NVARCHAR(1000) = 'Lỗi đồng bộ DW: ' + ERROR_MESSAGE();
        INSERT INTO SyncLog (Message) VALUES (@ErrorMsg);
        THROW;
    END CATCH;
END;
GO