USE IDBHotel;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_Sync_Hotel_Data]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BatchSize INT = 10000;
    DECLARE @Offset INT = 0;
    
    BEGIN TRY
        INSERT INTO SyncLog (Message) VALUES ('Bắt đầu đồng bộ dữ liệu.');

        -- 1. Location
        MERGE INTO Location AS target
        USING (
            SELECT MaThanhPho, TenThanhPho, VungMien
            FROM Hotel.dbo.ViTri
        ) AS source
        ON target.cityId = source.MaThanhPho
        WHEN MATCHED THEN
            UPDATE SET 
                cityName = source.TenThanhPho,
                region = source.VungMien
        WHEN NOT MATCHED THEN
            INSERT (cityId, cityName, region)
            VALUES (source.MaThanhPho, source.TenThanhPho, source.VungMien);

        -- 2. Hotel
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Hotel.dbo.KhachSan
            ORDER BY MaKhachSan
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaKhachSan, TenKhachSan, DiaChiChiTiet, HangSao, MaThanhPho
                FROM Hotel.dbo.KhachSan
                WHERE EXISTS (SELECT 1 FROM Location l WHERE l.cityId = MaThanhPho)
                ORDER BY MaKhachSan
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO Hotel AS target
            USING SourceData AS source
            ON target.hotelId = source.MaKhachSan
            WHEN MATCHED THEN
                UPDATE SET 
                    hotelName = source.TenKhachSan,
                    address = source.DiaChiChiTiet,
                    starRating = source.HangSao,
                    cityId = source.MaThanhPho
            WHEN NOT MATCHED THEN
                INSERT (hotelId, hotelName, address, starRating, cityId)
                VALUES (source.MaKhachSan, source.TenKhachSan, source.DiaChiChiTiet, source.HangSao, source.MaThanhPho);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 3. Room
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Hotel.dbo.Phong
            ORDER BY MaPhong
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaPhong, LoaiPhong, GiaNiemYet, TrangThai, MaKhachSan
                FROM Hotel.dbo.Phong
                WHERE EXISTS (SELECT 1 FROM Hotel h WHERE h.hotelId = MaKhachSan)
                ORDER BY MaPhong
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO Room AS target
            USING SourceData AS source
            ON target.roomId = source.MaPhong
            WHEN MATCHED THEN
                UPDATE SET 
                    roomType = source.LoaiPhong,
                    listedPrice = source.GiaNiemYet,
                    status = source.TrangThai,
                    hotelId = source.MaKhachSan
            WHEN NOT MATCHED THEN
                INSERT (roomId, roomType, listedPrice, status, hotelId)
                VALUES (source.MaPhong, source.LoaiPhong, source.GiaNiemYet, source.TrangThai, source.MaKhachSan);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 4. Service
        MERGE INTO Service AS target
        USING (
            SELECT MaDichVu, TenDichVu, LoaiDichVu, DonGia, MoTa
            FROM Hotel.dbo.DichVu
        ) AS source
        ON target.serviceId = source.MaDichVu
        WHEN MATCHED THEN
            UPDATE SET 
                serviceName = source.TenDichVu,
                serviceType = source.LoaiDichVu,
                unitPrice = source.DonGia,
                description = source.MoTa
        WHEN NOT MATCHED THEN
            INSERT (serviceId, serviceName, serviceType, unitPrice, description)
            VALUES (source.MaDichVu, source.TenDichVu, source.LoaiDichVu, source.DonGia, source.MoTa);

        -- 5. Customer
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Customer.dbo.KhachHang
            ORDER BY MaKH
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaKH, HoTen, QuocTich, LoaiKhach, Sdt
                FROM Customer.dbo.KhachHang
                ORDER BY MaKH
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO Customer AS target
            USING SourceData AS source
            ON target.customerId = source.MaKH
            WHEN MATCHED THEN
                UPDATE SET 
                    fullName = source.HoTen,
                    nationality = source.QuocTich,
                    customerType = source.LoaiKhach,
                    phoneNumber = source.Sdt
            WHEN NOT MATCHED THEN
                INSERT (customerId, fullName, nationality, customerType, phoneNumber)
                VALUES (source.MaKH, source.HoTen, source.QuocTich, source.LoaiKhach, source.Sdt);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 6. Booking
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Customer.dbo.DatPhong
            ORDER BY MaDatPhong
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaDatPhong, ThoiGian, GhiChu, MaKH
                FROM Customer.dbo.DatPhong
                WHERE EXISTS (SELECT 1 FROM Customer c WHERE c.customerId = MaKH)
                ORDER BY MaDatPhong
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO Booking AS target
            USING SourceData AS source
            ON target.bookingId = source.MaDatPhong
            WHEN MATCHED THEN
                UPDATE SET 
                    bookingTime = source.ThoiGian,
                    note = source.GhiChu,
                    customerId = source.MaKH
            WHEN NOT MATCHED THEN
                INSERT (bookingId, bookingTime, note, customerId)
                VALUES (source.MaDatPhong, source.ThoiGian, source.GhiChu, source.MaKH);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 7. BookedRoom
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Customer.dbo.PhongDuocDat
            ORDER BY MaPhongDuocDat
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaPhongDuocDat, NgayNhanPhong, NgayTraPhong, TongTienPhong, MaDatPhong, MaPhong
                FROM Customer.dbo.PhongDuocDat
                WHERE EXISTS (SELECT 1 FROM Booking b WHERE b.bookingId = MaDatPhong)
                AND EXISTS (SELECT 1 FROM Room r WHERE r.roomId = MaPhong)
                ORDER BY MaPhongDuocDat
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO BookedRoom AS target
            USING SourceData AS source
            ON target.bookedRoomId = source.MaPhongDuocDat
            WHEN MATCHED THEN
                UPDATE SET 
                    checkInDate = source.NgayNhanPhong,
                    checkOutDate = source.NgayTraPhong,
                    totalRoomPrice = source.TongTienPhong,
                    bookingId = source.MaDatPhong,
                    roomId = source.MaPhong
            WHEN NOT MATCHED THEN
                INSERT (bookedRoomId, checkInDate, checkOutDate, totalRoomPrice, bookingId, roomId)
                VALUES (source.MaPhongDuocDat, source.NgayNhanPhong, source.NgayTraPhong, source.TongTienPhong, source.MaDatPhong, source.MaPhong);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 8. ServiceUsage
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Customer.dbo.DichVu
            ORDER BY MaDichVuSuDung
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaDichVuSuDung, ThoiGian, SoLuong, ThanhTien, MaPhongDuocDat, MaDichVu
                FROM Customer.dbo.DichVu
                WHERE EXISTS (SELECT 1 FROM BookedRoom br WHERE br.bookedRoomId = MaPhongDuocDat)
                AND EXISTS (SELECT 1 FROM Service s WHERE s.serviceId = MaDichVu)
                ORDER BY MaDichVuSuDung
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO ServiceUsage AS target
            USING SourceData AS source
            ON target.serviceUsageId = source.MaDichVuSuDung
            WHEN MATCHED THEN
                UPDATE SET 
                    serviceTime = source.ThoiGian,
                    quantity = source.SoLuong,
                    totalServicePrice = source.ThanhTien,
                    bookedRoomId = source.MaPhongDuocDat,
                    serviceId = source.MaDichVu
            WHEN NOT MATCHED THEN
                INSERT (serviceUsageId, serviceTime, quantity, totalServicePrice, bookedRoomId, serviceId)
                VALUES (source.MaDichVuSuDung, source.ThoiGian, source.SoLuong, source.ThanhTien, source.MaPhongDuocDat, source.MaDichVu);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        -- 9. Review
        SET @Offset = 0;
        WHILE EXISTS (
            SELECT 1
            FROM Customer.dbo.DanhGia
            ORDER BY MaDanhGia
            OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
        )
        BEGIN
            WITH SourceData AS (
                SELECT MaDanhGia, ThoiGian, 
                    CASE 
                        WHEN DiemDanhGia BETWEEN 1 AND 5 THEN DiemDanhGia 
                        ELSE 1 
                    END AS DiemDanhGia, 
                    NhanXet, MaPhongDuocDat
                FROM Customer.dbo.DanhGia
                WHERE EXISTS (SELECT 1 FROM BookedRoom br WHERE br.bookedRoomId = MaPhongDuocDat)
                ORDER BY MaDanhGia
                OFFSET @Offset ROWS FETCH NEXT @BatchSize ROWS ONLY
            )
            MERGE INTO Review AS target
            USING SourceData AS source
            ON target.reviewId = source.MaDanhGia
            WHEN MATCHED THEN
                UPDATE SET 
                    reviewTime = source.ThoiGian,
                    ratingScore = source.DiemDanhGia,
                    feedback = source.NhanXet,
                    bookedRoomId = source.MaPhongDuocDat
            WHEN NOT MATCHED THEN
                INSERT (reviewId, reviewTime, ratingScore, feedback, bookedRoomId)
                VALUES (source.MaDanhGia, source.ThoiGian, source.DiemDanhGia, source.NhanXet, source.MaPhongDuocDat);
            
            SET @Offset = @Offset + @BatchSize;
        END;

        INSERT INTO SyncLog (Message) VALUES ('Đồng bộ dữ liệu thành công.');
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(1000) = 'Lỗi đồng bộ: ' + ERROR_MESSAGE();
        INSERT INTO SyncLog (Message) VALUES (@ErrorMsg);
        THROW;
    END CATCH;
END;
GO

