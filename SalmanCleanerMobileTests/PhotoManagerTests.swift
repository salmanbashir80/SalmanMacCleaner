import XCTest
@testable import SalmanCleanerMobile

final class PhotoManagerTests: XCTestCase {
    var photoManager: PhotoManager!

    override func setUp() {
        super.setUp()
        photoManager = PhotoManager()
    }

    override func tearDown() {
        photoManager = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(photoManager.largeMedia.count, 0)
        XCTAssertEqual(photoManager.duplicateGroups.count, 0)
        XCTAssertEqual(photoManager.isScanning, false)
        XCTAssertEqual(photoManager.scannedBytes, 0)
    }
}
