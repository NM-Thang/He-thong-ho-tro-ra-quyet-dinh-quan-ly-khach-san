-- Tạo cơ sở dữ liệu
CREATE DATABASE Customer;
GO

USE Customer;
GO

-- Tạo bảng KhachHang
CREATE TABLE KhachHang (
    MaKH VARCHAR(10) PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    QuocTich NVARCHAR(50),
    LoaiKhach NVARCHAR(20),
    Sdt VARCHAR(15)
);
GO

-- Tạo bảng DatPhong
CREATE TABLE DatPhong (
    MaDatPhong VARCHAR(10) PRIMARY KEY,
    MaKH VARCHAR(10),
    ThoiGian DATETIME NOT NULL,
    GhiChu NVARCHAR(200),
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
);
GO

-- Tạo bảng PhongDuocDat
CREATE TABLE PhongDuocDat (
    MaPhongDuocDat VARCHAR(10) PRIMARY KEY,
    MaDatPhong VARCHAR(10),
    MaPhong VARCHAR(20),
    NgayNhanPhong DATE NOT NULL,
    NgayTraPhong DATE NOT NULL,
    TongTienPhong DECIMAL(15, 2),
    FOREIGN KEY (MaDatPhong) REFERENCES DatPhong(MaDatPhong)
);
GO

-- Tạo bảng DichVu
CREATE TABLE DichVu (
    MaDichVuSuDung VARCHAR(10) PRIMARY KEY,
    MaDichVu VARCHAR(10) ,
    MaPhongDuocDat VARCHAR(10),
    ThoiGian DATETIME NOT NULL,
    SoLuong INT NOT NULL,
    ThanhTien DECIMAL(15, 2),
    FOREIGN KEY (MaPhongDuocDat) REFERENCES PhongDuocDat(MaPhongDuocDat)
);
GO

-- Tạo bảng DanhGia
CREATE TABLE DanhGia (
    MaDanhGia VARCHAR(15) PRIMARY KEY,
    MaPhongDuocDat VARCHAR(10),
    ThoiGian DATETIME NOT NULL,
    DiemDanhGia INT CHECK (DiemDanhGia >= 1 AND DiemDanhGia <= 5),
    NhanXet NVARCHAR(500),
    FOREIGN KEY (MaPhongDuocDat) REFERENCES PhongDuocDat(MaPhongDuocDat)
);