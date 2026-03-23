
CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE 
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    batch_start_time TIMESTAMP;
    batch_end_time TIMESTAMP;
	row_count int;
BEGIN
    batch_start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '================================================';

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';

    -- ===============================
    -- crm_cust_info
    -- ===============================
    start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;

    RAISE NOTICE '>> Inserting Data Into: silver.crm_cust_info';

    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gndr, cst_create_date
    )
    select
		cst_id,
	    cst_key,
	    trim(cst_firstname) as cst_firstname,
	    trim(cst_lastname) as cst_lastname,
	 
	 	-- Data standardization and completeness
		-- Apply upper(), in case mixed case values appear later in the column
		-- Apply trim(), in case unwanted spaces appear later in the column
		
		case upper(trim(cst_marital_status))
			when 'M' then 'Married'
			when 'S' then 'Single'
			else 'n/a'
		end as cst_marital_status,
		
		case upper(trim(cst_gndr))
			when 'M' then 'Male'
			when 'F' then 'Female'
			else 'n/a'
		end as cst_gndr,
	    cst_create_date
	from (
		select 
			*,
			row_number() over(partition by cst_id order by cst_create_date desc) rank
		from bronze.crm_cust_info
		where cst_id is not null
		)
	where rank = 1;

	GET DIAGNOSTICS row_count = ROW_COUNT;

    end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Row Count: % rows, Load Duration: % seconds',
        row_count, ROUND(EXTRACT(EPOCH FROM (end_time - start_time)));
	RAISE NOTICE '----------';
	
    -- ===============================
    -- crm_prd_info
    -- ===============================
    start_time := CURRENT_TIMESTAMP;

	RAISE NOTICE '>> Truncating Table: silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
    
	RAISE NOTICE '>> Inserting Data Into: silver.crm_prd_info';

    INSERT INTO silver.crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm,
        prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    select
		prd_id,
		replace(substring(prd_key,1,5), '-', '_') cat_id, -- derived columns: extract prd_key for erp_px_cat_g1v2 table
		substring(prd_key, 7) prd_key, -- derived columns: extract id in crm_sales_details table
		prd_nm,
		coalesce(prd_cost, 0) prd_cost, -- Replace null with 0
		
		-- Data standardization and completeness
		-- Apply upper(), in case mixed case values appear later in the column
		-- Apply trim(), in case unwanted spaces appear later in the column
	
		case upper(trim(prd_line))
			when 'M' then 'Mountain'
			when 'S' then 'Others'
			when 'R' then 'Road'
			when 'T' then 'Touring'
			else 'n/a'
		end prd_line,
		prd_start_dt,
		lead(prd_start_dt) over(partition by prd_key order by prd_start_dt) - 1 as prd_end_dt
	from bronze.crm_prd_info;

    GET DIAGNOSTICS row_count = ROW_COUNT;
	
	end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Row Count: % rows, Load Duration: % seconds',
        row_count, ROUND(EXTRACT(EPOCH FROM (end_time - start_time)));
	RAISE NOTICE '----------';

    -- ===============================
    -- crm_sales_details
    -- ===============================
    start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Truncating Table: silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;

	RAISE NOTICE '>> Inserting Data Into: silver.crm_sales_details';
	
    INSERT INTO silver.crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price
    )
    select
		sls_ord_num,
	    sls_prd_key,
	    sls_cust_id,
	
		case
			when sls_order_dt <= 0 or length(sls_order_dt::text) != 8 then null
			else cast(cast(sls_order_dt as varchar) as date) -- in sql, you cannot cast from integer to date directly, you have to cast to text first
		end sls_order_dt,
		
		case
			when sls_ship_dt <= 0 or length(sls_ship_dt::text) != 8 then null
			else cast(cast(sls_ship_dt as varchar) as date) -- in sql, you cannot cast from integer to date directly, you have to cast to text first
		end sls_ship_dt,
	
		case
			when sls_due_dt <= 0 or length(sls_due_dt::text) != 8 then null
			else cast(cast(sls_due_dt as varchar) as date) -- in sql, you cannot cast from integer to date directly, you have to cast to text first
		end sls_due_dt,
		
		-- if sales is negative, null or zero, then derive it from abs(price) and quantity
		case
			when sls_sales <=0 or sls_sales is null or sls_sales != sls_quantity * abs(sls_price)
				then sls_quantity * abs(sls_price)
			else sls_sales
		end sls_sales,
		
		sls_quantity,
		
		-- if price is null or zero, then derive it from sales and quantity
		case
			when sls_price <= 0 or sls_price is null
				then sls_sales/nullif(sls_quantity, 0) -- in case qty is 0, nullif converts it to 0. sql cannot divide by 0
			else sls_price
		end sls_price
	from bronze.crm_sales_details;

    GET DIAGNOSTICS row_count = ROW_COUNT;
	
	end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Row Count: % rows, Load Duration: % seconds',
        row_count, ROUND(EXTRACT(EPOCH FROM (end_time - start_time)));

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '------------------------------------------------';

	-- ===============================
    -- erp_cust_az12
    -- ===============================
    start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Truncating Table: silver.erp_cust_az12';
	truncate table silver.erp_cust_az12;

	RAISE NOTICE '>> Inserting Data Into: silver.erp_cust_az12';
	
	insert into silver.erp_cust_az12 (
		cid,
		bdate,
		gen
	)

	select
		case -- remove NAS prefix if present
			when cid like 'NAS%' then substring(cid,4)
			else cid
		end cid,
		case -- set future dates to null
			when bdate > current_date then null
			else bdate
		end bdate,
		case -- ormalize gender values and handle unknown cases
			when upper(trim(gen)) in ('F', 'FEMALE') then 'Female'
			when upper(trim(gen)) in ('M', 'MALE') then 'Male'
			else 'n/a'
		end gen
	from bronze.erp_cust_az12;

    GET DIAGNOSTICS row_count = ROW_COUNT;
	
	end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Row Count: % rows, Load Duration: % seconds',
        row_count, ROUND(EXTRACT(EPOCH FROM (end_time - start_time)));
	RAISE NOTICE '----------';

	-- ===============================
    -- erp_loc_a101
    -- ===============================
    start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Truncating Table: silver.erp_loc_a101';
	truncate table silver.erp_loc_a101;

	RAISE NOTICE '>> Inserting Data Into: silver.erp_loc_a101';
	
	insert into silver.erp_loc_a101(
		cid,
		cntry
	)
	
	select
		replace(cid, '-', '') cid,
		case -- normalize and handle missing values and nulls
			when trim(cntry) = 'DE' then 'Germany'
			when trim(cntry) in ('US', 'USA') then 'United States'
			when trim(cntry) = '' or cntry is null then 'n/a'
			else trim(cntry)
		end cntry
	from bronze.erp_loc_a101;

    GET DIAGNOSTICS row_count = ROW_COUNT;
	
	end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Row Count: % rows, Load Duration: % seconds',
        row_count, ROUND(EXTRACT(EPOCH FROM (end_time - start_time)));
	RAISE NOTICE '----------';

	-- ===============================
    -- erp_lpx_cat_g1v2
    -- ===============================
    start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Truncating Table: silver.erp_px_cat_g1v2';
	truncate table silver.erp_px_cat_g1v2;

	RAISE NOTICE '>> Inserting Data Into: silver.erp_px_cat_g1v2';

	insert into silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance
	)
	
	select
		id,
		cat,
		subcat,
		maintenance
	from bronze.erp_px_cat_g1v2;

    GET DIAGNOSTICS row_count = ROW_COUNT;
	
	end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '>> Row Count: % rows, Load Duration: % seconds',
        row_count, ROUND(EXTRACT(EPOCH FROM (end_time - start_time)));
	RAISE NOTICE '----------';

    -- ===============================
    -- FINAL
    -- ===============================
    batch_end_time := CURRENT_TIMESTAMP;

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Loading Silver Layer Completed';
    RAISE NOTICE 'Total Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM (batch_end_time - batch_start_time)));
    RAISE NOTICE '==========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED: %', SQLERRM;
        RAISE NOTICE '==========================================';
END;
$$;

CALL silver.load_silver()

drop procedure if exists silver.load_silver
