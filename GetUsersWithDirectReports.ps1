cls
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "Group.Read.All", "Directory.Read.All", "User.Read.All" -NoWelcome

Write-Host "Starting the script..."
Write-Host "`nGetting all the users in your tenant"

#Get All users
$users = @()
$users = Get-MgUser -All | Select Id
Write-Host "Total users discovered :" -NoNewLine
Write-Host $Users.count -ForeGroundColor Green


Write-Host "`nWe will identify which users have direct reports, this process can take some time..."
$managers = @()

#To be used in a progress bar
$totalItems = $users.Count
$StartPoint = 0

foreach($user in $users)
{
	$percentComplete = [math]::Round((($StartPoint + 1) / $totalItems) * 100, 2)
	$IsItManager = Get-MgUserDirectReport -UserId $user.Id
	#Identifying which users have direct reports, if the user have a direct report the count will be 1 or more
	if ($IsItManager.count -ne 0)
	{
		$managers += $user
	}
	$StartPoint++
	Write-Progress -Activity "Processing Users" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
}

Write-Host "`nTotal managers discovered :" -NoNewLine
Write-Host $managers.count -ForeGroundColor Green
#Getting the detailed information for each manager

Write-Host "`nWe are getting the details for each manager..."
$managersdetails = @()

#To be used in a progress bar
$totalItems = $managers.Count
$StartPoint = 0

foreach($manager in $managers)
{
	$percentComplete = [math]::Round((($StartPoint + 1) / $totalItems) * 100, 2)
	$UserDetails = Get-MgUser -UserId $manager.Id | select Id, DisplayName, Mail, UserPrincipalName
	$managersdetails += $UserDetails
	$StartPoint++
	Write-Progress -Activity "Processing Managers" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
}

#Exporting the results to CSV
$ExportFolder = $PSScriptRoot
$managersdetails | Export-Csv -Path "ManagersDetailed.CSV" -NTI -Force -Append | Out-Null

Write-Host "`nA detailed list called " -NoNewLine
Write-Host "'ManagersDetailed.CSV' " -NoNewLine -ForeGroundColor Green
Write-Host "was created under " -NoNewLine
Write-Host "$ExportFolder`n`n" -ForeGroundColor Green
