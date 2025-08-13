
# Power BI Setup (Template Guide)

This repository does not include a `.pbix` file, but you can build it in minutes:

## Option A) Connect directly to SQL
1. Open Power BI Desktop.
2. **Get Data > SQL Server**: 
   - Server: `YOUR_SQL_SERVER_NAME`
   - Database: `SalesAnalytics`
   - Use the view `dbo.v_SalesSummary` (or the stored procedure output via a parameterized query).
3. Load data and create visuals:
   - **Cards**: Total Revenue, Units Sold, Unique Customers.
   - **Line chart**: Revenue by Date.
   - **Bar chart**: Top Products by Revenue.
   - **Map or Filled Map**: Revenue by RegionName.
   - **Slicers**: Date range, RegionName, Category.
4. Save as `Automated_Sales_Analytics.pbix`.

## Option B) Use Excel output
1. Run the Excel VBA macro to generate the table `tblSalesData`.
2. In Power BI: **Get Data > Excel**, select the generated workbook and table.
3. Create the same visuals and publish.

## Recommended Measures (DAX)
```
Total Revenue = SUM('SalesSummary'[NetSales])
Units Sold    = SUM('SalesSummary'[Quantity])
Avg Discount  = AVERAGE('SalesSummary'[DiscountPct])
```

## Data Model
- Single table (SalesSummary) is enough for the first version.
- For a star schema, import dimension tables (Products, Customers, Regions) and link to fact Sales.
