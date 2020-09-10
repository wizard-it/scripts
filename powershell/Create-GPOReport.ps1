function Create-GPOReport() {
    <#
        .SYNOPSIS
        Создает файлы отчетов групповой политики.

        .DESCRIPTION
        Функция Create-GPOReport оформлена в виде командлета PowerShell и предоставляет администратору средство для генерации файлов отчета по политике AD.

        .EXAMPLE
        Создать отчет по политике RGr_Set_Internet_Explorer в директории по умолчанию "D:\gporeport":
            Create-GPOReport -policyName "RGr_Set_Internet_Explorer"
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander
    #>
    param(
        [Parameter (Mandatory=$true)]
        [string]$policyName,
        [string]$workDir = "D:\gporeport"
    )

    # Создаем массивы данных
    try {
        [xml]$gp = Get-GPOReport -Name $policyName -ReportType XML -ErrorAction Stop
        $gpo = Get-GPO -Name $policyName -ErrorAction Stop
    } catch {
        return "Policy $policyName is missed! Check policy is created and permissions to GPO."
    }
    if ($gpo.WmiFilter) { $wmi = $gpo.WmiFilter } else { $wmi = "не применяются" }
    #### Генерация DOCX файла с отчетом ####
#    $encoding = [Console]::OutputEncoding 
#    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("1251")
    [Microsoft.Office.Interop.Word.ApplicationClass]$WordApp = New-Object -ComObject word.application
    $WordApp.Visible = $false
    $Document = $WordApp.Documents.Add()
    $WordApp.ActiveDocument.TextEncoding = [Microsoft.Office.Core.MsoEncoding]::msoEncodingUTF8
    $WordApp.ActiveDocument.SaveEncoding = [Microsoft.Office.Core.MsoEncoding]::msoEncodingUTF8
    $Selection = $WordApp.Selection
    $Selection.Pagesetup.TopMargin = 50
	$Selection.Pagesetup.LeftMargin = 50
	$Selection.Pagesetup.RightMargin = 50
    $Selection.Pagesetup.BottomMargin = 50
    $Selection.Font.Name = "Times New Roman"

    #region Колонтитул
    $header = $Selection.Sections.Item(1).Headers.Item(1)
    #region Описание политики
    $Selection.Range.ParagraphFormat.SpaceAfter = 6
    $Selection.TypeParagraph()
    $Selection.TypeParagraph()
    $Selection.Font.Bold = $true
    $Selection.Font.Size = 14
    $Selection.ParagraphFormat.Alignment = 1
    $Selection.TypeText("Описание групповой политики $($gp.GPO.Name)")
    $Selection.TypeParagraph()
    $Selection.Font.Bold = $false
    $Selection.Font.Size = 12
    $Selection.ParagraphFormat.Alignment = 0
    $Selection.TypeText("Имя групповой политики: $($gp.GPO.Name)")
    $Selection.TypeParagraph()
    $Selection.TypeText("Назначение: $($gpo.Description)") 
    $Selection.TypeParagraph()
    $Selection.TypeText("Уникальный номер: $($gp.GPO.Identifier.Identifier.'#text')")
    $Selection.TypeParagraph()
    $Selection.TypeText("Дата создания: $(get-date $gp.GPO.CreatedTime -format "dd.MM.yyyy HH:mm:ss")")
    $Selection.TypeParagraph()
    $Selection.TypeText("Дата изменения: $(get-date $gp.GPO.ModifiedTime -format "dd.MM.yyyy HH:mm:ss")")
    $Selection.TypeParagraph()
    $Selection.TypeText("Дата изменения: $(get-date $gp.GPO.ModifiedTime -format "dd.MM.yyyy HH:mm:ss")")
    $Selection.TypeParagraph()
    $Selection.TypeText("WMI фильтры: $($wmi)")
    $Selection.TypeParagraph()
    $Selection.TypeText("Дополнительные административные шаблоны: не используются")
    $Selection.TypeParagraph()
    $Selection.TypeText("Краткое описание основных параметров:")
    $Selection.TypeParagraph()
   
    
    #region Сохранение DOCX
    if ((Test-Path "$workDir") -eq $false) {
        New-Item -Type Directory -Path "$workDir"
    }
    $Document.SaveAs([ref]$("$workDir\$($gp.GPO.Name).docx"),[ref]$([Microsoft.Office.Interop.Word.WdSaveFormat]::wdFormatDocumentDefault))
#    $Document.Close()
    $WordApp.Quit()
    #$null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$WordApp)
    #endregion

    #region Generate a html report
    Get-GPOReport -Name $policyName -ReportType html -Path "$workDir\$policyName.html"
    #endregion

    Remove-Variable WordApp, gp, gpo
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
#    [Console]::OutputEncoding = $encoding
}