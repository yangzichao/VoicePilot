import Foundation
import AppKit
import os

/// Stubbed screen-capture service.
/// In this fork, screen recording is fully disabled to avoid requiring Screen Recording permissions.
@MainActor
class ScreenCaptureService: ObservableObject {
    @Published var isCapturing = false
    @Published var lastCapturedText: String?

    private let logger = Logger(
        subsystem: "com.yangzichao.hoah",
        category: "aienhancement"
    )

    func captureAndExtractText() async -> String? {
        logger.notice("📸 Screen capture is disabled in this build.")
        lastCapturedText = nil
        return nil
    }
}
