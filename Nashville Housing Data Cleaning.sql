--Cleaning Data in SQL

/*The SaleDate column has a date type that includes time, and the time is the same, midnight for all the rows. 
The field needs to be updated to show only the date using CONVERT or CAST*/

--first check to see what the converted field will look like
SELECT SaleDate, CONVERT(date, SaleDate) --use of CONVERT
FROM [dbo].[nashvillehousing];

--adding a new field to the table and updating it with the new converted data
ALTER TABLE nashvillehousing
ADD SaleDate0 date;

UPDATE [dbo].[nashvillehousing]
SET SaleDate0 = CAST(SaleDate AS date);  --use of CAST, same result as using CONVERT

--checking to see the updated table
SELECT SaleDate0
FROM [dbo].[nashvillehousing];

----------------------------------------------------------------------------------------------------------------------------------------------------

--Populate Property Address data

/*For this dataset, there are property addresses that have nulls, which is not normal. If we inspect the whole data, 
we will observe that the uniqueids are unique to each row, but some parcelids are duplicated. This can help us point to some of the property addresses
that are nulls, and we can link them together to populate the nulls using the parcelid.*/

--first we check to see the rows where the property address is null
SELECT *
FROM [dbo].[nashvillehousing]
WHERE PropertyAddress IS NULL;

--Self-join the data to show the rows where the parcelid is duplicated, to distinguish where the data has uniqueids but not unique parcelids
SELECT a.uniqueid, a.ParcelID, a.PropertyAddress, b.uniqueid, b.ParcelID,b.PropertyAddress
FROM [dbo].[nashvillehousing] a
	JOIN dbo.nashvillehousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;

--Using ISNULL to populate the address from the second table to the first table
UPDATE a
SET PropertyAddress = ISNULL(a.propertyaddress, b.propertyaddress)
FROM [dbo].[nashvillehousing] a
	JOIN dbo.nashvillehousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL

--None of the rows contain a null value for the property address anymore

--------------------------------------------------------------------------------------------------------------------------------------------------

--Breaking out address into Individual columns (Address, city, state)

/*The address columns have been bunched together in a way that the street, city and state are all spelt out in one cell. 
Tp separate them so each can have their own column, we can use two methods. The SUBSTRING... CHARINDEX method, and the NAMEPARSE method
as follows*/

--Check to see how the outcome will be before updating the table
SELECT SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) AS street_address,
		SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) AS city
FROM [dbo].[nashvillehousing]

--Add the new columns street and city to the table using ALTER TABLE... ADD, and UPDATE...SET
ALTER TABLE nashvillehousing
ADD property_street nvarchar(255);

ALTER TABLE nashvillehousing
ADD property_city nvarchar(255);

UPDATE [dbo].[nashvillehousing]
SET property_street = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1);

UPDATE [dbo].[nashvillehousing]
SET property_city = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress));

--check to see what the updated table looks like
SELECT TOP 100 PropertyAddress, property_street, property_city
FROM nashvillehousing;


/*Using the second method on the Owner's address, PARSENAME usually only acts on periods(.), and not commas(,), 
so we have to first replace all the commas with periods, then pass it to PARSENAME. Also the query works backwards,
which means we have to know how many commas or periods are in the string, and start from the top number to the lower numbers.*/

SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) AS owner_street,
		PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2) AS owner_city,
		PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) AS owner_state
FROM nashvillehousing;

--Then the table can be updated with the new columns as applied earlier
ALTER TABLE nashvillehousing
ADD owner_street nvarchar(255);

ALTER TABLE nashvillehousing
ADD owner_city nvarchar(255);

ALTER TABLE nashvillehousing
ADD owner_state nvarchar(255);

UPDATE [dbo].[nashvillehousing]
SET owner_street = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3);

UPDATE [dbo].[nashvillehousing]
SET owner_city = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2);

UPDATE [dbo].[nashvillehousing]
SET owner_state = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

--check to see what the updated table looks like
SELECT TOP 100 OwnerAddress, owner_street, owner_city, owner_state
FROM nashvillehousing;


---------------------------------------------------------------------------------------------------------------------------------------------

--Change Y and N to Yes and No in Sold as Vacant field

/*some entries in the field "Sold as Vacant" are not consistent with the rest of the data, entered as Y instead of Yes, or N instead of No. 
Using a CASE statement, this can be corrected*/

--Using the DISTINCT function to confirm that there are inconsistent entries
SELECT DISTINCT SoldAsVacant
FROM nashvillehousing;

--Checking to see what the corrected field will look like
SELECT SoldAsVacant, 
	CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
		END
FROM nashvillehousing;

--Updating the table with the correction
UPDATE nashvillehousing
SET SoldAsVacant =
	CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
		END;

--Recheck to see if the incorrect entries have been corrected
SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant)
FROM nashvillehousing
GROUP BY SoldAsVacant;

--Update successful


------------------------------------------------------------------------------------------------------------------------------------------------

--Removing Duplicates

/*This data contains duplicates that will be removed in this query, however it is not always advisable to delete or remove any data from the database,
because any data deleted in SQL database cannot be retrieved*/

--Using CTEs and some functions to find where there are duplicate values

--First we partition our data, (we need to be able to have a way to identify duplicate rows, we can use RANK, ORDER RANK, ROW_NUMBER) using ROW_NUMBER
SELECT *, 
		ROW_NUMBER() OVER 
		(
		   PARTITION BY ParcelID, 
						PropertyAddress, 
						SalePrice, 
						SaleDate, 
						LegalReference 
		   ORDER BY UniqueID
		 ) AS row_num
FROM nashvillehousing
/*The new field assigns to each row 1 count, and if a new row has the same exact information across the selected fields mentioned in the PARTITION BY,
it is given count number 2, and so on. To be able to filter for the rows that have more than 1 count, we can wrap the above query in a CTE*/

WITH duplis AS(
	SELECT *, 
		ROW_NUMBER() OVER 
		(
		   PARTITION BY ParcelID, 
						PropertyAddress, 
						SalePrice, 
						SaleDate, 
						LegalReference 
		   ORDER BY UniqueID
		 ) AS row_num
	FROM nashvillehousing
)
SELECT *
FROM duplis
WHERE row_num > 1
ORDER BY PropertyAddress;

--to delete the duplicates, the SELECT statement in the CTE can then be changed to DELETE

WITH duplis AS(
	SELECT *, 
		ROW_NUMBER() OVER 
		(
		   PARTITION BY ParcelID, 
						PropertyAddress, 
						SalePrice, 
						SaleDate, 
						LegalReference 
		   ORDER BY UniqueID
		 ) AS row_num
	FROM nashvillehousing
)
DELETE 
FROM duplis
WHERE row_num > 1;
--The table can be checked to see if these duplicates still exist using the CTE conatining the SELECT statement above.
--Table successfully updated


-------------------------------------------------------------------------------------------------------------------------------------------------------

--Delete Unused Columns

/*It is always unadvisable to delete any columns from our raw data. However, the property address and owner address in these table are not useful,
they will be deleted here using ALTER TABLE... DROP COLUMN*/

ALTER TABLE nashvillehousing
DROP COLUMN SaleDathe, OwnerAddress, PropertyAddress;

--checking to see the updated table
SELECT * FROM nashvillehousing;
--table successfully updated
