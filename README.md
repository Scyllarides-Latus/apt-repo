# apt-repo

Central APT repository for Scyllarides-Latus packages, hosted on GitHub Pages.

## End-user installation

```bash
curl -fsSL https://scyllarides-latus.github.io/apt-repo/setup.sh | sudo bash
sudo apt update
```

## How it works

Source projects build `.deb` packages and upload them as GitHub Release assets. They then fire a `repository_dispatch` event to this repo, which triggers a workflow that:

1. Downloads the `.deb` files from the source release
2. Copies them into `pool/main/`
3. Rebuilds the `Packages` index for each architecture (arm64, armhf, amd64)
4. Signs the `Release` file with GPG
5. Pushes the updated repo to `gh-pages`

### Dispatch payload

Source projects send this event to trigger a rebuild:

```json
{
  "event_type": "publish-deb",
  "client_payload": {
    "project": "owner/repo",
    "tag": "1.2.3"
  }
}
```

## Setup: GPG key

Generate a key pair (no passphrase):

```bash
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Scyllarides-Latus APT Repository
Name-Email: noreply@scyllarides-latus.github.io
Expire-Date: 0
%no-protection
EOF
```

Export and store:

```bash
# Public key → commit to gh-pages as gpg.key
gpg --armor --export "Scyllarides-Latus APT Repository" > gpg.key

# Private key → store as GPG_PRIVATE_KEY secret on this repo
gpg --armor --export-secret-keys "Scyllarides-Latus APT Repository"
```

## Setup: Source project integration

Authentication uses a GitHub App (`Scyllarides-Latus APT Publisher`) owned by the org. This provides short-lived, scoped tokens instead of long-lived PATs.

Each source project needs two secrets:

| Secret | Value |
|--------|-------|
| `APT_APP_ID` | The App's numeric ID (from the App settings page) |
| `APT_APP_PRIVATE_KEY` | The App's private key (`.pem` file contents) |

Then add these steps to the release workflow:

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

The `actions/create-github-app-token` action mints an ephemeral token (1hr) scoped to `apt-repo` only.
