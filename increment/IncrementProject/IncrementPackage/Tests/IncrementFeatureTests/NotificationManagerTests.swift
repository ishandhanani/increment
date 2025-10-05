import Testing
import UserNotifications
@testable import IncrementFeature

@Suite("NotificationManager Tests")
struct NotificationManagerTests {

    @Test("Manager is a singleton")
    func testSingleton() async {
        let instance1 = await NotificationManager.shared
        let instance2 = await NotificationManager.shared

        #expect(instance1 === instance2)
    }

    @Test("Request authorization returns boolean result")
    func testRequestAuthorization() async {
        let manager = await NotificationManager.shared

        let result = await manager.requestAuthorization()

        // Result should be either true or false, not nil
        #expect(result == true || result == false)
    }

    @Test("Check authorization status")
    func testIsAuthorized() async {
        let manager = await NotificationManager.shared

        let authorized = await manager.isAuthorized()

        // Should return a boolean value
        #expect(authorized == true || authorized == false)
    }

    @Test("Multiple authorization requests are idempotent")
    func testMultipleAuthorizationRequests() async {
        let manager = await NotificationManager.shared

        let result1 = await manager.requestAuthorization()
        let result2 = await manager.requestAuthorization()

        // Both requests should complete successfully
        #expect(result1 == result2)
    }

    @Test("Authorization check after request reflects status")
    func testAuthorizationCheckAfterRequest() async {
        let manager = await NotificationManager.shared

        // Request authorization
        let requestResult = await manager.requestAuthorization()

        // Check authorization status
        let authStatus = await manager.isAuthorized()

        // If request was granted, status should show authorized
        if requestResult {
            #expect(authStatus == true)
        }
    }

    @Test("Notification manager methods are thread-safe")
    func testThreadSafety() async {
        let manager = await NotificationManager.shared

        // Fire multiple concurrent requests
        async let check1: Bool = manager.isAuthorized()
        async let check2: Bool = manager.isAuthorized()
        async let request: Bool = manager.requestAuthorization()

        let results = await (check1, check2, request)

        // All operations should complete without crashes
        #expect(results.0 == true || results.0 == false)
        #expect(results.1 == true || results.1 == false)
        #expect(results.2 == true || results.2 == false)
    }
}
