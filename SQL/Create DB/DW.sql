-- Tạo CSDL
CREATE DATABASE DW_Hotel;
GO

-- Sử dụng CSDL
USE DW_Hotel;
GO

-- Bảng Dim_Time
CREATE TABLE Dim_Time (
    time_key INT PRIMARY KEY,
    month INT,
    quarter INT,
    year INT
);
GO

-- Bảng Dim_Location
CREATE TABLE Dim_Location (
    location_key INT IDENTITY(1,1) PRIMARY KEY,
	hotel_id VARCHAR(10),
	cityId VARCHAR(10),
	hotelName VARCHAR (250),
    cityName NVARCHAR(100),
    region NVARCHAR(100)
);
GO

-- Bảng Dim_Room
CREATE TABLE Dim_Room (
    room_key INT IDENTITY(1,1) PRIMARY KEY,
    roomType NVARCHAR(250)
);
GO

-- Bảng Dim_Service
CREATE TABLE Dim_Service (
    service_key VARCHAR(10) PRIMARY KEY,
    serviceType NVARCHAR(100),
    serviceName NVARCHAR(250),
);
GO

-- Bảng Dim_Customer
CREATE TABLE Dim_Customer (
    customer_key VARCHAR(10) PRIMARY KEY,
	customerName NVARCHAR(100),
    customerType NVARCHAR(100),
    nationality NVARCHAR(100)
);
GO

-- Bảng Fact_Room
CREATE TABLE Fact_Room (
    time_key INT NOT NULL,
    location_key INT NOT NULL,
    room_key INT NOT NULL,
    customer_key VARCHAR(10) NOT NULL,
    roomRevenue DECIMAL(18,2),
    roomBookingCount INT,
    avgRating DECIMAL(3,2),
    CONSTRAINT FK_FactRoom_Time FOREIGN KEY (time_key) REFERENCES Dim_Time(time_key),
    CONSTRAINT FK_FactRoom_Location FOREIGN KEY (location_key) REFERENCES Dim_Location(location_key),
    CONSTRAINT FK_FactRoom_Room FOREIGN KEY (room_key) REFERENCES Dim_Room(room_key),
    CONSTRAINT FK_FactRoom_Customer FOREIGN KEY (customer_key) REFERENCES Dim_Customer(customer_key),
);
GO

-- Bảng Fact_Service
CREATE TABLE Fact_Service (
    time_key INT NOT NULL,
    location_key INT NOT NULL,
    service_key VARCHAR(10) NOT NULL,
    customer_key VARCHAR(10) NOT NULL,
    serviceRevenue DECIMAL(18,2),
    serviceCount INT,
    CONSTRAINT FK_FactService_Time FOREIGN KEY (time_key) REFERENCES Dim_Time(time_key),
    CONSTRAINT FK_FactService_Location FOREIGN KEY (location_key) REFERENCES Dim_Location(location_key),
    CONSTRAINT FK_FactService_Service FOREIGN KEY (service_key) REFERENCES Dim_Service(service_key),
    CONSTRAINT FK_FactService_Customer FOREIGN KEY (customer_key) REFERENCES Dim_Customer(customer_key),
);
GO

-- Bảng Fact_Revenue
CREATE TABLE Fact_Revenue (
    time_key INT NOT NULL,
    location_key INT NOT NULL,
    customer_key VARCHAR(10) NOT NULL,
    totalRevenue DECIMAL(18,2),
    CONSTRAINT FK_FactRevenue_Time FOREIGN KEY (time_key) REFERENCES Dim_Time(time_key),
    CONSTRAINT FK_FactRevenue_Location FOREIGN KEY (location_key) REFERENCES Dim_Location(location_key),
    CONSTRAINT FK_FactRevenue_Customer FOREIGN KEY (customer_key) REFERENCES Dim_Customer(customer_key),
);
GO
