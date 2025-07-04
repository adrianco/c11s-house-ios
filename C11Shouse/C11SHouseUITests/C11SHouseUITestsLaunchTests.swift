/*
 * CONTEXT & PURPOSE:
 * C11SHouseUITestsLaunchTests focuses on testing the app launch experience and capturing
 * screenshots for documentation and App Store submission. It runs for each UI configuration
 * to ensure the app launches correctly across different device sizes and orientations.
 *
 * DECISION HISTORY:
 * - 2025-07-02: Initial implementation (Created by Adrian Cockcroft)
 *   - runsForEachTargetApplicationUIConfiguration = true for comprehensive testing
 *   - Screenshot capture on launch for visual verification
 *   - XCTAttachment with keepAlways lifetime for persistent screenshots
 *   - @MainActor for UI-related test execution
 *   - Placeholder for future launch customization (login, navigation)
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  C11SHouseUITestsLaunchTests.swift
//  C11SHouseUITests
//
//  Created by Adrian Cockcroft on 7/2/25.
//

import XCTest

final class C11SHouseUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
