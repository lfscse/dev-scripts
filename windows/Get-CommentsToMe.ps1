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

function Invoke-GhApiArray {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	$json = gh api --paginate --slurp $Path
	if ($LASTEXITCODE -ne 0) {
		throw "GitHub API request failed: $Path"
	}

	$pages = $json | ConvertFrom-Json
	$items = @()

	foreach ($page in $pages) {
		if ($null -eq $page) {
			continue
		}

		if ($page -is [System.Array]) {
			$items += $page
			continue
		}

		$items += ,$page
	}

	return $items
}

function Test-TargetsUser {
	param(
		[AllowNull()]
		[string]$Body,

		[Parameter(Mandatory = $true)]
		[string]$TargetUser
	)

	if ([string]::IsNullOrWhiteSpace($Body)) {
		return $false
	}

	$escapedTargetUser = [regex]::Escape($TargetUser)
	return $Body -match "(?i)(?<![A-Za-z0-9-])@$escapedTargetUser\b"
}

function Get-ReviewThreadId {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$Comment
	)

	if ($Comment.PSObject.Properties.Name -contains 'in_reply_to_id' -and $Comment.in_reply_to_id) {
		return [string]$Comment.in_reply_to_id
	}

	return [string]$Comment.id
}

function Test-CommentReaction {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[string]$TargetUser
	)

	$reactions = Invoke-GhApiArray -Path $Path
	return [bool]($reactions | Where-Object { $_.user.login -eq $TargetUser } | Select-Object -First 1)
}

$openPrs = Invoke-GhApiArray -Path 'repos/{owner}/{repo}/pulls?state=open&per_page=100'
$results = foreach ($pr in $openPrs) {
	$issueComments = @(Invoke-GhApiArray -Path "repos/{owner}/{repo}/issues/$($pr.number)/comments?per_page=100") |
		Sort-Object { [datetime]$_.created_at }

	$reviewComments = @(Invoke-GhApiArray -Path "repos/{owner}/{repo}/pulls/$($pr.number)/comments?per_page=100") |
		Sort-Object { [datetime]$_.created_at }

	foreach ($comment in $issueComments) {
		if ($comment.user.login -eq $TargetUser) { continue }
		if (-not (Test-TargetsUser -Body $comment.body -TargetUser $TargetUser)) { continue }

		$hasResponse = [bool]($issueComments | Where-Object {
			$_.user.login -eq $TargetUser -and [datetime]$_.created_at -gt [datetime]$comment.created_at
		} | Select-Object -First 1)

		if ($hasResponse) { continue }

		$hasReaction = Test-CommentReaction -Path "repos/{owner}/{repo}/issues/comments/$($comment.id)/reactions?per_page=100" -TargetUser $TargetUser
		if ($hasReaction) { continue }

		[PSCustomObject]@{
			'PR ID' = $pr.number
			Link    = $comment.html_url
		}
	}

	$reviewCommentsByThread = @{}
	foreach ($reviewComment in $reviewComments) {
		$threadId = Get-ReviewThreadId -Comment $reviewComment

		if (-not $reviewCommentsByThread.ContainsKey($threadId)) {
			$reviewCommentsByThread[$threadId] = @()
		}

		$reviewCommentsByThread[$threadId] += $reviewComment
	}

	foreach ($comment in $reviewComments) {
		if ($comment.user.login -eq $TargetUser) { continue }
		if (-not (Test-TargetsUser -Body $comment.body -TargetUser $TargetUser)) { continue }

		$threadId = Get-ReviewThreadId -Comment $comment
		$threadComments = $reviewCommentsByThread[$threadId]
		$hasResponse = [bool]($threadComments | Where-Object {
			$_.user.login -eq $TargetUser -and [datetime]$_.created_at -gt [datetime]$comment.created_at
		} | Select-Object -First 1)

		if ($hasResponse) { continue }

		$hasReaction = Test-CommentReaction -Path "repos/{owner}/{repo}/pulls/comments/$($comment.id)/reactions?per_page=100" -TargetUser $TargetUser
		if ($hasReaction) { continue }

		[PSCustomObject]@{
			'PR ID' = $pr.number
			Link    = $comment.html_url
		}
	}
}

if ($results) {
	$results | Sort-Object 'PR ID', Link | Format-Table -AutoSize
} else {
	Write-Host "No open PR comments found requiring your response." -ForegroundColor Green
}
