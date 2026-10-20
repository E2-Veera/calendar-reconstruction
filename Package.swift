// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CalendarReconstruction",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CalendarReconstruction", targets: ["CalendarReconstruction"]),
    ],
    targets: [
        // Pure logic: models, persistence, date math, layout, controller. No SwiftUI.
        .target(name: "CalendarCore"),
        // SwiftUI user interface + headless command-line modes used by tests.
        .executableTarget(name: "CalendarReconstruction", dependencies: ["CalendarCore"]),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"]),
    ]
)
