Sub ЗаменаИспорченныхГиперссылок_2()
    On Error Resume Next
    Dim hl As Hyperlink, newString$, sh As Worksheet
 
    ' часть гиперссылки, подлежащая замене
    oldString1 = "C:\Users\kornilovaa\AppData\Roaming\Microsoft"
    oldString2 = "C:\Users\piskunovdv\AppData\Roaming\Microsoft"
 
    ' на что заменяем
    newString = ".."
 
    For Each sh In ActiveWorkbook.Worksheets    ' перебираем все листы в активной книге
        For Each hl In sh.Hyperlinks    ' перебираем все гиперссылки на листе
            If hl.Address Like oldString1 & "*" Then  hl.Address = Replace(hl.Address, oldString1, newString)
            If hl.Address Like oldString2 & "*" Then  hl.Address = Replace(hl.Address, oldString2, newString)            
        Next
    Next sh
 
End Sub