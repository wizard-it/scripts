$workdir = ".\"
$OU = "OU=RGr Users,DC=SHUVOE,DC=RG-RUS,DC=RU","OU=Moscow Office,OU=RGr Users,DC=SHUVOE,DC=RG-RUS,DC=RU"

$RGRUsers = Get-ADUser -SearchBase $OU[0] -SearchScope OneLevel -Properties OtherName -Filter {OtherName -like "*"}
$MSKUsers = Get-ADUser -SearchBase $OU[1] -SearchScope OneLevel -Properties OtherName -Filter {OtherName -like "*"}

$Links = @{}

foreach ($user in $RGRUsers) {
    $Links.Add("$($user.SamAccountname)","http://intranet/Employees/ProfilePhotos/$($user.Surname)%20$($user.givenName)%20$($user.otherName).jpg")
}

foreach ($user in $MSKUsers) {
    $Links.Add("$($user.SamAccountname)","http://intranet/Employees/ProfilePhotos/$($user.Surname)%20$($user.givenName)%20$($user.otherName).jpg")
}

foreach ($samaccountname in $($links.Keys)) {
    $link = $links.$samaccountname
    Invoke-WebRequest -Uri $link -OutFile "$workdir\$samaccountname.jpg" -UseDefaultCredentials
}