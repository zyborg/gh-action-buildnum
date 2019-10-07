# gh-action-buildnum
GitHub Action to implement build numbers in Workflows.

---

This Action can be used to generate increasing build numbers across a number
of _scopes_ that can be useful for tracking purposes and defining complete
version strings for product releases.

This Action uses a Gist to store persistent state between invocations.
The OAuth token that is normally made available to GitHub Workflows
and its Actions (`GITHUB_TOKEN`) does not provide any access to Gists
(read or write) therefore this Action requires a separate parameter
(`gist_token`) for an OAuth or PAT token which will be used to read
and write the _state Gist_.
Note, it is not necessary that the Gist token be associated
with the repository in which the Workflow that consumes this Action is
targeting.  In this way, a separate GitHub account can actually be used
to store the state.

> NOTE: this action does include some debug messaging so if you need
> to troubleshoot its behavior, you can enable debug logging using
> the `ACTIONS_STEP_DEBUG` secrets variable.  You can find more info
> [here](https://help.github.com/en/articles/development-tools-for-github-actions#set-a-debug-message-debug).

## Scopes

When this action runs it generates several build numbers that are relative
to a number of scopes.

### Repository or _Global_ Scope

This scope tracks build numbers across *all* Workflows of a given GitHub
repository which make use of this Action.  The state of this build number
is stored as a top-level value in the state Gist.

The resolved value of the Global Scope is made available as an output
named `global_build_number` and optionally as an environment variable
named `BUILDNUM_FOR_GLOBAL`.

### Workflow Scope

This scope tracks build numbers across every invocation of single Workflow.
The state of this build number is stored in the state Gist indexed by the
current Workflow name.

The resolved value of the Workflow Scope is made available as an output
named `workflow_build_number` and optionally as an environment variable
named `BUILDNUM_FOR_WORKFLOW`.

### Version Scope

This scope tracks build numbers across every invocation of single Workflow
for a given, unique version _key_.  This scope is optional and will only
be resolved if the input parameter of `version_key` is provided with a
non-null/non-empty value.
The state of this build number is stored in the state Gist indexed by the
current Workflow name and the given version key.

The resolved value of the Version Scope is made available as an output
named `version_build_number` and optionally as an environment variable
named `BUILDNUM_FOR_VERSION`.

## Inputs

This Action defines the following formal inputs.

| Name | Req | Description |
|-|-|-|
| **`gist_token`**     | true  | GitHub OAuth/PAT token to be used for accessing Gist to store builder number state. The integrated GITHUB_TOKEN that is normally accessible during a Workflow does not include read/write permissions to associated Gists, therefore a separate token is needed.  You can control which account is used to actually store the state by generating a token associated with the target account. 
| **`repo_full_name`** | false | The name of the current repository, in `<OWNER>/<REPO-NAME>` format. This input is optional and is only used to override the default value which is pulled in from the running Workflow context.  This value is used to compute a unique identifier for the Gist that will be used to store state for current and subsequent build numbers. Default is `$env:GITHUB_REPOSITORY`.
| **`workflow_name`**  | false | The name of the workflow to identify the build number with. This input is optional and is only used to override the default value which is pulled in from the running Workflow context.  This value is used to compute a unique identifier for the Gist that will be used to store state for current and subsequent build numbers. Default is `$env:GITHUB_WORKFLOW`.
| **`version_key`**    | false | A unique identifer used to calculate a version-specific build number.
| **`skip_bump`**      | false | If true, this will skip bumping up the build numbers, and only pulls in the last values stored in the state Gist.
| **`set_env`**        | false | If true, this will export the resolved version numbers as environment variables for the current and future steps.

## Outputs

This Action defines the following formal outputs.

| Name | Description |
|-|-|
| **`global_build_number`**   | Resolved build number for the repository or `global` scope.
| **`workflow_build_number`** | Resolved build number for the Workflow scope.
| **`version_build_number`**  | Resolved build number for the Version scope.

## Environment Variables

If the `set_env` input is true, then the following environment variables will be defined.

| Name | Description |
|-|-|
| **`BUILDNUM_FOR_GLOBAL`**   | Resolved build number for the repository or `global` scope.
| **`BUILDNUM_FOR_WORKFLOW`** | Resolved build number for the Workflow scope.
| **`BUILDNUM_FOR_VERSION`**  | Resolved build number for the Version scope.
