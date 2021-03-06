function ConvertFrom-SecureToPlain {
<#
    .SYNOPSIS
        This function converts a PowerShell SecureString back to Plaintext.
    .DESCRIPTION
        This function is used in conjuction with Set-WebADM-AuthHeaders, as WebADM will not accept a PS SecureString.
    .EXAMPLE
        $SecurePassword = Read-Host -Prompt 'Enter your password' -AsSecureString
        $AuthHeader = Set-WebADM-AuthHeaders -Username $ENV:USERNAME -Password (ConvertFrom-SecureToPlain -SecurePassword $SecurePassword)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString] $SecurePassword
    )
    $PasswordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $PlainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($PasswordPointer)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPointer)
    Return $PlainTextPassword
}

function Set-WebADM-AuthHeaders {
<#
    .SYNOPSIS
        This function creates a base64 authentication header for communication with a JSON API.
    .DESCRIPTION
        This function will use a username and password to generate an authentication header
        converted to base64 that can be used to authenicate with a JSON-RPC API. 
        In this case it will be used to authenticate with the WebADM API.
        This is used in conjuction with ConvertFrom-SecureToPlain because the API will not 
        accept a PS SecureString. However you can just use a Plaintext password if you wish.

        The function will test the WebADM API to confirm the credentials are correct and pass a error
        if they are not.
    .EXAMPLE
        $SecurePassword = Read-Host -Prompt 'Enter your password' -AsSecureString
        $AuthHeader = Set-WebADM-AuthHeaders -Username $ENV:USERNAME -Password (ConvertFrom-SecureToPlain -SecurePassword $SecurePassword)
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string]$Username,
		[Parameter(Mandatory=$true)]
		[string]$Password,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
    )
	$Username = "default\$Username" # Replace default with your domain name.
	$Userpass = $Username + ":" + $Password
	$Bytes = [System.Text.Encoding]::UTF8.GetBytes($Userpass)
	$EncodedLogin = [Convert]::ToBase64String($Bytes)
	$AuthHeader = "Basic " + $Encodedlogin
	$Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$Headers.Add("Authorization", $AuthHeader)
	$Headers.Add("Accept", "application/json")
	$Headers.Add("Content-Type", "application/json")
	$Response = Invoke-RestMethod -Uri $URL -Headers $Headers
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
	} Else {
		Return $Headers
	}
}

function Get-WebADM-RandomBytes {
<#
    .SYNOPSIS
        This function returns pseudo-random bytes generated by the WebADM true random engine.
    .DESCRIPTION
        This function returns pseudo-random bytes generated by the WebADM true random engine.
        The random bytes are usable for cryptography and random seeds.

        Key length can be:
         - 20 Bytes for a SHA1 OATH Token
         - 32 Bytes for a SHA256 OATH Token
         - 64 Bytes for a SHA512 OATH Token
    .EXAMPLE
        $Key = Get-WebADM-RandomBytes -Length 20 -AuthHeader $AuthHeader
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string][ValidateSet('20','32','64')]$Length,
		[Parameter(Mandatory=$true)]
		$AuthHeader,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
	)
	$method = 'Get_Random_Bytes'
	$params = @{
		Length = $Length
	}
	$request = @{
		jsonrpc = '2.0'
		method = $method
		params = $params
		id = 0
	}
	$json = $request | ConvertTo-Json
	$Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError 
	} Else {
		Return $Response.Result
	}
}

function Get-WebADM-UserDN {
<#
    .SYNOPSIS
        This function returns a user distinguished name based off their username.
    .DESCRIPTION
        This function will use a username value and search WebADM to return the users 
        distinguished name.
        If the user cannot be found the function will return an error.
    .EXAMPLE
        $UserDN = Get-WebADM-UserDN -SamAccountName Username -Domain Domain -AuthHeader $AuthHeader -ErrorAction Stop
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
        [string]$SamAccountName,
        [Parameter(Mandatory=$true)]
		[string]$Domain,
		[Parameter(Mandatory=$true)]
		$AuthHeader,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
	)
	$method = 'Get_User_DN'
	$params = @{
		username = $SamAccountName
		domain = $Domain
	}
	$request = @{
		jsonrpc = '2.0'
		method = $method
		params = $params
		id = 0
	}
	$json = $request | ConvertTo-Json
	$Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
	} elseif ($Response.Result -like 'False') {
        	Write-Error -Message "Cannot find any user with SamAccountName: $SamAccountName" -Category ObjectNotFound
	} Else {
		Return $Response.Result
	}
}

function Set-WebADM-ActivateUser {
<#
    .SYNOPSIS
        This function will activate a user in WebADM.
    .DESCRIPTION
        This function will use the users distinguished name to activate them in WebADM.
        If the user cannot be found or the user is already activated the function will return an error.
        Successful $Result will return 'True'
    .EXAMPLE
        $Result = Set-WebADM-ActivateUser -UserDN $UserDN -AuthHeader $AuthHeader -ErrorAction Stop
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string]$UserDN,
		[Parameter(Mandatory=$true)]
		$AuthHeader,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
	)
	$method = 'Activate_LDAP_Object'
	$params = @{
		dn = $UserDN
	}
	$request = @{
		jsonrpc = '2.0'
		method = $method
		params = $params
		id = 0
	}
	$json = $request | ConvertTo-Json
	$Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
		Return
	} elseif ($Response.Result -like 'False') {
		Write-Error -Message "Invalid User DN or already activated" -Category InvalidResult
		Return
	} Else {
		Return $Response.Result
	}
}

function Set-WebADM-DeactivateUser {
<#
    .SYNOPSIS
        This function will deactivate a user in WebADM.
    .DESCRIPTION
        This function will use the users distinguished name to deactivate them in WebADM.
        If the user cannot be found or the user is already deactivated the function will return an error.
        Successful $Result will return 'True'
    .EXAMPLE
        $Result = Set-WebADM-DeactivateUser -UserDN $UserDN -AuthHeader $AuthHeader -ErrorAction Stop
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string]$UserDN,
		[Parameter(Mandatory=$true)]
		$AuthHeader,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
	)
	$method = 'Deactivate_LDAP_Object'
	$params = @{
		dn = $UserDN
	}
	$request = @{
		jsonrpc = '2.0'
		method = $method
		params = $params
		id = 0
	}
	$json = $request | ConvertTo-Json
	$Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
		Return
	} elseif ($Response.Result -like 'False') {
		Write-Error -Message "Invalid User DN or already deactivated" -Category InvalidResult
		Return
	} Else {
		Return $Response.Result
	}
}

function Set-WebADM-EnableOTP {
<#
    .SYNOPSIS
        This function will enable a users OTP in WebADM.
    .DESCRIPTION
        This function will use the users distinguished name to enable a users OTP in WebADM.
        If the user cannot be found or the users OTP is already enabled the function will return an error.
        Successful $Result will return 'True'
    .EXAMPLE
        $Result = Set-WebADM-EnableOTP -UserDN $UserDN -AuthHeader $AuthHeader -ErrorAction Stop
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserDN,
        [Parameter(Mandatory=$true)]
        $AuthHeader,
        [string]$URL = 'https://webadm-server-fqdn/manag/'
    )
    $method = 'OpenOTP.Token_Enable'
    $params = @{
        dn = $UserDN
    }
    $request = @{
        jsonrpc = '2.0'
        method = $method
        params = $params
        id = 0
    }
    $json = $request | ConvertTo-Json
    $Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
    If ($Response.Error.Data -like 'Invalid Username or Password') {
        Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
        Return
    } elseif ($Response.Result -like 'False') {
        Write-Error -Message "Failed to enable OTP: $UserDN" -Category InvalidResult
        Return
    } Else {
        Return $Response.Result
    }
}

function Set-WebADM-DisableOTP {
<#
    .SYNOPSIS
        This function will disable a users OTP in WebADM.
    .DESCRIPTION
        This function will use the users distinguished name to disable a users OTP in WebADM.
        If the user cannot be found or the users OTP is already disabled the function will return an error.
        Successful $Result will return 'True'
    .EXAMPLE
        $Result = Set-WebADM-DisableOTP -UserDN $UserDN -AuthHeader $AuthHeader -ErrorAction Stop
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserDN,
        [Parameter(Mandatory=$true)]
        $AuthHeader,
        [string]$URL = 'https://webadm-server-fqdn/manag/'
    )
    $method = 'OpenOTP.Token_Disable'
    $params = @{
        dn = $UserDN
    }
    $request = @{
        jsonrpc = '2.0'
        method = $method
        params = $params
        id = 0
    }
    $json = $request | ConvertTo-Json
    $Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
    If ($Response.Error.Data -like 'Invalid Username or Password') {
        Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
        Return
    } elseif ($Response.Result -like 'False') {
        Write-Error -Message "Failed to disable OTP: $UserDN" -Category InvalidResult
        Return
    } Else {
        Return $Response.Result
    }
}

function Set-WebADM-TOTPRegister {
<#
    .SYNOPSIS
        This function will register a TOTP token against a user.
    .DESCRIPTION
        This function will use the users distinguished name and random key to register a TOTP token in WebADM.
        Successful $Result will return 'True'

        Use Get-WebADM-RandomByte to generate the $Key
    .EXAMPLE
        $Result = Set-WebADM-TOTPRegister -UserDN $UserDN -Key $Key -AuthHeader $AuthHeader -ErrorAction Stop
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string]$UserDN,
		[Parameter(Mandatory=$true)]
		[string]$Key,
		[Parameter(Mandatory=$true)]
        $AuthHeader,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
	)
	$method = 'OpenOTP.TOTP_Register'
	$params = @{
		dn = $UserDN
		key = $Key
	}
	$request = @{
		jsonrpc = '2.0'
		method = $method
		params = $params
		id = 0
	}
	$json = $request | ConvertTo-Json
	$Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
		Return
	} elseif ($Response.Result -like 'False') {
		Write-Error -Message "Unable to register TOTP for user: $UserDN" -Category InvalidResult
		Return
	} Else {
		Return $Response.Result
	}
}

function Get-WebADM-TOTPUri {
<#
    .SYNOPSIS
        This function will return the URI to be used in a QR Code.
    .DESCRIPTION
        This function will return the enrolment URI to be used in a QRCode.
        Name is the display name for the software Token.

        Period, Digits and Values are taken as default from the server.

    .EXAMPLE
        $URI = Get-WebADM-TOTPUri -Name '' -$Key $Key -UserID Username -Domain Domain -AuthHeader $AuthHeader
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[Parameter(Mandatory=$true)]
        [string]$Key,
        [Parameter(Mandatory=$true)]
        [string]$UserID,
        [Parameter(Mandatory=$true)]
		[string]$Domain,
		[Parameter(Mandatory=$true)]
        $AuthHeader,
		[string]$URL = 'https://webadm-server-fqdn/manag/'
	)
	$method = 'OpenOTP.TOTP_URI'
	$params = @{
		name = $Name
        key = $Key
        userid = $UserID
        domain = $Domain
	}
	$request = @{
		jsonrpc = '2.0'
		method = $method
		params = $params
		id = 0
	}
	$json = $request | ConvertTo-Json
	$Response = Invoke-RestMethod -Uri $URL -Headers $AuthHeader -Method Post -Body $json -ContentType application/json
	If ($Response.Error.Data -like 'Invalid Username or Password') {
		Write-Error -Message 'Invalid Username or Password' -Category AuthenticationError
		Return
	} elseif ($Response.Result -like 'False') {
		Write-Error -Message "Unable to register TOTP for user: $UserDN" -Category InvalidResult
		Return
	} Else {
		Return $Response.Result
	}
}

function Generate-TOTP-QRCode {
<#
    .SYNOPSIS
        This function will generate a QR code using the TOTP URI (from Get-WebADM-TOTPUri)
    .DESCRIPTION
        This function will generate a QR code using the TOTP URI (from Get-WebADM-TOTPUri)
            Name is the filename for the generated QR code (Eg. the Users DN)
            Payload is the URI from Get-WebADM-TOTPUri

        The URI will get rewritten to remove some inrelevant data and produce a cleaner string.
            -SecretOnly will return a QR code which includes only the secret key.
            -Show will get the system only open the QR code in a relevant program.

        The returned value of the function will be the filepath to the generate QR code.

        Create-QRCoderDLL will create the DLL required to run this function.
    .EXAMPLE
        $FilePath = Generate-TOTP-QRCode -Name $UserDN -$Payload $URI
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Payload,
        [ValidateRange(10, 2000)]
        [int]$Width = 10,
        [Switch]$SecretOnly,
        [Switch]$Show
    )
    $Split = $Payload -split '&'
    If ($SecretOnly) {
        $Split = $Split[0] -split '='
        $Payload = $Split[1]
    } Else {
        $Payload = "$($Split[0])&$($Split[1])&$($Split[3])&$($Split[4])&$($Split[5])"
    }

    If (!(Test-Path -Path "$ScriptDirectory\QR")) {New-Item -Path $ScriptDirectory -ItemType Directory -Name 'QR'}
    $OutPath = "$ScriptDirectory\QR\$Name.png"
    If (!(Test-Path -Path "$ScriptDirectory\binaries\QRCoder.dll")) {Create-QRCoderDLL}
    Add-Type -Path "$ScriptDirectory\binaries\QRCoder.dll"
    
    $Generator = New-Object -TypeName QRCoder.QRCodeGenerator
    $Data = $Generator.CreateQrCode($Payload, 'Q')
    $Code = New-Object -TypeName QRCoder.PngByteQRCode -ArgumentList ($Data)
    $ByteArray = $Code.GetGraphic($Width)
    [System.IO.File]::WriteAllBytes($OutPath, $ByteArray)
    
    If ($Show) {Invoke-Item -Path $OutPath}
    Return $OutPath
}
