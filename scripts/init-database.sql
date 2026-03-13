/* 
Add header comment at the start of each script

Create Database and Schemas

Script Purpose:
  This script creates a new database named 'DataWarehouse' after checking if it already exists. 
  If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas 
  within the database: 'bronze', 'silver', and 'gold'.
*/

-- Drop and create a new 'DataWarehouse' database
drop database if exists DataWarehouse

create database DataWarehouse

-- Create Schemas for each layer
create schema bronze

create schema silver

create schema gold 
