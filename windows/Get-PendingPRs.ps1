[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$TargetUser
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI 'gh' is not installed or not available on PATH."
}

$insideGitRepo = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $insideGitRepo -ne "true") {
  throw "Current directory is not a Git repository."
}

# Fetch open PRs and convert JSON into a PowerShell object
$PrList = gh pr list --state OPEN --json number,title,author,reviews | ConvertFrom-Json

# Filter and process data
$Result = foreach ($pr in $PrList) {
  # Skip PRs authored by the target user
  if ($pr.author.login -eq $TargetUser) { continue }

  # Skip if the target user has already approved it
  $alreadyApproved = $pr.reviews | Where-Object { $_.author.login -eq $TargetUser -and $_.state -eq "APPROVED" }
  if ($alreadyApproved) { continue }

  # Gather a list of users who HAVE approved it
  $approvedBy = ($pr.reviews | Where-Object { $_.state -eq "APPROVED" } | ForEach-Object { $_.author.login }) -join ", "

  # Create a clean object for the final table
  [PSCustomObject]@{
    ID          = $pr.number
    Title       = $pr.title
    Author      = $pr.author.login
    "Approved By" = $approvedBy
  }
}

# Display the results in a clean, auto-sized table
if ($Result) {
  $Result | Format-Table -AutoSize
} else {
  Write-Host "No open PRs found requiring your review." -ForegroundColor Green
}
