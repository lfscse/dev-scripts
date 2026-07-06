# dev-scripts

## Windows

### Create script Aliases 

Add in Powershell profile:

```ps1
function which-prs-review {
  $scriptUrl = "https://raw.githubusercontent.com/lfscse/dev-scripts/main/windows/Get-PendingPRs.ps1"
  $script = Invoke-RestMethod $scriptUrl
  & ([scriptblock]::Create($script)) -TargetUser <GitHubUsername>
}

function which-comments-to-me {
  $scriptUrl = "https://raw.githubusercontent.com/lfscse/dev-scripts/main/windows/Get-CommentsToMe.ps1"
  $script = Invoke-RestMethod $scriptUrl
  & ([scriptblock]::Create($script)) -TargetUser <GitHubUsername>
}
```

### Get PRs pending for review

```powershell
& ([scriptblock]::Create((Invoke-RestMethod "https://raw.githubusercontent.com/lfscse/dev-scripts/main/windows/Get-PendingPRs.ps1"))) -TargetUser <GitHubUsername>
```

### Get comments to me

```powershell
& ([scriptblock]::Create((Invoke-RestMethod "https://raw.githubusercontent.com/lfscse/dev-scripts/main/windows/Get-CommentsToMe.ps1"))) -TargetUser <GitHubUsername>
```
