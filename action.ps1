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

## We represent each scope as its own class to form a tree structure of nodes
## and this also gives us the ability to add more metadata fields in the future
class VersionBuildNum {
    [int]$build_num = 0
}

class WorkflowBuildNum {
    [int]$build_num = 0
    [System.Collections.Generic.Dictionary[
        string, int]]$version_buildnums =
            [System.Collections.Generic.Dictionary[string, VersionBuildNum]]::new()
}

class GlobalBuildNum {
    [int]$build_num = 0
    [System.Collections.Generic.Dictionary[
        string, WorkflowBuildNum]]$workflow_buildnums =
            [System.Collections.Generic.Dictionary[string, WorkflowBuildNum]]::new()
}

# # # try {

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

    ## Create initial global state data if it doesn't exist
    if (-not $stateData) {
        Write-ActionWarning "BuildNum state for Repo not found, INITIALIZING"
        $stateData = [GlobalBuildNum]::new()
    }

    ## Create initial state data for current workflow if it doesn't exist
    if (-not $stateData.workflow_buildnums.ContainsKey($workflow_name)) {
        Write-ActionDebug "BuildNum state for Workflow not found, initializing"
        $stateData.workflow_buildnums[$workflow_name] = [WorkflowBuildNum]::new()
    }

    ## Create initial state data for specified version key if it doesn't exist
    if ($version_key -and (-not $stateData.workflow_buildnums[
            $workflow_name].version_buildnums.ContainsKey($version_key))) {
        Write-ActionDebug "BuildNum state for Version not found, initializing"
        $stateData.workflow_buildnums[$workflow_name].version_buildnums[$version_key] =
            [VersionBuildNum]::new()
    }

    if (-not $stateGist) {
        Write-ActionInfo "Creating initial state Gist"
        $createGistResp = Invoke-WebRequest -Headers $apiHeaders -Uri $gistsApiUrl -Method Post -Body (@{
            public = $false
            files = @{
                $stateGistName = @{
                    content = @"
$stateGistBanner
$($stateData | ConvertTo-Json -Depth 10)
"@
                }
            }
        } | ConvertTo-Json)
        $createGist = $createGistResp.Content | ConvertFrom-Json -AsHashtable
        $stateGist = $createGist
    }

    Write-ActionDebug "Resolved starting state data:"
    Write-ActionDebug ($stateData | ConvertTo-Json -Depth 10)

    if (-not $skip_bump) {
        Write-ActionInfo "Bumping up version numbers"

        $stateData.build_num += 1;
        Write-Debug "New Global build_num = [$($stateData.build_num)]"

        $stateData.workflow_buildnums[$workflow_name].build_num += 1;
        Write-Debug "New Workflow build_num = [$($stateData.workflow_buildnums[$workflow_name].build_num)]"

        if ($version_key) {
            $stateData.workflow_buildnums[$workflow_name].version_buildnums[
                $version_key].build_num += 1
            Write-Debug "New Workflow build_num = [$($stateData.workflow_buildnums[$workflow_name].version_buildnums[
                $version_key].build_num)]"
        }

        Write-ActionDebug "Resolved updated state data:"
        Write-ActionDebug ($stateData | ConvertTo-Json -Depth 10)

        Write-ActionInfo "Updating state Gist"
        $patchGistUrl = "$gistsApiUrl/$($metadataGist.id)"
        $patchGistResp = Invoke-WebRequest -Headers $apiHeaders -Uri $patchGistUrl -ErrorAction Stop -Method Patch -Body (@{
            files = @{
                $metadataFilename = @{
                    content = @"
$stateGistBanner
$($stateData | ConvertTo-Json -Depth 10)
"@
                }
            }
        } | ConvertTo-Json)
    }

    Write-ActionDebug "Setting outputs"
    Set-ActionOutput global_build_number ($stateData.build_num)
    Set-ActionOutput workflow_build_number ($stateData.workflow_buildnums[
        $workflow_name].build_num)
    if ($version_key) {
        Set-ActionOutput version_build_number ($stateData.workflow_buildnums[
            $workflow_name].version_buildnums[$version_key].build_num)
    }

    if ($set_env) {
        Write-ActionDebug "Setting env vars"
        Set-ActionVariable BUILDNUM_FOR_GLOBAL ($stateData.build_num)
        Set-ActionVariable BUILDNUM_FOR_WORKFLOW ($stateData.workflow_buildnums[
            $workflow_name].build_num)
        if ($version_key) {
            Set-ActionVariable BUILDNUM_FOR_VERSION ($stateData.workflow_buildnums[
                $workflow_name].version_buildnums[$version_key].build_num)
        }
    }

# # # }
# # # catch {
# # #     Write-ActionError "Fatal Exception:  $($Error[0])"
# # #     exit
# # # }






# $greeting = "$($salutation) $($audience)!"

# ## Persist the greeting in the environment for all subsequent steps
# Set-ActionVariable -Name build_greeting -Value greeting

# ## Expose the greeting as an output value of this step instance
# Set-ActionOutput -Name greeting -Value $greeting

# ## Write it out to the log for good measure
# Write-ActionInfo $greeting


