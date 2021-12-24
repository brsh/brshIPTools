function Get-iptServicesEntry {
	<#
.SYNOPSIS
Breaks the Services file into PS Objects

.DESCRIPTION
Just a simple script to parse the etc/services file - with a few extended features:
* Default searches the "native" services files (/etc/services on linux, and %systemroot%\System32\drivers\etc\services on windows)
* Can search the module-provided services file (Ubuntu, Windows, IANA, and NMAP) - singly or all-together
* Can search a user specified services file - provided it fits the correct services format

Filters on things like Port, Protocol Name, and TCP vs UDP

.PARAMETER Protocol
Filter TCP or UDP

.PARAMETER Port
Filter the list on a specific Port number

.PARAMETER Name
Filter the list on a specific name (well, start of name - the regex is ^ plus chars entered)

.PARAMETER AlternateServicesFile
By default, will use the OS native - but you can specify the services bottled with the module (or ALL) or specify a path to another file

.EXAMPLE
Get-ServiceEntry.ps1

Outputs the entire native services file with name, IP, and comment (if any)

.EXAMPLE
Get-ServiceEntry.ps1 -Protocol TCP

Outputs the entire native services file with name, IP, and comment (if any), filtering on TCP

.EXAMPLE
Get-ServiceEntry.ps1 -port 445

Outputs the entire native services file with name, IP, and comment (if any), filtering on port 445

.EXAMPLE
Get-ServiceEntry.ps1 -name dhcpv6-client

Outputs the entire native services file with name, IP, and comment (if any), filtering on dhcpv6-client

.EXAMPLE
Get-ServiceEntry.ps1 -name dhcpv6-client -tcp

Outputs the entire native services file with name, IP, and comment (if any), filtering on the tcp ports of dhcpv6-client

.EXAMPLE
Get-ServiceEntry.ps1 -AlternateServiceFile c:\temp\services.mine

Parses the file called c:\temp\services.mine

.EXAMPLE
Get-ServiceEntry.ps1 -AlternateServiceFile IANA

Parses the module supplied IANA file

.EXAMPLE
Get-ServiceEntry.ps1 -AlternateServiceFile ALL

Parses all the module supplied services file
#>
	[CmdLetBinding(DefaultParameterSetName = 'Name')]
	param (
		[ValidateSet('TCP', 'UDP')]
		[string] $Protocol = '',
		[parameter(Mandatory = $false, ParameterSetName = 'Port')]
		[int] $Port = -1,
		[parameter(Mandatory = $false, ParameterSetName = 'Name')]
		[string] $Name = '',
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-iptServicesFiles -Filter "$WordToComplete").Extension
				} else {
					(Get-iptServicesFiles).Extension
				}
			})]
		[string] $AlternateServicesFile
	)

	[string] $PSType = "brsh.iptServices"
	$HostsFile = if ($AlternateServicesFile.Trim().Length -eq 0) {
		$Native = if ($IsLinux) {
			Get-ChildItem -path '/etc/services'
		} else {
			Get-ChildItem -path "${env:windir}\System32\drivers\etc\services"
		}
		Format-ServicesFile -Object $Native -Extension 'Native'
	} else {
		if ($AlternateServicesFile.ToUpper() -eq 'ALL') {
			Get-iptServicesFiles
			$PSType = "brsh.iptServicesSource"
		} elseif (Test-Path -path $AlternateServicesFile -ErrorAction SilentlyContinue) {
			$Native = Get-ChildItem -path $AlternateServicesFile
			Format-ServicesFile -Object $Native -Extension 'Custom'
		} else {
			$Attempt = Get-iptServicesFiles -filter $AlternateServicesFile
			if ($Attempt) {
				$Attempt
			} else {
				Throw 'File Not Found'
			}
		}
	}

	[string] $WhereClause = '((-not $_.StartsWith("#")) -and ($_.Trim().Length -gt 0))'
	if ($Protocol.Length -gt 0) {
		$WhereClause += " -and `(`$_ -match `"/$Protocol`"`)"
	}

	if ($name.Length -gt 0) {
		$WhereClause += " -and `(`$_ -match `"`^`$name`"`)"
	} elseif ($port -gt -1) {
		$WhereClause += " -and `(`$_ -match `"`\s$port`/`"`)"
	}

	Write-Verbose "Where Filter:  $WhereClause"
	$ScriptBlock = [scriptblock]::Create($WhereClause)

	$HostsFile | ForEach-Object {
		Write-Verbose "Reading: $($_.Path)"

		$Extension = $_.Extension

		$Entries = Get-Content $_.Path -ReadCount 0
		Write-Verbose "Total: $($Entries.Count) Entries"
		$Entries | Where-Object -FilterScript $ScriptBlock | ForEach-Object {

			[bool] $WasPortError = $false
			[string] $ServiceName, [string] $PortTemp, [string] $TheRestTemp = $_.ToString().Trim() -split "\s+"
			[int] $PortNumber = 0
			try {
				$PortNumber = $PortTemp.Split("/")[0]
			} catch {
				$PortNumber = 0
				$WasPortError = $true
			}

			[string] $PortType = $PortTemp.Split("/")[1]
			[string] $Nick = $TheRestTemp.Split("#")[0].Trim()
			[string] $Comment = ""
			try {
				$Comment = $TheRestTemp.Split("#")[1].Trim()
			} catch {
				$Comment = ""
			} finally {
				if ($WasPortError) { $Comment += " !! Port number misread !!" }
			}

			[pscustomobject] [ordered] @{
				PSTypeName = $PSType
				Name       = $ServiceName.Trim()
				Port       = $PortNumber
				Protocol   = $PortType.Trim()
				Nickname   = $Nick.Trim() -split "\s+"
				Comment    = $Comment.Trim()
				Source     = $Extension
			}
		}
	}
}

function Get-iptServicesFiles {
	param (
		[string] $Filter = ''
	)
	$retval = Get-ChildItem -path "${script:ScriptPath}\config\services.*" | ForEach-Object {
		$Extension = $_.Extension.Trim().TrimStart('.')
		$Extension = switch -Regex ($Extension) {
			"(iana|nmap)" { $_.ToUpper() }
			DEFAULT { (Get-Culture).TextInfo.ToTitleCase($_) }
		}
		Format-ServicesFile -Object $_ -Extension $Extension
	}
	if ($Filter.Trim().Length -gt 0) {
		$retval = $retval | Where-Object { $_.Extension -match "$Filter" }
	}
	$retval
}
