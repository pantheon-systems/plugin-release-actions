# plugin-release-actions
GitHub actions for standardized releases for WP plugins and Drupal modules

## Actions
### Build Tag and Release
This action will build a tag and draft a release for a plugin or module.

To use this action, create a workflow file in your plugin or module repository (e.g. `.github/workflows/release.yml`) with the following contents:

```yaml
name: Build, Tag, and Release
on:
  push:
    branches:
      - 'release'

permissions:
  pull-requests: write
  contents: write

jobs:
  tag:
    name: Tag and Release
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    - name: Build, tag, and release
      uses: pantheon-systems/plugin-release-actions/build-tag-release@main
      with:
        gh_token: ${{ secrets.GITHUB_TOKEN }}
        build_node_assets: "true"
        build_composer_assets: "true"
        generate_release_notes: "true"
        draft: "true"
```

#### Inputs

| Name | Description | Default |
| --- | --- | --- |
| `gh_token` | GitHub token | |
| `build_node_assets` | Whether to build node assets | `false` |
| `build_composer_assets` | Whether to build composer assets | `false` |
| `draft` | Whether to make the release a draft or live | `true` |
| `readme_md` | The file name of the readme to source the version number and changelog.| `README.md` |
| `generate_release_notes` | Generate release notes based on commits instead of parsing README. | `false` |


### Prepare Dev
This action will update the development branch to be ready for the next release after releasing a new version of a plugin or module. This action search and replaces the version number across all the top-level files in the repo.

### Release PR
This action will draft a "ship it" PR to the `release` branch when new features are added to the development branch. This action search and replaces the version number in relevant places across all the top-level files in the repo.

This action expects to make use of the label "automation" on the repo. Create it if it does not already exist.

### Validate Fixture Version

This action validates that the plugin's `readme.txt` `Tested up to:` field matches the current WordPress version published on WP.org, as well as the WordPress version running on a Pantheon Terminus `.dev` fixture environment. Patch versions are ignored during comparison (e.g. `Tested up to: 6.9` will match WP `6.9.4`). If the fixture is behind the current WordPress version, the action applies upstream updates automatically before validating.

```yaml
- name: Validate Fixture Version
  uses: pantheon-systems/plugin-release-actions/validate-fixture-version@main
  with:
    terminus_token: ${{ secrets.TERMINUS_MACHINE_TOKEN }}
    terminus_site: my-pantheon-site
```

#### Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `terminus_token` | Pantheon machine token for Terminus authentication. Not required if Terminus is already authenticated in a prior step. | No | |
| `terminus_site` | The Pantheon site machine name to use as the WordPress fixture environment. | Yes | |
| `readme_txt` | Path to the plugin's `readme.txt`, relative to the repository root. | No | `readme.txt` |

## Merging Commits
_TBD explain why features should be squashed and releases must be merged._
