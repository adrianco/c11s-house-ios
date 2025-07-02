# c11s-house-ios

## An iOS app that provides a voice based interface to the house consciousness system

Using native swift and the latest Apple Intelligence features, support the APIs and functionality of https://github.com/adrianco/consciousness

Plans created here with claude-flow

------
Prompt used was 

$ ./claude-flow swarm "review the README.md in root and create a detailed technical implementation plan in /plans using TDD, don't implement any code yet"

Above this line is all that was provided as input to this development process.

Update after plans were built in 5 minutes and pushed back to the repo.

Log of the output as it did this work is saved in the repo.

## Status
Reviewed with help from someone that knows current Apple development and looks good.
Working on refining the server and its user flows before we will attempt to build this app.

## Xcode Project Setup

The project is now configured for Xcode Cloud CI/CD. To set up:

1. **Create Xcode Project**
   - Open Xcode and create new iOS App named "C11SHouse"
   - Save it in this directory (let Xcode create the C11SHouse folder)
   
2. **Run Setup Script**
   ```bash
   ./setup_xcode_project.sh
   ```

3. **Configure Xcode Cloud**
   - See [XCODE_CLOUD_SETUP.md](XCODE_CLOUD_SETUP.md) for detailed instructions

## Project Structure

- `xcode-templates/` - Pre-configured files for SwiftUI app and Xcode Cloud workflows
- `plans/` - Architecture and implementation documentation
- `.xcode/workflows/` - CI/CD pipelines (created after setup)
- `ci_scripts/` - Build automation scripts (created after setup)
