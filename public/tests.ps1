function Test-iptValidIPAddress {
    <#
    .SYNOPSIS
        Tests for valid IP Address

    .DESCRIPTION
        Validates that the input text is in the correct format of an IP Address. Tests both IPv4 and IPv6. Can test if the ip is alive by using the -IsAlive switch.

    .PARAMETER  Text
        The text you expect to be IP Address

    .PARAMETER  IsAlive
        Test that the ip is online and accessible via ICMP

    .EXAMPLE
        PS C:\> Test-ValidIPv4Address 192.178.1.1

        Returns true because this is a valid IP Address in form
    #>
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Text,
        [Parameter(Position = 1, Mandatory = $false)]
        [Switch] $IsAlive = $false
    )
    try {
        if ($Text -eq [System.Net.IPAddress]::Parse($Text)) {
            if ($IsAlive) {
                Test-Connection $Text -Count 1 -EA Stop -Quiet
            } else {
                $true
            }
        }
    } Catch {
        $false
    }
}

function Test-iptValidMACAddress {
    <#
    .SYNOPSIS
        Returns true if valid MAC Address

    .DESCRIPTION
        Validates that the input text is in the correct format of a MAC Address.

    .PARAMETER  Text
        The text you expect to be a MAC Address

    .EXAMPLE
        PS C:\> Test-ValidMACAddress 82-E4-52-1c-C1-39

        Returns true because this is a valid MAC Address
    #>
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Text
    )
    $Text -match "^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$"
}
