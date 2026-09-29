<#
Local, newline-delimited JSON client for the project's existing Godot bridge.
This script never adopts or stops the user's running game/editor.
Examples:
  . ./tests/godot_bridge.ps1
  Invoke-GodotBridge -Port 19091 -Command get_performance
  Save-GodotScreenshot -Port 19091 -Path ./docs/verification/battle.png
#>
function Invoke-GodotBridge {
    [CmdletBinding()]
    param(
        [int] $Port = 19091,
        [Parameter(Mandatory)] [string] $Command,
        [hashtable] $Parameters = @{},
        [int] $TimeoutMilliseconds = 30000
    )
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $client.Connect('127.0.0.1', $Port)
        $stream = $client.GetStream()
        $stream.ReadTimeout = $TimeoutMilliseconds
        $stream.WriteTimeout = $TimeoutMilliseconds
        $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false), 8192, $true)
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.UTF8Encoding]::new($false), $false, 8192, $true)
        $request = @{ id = [guid]::NewGuid().ToString(); command = $Command; params = $Parameters }
        $writer.WriteLine(($request | ConvertTo-Json -Depth 50 -Compress))
        $writer.Flush()
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { throw 'Godot bridge closed without a response.' }
        $result = $line | ConvertFrom-Json
        if ($result.error) { throw "Godot bridge ${Command}: $($result.error)" }
        return $result
    }
    finally { $client.Dispose() }
}

function Save-GodotScreenshot {
    [CmdletBinding()]
    param(
        [int] $Port = 19091,
        [Parameter(Mandatory)] [string] $Path
    )
    $result = Invoke-GodotBridge -Port $Port -Command screenshot
    $absolute = [System.IO.Path]::GetFullPath($Path)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($absolute)) | Out-Null
    [System.IO.File]::WriteAllBytes($absolute, [Convert]::FromBase64String($result.data))
    return [pscustomobject]@{ path = $absolute; width = $result.width; height = $result.height }
}
