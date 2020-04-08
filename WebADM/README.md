## WebADM Authentication - Required for all sections below.
### Step 1 - Prompt for users username/password
$SecurePassword = Read-Host -Prompt 'Enter your password' -AsSecureString

### Step 2 - Generate WebADM Authentication Headers
$AuthHeader = Generate-WebADM-AuthHeaders -Username $ENV:USERNAME -Password (ConvertFrom-SecureToPlain -SecurePassword $SecurePassword)


## WebADM User activation
### Step 3 - Get Random Seed from WebADM
$Key = Get-WebADM-RandomByte -Length 20 -AuthHeader $AuthHeader

### Step 4 - Get UserDN from WebADM
$UserDN = Get-WebADM-UserDN -SamAccountName 'Username' -AuthHeader $AuthHeader

### Step 5 - Activate User in WebADM
$Result = Set-WebADM-ActivateUser -UserDN $UserDN -AuthHeader $AuthHeader

### Step 6 - Register TOTP in WebADM
$Result = Set-WebADM-TOTPRegister -UserDN $UserDN -Key $Key -AuthHeader $AuthHeader

### Step 7 - Get TOTP URI from WebADM
$URI = Get-WebADM-TOTPUri -Name 'Company OTP' -Key $Key -UserID 'Username' -Domain 'default' -AuthHeader $AuthHeader

### Step 8 - Generate and Display QR Code
$FilePath = Generate-TOTP-QRCode -Name 'Test' -Payload $URI -Show

#### The resulting QR Code can be scanned directly into a relevant OTP application. I.E Google/Microsoft Authenticator, Authy, FreeOTP, etc

## WebADM User Deactivation
### Step 3 - Get UserDN from WebADM
$UserDN = Get-WebADM-UserDN -SamAccountName 'Username' -AuthHeader $AuthHeader

### Step 4 - Deactivate User in WebADM
$Result = Set-WebADM-ActivateUser -UserDN $UserDN -AuthHeader $AuthHeader

## WebADM Disable Primary Token
### Step 3 - Get UserDN from WebADM
$UserDN = Get-WebADM-UserDN -SamAccountName 'Username' -AuthHeader $AuthHeader

### Step 4 - Disable OTP in WebADM
$Result = Set-WebADM-DisableOTP -UserDN $UserDN -AuthHeader $AuthHeader

## WebADM Enable Primary Token
### Step 3 - Get UserDN from WebADM
$UserDN = Get-WebADM-UserDN -SamAccountName 'Username' -AuthHeader $AuthHeader

### Step 4 - Disable OTP in WebADM
$Result = Set-WebADM-EnableOTP -UserDN $UserDN -AuthHeader $AuthHeader
