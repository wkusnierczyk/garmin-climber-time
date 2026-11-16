# Changelog

Everything in Climber Time that a user could notice, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[semantic versioning](https://semver.org/spec/v2.0.0.html). A section is a code release, tagged `vX.Y.Z`,
and the face's version is the one in `manifest.xml`. A release that changes only the tooling leaves
that version where it was, and carries the bundle at it.

Each section is headed `## X.Y.Z -- YYYY-MM-DD`, two hyphens and the date the tag is pushed: the
release workflow takes the section with that heading as the release's notes, and refuses a tag
without one (`tools/release-notes.py`). The first section, 0.1.0, comes with the release.

Issue numbers in parentheses point at
[the tracker](https://github.com/wkusnierczyk/garmin-climber-time/issues), where the reasoning behind
each change is recorded in full.
