# Contributing

Start with [setup](docs/SETUP.md), [architecture](docs/ARCHITECTURE.md), and [verification](docs/DEVELOPMENT.md). This repository is published for portfolio review; it does not grant a general open-source license.

Keep changes focused on one behavior or documentation area. Describe the trigger, the resulting behavior, and the checks performed. Add a regression test for a meaningful behavior change; documentation and image changes need link/provenance/render checks rather than artificial unit tests.

Run the localization checker and relevant XCTest suites. Keep the shared package lock and maintained Xcode project intact. Never regenerate the app from the UI harness's `project.yml`. Preserve installed-user identifiers and migration paths when changing persistence or subscription behavior.

Use a disposable simulator for previews and first-launch QA. Configure your own external-service projects before enabling analytics delivery or exercising a service catalog. Keep signing material, credentials, derived data, raw customer data, archive exports, and duplicated source files outside Git.

Write repository documentation in English. Describe heuristic scores, fixture data, and test outcomes precisely; do not claim model accuracy or production store validation from seeded screenshots or Test Store results.
