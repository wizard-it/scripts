# LDAP Query
# Look for all people. Excludes the DISABLED OU

$Searcher = New-Object DirectoryServices.DirectorySearcher
$Searcher.SearchRoot = 'LDAP://OU=RGr Users,DC=shuvoe,DC=rg-rus,DC=ru'
#$Searcher.Filter = '(&(objectCategory=person))'
$Searcher.Filter = '(&(objectClass=user)(!userAccountControl=514)(!userAccountControl=66050)(objectCategory=person)(showInAddressBook=*)(title=*)(company=Gedeon Richter RUS))'

$res = $Searcher.FindAll()  | Sort-Object path
foreach ($usrTmp in $res)
{
  
  Write-Host $usrTmp.Properties["cn"]
}
Write-Host "------------------------------"
Write-Host "Number of Users Returned: " @($res).count
Write-Host
