param(
    [switch]$NoFrontend
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$RpcUrl = "http://127.0.0.1:8545"
$Governor = "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6"
$AnvilAccount = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
$AnvilKey = "0x" + "ac0974bec39a17e36ba4a6b4d238ff944" + "bacb478cbed5efcae784d7bf4f2ff80"

Set-Location $Root

function Test-Anvil {
    try {
        cast chain-id --rpc-url $RpcUrl | Out-Null
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-Anvil)) {
    Write-Host "Starting Local Anvil on chain 31337..."
    Start-Process `
        -FilePath "anvil" `
        -ArgumentList "--host", "127.0.0.1", "--port", "8545", "--chain-id", "31337" `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -RedirectStandardOutput "$Root\anvil.log" `
        -RedirectStandardError "$Root\anvil.err.log"

    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Anvil) { break }
    }
}

if (-not (Test-Anvil)) {
    throw "Anvil did not start on $RpcUrl"
}

Write-Host "Resetting Local Anvil state for a fresh classroom demo..."
cast rpc anvil_reset --rpc-url $RpcUrl | Out-Null

$code = cast code $Governor --rpc-url $RpcUrl
if ($code -eq "0x") {
    Write-Host "Deploying local contracts..."
    $env:PRIVATE_KEY = $AnvilKey
    try {
        forge script script/Deploy.s.sol:Deploy --rpc-url $RpcUrl --broadcast
    } finally {
        Remove-Item Env:\PRIVATE_KEY -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Local contracts already deployed."
}

Write-Host ""
Write-Host "MetaMask Local Anvil account:"
Write-Host "Address: $AnvilAccount"
Write-Host "Import the first default Anvil account in MetaMask if it is not already imported."
Write-Host ""
Write-Host "Network:"
Write-Host "Name: Local Anvil"
Write-Host "RPC:  $RpcUrl"
Write-Host "Chain ID: 31337"
Write-Host ""

if (-not $NoFrontend) {
    npm run frontend:dev
}
