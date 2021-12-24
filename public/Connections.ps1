function Test-iptConnection {
    <#
    .SYNOPSIS
    A Test-NetConnection Wrapper

    .DESCRIPTION
    A simple Test-NetConnection Wrapper that "simplifies" and expands some of the features.

    I wanted a function that did some extra stuff I was always doing with T-NC so I wouldn't
    have to remember the select-object statements, plus had the formatting features I like
    (like Green and Red for Alive or Not). I also liked linking the services entries for port
    numbers - and having the DNS lookup right there (PTR baybee!).

    (C'mon, MS - give us Test-NetConnection on Linux!!!)

    .PARAMETER Computer
    The computer(s) or IP to test

    .PARAMETER Port
    The port(s) to also test (not required)

    .EXAMPLE
    Test-iptConnection -Computer bilbo.baggins.hob

    Tests if bilbo.baggins.hob is alive

    ShortName              IP               Alive  Host
    ---------              --               -----  ----
    bilbo                  172.16.1.1       True   bilbo.baggins.hob

    .EXAMPLE
    Test-iptConnection -Computer 172.16.1.1

    Tests if 192.168.1.1 is alive

    ShortName              IP               Alive  Host
    ---------              --               -----  ----
    bilbo                  172.16.1.1       True   bilbo.baggins.hob

    .EXAMPLE
    Test-iptConnection -Computer bilbo.baggins.hob -Port 53

    Tests if bilbo.baggins.hob is alive also checks if port 53 is alive. Will try to get the ptr record too.

    ShortName              IP               Port   PortName               PortAlive PingAlive Host
    ---------              --               ----   --------               --------- --------- ----
    bilbo                  172.16.1.1       53     Domain                 False     True      bilbo.baggins.hob

    .EXAMPLE
    Test-iptConnection -Computer 172.16.1.1 -Port 53

    Tests if 192.168.1.1 is alive also checks if port 53 is alive. Will try to get the ptr record too.

    ShortName              IP               Port   PortName               PortAlive PingAlive Host
    ---------              --               ----   --------               --------- --------- ----
    bilbo                  172.16.1.1       53     Domain                 False     True      bilbo.baggins.hob

    .EXAMPLE
    Test-iptConnection 172.16.1.1, 172.16.1.2 -port 22, 53, 135

    ShortName              IP               Port   PortName               PortAlive PingAlive Host
    ---------              --               ----   --------               --------- --------- ----
    bilbo                  172.16.1.1       22     ssh                    False     True      bilbo.baggins.hob
    bilbo                  172.16.1.1       53     domain                 True      True      bilbo.baggins.hob
    bilbo                  172.16.1.1       135    epmap                  True      True      bilbo.baggins.hob
    frodo                  172.16.1.2       22     ssh                    True      True      frodo.baggins.hob
    frodo                  172.16.1.2       53     domain                 False     True      frodo.baggins.hob
    frodo                  172.16.1.2       135    epmap                  False     True      frodo.baggins.hob

    .EXAMPLE
    > '172.16.1.1', '172.16.1.2' | Test-iptConnection -port 22, 3389 | Sort-Object Port
    Quick test (not absolute, of course) if a box could be Linux (ssh) or Windows (rdp)

    ShortName              IP               Port   PortName               PortAlive Alive     Host
    ---------              --               ----   --------               --------- -----     ----
    bilbo                  172.16.1.1       22     ssh                    False     True      bilbo.baggins.hob
    frodo                  172.16.1.2       22     ssh                    True      True      frodo.baggins.hob
    bilbo                  172.16.1.1       3389   ms-wbt-server          True      True      bilbo.baggins.hob
    frodo                  172.16.1.2       3389   ms-wbt-server          False     True      frodo.baggins.hob
    #>
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Host', 'HostName', 'System')]
        [string[]] $Computer,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int[]] $Port
    )

    BEGIN {
        $OriginalProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = 'SilentlyContinue'
    }

    PROCESS {
        foreach ($Comp in $Computer) {
            if ($Port) {
                foreach ($item in $Port) {
                    Ping-It -Name $Comp -Port $item
                }
            } else {
                Ping-It -Name $Comp
            }
        }
    }

    END {
        $Global:ProgressPreference = $OriginalProgressPreference
    }
}
