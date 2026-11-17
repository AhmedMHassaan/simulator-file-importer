# Contributing to Simulator File Importer

Contributions from all developers are welcome: bug fixes, features, tests, documentation, and reproducible issue reports.

## Send a pull request

1. Fork the repository into your GitHub account.
2. Create a feature branch in your fork, such as `fix/pdf-import`.
3. Make focused changes and update relevant tests or documentation.
4. Open a pull request from your branch into `AhmedMHassaan/simulator-file-importer:main`.
5. Explain the problem, resulting behavior, and how you verified it. Include screenshots for interface changes.

You do not need collaborator access. Everyone can propose changes through a fork and pull request. **Ahmed Mohamed Hassaan (@AhmedMHassaan) reviews and accepts contributions. Only that account may merge or push to `main`.** Main is protected against force pushes and deletion.

## Build and test

Use macOS 13 or later with Xcode installed. Open `SimulatorPhotos.xcodeproj` and select the **SimulatorPhotos** scheme. Build with **Product → Build** and run tests with **Product → Test**. The internal scheme/module name is retained from the original photo-only app.

Alternatively, install XcodeBuildMCP and run `Build.command` for a universal release, or use its `macos test` command to run the test scheme.

Most tests do not need running simulators. Set `SIMULATOR_PHOTOS_LIVE_TEST=1` in the test runner environment to enable live imports. Run two simulators when verifying selection and multiple destinations. Live tests add small image/PDF/text fixtures to the simulators; use disposable test devices when appropriate.

## Keep changes focused

- Keep image imports in Photos and supported documents in the shared Files Downloads folder.
- Preserve existing filenames; do not overwrite user documents.
- Keep subprocess arguments separate; never evaluate user input through a shell.
- Do not commit build output, signing certificates, credentials, or local Xcode settings.
- Update the user guide when changing supported formats or interface behavior.
- Report the checks you ran and their practical limits; do not claim testing on devices you did not use.

## Report a problem

Use the bug report form with your macOS/Xcode/simulator versions, input type, expected behavior, actual behavior, and reproducible steps. Remove personal information from logs and use a non-sensitive sample file.

## License

The project uses the [MIT License](LICENSE). By submitting a contribution, you agree to make it available under that license.
