
Import-Module ActiveDirectory


$csvPath = "Documents\Users.csv"
$domain = "hohops.com"
$defaultPassword = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force


$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    $givenName = $user.FirstName
    $surname = $user.LastName
    $department = $user.Department
    $samAccountName = $user.Username
    $upn = "$samAccountName@$domain"
    

    $ouPath = "OU=$department,OU=Company,DC=hohops,DC=com"

    try {
        New-ADUser -SamAccountName $samAccountName `
                   -UserPrincipalName $upn `
                   -Name "$givenName $surname" `
                   -GivenName $givenName `
                   -Surname $surname `
                   -Department $department `
                   -Path $ouPath `
                   -AccountPassword $defaultPassword `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true
                   
        Write-Host "Successfully created user: $samAccountName in$department OU" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create user: $samAccountName. Error: $_" -ForegroundColor Red
    }
}