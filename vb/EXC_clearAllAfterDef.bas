Attribute VB_Name = "Module1"
Sub RowDel2()
    For Each SN In ThisWorkbook.Sheets
        SN.Rows(21).Resize(SN.Rows.Count - 20).EntireRow.Clear
    Next
End Sub
