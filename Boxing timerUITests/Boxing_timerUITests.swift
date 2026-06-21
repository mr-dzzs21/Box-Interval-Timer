//
//  Boxing_timerUITests.swift
//  Boxing timerUITests
//
//  Created by Diyar on 28.02.26.
//

import XCTest

final class Boxing_timerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testTabsDoNotCrash() throws {
        let app = XCUIApplication()
        // Onboarding + Spenden-Popup überspringen (UserDefaults via Launch-Args)
        app.launchArguments = ["-onboardingCompleted", "YES", "-donationPromptShown", "YES"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground, "App nicht im Vordergrund nach Launch")

        let tabButtons = app.tabBars.buttons
        XCTAssertGreaterThan(tabButtons.count, 0, "Keine Tab-Bar-Buttons gefunden")

        // Jeden Tab antippen und prüfen, dass die App nicht abstürzt
        for i in 0..<tabButtons.count {
            let btn = tabButtons.element(boundBy: i)
            if btn.exists { btn.tap() }
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertEqual(app.state, .runningForeground, "App ist auf Tab \(i) abgestürzt")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "tab-\(i)"
            shot.lifetime = .keepAlways
            add(shot)
        }

        // Falls die letzten Tabs unter "More" liegen: dort die Einträge öffnen
        let more = app.tabBars.buttons.element(boundBy: tabButtons.count - 1)
        if more.exists { more.tap(); Thread.sleep(forTimeInterval: 0.5) }
        let cells = app.cells
        for i in 0..<min(cells.count, 4) {
            let cell = cells.element(boundBy: i)
            if cell.exists && cell.isHittable {
                cell.tap()
                Thread.sleep(forTimeInterval: 1.0)
                XCTAssertEqual(app.state, .runningForeground, "App ist in More-Eintrag \(i) abgestürzt")
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "more-\(i)"
                shot.lifetime = .keepAlways
                add(shot)
                if app.navigationBars.buttons.element(boundBy: 0).exists {
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                }
            }
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
