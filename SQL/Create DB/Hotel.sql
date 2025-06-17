-- Tạo database
CREATE DATABASE Hotel;
GO

-- Sử dụng database vừa tạo
USE Hotel;
GO

-- Bảng ViTri
CREATE TABLE ViTri (
    MaThanhPho VARCHAR(10) PRIMARY KEY,
    TenThanhPho NVARCHAR(100) NOT NULL,
    VungMien NVARCHAR(50) NOT NULL
);
GO

-- Bảng KhachSan
CREATE TABLE KhachSan (
    MaKhachSan VARCHAR(10) PRIMARY KEY,
    TenKhachSan NVARCHAR(100) NOT NULL,
    MaThanhPho VARCHAR(10) NOT NULL,
    DiaChiChiTiet NVARCHAR(200),
    HangSao INT CHECK (HangSao BETWEEN 1 AND 5),
    FOREIGN KEY (MaThanhPho) REFERENCES ViTri(MaThanhPho)
);
GO

-- Bảng Phong
CREATE TABLE Phong (
    MaPhong VARCHAR(20) PRIMARY KEY,
    MaKhachSan VARCHAR(10) NOT NULL,
    LoaiPhong NVARCHAR(50) NOT NULL,
    GiaNiemYet DECIMAL(18, 2) NOT NULL,
    TrangThai NVARCHAR(50),
    FOREIGN KEY (MaKhachSan) REFERENCES KhachSan(MaKhachSan)
);
GO

-- Bảng DichVu
CREATE TABLE DichVu (
    MaDichVu VARCHAR(10) PRIMARY KEY,
    TenDichVu NVARCHAR(100) NOT NULL,
    LoaiDichVu NVARCHAR(50),
    DonGia DECIMAL(18, 2),
    MoTa NVARCHAR(255)
);
GO
