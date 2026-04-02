# GitHub App Auth for Cross-Repo APT Dispatch

## Problem

Source repos under `ko5tas` (e.g., `t2`, `myenergi`, `t212`) need to trigger `repository_dispatch` on `Scyllarides-Latus/apt-repo`. A long-lived PAT tied to a personal account is fragile (account changes break it) and overly broad. A GitHub App provides scoped, ephemeral tokens.

## Design

### GitHub App

- **Name**: `Scyllarides-Latus APT Publisher`
- **Owner**: `Scyllarides-Latus` organization
- **Permissions**: Repository > Contents: Read & Write
- **Installation scope**: Only the `apt-repo` repository
- **Webhook**: Inactive (not needed)
- **Installable by**: Only this account (the org)

### How source repos authenticate (future, per-project migration)

Each source repo stores two secrets:
- `APP_ID` — the GitHub App's numeric ID
- `APP_PRIVATE_KEY` — the App's generated private key (PEM format)

At workflow runtime, the source repo uses [`actions/create-github-app-token@v1`](https://github.com/actions/create-github-app-token) to mint a short-lived installation token scoped to `Scyllarides-Latus/apt-repo`, then uses that token to POST the `repository_dispatch` event.

### Token flow

```
Source repo workflow (e.g., ko5tas/t2)
  ├─ reads APP_ID + APP_PRIVATE_KEY from repo secrets
  ├─ actions/create-github-app-token@v1
  │    → GitHub API: JWT auth → installation token (1hr, contents:write on apt-repo)
  └─ curl POST /repos/Scyllarides-Latus/apt-repo/dispatches
       Authorization: token <ephemeral-token>
```

### Example source repo workflow step

```yaml
- name: Generate APT repo token
  id: app-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APT_APP_ID }}
    private-key: ${{ secrets.APT_APP_PRIVATE_KEY }}
    owner: Scyllarides-Latus
    repositories: apt-repo

- name: Notify APT repo
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
    TAG: ${{ github.ref_name }}
  run: |
    gh api repos/Scyllarides-Latus/apt-repo/dispatches \
      -f event_type=publish-deb \
      -f "client_payload[project]=${GITHUB_REPOSITORY}" \
      -f "client_payload[tag]=${TAG}"
```

## Scope of this change

**In scope (apt-repo only):**
- Create the GitHub App under the org (manual, web UI)
- Install it on the org scoped to `apt-repo`
- Update `README.md` to document App-based auth

**Out of scope:**
- Modifying any source repo (`t2`, `myenergi`, etc.)
- Adding secrets to source repos

## Why GitHub App over PAT

| Aspect | PAT | GitHub App |
|--------|-----|------------|
| Token lifetime | Long-lived (until revoked) | 1 hour (auto-expires) |
| Tied to user | Yes (breaks if account changes) | No (org-owned) |
| Scope | Account-wide or repo-specific | Installation-specific |
| Key rotation | Must update every repo's secret | Rotate once, update secrets |

## Verification

1. Create the App in the org settings UI
2. Install it on `apt-repo`
3. Verify the App ID and private key are generated
4. (Future) Add secrets to a source repo and test dispatch
