USE master;
GO

-- Tạo database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'IDBHotel')
    CREATE DATABASE IDBHotel;
GO

USE IDBHotel;
GO

-- Bảng Location
CREATE TABLE Location (
    cityId NVARCHAR(20) PRIMARY KEY,
    cityName NVARCHAR(100),
    region NVARCHAR(100)
);

-- Bảng Hotel
CREATE TABLE Hotel (
    hotelId NVARCHAR(20) PRIMARY KEY,
    hotelName NVARCHAR(100),
    address NVARCHAR(200),
    starRating INT,
    cityId NVARCHAR(20),
    FOREIGN KEY (cityId) REFERENCES Location(cityId)
);

-- Bảng Room
CREATE TABLE Room (
    roomId NVARCHAR(20) PRIMARY KEY,
    roomType NVARCHAR(50),
    listedPrice DECIMAL(18,2),
    status NVARCHAR(50),
    hotelId NVARCHAR(20),
    FOREIGN KEY (hotelId) REFERENCES Hotel(hotelId)
);

-- Bảng Service
CREATE TABLE Service (
    serviceId NVARCHAR(20) PRIMARY KEY,
    serviceName NVARCHAR(100),
    serviceType NVARCHAR(50),
    unitPrice DECIMAL(18,2),
    description NVARCHAR(255)
);

-- Bảng Customer
CREATE TABLE Customer (
    customerId NVARCHAR(20) PRIMARY KEY,
    fullName NVARCHAR(100),
    nationality NVARCHAR(50),
    customerType NVARCHAR(50),
    phoneNumber NVARCHAR(20)
);

-- Bảng Booking
CREATE TABLE Booking (
    bookingId NVARCHAR(20) PRIMARY KEY,
    bookingTime DATETIME,
    note NVARCHAR(255),
    customerId NVARCHAR(20),
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
);

-- Bảng BookedRoom
CREATE TABLE BookedRoom (
    bookedRoomId NVARCHAR(20) PRIMARY KEY,
    checkInDate DATE,
    checkOutDate DATE,
    totalRoomPrice DECIMAL(18,2),
    bookingId NVARCHAR(20),
    roomId NVARCHAR(20),
    FOREIGN KEY (bookingId) REFERENCES Booking(bookingId),
    FOREIGN KEY (roomId) REFERENCES Room(roomId)
);

-- Bảng ServiceUsage
CREATE TABLE ServiceUsage (
    serviceUsageId NVARCHAR(20) PRIMARY KEY,
    serviceTime DATETIME,
    quantity INT,
    totalServicePrice DECIMAL(18,2),
    bookedRoomId NVARCHAR(20),
    serviceId NVARCHAR(20),
    FOREIGN KEY (bookedRoomId) REFERENCES BookedRoom(bookedRoomId),
    FOREIGN KEY (serviceId) REFERENCES Service(serviceId)
);

-- Bảng Review
CREATE TABLE Review (
    reviewId NVARCHAR(20) PRIMARY KEY,
    reviewTime DATETIME,
    ratingScore INT CHECK (ratingScore BETWEEN 1 AND 5),
    feedback NVARCHAR(500),
    bookedRoomId NVARCHAR(20),
    FOREIGN KEY (bookedRoomId) REFERENCES BookedRoom(bookedRoomId)
);

-- Bảng SyncLog để ghi nhật ký đồng bộ
CREATE TABLE SyncLog (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    LogTime DATETIME DEFAULT GETDATE(),
    Message NVARCHAR(1000)
);
GO