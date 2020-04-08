
$form1_Load={
	[string]$Script:ScriptDirectory = Get-ScriptDirectory
	$Script:SecretOnly = $false
}

$checkboxSecretOnly_SelectedIndexChanged = {
	[boolean]$Script:SecretOnly = $checkboxSecretOnly.Checked
}

$combobox1_SelectedIndexChanged = {
	If ($combobox1.SelectedItem.BootFile -notlike $NULL) {
		$textbox1.Text = 'Active'
		$textbox1.BackColor='LightGreen'
		$buttonActivate.Enabled = $false
		$buttonDeactivate.Enabled = $true
	} Else {
		$textbox1.Text = 'Inactive'
		$textbox1.BackColor='Red'
		$buttonActivate.Enabled = $true
		$buttonDeactivate.Enabled = $false
	}
}

$buttonRefresh_Click = {
	Try {
		If ($AuthHeaders -like $null) {
			$SecurePassword = Read-Host -Prompt 'Enter your password' -AsSecureString
			$Script:AuthHeader = Generate-WebADM-AuthHeaders -Username $ENV:USERNAME -Password (ConvertFrom-SecureToPlain -SecurePassword $SecurePassword) -ErrorAction Stop
		}
		
		$Users = Get-AllADUsers
		
		Update-ComboBox -ComboBox $combobox1 -Items $Users -DisplayMember $Users.SelectedItem.DisplayName
		$combobox1.SelectedIndex=0
	} Catch {
		Write-Host 'WebADM Password Incorrect'
	}
}

$buttonActivate_Click={
	Try {
		$Key = Get-WebADM-RandomByte -Length 20 -Headers $Headers
		$UserDN = Get-WebADM-UserDN -SamAccountName $combobox1.SelectedItem.SamAccountName -AuthHeader $AuthHeader
		If ($UserDN -notlike $NULL) {
			$WebADMUserActive = Set-WebADM-ActivateUser -UserDN $UserDN -Headers $Headers
			If ($WebADMUserActive -like 'true') {
				$WebADMTOTPToken = Set-WebADM-TOTPRegister -UserDN $UserDN -Key $Key -Headers $Headers
				If ($WebADMTOTPToken -like 'true') {
					$URI = Get-WebADM-TOTPUri -Name 'Company OTP' -Key $Key -UserID $combobox1.SelectedItem.SamAccountName -Domain 'Default' -Headers $Headers
				}
				If ($SecretOnly) {
					$Location = Generate-TOTPQRCode -Name $UserDN -Payload $URI -Width 10 -SecretOnly
				} Else {
					$Location = Generate-TOTPQRCode -Name $UserDN -Payload $URI -Width 10
				}
				$picturebox1.ImageLocation = $Location
			}
		}
	} Catch {
		Write-Host "$Error"
	} Finally {
		If ($WebADMTOTPToken -like 'true') {
			Write-Host "Successfully registered user: $UserDN"
		}
		$SelectedIndex = $combobox1.SelectedIndex
		&$buttonRefresh_Click
		$combobox1.SelectedIndex=$SelectedIndex
	}
}

$buttonDeactivate_Click={
	$UserDN = Get-WebADM-UserDN -SamAccountName $combobox1.SelectedItem.SamAccountName -AuthHeader $AuthHeader
	If ($UserDN -notlike $NULL) {
		$title = 'something'
		$question = 'Are you sure you want to proceed?'
		
		$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
		$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
		$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
		
		$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
		if ($decision -eq 0) {
			$WebADMUserInactive = Set-WebADM-DeactivateUser -UserDN $UserDN -AuthHeader $AuthHeader
			Write-Host 'User Deactivated'
		} else {
			Write-Host 'cancelled'
		}
	}
	$SelectedIndex = $combobox1.SelectedIndex
	&$buttonRefresh_Click
	$combobox1.SelectedIndex = $SelectedIndex
}
