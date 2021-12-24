function Get-Indent {
	param (
		[int] $Level,
		[string] $Char = '  '
	)
	($Char * $Level)
}

function Write-Status {
	param (
		[Parameter(Position = 0)]
		[Alias('Text', 'Subject')]
		[string[]] $Message,
		[Parameter(Position = 1)]
		[string[]] $Type,
		[Parameter(Position = 2)]
		[int] $Level = 0,
		[Parameter(Position = 3)]
		[System.Management.Automation.ErrorRecord] $e,
		[int] $EventID = -1
	)
	[string] $LogType = 'Information'

	[System.ConsoleColor] $ColorInfo = [ConsoleColor]::White
	[System.ConsoleColor] $ColorGood = [ConsoleColor]::Green
	[System.ConsoleColor] $ColorError = [ConsoleColor]::Red
	[System.ConsoleColor] $ColorWarning = [ConsoleColor]::Yellow
	[System.ConsoleColor] $ColorDebug = [ConsoleColor]::Cyan

	[System.ConsoleColor] $FGColor = $ColorInfo
	[System.ConsoleColor] $DefaultBGColor = $Host.UI.RawUI.BackgroundColor
	[System.ConsoleColor] $BGColor = $DefaultBGColor

	[System.ConsoleColor] $ColorHighlight = [ConsoleColor]::DarkGray

	if ($BGColor -eq $ColorHighlight) {
		[System.ConsoleColor] $ColorHighlight = [ConsoleColor]::DarkMagenta
	}

	[string] $Space = Get-Indent -Level $Level

	if ($Message) {
		:parent foreach ($txt in $Message) {
			$BGColor = $DefaultBGColor
			[int] $index = [array]::indexof($Message, $txt)
			Switch -regex ($Type[$index]) {
				'^G' {
					$FGColor = $ColorGood
					$LogType = "Information"
					break
				}
				'^E' {
					$FGColor = $ColorError
					$LogType = "Error"
					break
				}
				'^W' {
					$FGColor = $ColorWarning
					$LogType = "Warning"
					break
				}
				'^D' {
					$FGColor = $ColorDebug
					$LogType = "Information"
					$EventLog = $false
					break
				}
				'^S' {
					break parent
				}
				DEFAULT {
					$FGColor = $ColorInfo
					$LogType = "Information"
					break
				}
			}
			if ($index -ge 0) {
				$space = ' '
			}
			Write-Host $Space  -ForegroundColor $FGColor -BackgroundColor $BGColor -NoNewline
			if ($Type[$index] -match 'High$') { $BGColor = $ColorHighlight }
			Write-Host $txt -ForegroundColor $FGColor -BackgroundColor $BGColor -NoNewline
		}
		write-host ''
	}

	if ($e) {
		$Level += 1
		$space = Get-Indent -Level $Level

		[string[]] $wrapped = Set-WordWrap -Message $($e.InvocationInfo.PositionMessage -split "`n") -Level $Level
		$wrapped | ForEach-Object {
			if ($_ -notmatch '^\+ \~') {
				Write-Status -Message $_ -Type 'Warning' -Level $Level
			}
		}

		$wrapped = Set-WordWrap -Message $e.Exception.Message -Level $Level
		$wrapped | ForEach-Object {
			Write-Status -Message $_ -Type 'Error' -Level $Level
		}
	}
	if ($EventID -ge 0) {
		Write-brshEventLog -Type $LogType -Message $Message -e $e -ID $EventID
	}
}

<#
.SYNOPSIS
wraps a string or an array of strings at the console width without breaking within a word
.PARAMETER chunk
a string or an array of strings
.EXAMPLE
word-wrap -chunk $string
.EXAMPLE
$string | word-wrap
#>
function Set-WordWrap {
	[CmdletBinding()]
	Param(
		[string[]] $Message,
		[int] $Level = 0
	)

	BEGIN {
		[string] $Space = Get-Indent -Level $Level
		$Lines = @()
	}

	PROCESS {
		foreach ($line in $Message) {
			$words = ''
			$count = 0
			$line -split '\s+' | ForEach-Object {
				$count += $_.Length + 1
				if ($count -gt ($Host.UI.RawUI.WindowSize.Width - $Space.Length - 6)) {
					$Lines += , $words.trim()
					$words = ''
					$count = $_.Length + 1
				}
				$words = "$words$_ "
			}
			$Lines += , $words.trim()
		}
		# $Lines
	}

	END {
		$Lines
	}
}


# SIG # Begin signature block
# MIIapgYJKoZIhvcNAQcCoIIalzCCGpMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwg2BDBcjdVJxh1XkeeY8pMZV
# XxmgghX4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggYtMIIEFaADAgECAhMpAAAABXWymYTGfpE6AAAAAAAFMA0GCSqGSIb3DQEBCwUA
# MBkxFzAVBgNVBAMTDlNtYXJzaCBSb290IENBMB4XDTIwMDMxOTIyNDQxOVoXDTMw
# MDMxOTIyNTQxOVowUTETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcGCgmSJomT8ixk
# ARkWCXNtYXJzaGluYzEfMB0GA1UEAxMWU21hcnNoIFByb2QgSXNzdWluZyBDQTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAM9BEPWp/klPQ+oqFjkjb8RL
# KyRmP/TOEUruMhSIh/zC3cDbfFCNTwuxEuGoLdnZseR4d7Ic8EfD7w0lHZ1Y/v5j
# Ps7nhtpmlvzeGSVqzJbLd07rexKNeZiiOK5ggfYAcsQsJLUwGTHa7V8KmixHSQWz
# 1LsicABSLsec1lQOmCJDu9SxoC5P5QHygiSx+9/Qrlg0JQaKxWgH63lI3bG3BBie
# /JqX9dgsMfO7QBuDzErRGSSYC4QoE7B78b9AXC7FT3bHF9/ZKJ72qIpaRfBNE5Dm
# boCq1STg6s0JRPktfl3Y4IfbZa8YL9AalmwgrWVlOBk3D6r1cmgE41LY5Sq9/49w
# IhcTKhRM7GPzIjM9rurKAH36u1DGZVm7mlPQAjsmtiGuZHJ9WHYDu5VPwAmRooT+
# K7sQQcNzgIbR/qISx8BWLYOpWVsdHaO9QAYbo5fHCYow8fPmxYqRP+Uc+nc50Pib
# 5u4grrb650zMVEjd95UOw8vGDsnaI50XeQCPL8xQ3wGPpLoPqyEQAb+elTGemwB1
# zjheNHlcrxqjbXisCQjwtMLYL4rI1euZ65pUkj4UD0njsOBUyexVx0SuNXki+1QW
# BgbFB8W/4fHcdYV3+jWu/r+E0uSxPtk8X3XZklUK0//ibfftgONIYx2DBBvSr5+Z
# 6b2eHTMp/jf72An7e08pAgMBAAGjggE0MIIBMDAQBgkrBgEEAYI3FQEEAwIBADAd
# BgNVHQ4EFgQULb1HehO6GxhT475i7QAUQ3d/eb4wGQYJKwYBBAGCNxQCBAweCgBT
# AHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgw
# FoAUF9H0i4YCRl9YnSZ+NAifv3XR2cQwSwYDVR0fBEQwQjBAoD6gPIY6aHR0cDov
# L2NlcnRzLnNtYXJzaHBraS5jb20vQ2VydERhdGEvU21hcnNoJTIwUm9vdCUyMENB
# LmNybDBWBggrBgEFBQcBAQRKMEgwRgYIKwYBBQUHMAKGOmh0dHA6Ly9jZXJ0cy5z
# bWFyc2hwa2kuY29tL0NlcnREYXRhL1NtYXJzaCUyMFJvb3QlMjBDQS5jcnQwDQYJ
# KoZIhvcNAQELBQADggIBADdTClzBIK037D3k/b9D3fmsAZgc14DWGmxjP438uoTv
# avhFEdHwfde0a0MVQ8eExfn6FVWftULlm6MUkvgWNTQSeRLVQmjUZpMMYvfOSWH0
# vk9eu853byCTIJzsBUMdcUUgOAxWWZfUrefGkjDxlizfaV5BF6U7onHYPUFX9aoq
# rHAZRwQBxmUez+4itCVfjPJwMdgTTT+Yr5fY1D1Dv25lLvXTDAzuwahF/cf9szsV
# lWsv6C0OU31XpWDS8cCUQEi/Mt+f/lWO7UVBoN7KY/tsXoMIMUBZwjTG1+dJlrMP
# 2F8yz3D+jdVFzL0kmgKZXYTJafZu9UsnHf1sXBYvszatjQYwJgxPlGWMcu7fXrWC
# 9AQCtpLpuRWaxLA/nNccEZ0eHBESkTL4LNrknmf7aTbM1jpx2tPNPbB4+ZrYAYPa
# JhVYwp+YefMpVttc8chTPWtlK+nNNH1rGsO+MoJ3cm8sV6dinD99JG9ePXmdzFPF
# mTskqzho/5pgLENG/WCAQrBw+twvefDXKdgoC8YqOzlXvKfnYcSb0dikHuF9q0MP
# mPiPS7UVXf2rIj6AiCltHnJc3Ny2szVRzqiUTD8bMQisaHoQi6ugVcuqnXVO2dhD
# YIEDYtWfZLYvd9xttiWL5SWuVaR2Ot9WYuWNw8eqtXEu9ayIyyavZbdQWy67ck+h
# MIIHKjCCBRKgAwIBAgITJwAAAA7w2Aegk0evuAAAAAAADjANBgkqhkiG9w0BAQsF
# ADBRMRMwEQYKCZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJc21hcnNo
# aW5jMR8wHQYDVQQDExZTbWFyc2ggUHJvZCBJc3N1aW5nIENBMB4XDTIwMDUyODIx
# NTM1NFoXDTI1MDUyNzIxNTM1NFowfzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCXNtYXJzaGluYzEiMCAGA1UECxMZRW1wbG95ZWUgU2Vydmlj
# ZSBBY2NvdW50czEQMA4GA1UECxMHVGVjaE9wczEXMBUGA1UEAxMOQnJpYW4gU2hl
# YWZmZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDUbaxSpz2yWaok
# 5ZGDM1ubeLoaXP1nLOZ3ankQWOU4xm00GwRbqaCZdRlYRPQcyiYHCxa+I6ICDpAy
# Qg5iZlO3ltQiWNhqrbYIsNP+LWvyR3VwFLFTlv6kbJexfBPtm1HJpJoggZ/OGdzW
# UJjWr6kUY2lGQ71g7VTh8qVRvNrva7AXnt1l6DOaCBHZ3czUY1D3UnlsoHhrRpHz
# b68UywykkKYMVcpt5DjqjvONUvVHNY3hHmqhjfgriexSEzt2zhoYgErrkOizLvs7
# 6jwOxz+3IWThgYU07wlPuE1AVsojs+yLfcQobvxKJAV7BCrTyj3OdMmG/ruMD5mS
# drG5f7f5AgMBAAGjggLLMIICxzA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiH
# 2Yg1g/HlRIW9hQaF8fsQgsfCCGaCzP4yguKDFgIBZAIBAjATBgNVHSUEDDAKBggr
# BgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEF
# BQcDAzAdBgNVHQ4EFgQUIJyvB574ZYveV1moHbngC/cSGpYwHwYDVR0jBBgwFoAU
# Lb1HehO6GxhT475i7QAUQ3d/eb4wgd4GA1UdHwSB1jCB0zCB0KCBzaCByoaBx2xk
# YXA6Ly8vQ049U21hcnNoJTIwUHJvZCUyMElzc3VpbmclMjBDQSxDTj1waXQtY2Et
# MDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9c21hcnNoaW5jLERDPWNvbT9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnQwgdAGCCsGAQUFBwEBBIHDMIHAMIG9BggrBgEFBQcwAoaBsGxkYXA6Ly8v
# Q049U21hcnNoJTIwUHJvZCUyMElzc3VpbmclMjBDQSxDTj1BSUEsQ049UHVibGlj
# JTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixE
# Qz1zbWFyc2hpbmMsREM9Y29tP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFz
# cz1jZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MFAGA1UdEQRJMEegJwYKKwYBBAGCNxQC
# A6AZDBdCU2hlYWZmZXJAc21hcnNoaW5jLmNvbYEcYnJpYW4uc2hlYWZmZXJAc21h
# cnNoaW5jLmNvbTANBgkqhkiG9w0BAQsFAAOCAgEAza4rg5FNuJ9uSBTeyJ6BOw6M
# 29qxVqjLAIw9Mk+JJoeZGGB4Gl0wRlHB9LjF06Zt8CPKpCnNI5viS763nAPdbCFx
# 6QrZ8CbCtSGrT1wOQL5WesDcmu8wfgsskerJ1evhfGSuZOFutgHbIUEnWA/ez/de
# Gp9xGNDE/dBauRK0xWWVelTwnKSC4H6ESTdYrOYifownTTPaCmYHS3lgGA0kDtyI
# NABrK8RVP3+NMkKwQTGEKkQi52jkctUmJa2IeeNUgD05A5PTOaNBIVwb75oKziv6
# 0NHSS1H/GFLbREkDcu9oxL8uzc8UKWptbh2+AR5MU8QgDT93l9APptSkVi7Mumf1
# unovnk8/IgazygQ75hUvtP+fDNI43CNzjaYLclciyHJvIvGpL0Cbx5k4tFyjbQGi
# cRxAX9nsh1zNorj6U/xRJSqvGyvB8azCusZXxGn77dyMErQpJfY+oSJMKzhSoTp+
# xQrO1lERnDdMtXY3gthucJlhdayyiE87iGtXvXY2Bkeg57IVlosp6qMYiPl4sfPD
# JXfHf/NMKUnkSrlmx/fxP+w1ZqcnMYG+wdk95yTgQaY9Uv5iuyOm+Q0deBfzPrKo
# 4nsGvMlGQkd0ffA+wnVr/lwytlyTLSfD0s6d6oC6nwjNiXe3z8kz6Fnh/HDrLu9s
# F2mfAJVjT7VrTlHoLXwxggQYMIIEFAIBATBoMFExEzARBgoJkiaJk/IsZAEZFgNj
# b20xGTAXBgoJkiaJk/IsZAEZFglzbWFyc2hpbmMxHzAdBgNVBAMTFlNtYXJzaCBQ
# cm9kIElzc3VpbmcgQ0ECEycAAAAO8NgHoJNHr7gAAAAAAA4wCQYFKw4DAhoFAKB4
# MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQB
# gjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkE
# MRYEFHZR5R6/k5R1VIuhuV6V65MRqBxaMA0GCSqGSIb3DQEBAQUABIIBAExtWquG
# JnfkKQiqV31WSvyVQOQGW2hBMPOJve7sK7zDvfmfaYxc1Py/aeQWIa6S+0eIjA1N
# M3HZ3Cw5V9+eHE1KP2rTi0BEPTiLeVV1F78gDpT27hkRq+HlQv9QnW5mG8lKcUQ6
# RVZVP0BDlXaJbE8DPf8m7Wr/dr5Ol4Ecmj8/J3wPlrAeCGwjjFHTcSHUAqHi/Y3e
# fIV7HSobGmFOfpwk3K+LR2q9w1iQOlWdVUGrQd5RloNKciBIyt/dNMx4mRKZwTlY
# LQNad9ZL9zDG6WNCzMqtfTxrgWbU6E6lgbwxOIh6+3rCZafAk3qTJE4lDU1J9iQ8
# x1dDOW39puptJ0uhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMjAwNjE4MTk0NTUwWjAjBgkqhkiG9w0BCQQx
# FgQUCoOOTAls62hePsXrGM3hngoGQeEwDQYJKoZIhvcNAQEBBQAEggEAUybWcOal
# qPOTc83QG+k9Fa5k8HHRDOy7qA7Cmuujq/BucQwlPyt1wVOcOahZePVqgvWvC/y3
# QOkgqFrvVGf8EJZOB9zR4Ykks581NLwNtxgyByKhc7uZxk0IxUCHPJ3l6SOUz+xq
# U+zGV6QXsm+QjyO5ANqC6AdpDi0cg4hp9Wd/6tnHiK8oV1k9/xwVhphjSx6+2Esw
# I4VWuPjb5gNB1p7GiGDQhRl8qM6WQdSLp7W9+rEfa78Kl+fwyI34jobGr7vm3fVb
# wokYSiLGkhlmIB/4ZCU1eb1o+CdmrbfGtwye16+bFrez05ioVBcgTPBeGOlMFmyt
# lBFmCHBuHNyjHA==
# SIG # End signature block
