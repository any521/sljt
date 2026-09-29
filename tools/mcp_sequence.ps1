param([int]$Port = 19102, [string]$EvalCode, [string]$OutPath, [int]$DelayMs = 70)
$client = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $Port)
$stream = $client.GetStream()
$reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
function Send-GameCommand([int]$Id, [string]$Name, $Params) {
    $payload = @{ id = $Id; command = $Name; params = $Params }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress -Depth 8) + "`n")
    $stream.Write($bytes, 0, $bytes.Length)
    return ($reader.ReadLine() | ConvertFrom-Json)
}
$null = Send-GameCommand 1 "eval" @{ code = $EvalCode }
Start-Sleep -Milliseconds $DelayMs
$shot = Send-GameCommand 2 "screenshot" @{}
[IO.File]::WriteAllBytes($OutPath, [Convert]::FromBase64String($shot.data))
[pscustomobject]@{ success = $shot.success; width = $shot.width; height = $shot.height; path = $OutPath; delay_ms = $DelayMs }
$reader.Dispose(); $stream.Dispose(); $client.Dispose()
