param(
    [int]$Port = 19102,
    [string]$Command = "screenshot",
    [string]$OutPath = "",
    [string]$EvalCode = "",
    [string]$ParamsJson = ""
)
$client = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $Port)
$stream = $client.GetStream()
$payload = @{ id = 1; command = $Command; params = @{} }
if ($Command -eq "eval") { $payload.params = @{ code = $EvalCode } }
if ($ParamsJson) { $payload.params = $ParamsJson | ConvertFrom-Json }
$bytes = [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress -Depth 8) + "`n")
$stream.Write($bytes, 0, $bytes.Length)
$reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
$line = $reader.ReadLine()
$reply = $line | ConvertFrom-Json
if ($Command -eq "screenshot" -and $OutPath -and $reply.data) {
    [IO.File]::WriteAllBytes($OutPath, [Convert]::FromBase64String($reply.data))
    [pscustomobject]@{ success = $reply.success; width = $reply.width; height = $reply.height; path = $OutPath }
} else {
    $reply | Select-Object * -ExcludeProperty data
}
$reader.Dispose()
$stream.Dispose()
$client.Dispose()
