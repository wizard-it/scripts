Function Get-EmployeeID {
<#
        .SYNOPSIS
        Поиск EmployeeID из выгрузки 1С

        .DESCRIPTION
        Поиск EmployeeID из выгрузки 1С.

        .EXAMPLE
        C:\PS>Get-EmployeeID -SurName Ив
        employeeid sn      givenName middleName    title                        division                  department                                   
        ---------- --      --------- ----------    -----                        --------                  ----------                                   
        0000001134 Иванова Валентина Николаевна    Укладчик-упаковщик           Производственная дирекция Цех фасовки и упаковки
                
        Описание 
        -----------

        EmployeeID пользователей Ив*                       

        .EXAMPLE
        C:\PS>Get-EmployeeID -SurName Ив -CSVPath "C:\tmp\employees.csv"
        employeeid sn      givenName middleName    title                        division                  department                                   
        ---------- --      --------- ----------    -----                        --------                  ----------                                   
        0000001134 Иванова Валентина Николаевна    Укладчик-упаковщик           Производственная дирекция Цех фасовки и упаковки                       
        
        Описание 
        -----------

        Изменить пусть к файлу CSV

        .NOTES
        Organization: JSC "Gedeon Richter-RUS"
        Authors:  Piskunov Dmitry

    #>
    [CmdLetBinding()]
     Param (
     [ValidatePattern('^[А-ЯЁ][а-яё]+\s?$')][string]$SurName,
     [string]$CSVPath = "\\fsc01\logs$\csv2ldap\employees.csv"
     )
    
    #Импорт CSV (делаем так, потому что Import-Csv не смог)
    $getcsv = Get-Content -Path $CSVPath
    $csv = ConvertFrom-Csv $getcsv -Delimiter ";"

    #Время формирования выгрузки
    $CSVCreationtime = (Get-Item $CSVPath).LastWriteTime
    $CSVCreationtimeConv = $CSVCreationtime.ToString("dd.MM.yyyy HH:mm") 

    #Поиск
    $out = $csv | Where-Object {$_.sn -like "*$SurName*"} | select employeeid,sn,givenName,middleName,title | ft | Out-String
    
    #Вывод
    Write-Host $out
    Write-Host "Дата изменения выгрузки: $CSVCreationtimeConv"
    Clear-Variable -Name CSVPath, getcsv, csv, CSVCreationtime, CSVCreationtimeConv, out

}