# Vendored third-party code

The only third-party code in Halo. Vendored (copied into the repo) rather
than fetched at build time, so every line is pinned, reviewable, and cannot
change out from under us.

## mediaremote-adapter

- **What:** Streams system-wide "Now Playing" info and sends media commands.
  Since macOS 15.4, Apple's `mediaremoted` only talks to entitled processes;
  this adapter works by having Apple's own `/usr/bin/perl` (which is
  entitled) load a small helper framework that we compile from the source in
  this folder. See `Scripts/embed-mediaremote-adapter.sh`.
- **Upstream:** <https://github.com/ungive/mediaremote-adapter>
- **Version:** v0.7.6, commit `3ac3d4bdf862c7b5399b4fba4df5689f5c38609a`
- **License:** BSD 3-Clause (see `LICENSE` in this folder)
- **Audit notes (2026-07-12):** No network access, no code downloading; the
  perl script only `dlopen`s the locally built framework. Editor configs and
  upstream CI scripts were dropped in vendoring; source is otherwise
  unmodified.
- **Risk:** Uses Apple's private MediaRemote framework indirectly. A future
  macOS update may break it. Failure mode is contained: the Now Playing
  module simply shows nothing; the rest of Halo is unaffected.
