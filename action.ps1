#!/usr/bin/env pwsh

$ErrorActionPreference = "STOP"

. ./lib/ActionsCore.ps1

## Pull in some inputs
$gist_token     = Get-ActionInput gist_token -Required
$repo_full_name = Get-ActionInput repo_full_name
$workflow_name  = Get-ActionInput workflow_name
$version_key    = Get-ActionInput version_key
$skip_bump      = 'TRUE' -ieq (Get-ActionInput skip_bump)
$set_env        = 'TRUE' -ieq (Get-ActionInput set_env)


if (-not $repo_name) {
    $repo_full_name = $env:GITHUB_REPOSITORY
}
if (-not $workflow_name) {
    $workflow_name = $env:GITHUB_WORKFLOW
}

($repo_owner, $repo_name) = $repo_full_name -split '/'

Write-ActionInfo "Resolved Repository..........: [$repo_full_name]"
Write-ActionInfo "Resolved Repository Owner....: [$repo_owner]"
Write-ActionInfo "Resolved Repository Name.....: [$repo_name]"
Write-ActionInfo "Resolved Workflow............: [$workflow_name]"

$stateGistName = "GITHUB_BUILDNUM_METADATA:$repo_name"
Write-ActionInfo "Resolved State Gist Name.....: [$stateGistName]"

$gistsApiUrl = "https://api.github.com/gists"
$apiHeaders = @{
    Accept        = "application/vnd.github.v2+json"
    Authorization = "token $gist_token"
}

$stateGistBanner = @"
/* THIS FILE IS AUTO-GENERATED AND MANAGED BY GITHUB ACTIONS. MANUAL MODIFICATIONS
** CAN BREAK THINGS IF YOU DO NOT KNOW WHAT YOU ARE DOING! *YOU* HAVE BEEN WARNED!
*/
"@

class WorkflowBuildNum {
    [int]$build_num = 0
    [System.Collections.Generic.Dictionary[
        string, int]]$version_buildnums
}

class GlobalBuildNum {
    [int]$build_num = 0
    [System.Collections.Generic.Dictionary[
        string, WorkflowBuildNum]]$workflow_buildnums
}

try {
    ## Request all Gists for the current user
    $listGistsResp = Invoke-WebRequest -Headers $apiHeaders -Uri $gistsApiUrl

    ## Parse response content as JSON
    $listGists = $listGistsResp.Content | ConvertFrom-Json -AsHashtable
    Write-ActionInfo "Got [$($listGists.Count)] Gists for current account"

    ## Isolate the first Gist with a file matching the expected metadata name
    $stateGist = $listGists | Where-Object { $_.files.$stateGistName } | Select-Object -First 1
    $stateData = $null

    if ($stateGist) {
        Write-ActionInfo "Found the build number state!"
 
        $stateDataRawUrl = $stateGist.files.$stateGistName.raw_url
        Write-ActionInfo "Fetching state content from Raw Url"
 
        $stateDataRawResp = Invoke-WebRequest -Headers $apiHeaders -Uri $stateDataRawUrl
        $stateDataContent = $stateDataRawResp.Content
        $stateData = $stateDataContent | ConvertFrom-Json -AsHashtable -ErrorAction Continue
        if (-not $stateData) {
            Write-ActionWarning "State content seems to be either missing or unparsable JSON:"
            Write-ActionWarning "[$($stateGist.files.$stateGistName)]"
            Write-ActionWarning "[$stateDataContent]"
            Write-ActionWarning "RESETTING STATE DATA"
        }
        else {
            Write-Information "Got state data"
        }
    }

}
catch {
    Write-ActionError "Fatal Exception:  $($Error[0])"
    return
}






# $greeting = "$($salutation) $($audience)!"

# ## Persist the greeting in the environment for all subsequent steps
# Set-ActionVariable -Name build_greeting -Value greeting

# ## Expose the greeting as an output value of this step instance
# Set-ActionOutput -Name greeting -Value $greeting

# ## Write it out to the log for good measure
# Write-ActionInfo $greeting


