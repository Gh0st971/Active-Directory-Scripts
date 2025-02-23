<#
.SYNOPSIS
Create realistic-looking Active Directory accounts.
Written by Gh0st971
Version 0.1
Last Updated Jun 25 2024

.LINK
https://gist.github.com/tylerapplebaum/d692d9d2e1335b8b111927c8292c5dac
https://randomuser.me/

.DESCRIPTION
Queries randomuser.me to generate user information. Creates an Active Directory user based on that.

.PARAMETER NumUsers
Specify the number of users to create

.PARAMETER CompanyName
Specify the company name to be used in the AD users' profile

.PARAMETER Nationalities
Specify the nationality of the users you are creating. randomuser.me relies on this for correct address formatting.

.INPUTS
System.String, System.Int32

.OUTPUTS
CSV with the creation results; Active Directory user account

.EXAMPLE
PS C:> .\AD-Bulk-Create-Random-Users.ps1 -NumUsers 10
Creates 10 AD user accounts

.EXAMPLE
PS C:> .\AD-Bulk-Create-Random-Users.ps1 -NumUsers 18 -CompanyName "ACME"
Creates 18 AD user accounts with Apple Computer as the Company Name under Organization
#>

[CmdletBinding()]
    param(
    [Parameter(mandatory=$true, HelpMessage="Specify the number of users to create")]
    [Alias("users")]
    [ValidateRange(1,1000)]
    [int]$NumUsers,

    [Parameter(HelpMessage="Specify credentials to connect from a non-domain-joined computer")]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credentials = [System.Management.Automation.PSCredential]::Empty,
    
    [Parameter(HelpMessage="Specify the company name")]
    [Alias("co")]
    [string]$CompanyName = "Evil Corp",
    
    [Parameter(HelpMessage="Specify the users' nationalities")]
    [Alias("nat")]
    [string]$Nationalities = "IT"
    )

$ErrorActionPreference = 'SilentlyContinue'

Function script:Set-Environment {
$RandomUsersArr = New-Object System.Collections.ArrayList
$Date = (Get-Date -Format (Get-Culture).DateTimeFormat.ShortDatePattern) -replace '/','.'
$DesktopPath = [Environment]::GetFolderPath("Desktop")
  Try {
    Import-Module ActiveDirectory -ErrorAction Stop
  }
  Catch [Exception] {
    Return $_.Exception.Message
  }

  #$DomainInfo = Get-ADDomain -Credential $Credentials -Current LocalComputer
  $DomainInfo = Get-ADDomain -Current LocalComputer
  $UsersOU=$DomainInfo.UsersContainer #Creates users in the Users container by default
  $UPNSuffix = "@" + $DomainInfo.DNSRoot
} #End Set-Environment

Function script:Get-UserData {
  Try {
    $RandomUsers = Invoke-RestMethod "https://www.randomuser.me/api/?results=$NumUsers&amp;nat=$Nationalities" | Select-Object -ExpandProperty Results
  }
  Catch [Exception] {
    Return $_.Exception.Message
  }
} #End Get-Users

Function script:Format-Passwords {
#Generate passwords to meet default Server 2012 R2 complexity requirements - https://technet.microsoft.com/en-us/library/cc786468(v=ws.10).aspx
  $RandomInputSymbol = $(ForEach ($Char in @(32..47+58..64+91..96+123..126)){[char]$Char}) | Get-Random -count 2
  $RandomInputNum = $(ForEach ($Char in @(48..57)){[char]$Char}) | Get-Random -count 2
  $RandomInputUpper = $(ForEach ($Char in @(65..90)){[char]$Char}) | Get-Random -count 4
  $RandomInputLower = $(ForEach ($Char in @(97..122)){[char]$Char}) | Get-Random -count 4
  $PasswordArrComplete = $RandomInputSymbol+$RandomInputNum+$RandomInputUpper+$RandomInputLower
  $Random = New-Object Random
  $Password = [string]::join("",($PasswordArrComplete | sort {$Random.Next()}))
  $script:PlainTextPW = @{ #Snag the plaintext password for later use
    "PlainPW" = $Password
  }
  Return $Password | ConvertTo-SecureString -AsPlainText -Force #Pass a SecureString to New-ADUser
} #End Format-Passwords

. Set-Environment
. Get-UserData

ForEach ($RandomUser in $RandomUsers) {
  $First = $RandomUser.Name.First.Substring(0,1).ToUpper()+$RandomUser.Name.First.Substring(1).ToLower()
  $Last = $RandomUser.Name.Last.Substring(0,1).ToUpper()+$RandomUser.Name.Last.Substring(1).ToLower()

  $UserProperties = @{
  "GivenName" = $First
  "Surname" = $Last
  "Name" = $First + " " + $Last
  "DisplayName" = $First + " " + $Last
  "OfficePhone" = $RandomUser.Phone
  "City" = $RandomUser.Location.City
  "State" = $RandomUser.Location.State
  "Country" = $Nationalities
  "Company" = $CompanyName
  "SAMAccountName" = $Last + $First[0]
  "UserPrincipalName" = $Last + $First[0] + $UPNSuffix
  "AccountPassword" = . Format-Passwords
  "Enabled" = $True
  "ChangePasswordAtLogon" = $False
  "Description" = "Test Account Generated $Date by $env:username"
  "Path" = $UsersOU
  }

  New-ADUser @UserProperties #-Credential $Credentials
  $UserPropertiesObj = New-Object PSObject -Property $UserProperties
  $UserPropertiesObj | Add-Member $PlainTextPW
  $RandomUsersArr.Add($UserPropertiesObj) | Out-Null #Add the object to the array

} #End ForEach

$RandomUsersArr | Export-CSV $DesktopPath\UserCreation.csv -Append -NoTypeInformation
