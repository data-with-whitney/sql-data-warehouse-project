
-- Quality check of the Silver layer

-- crm_cust_info

-- Quality check: check for nulls or duplicates in the PK
-- Expectation: No result

select
	cst_id,
	count(*)
from silver.crm_cust_info
group by cst_id
having count(*) > 1 or cst_id is null -- in case we have null count = 1 we still want to see the result

select
	cst_key,
	count(*)
from silver.crm_cust_info
group by cst_key
having count(*) > 1 or cst_key is null

-- Quality check: check for unwanted spaces for the string columns

select
	cst_firstname
from silver.crm_cust_info
where cst_firstname != trim(cst_firstname)

select
	cst_lastname
from silver.crm_cust_info
where cst_lastname != trim(cst_lastname)

select
	cst_marital_status
from silver.crm_cust_info
where cst_marital_status != trim(cst_marital_status)

select
	cst_gndr
from silver.crm_cust_info
where cst_gndr != trim(cst_gndr)

-- Quality check: data standardization and consistency
select
	distinct cst_marital_status
from silver.crm_cust_info

select
	distinct cst_gndr
from silver.crm_cust_info

select * from silver.crm_cust_info 


-- crm_prd_info
select * from silver.crm_prd_info 

-- Quality check: check for nulls or duplicates in the PK
select
	prd_id,
	count(*)
from silver.crm_prd_info
group by prd_id
having count(*) > 1

-- Quality check: check for unwanted spaces for the string columns

select
	prd_nm
from silver.crm_prd_info
where prd_nm != trim(prd_nm)

-- Check for nulls or negative numbers for numeric columns

select
	prd_cost
from silver.crm_prd_info
where prd_cost < 0 or prd_cost is null

-- Quality check: data standardization and consistency

select distinct prd_line
from silver.crm_prd_info

-- Check for invalid date orders i.e where end date < start date
-- end date cannot be earlier than start date 

select * from silver.crm_prd_info
where prd_end_dt < prd_start_dt 


-- crm_sales_details
select * from silver.crm_sales_details

-- Quality check: check for nulls

select	
	sls_ord_num,
	count(*)
from silver.crm_sales_details
group by sls_ord_num
having sls_ord_num is null

-- Quality check: check for unwanted spaces for the string columns

select sls_ord_num
from silver.crm_sales_details
where sls_ord_num != trim(sls_ord_num)

-- Since sls_prd_key connects to prd_key in the product info table, check to see which sls_prd_key is not in the product table
-- Expected result: all the prd_key in the sales table can be used and connected to the prd_key in the product table

select *
from silver.crm_sales_details
where sls_prd_key not in (select prd_key from silver.crm_prd_info)

-- Since sls_cust_id connects to cst_id in the customer table, check to see which sls_cust_id is not in the customer table
-- Expected result: all the sls_cust_id in the sales table can be used and connected to the cst_id in the customer table

select *
from silver.crm_sales_details
where sls_cust_id not in (select cst_id from silver.crm_cust_info)

-- Change date type from integer to date
-- to do this;
	-- 1. check for negative or 0 values as they cant be case to date
	-- 2. replace 0 values with null
	-- 3. in this scenario, the length of the date must be 8. (length fn only works for text/string so cast as text first)
	
select
	nullif(sls_order_dt, 0)
from silver.crm_sales_details
where sls_order_dt <= 0 or length(sls_order_dt::varchar) != 8

select
	nullif(sls_ship_dt, 0)
from silver.crm_sales_details
where sls_ship_dt <= 0 or length(sls_ship_dt::varchar) != 8

select
	nullif(sls_due_dt, 0)
from silver.crm_sales_details
where sls_due_dt <= 0 or length(sls_due_dt::varchar) != 8

-- Check that order date < ship date and due date

select *
from silver.crm_sales_details
where sls_order_dt > sls_ship_dt or sls_order_dt > sls_due_dt

-- Data consistency check

select 
	sls_sales,
	sls_quantity,
	sls_price
from silver.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <= 0 or sls_quantity <= 0 or sls_price <=0

-- erp.cust_az12
select *
from silver.erp_cust_az12

-- Since cust_az12 connects to cst_key in the customer info table, check to see which cid is not in the cust_info table
-- Expected result: all the cid in the cust_az12 table can be used and connected to the cst_key in the cust_info table

select *
from silver.erp_cust_az12
where cid not in (select cst_key from silver.crm_cust_info)

-- Quality check: identify out-of-range dates

select bdate
from silver.erp_cust_az12
where bdate > current_date

-- Data standardization

select 
	distinct(gen)
from silver.erp_cust_az12 


-- erp_loc_a101
select * from silver.erp_loc_a101

-- Since cid connects to cst_id in the customer table, check to see if they match

select 
	cid
from silver.erp_loc_a101
where cid not in (select cst_key from silver.crm_cust_info)

-- Data standardization

select distinct(cntry)
from silver.erp_loc_a101


-- erp_px_cat_g1v2
select * from silver.erp_px_cat_g1v2

-- Check for unwanted spaces
select *
from silver.erp_px_cat_g1v2
where cat != trim(cat) or subcat != trim(subcat) or maintenance != trim(maintenance)

-- check for consistency
select distinct(cat)
from silver.erp_px_cat_g1v2

select distinct(maintenance)
from silver.erp_px_cat_g1v2

select distinct(subcat)
from silver.erp_px_cat_g1v2

