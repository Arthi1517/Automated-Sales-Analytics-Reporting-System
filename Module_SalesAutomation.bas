
Attribute VB_Name = "SalesAutomation"
Option Explicit

' === Configuration ===
Private Const CONN_STR As String = "Provider=SQLOLEDB;Data Source=YOUR_SQL_SERVER_NAME;Initial Catalog=SalesAnalytics;Integrated Security=SSPI;"
' For SQL Auth, use:
' "Provider=SQLOLEDB;Data Source=YOUR_SQL_SERVER_NAME;Initial Catalog=SalesAnalytics;User ID=YOUR_USER;Password=YOUR_PASSWORD;"

' === Public entry point ===
Public Sub RefreshSalesData()
    Dim sql As String
    sql = "SELECT * FROM dbo.v_SalesSummary WHERE SaleDate >= DATEADD(DAY,-30,CAST(GETDATE() AS date));"
    FetchToSheet sql, "Sales_Data", True

    ' Basic cleanup: remove duplicates on key columns
    RemoveDuplicates "Sales_Data", Array(1, 2, 4, 6, 9) ' columns: SaleDate, RegionName, ProductName, Quantity, NetSales

    ' Auto format table
    FormatAsTable "Sales_Data"

    MsgBox "Sales data refreshed.", vbInformation
End Sub

' === Helper to execute SQL and dump to a sheet ===
Private Sub FetchToSheet(ByVal sql As String, ByVal sheetName As String, ByVal clearFirst As Boolean)
    Dim cn As Object, rs As Object
    Set cn = CreateObject("ADODB.Connection")
    Set rs = CreateObject("ADODB.Recordset")

    cn.Open CONN_STR
    rs.Open sql, cn, 1, 1  ' adOpenKeyset, adLockReadOnly

    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = sheetName
    End If
    On Error GoTo 0

    If clearFirst Then ws.Cells.ClearContents

    Dim i As Long, r As Long, c As Long
    ' Write headers
    For i = 1 To rs.Fields.Count
        ws.Cells(1, i).Value = rs.Fields(i - 1).Name
    Next i
    ' Write rows
    r = 2
    Do While Not rs.EOF
        For c = 1 To rs.Fields.Count
            ws.Cells(r, c).Value = rs.Fields(c - 1).Value
        Next c
        r = r + 1
        rs.MoveNext
    Loop

    rs.Close: cn.Close
    Set rs = Nothing: Set cn = Nothing
End Sub

' === Remove duplicates by column indices ===
Private Sub RemoveDuplicates(ByVal sheetName As String, ByVal cols As Variant)
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets(sheetName)
    Dim lastRow As Long, lastCol As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    lastCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
    ws.Range(ws.Cells(1, 1), ws.Cells(lastRow, lastCol)).RemoveDuplicates Columns:=cols, Header:=xlYes
End Sub

' === Format as Excel table for Power BI connection ===
Private Sub FormatAsTable(ByVal sheetName As String)
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets(sheetName)
    Dim lastRow As Long, lastCol As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    lastCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column

    Dim rng As Range
    Set rng = ws.Range(ws.Cells(1, 1), ws.Cells(lastRow, lastCol))

    Dim objList As ListObject
    On Error Resume Next
    Set objList = ws.ListObjects("tblSalesData")
    On Error GoTo 0
    If objList Is Nothing Then
        Set objList = ws.ListObjects.Add(xlSrcRange, rng, , xlYes)
        objList.Name = "tblSalesData"
    Else
        objList.Resize rng
    End If
End Sub

' === Optional: schedule weekly refresh ===
Public Sub ScheduleWeeklyRefresh()
    Application.OnTime Now + TimeSerial(0, 0, 10), "SalesAutomation.RefreshSalesData"
End Sub
