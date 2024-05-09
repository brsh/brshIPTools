function Test-iptNetConnectivity {
    <#
.SYNOPSIS
Runs Pings or TCP Port tests of/to/from various systems

.DESCRIPTION
Sometimes, network connectivity can have a problem. Maybe someone has the wrong subnet mask on a system. 
Maybe the router was misconfig'd for the route to a /27. Maybe there's just something weird going on and 
_some_ packets are dropped _sometimes_. It happens. This script can help localize some of those weird 
anomalies where something isn't quite right. 

At its most basic, this will ping a list of systems and/or IPs a set amount of times. Once tested, it'll 
return the total time taken, the maximum, average, and minimum milliseconds for those tests, and how many 
tests failed.

    "I'll ping these 2 servers 20 times."

    SourceName       SourceIP         Tests  Fails     RunTimeMS        MaxMS        AvgMS        MinMS
    ----------       --------         -----  -----     ---------        -----        -----        -----
    MyServer01       192.168.1.61        40      2     16,872.33    10,013.22     1,680.77         1.89

A little more complexly, it will test TCP ports across that list. 

    "I'll connect to RDP on these 2 servers 20 times."

    SourceName       SourceIP         Port   Tests  Fails     RunTimeMS        MaxMS        AvgMS        MinMS
    ----------       --------         ----   -----  -----     ---------        -----        -----        -----
    MyServer01       192.168.1.61     3389      40      8     16,872.33    10,013.22     1,680.77         1.89

It's strength comes once you use the -EnableRemoteTests switch, at which point it will ask the list of 
systems to perform those tests.

    "Hey 25 systems, please ping these 25 systems 20 times, I'll wait."
    
    SourceName       SourceIP         Port    Tests  Fails     RunTimeMS        MaxMS        AvgMS        MinMS
    ----------       --------         ----    -----  -----     ---------        -----        -----        -----
    Myserver01       192.168.1.25        0      625      0      4,519.53       322.43        87.44        15.90
    Myserver02       192.168.1.26        0      625      0      5,295.77       303.26        92.68        20.45
    Urserver03       192.168.2.23        0      625      0      8,650.25       383.19       197.51        19.12
    Urserver04       192.168.2.25        0      625      0      9,610.86       373.24       204.61        21.24
    ...

That's right - it will not only test connectivity from here to there (and there, and there...), it'll ask 
each server to test that same connectivity.

The number of ping/connection attempts can be changed, but it defaults to 20.

The destination(s) can also be set, in case you want to see if these systems can talk to those, rather than 
can everyone can talk to everyone.

One thing to be aware of: this function can generate a lot of traffic and take a lot of time. Let's take an example:
- Number of source systems: 20
- Number of destination systems: 20
- Number of tests: 20
= 20 source * 20 destinations * 20 tests = 8000 pings

Sure, it's just pings, but it grows quickly. And if any of those destinations time out, the wait adds to the time.

It returns _several_ objects.

The default is just a high-level summary of the tests. But, with the AllResults property, you can break out a
broader summary, showing general results of each source to each destination.

    SourceName       SourceIP         DestinationName                          DestinationIP     Tests  Fails   DNSLookupMS    TimeTakenMS
    ----------       --------         ---------------                          -------------     -----  -----   -----------    -----------
    Myserver01       192.168.1.25     Myserver02.dnsresult.com                 192.168.1.26         25      0          8.66         291.07
    Myserver01       192.168.1.25     Urserver03.dnsresult.com                 192.168.2.23         25      0          0.93         243.31
    ...
    Myserver02       192.168.1.26     Myserver01.dnsresult.com                 192.168.1.25         25      0         10.45         279.13
    Myserver02       192.168.1.26     Urserver03.dnsresult.com                 192.168.2.23         25      0          1.02         303.26
    ...

And the AllResults property has an EachResult property that includes each test run. That could be a lot of result; 
just warning you. I during development, I had 100 source (and destination) servers with 100 tests. That's 
1,000,000 pings. Took almost 20 minutes cuz of the timeouts. I do _not_ change the throttle limit on Invoke-Command, 
so that's 32 sets of source systems at a time.

    SourceName       SourceIP         DestinationName                          DestinationIP     RoundTripTime Response
    ----------       --------         ---------------                          -------------     ------------- --------
    PIT-REPORTDB-01  192.168.1.25     Myserver02.dnsresult.com                 192.168.1.26               9.00 Success
    PIT-REPORTDB-01  192.168.1.25     Myserver02.dnsresult.com                 192.168.1.26               9.00 Success
    ...

Please note: I do some DNS tests - name and address lookups _before_ any other processing. Part of that is to send 
_names_ to Invoke-Command rather than IP addresses. The other reason for that is to send IP Addresses to the remote 
systems. The remote system will also do DNS lookups (which can be disabled), but in the event of problems connecting 
to a DNS server (you are testing network connection problems, aren't you?), the remote system gets an IP Address and
tests an IP Address. If name resolution is left enabled, the AllResults object will include how long it took, but the
actual connection test doesn't depend on DNS.

.PARAMETER ComputerName
An array of systems or IP Addresses that will be the source systems (and maybe the destinations too). This is required.

.PARAMETER Destination
An array of systems or IP Addresses that will be the destination systems. This is optional, otherwise, it'll default to the array in the ComputerName switch.

.PARAMETER Port
Specify a port number if you want to try a port connection; otherwise the default is a plain old ping.

.PARAMETER TimeOutMS
Sets the wait for timeout time (milliseconds). Defaults to 5000ms

.PARAMETER EnableRemoteTests
Leverage WinRM and invoke-command to run the pings _from_ the source systems. It does require WinRM to work, with all the requirements thereof. Default is local only.

.PARAMETER DisableNameResolution
Disables Name Resolution during the actual connection tests. The default is DNS enabled (which can slow the tests down, depending).

.PARAMETER TestCount
How many times should the connection be tested. Handy if the problem is intermittent. Default is 20.

.PARAMETER Credential
Self-explanatory for WinRM connections, if needed. Default is empty, or "use my current user".

.EXAMPLE
Test-iptNetConnectivity -ComputerName 'myserver', 'yourserver'

Has the local server ping "myserver" and "yourserver" 20 times. Very boring.

.EXAMPLE
Test-iptNetConnectivity -ComputerName 'myserver', 'yourserver' -Port 3389

Has the local server test the RDP port of "myserver" and "yourserver" 20 times. Also very boring.

.EXAMPLE
Test-iptNetConnectivity -ComputerName 'myserver', 'yourserver' -EnableRemoteTests

Now we're getting interesting... It has "myserver AND "yourserver" ping each other (and themelves) 20 times (that's 80 tests).

.EXAMPLE
Test-iptNetConnectivity -ComputerName 'myserver', 'yourserver' -EnableRemoteTests -Destination 'theirserver', 'thatotherone'

And even more interesting: It has "myserver AND "yourserver" ping 'theirserver' and 'thatotherone' 20 times (again, that's 80 tests).

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Host', 'HostName', 'System', 'Server', 'Computer', 'MachineName', 'IP', 'IPAddress', 'Source')]
        [string[]] $ComputerName, 
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]] $Destination, 
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0, 65535)]
        [int] $Port = 0,
        [int] $TimeOutMS = 5000,
        [switch] $EnableRemoteTests = $false,
        [switch] $DisableNameResolution = $false,
        [Alias('Count')]
        [int] $TestCount = 20,
        [pscredential] $Credential
    )
    [datetime] $StartTime = Get-Date
    Write-Verbose "Origin : Startup: $(($StartTime).ToString('yyyy-MM-dd_HH:mm:sst'))"
    [bool] $SeparateSourceAndDestination = $false
    If ($PSBoundParameters.ContainsKey('Destination')) {
        $SeparateSourceAndDestination = $true
    } 

    function Test-TheConnection {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
            [Alias('Host', 'HostName', 'System', 'Server', 'Computer', 'MachineName', 'IP', 'IPAddress')]
            [string[]] $ComputerName, 
            [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateRange(0, 65535)]
            [int] $Port = 0,
            [Parameter(Position = 2)]
            [int] $TimeOutMS = 5000,
            [Parameter(Position = 3)]
            [switch] $DisableNameResolution = $false,
            [Parameter(Position = 4)]
            [Alias('Count')]
            [int] $TestCount = 20,
            [Parameter(Position = 5)]
            $Verbosity
        )
        $stopwatch = [system.diagnostics.stopwatch]::StartNew()
        [string] $RunningOn = $env:COMPUTERNAME

        $VerboseOld = $VerbosePreference
        $VerbosePreference = $Verbosity

        if (-not $IsLinux) {
            try {
                Write-Verbose "$RunningOn : Importing NetTCPIP Module..."
                Import-Module NetTCPIP -ErrorAction Stop -Verbose:$false 4>$null
            }
            catch {
                Write-Verbose "$RunningOn :   Fail: $($_.Exception.InnerException)"
            }

            try {
                Write-Verbose "$RunningOn : Importing NetConnection Module..."
                Import-Module NetConnection -ErrorAction Stop -Verbose:$false 4>$null
            }
            catch {
                Write-Verbose "$RunningOn :   Fail: $($_.Exception.InnerException)"
            }
            try {
                Write-Verbose "$RunningOn : Importing NetAdapter Module..."
                Import-Module NetAdapter -ErrorAction Stop -Verbose:$false 4>$null
            }
            catch {
                Write-Verbose "$RunningOn :   Fail: $($_.Exception.InnerException)"
            }
    
            if (-not $DisableNameResolution) {
                try {
                    Write-Verbose "$RunningOn : Importing DnsClient Module..."
                    Import-Module DnsClient -ErrorAction Stop -Verbose:$false 4>$null
                }
                catch {
                    Write-Verbose "$RunningOn :   Fail: $($_.Exception.InnerException)"
                }
            }
        }

        [string] $RunningOnIP = if ($IsLinux) {
        ([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | 
            Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } | 
            Select-Object -ExpandProperty UnicastAddress | 
            Select-Object -ExpandProperty Address | Where-Object IsIPv6LinkLocal -EQ $false).IPAddressToString
        }
        else {
        ((Get-NetIPConfiguration -ErrorAction SilentlyContinue -Verbose:$false | 
                Where-Object { $null -ne $_.IPv4DefaultGateway -and $_.NetAdapter.status -ne "Disconnected" }).IPv4Address | Where-Object { -not $_.SkipAsSource }).IPAddress
        }
        $OverallResult = [ordered] @{
            PSTypeName = 'brsh.iptHROver'
            SourceName = $RunningOn
            SourceIP   = $RunningOnIP
            Port       = $Port
            CountTests = 0
            CountFails = 0
            RunTimeMS  = -1
        }
        $AllResults = @()

        foreach ($Computer in $ComputerName) {
            Write-Verbose "$RunningOn : Testing Connection To: $Computer"
            [timespan] $dnscommandTime = 0
            $DNSResult = if ($DisableNameResolution) { 
                Write-Verbose "$RunningOn : Name Resolution is disabled. Will not query DNS."
                'NameResDisabled'
            }
            else { 
                try {
                    Write-Verbose "$RunningOn : Name Resolution is enabled. Trying to query DNS."
                    #$dnscommandTime = Measure-Command { Resolve-DnsName -Verbose:$false -Name $Computer -Type PTR -ErrorAction Stop -OutVariable namei }
                    #$namei.NameHost
                    #[System.Net.IPHostEntry] $namei
                    $dnscommandTime = Measure-Command { $namei = [System.Net.DNS]::GetHostByAddress($Computer) }
                    $namei.HostName
                    Write-Verbose "$RunningOn :   Name Resolution result: $($namei.HostName) : $($dnscommandTime.TotalMilliseconds)ms"
                }
                catch {
                    Write-Verbose "$RunningOn :   Name Resolution failed. $($_.Exception.InnerException)"
                    'NameResolutionFailed'
                }            
            }
            $ComputerResults = [ordered] @{
                PSTypeName      = 'brsh.iptHRAll'
                SourceName      = $RunningOn
                SourceIP        = $RunningOnIP
                DestinationName = $DNSResult
                DestinationIP   = $Computer
                DNSLookupMS     = $dnscommandTime.TotalMilliseconds
                Port            = $Port
            }
            [int] $fc = 0
            [int] $tc = 0
            $testResults = @()
            try {
                # The first ping sometimes goes slow??? Just throwing one away...
                $null = [System.Net.Networkinformation.Ping] $ping = New-Object System.Net.Networkinformation.Ping
                $null = $ping.Send($Computer, $TimeOutMS)
            }
            catch {}
            [timespan] $TestTime = Measure-Command { 
                1..$testcount | ForEach-Object { 
                    try {
                        $tc += 1
                        $hash = [ordered] @{
                            PSTypeName      = 'brsh.iptHREach'
                            SourceName      = $RunningOn
                            SourceIP        = $RunningOnIP
                            DestinationName = $DNSResult
                            DestinationIP   = $Computer
                            Port            = $Port
                            RoundtripTime   = -1
                            Response        = 'Unknown'
                        }
                        if ($Port -eq 0) {
                            Write-Verbose "$RunningOn : No Port - pinging $Computer"
                            $hash.Action = 'Ping'
                            $hash.PSTypeName = if ($DisableNameResolution) {
                                'brsh.iptHREachPingnDNS'
                            }
                            else {
                                'brsh.iptHREachPing'
                            }
                            try {
                                [System.Net.Networkinformation.Ping] $ping = New-Object System.Net.Networkinformation.Ping
                                $result = $ping.Send($Computer, $TimeOutMS)

                                $hash.DestinationIP = $result.Address
                                $hash.RoundtripTime = $result.RoundtripTime
                                $hash.Response = $result.Status

                                Write-Verbose "$RunningOn :   pinging $Computer ... $($result.Status) : $($result.RoundtripTime)ms"
                            }
                            catch {
                                Write-Verbose "$RunningOn :   pinging $Computer ... Error! $($_.Exception.Message)"
                                $hash.Response = $_.Exception.Message
                            }
                            if ($result.Status -ne 'Success') {
                                $fc += 1
                                $hash.DestinationIP = $Computer
                            }
                        }
                        else {
                            # Create TCP Client
                            # in the other file temporarily
                            Write-Verbose "$RunningOn : Port $Port - testing TCP Connection to $Computer"
                            $hash.Action = 'TCPTest'
                            $hash.PSTypeName = if ($DisableNameResolution) {
                                'brsh.iptHREachTCPnDNS'
                            }
                            else {
                                'brsh.iptHREachTCP'
                            }
                            
                            [System.Net.Sockets.TcpClient] $tcpClient = New-Object System.Net.Sockets.TcpClient
                            # Tell TCP Client to connect to machine on Port
                            [timespan] $tcptime = Measure-Command {
                                $result = 
                                Try {
                                    $iar = $tcpClient.BeginConnect($Computer, $Port, $null, $null)

                                    # Set the wait time - Note this only affects transmission, 
                                    #    connect and close don't have timeouts
                                    $wait = $iar.AsyncWaitHandle.WaitOne($TimeOutMS, $false)
                                    # Check to see if the connection is done
                                    if (-not $wait) {
                                        # Close the connection and report timeout
                                        [void] $tcpClient.Close()
                                        'TimeOut'
                                    }
                                    else {
                                        # Close the connection and report the error if there is one
                                        [void] $tcpClient.EndConnect($iar)
                                        [void] $tcpClient.Close()
                                        'Open'
                                    }
                                }
                                Catch {
                                    if ($_.Exception.Message -match 'actively refused') { 'Refused' } else { 'Error' }
                                    Write-Verbose $_.Exception.Message
                                    $_.Exception.Message
                                }
                            }

                            $hash.Response = $result
                            $hash.RoundtripTime = $tcptime.TotalMilliseconds

                            Write-Verbose "$RunningOn :   Port $Port ... $($result)"
                            if ($result -ne 'Open') {
                                $fc += 1
                            }
                        }
                    }
                    catch {
                        Write-Verbose "$RunningOn : Something went wrong testing connection..."
                        Write-Verbose "$RunningOn :  $($_.Exception.Message)"
                        $hash.Response = $_.Exception.Message
                    }
                    #$testResults += New-Object -TypeName PSCustomObject -Property $hash
                    $testResults += [pscustomobject] $hash
                }
            } 
            if ($DisableNameResolution) {
                $ComputerResults.PSTypeName = 'brsh.iptHRAllnDNS'
            }
            $ComputerResults.TimeTakenMS = $TestTime.TotalMilliseconds
            $ComputerResults.CountTests = $tc 
            $ComputerResults.CountFails = $fc 
            $ComputerResults.EachResult = $testResults
            $OverallResult.CountTests += $tc
            $OverallResult.CountFails += $fc
            $OverallResult."$Computer" = [math]::round($TestTime.TotalMilliseconds, 2)
            $AllResults += [pscustomobject] $ComputerResults
        }
        $OverallResult.AllResults = $AllResults
        $VerbosePreference = $VerboseOld
        [void] $stopwatch.Stop
        $OverallResult.RunTimeMS = $stopwatch.Elapsed.TotalMilliseconds
        [pscustomobject] $OverallResult
    }

    if (-not $SeparateSourceAndDestination) { $Destination = $ComputerName }

    # We need valid _names_ for Invoke-Command
    [string[]] $ValidSource = $ComputerName | ForEach-Object {
        $tempName = $_
        $resultName = try {
            if ([bool] ([ipaddress] $tempName).IPAddressToString -eq $tempName) {
                try {
                    [system.net.dns]::GetHostByAddress($tempName).HostName
                }
                catch {
                    Write-Verbose "Origin : DNSLookup Name for $tempName : $($_.Exception.Message)"
                }
            }
        }
        catch {
            try {
                if ([system.net.dns]::GetHostByName($tempName)) { $tempName }
            }
            catch { 
                Write-Verbose "Origin : DNSLookup Validating IP for $tempName : $($_.Exception.Message)"
            }  
        }
        if ($null -ne $resultName) { $resultName }
    }

    # We want valid IPs for the actual tests
    [string[]] $IPAddress = $Destination | ForEach-Object {
        $tempName = $_
        $resultName = try {
            if ([bool] ([ipaddress] $tempName).IPAddressToString -eq $tempName) {
                $tempName
            }
        }
        catch {
            try {
                [system.net.dns]::GetHostByName($tempName).AddressList[0].IPAddressToString
            }
            catch { 
                Write-Verbose "Origin : DNS Lookup Error for $tempName : $($_.Exception.Message)"
            }  
        }
        if ($null -ne $resultName) { $resultName }
    }

    if ($EnableRemoteTests) {
        $InvokeCLI = @{
            ArgumentList     = $IPAddress, $Port, $TimeOutMS, $DisableNameResolution, $TestCount, $VerbosePreference
            ComputerName     = $ValidSource
            HideComputerName = $true
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $InvokeCLI.Credential = $Credential
        }

        Invoke-Command -ScriptBlock ${function:Test-TheConnection} @InvokeCLI -ErrorAction Continue -ErrorVariable InvokeCommandErrors # | Select-Object -Property * -ExcludeProperty RunspaceId
    }
    else {
        $InvokeCLI = @{
            ComputerName          = $IPAddress
            Port                  = $Port
            TimeOutMS             = $TimeOutMS
            DisableNameResolution = $DisableNameResolution
            TestCount             = $TestCount
            Verbosity             = $VerbosePreference
        }
        Test-TheConnection @InvokeCLI
    }

    [datetime] $EndTime = Get-Date
    Write-Verbose "Origin : Complete: $(($EndTime).ToString('yyyy-MM-dd_HH:mm:sst'))"
    Write-Verbose "Origin :   Total RunTime: $(([timespan] ($EndTime - $StartTime)).ToString())"
}