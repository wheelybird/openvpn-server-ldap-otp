# Releasing

1. As changes land, add them to CHANGELOG.md under `## [Unreleased]`.
2. On an up-to-date `master`, run `scripts/release.sh` (a patch release), or `scripts/release.sh minor` / `major`. It shows the notes, asks for confirmation, then stamps the changelog, bumps the README image tags, commits, tags and pushes.
3. The tag triggers the Release workflow, which runs the configuration tests, builds the `linux/amd64`, `linux/arm64` and `linux/arm/v7` images, pushes `wheelybird/openvpn-ldap-otp:vX.Y.Z` and `:latest` to Docker Hub, and creates the GitHub release from that version's changelog section.

The PAM module is built from a pam-ldap-totp-auth release tag (`PAM_MODULE_VERSION` in the Dockerfile), so release that first when a change spans both.

One-time setup: the repository needs `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets (a Docker Hub access token with read/write scope).
