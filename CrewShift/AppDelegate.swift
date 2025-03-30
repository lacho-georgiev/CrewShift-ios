//
//  AppDelegate.swift
//  CrewShift
//
//  Created by Lachezar Georgiev on 30.03.25.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import FirebaseAuth



class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    // Flight data service for background fetching
    var flightDataService = FlightDataService()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Error requesting notifications permissions: \(error.localizedDescription)")
            }
            print("Notification permissions granted: \(granted)")
        }
        application.registerForRemoteNotifications()

        // Set Messaging delegate
        Messaging.messaging().delegate = self
        
        // Setup background fetch capability
        setupBackgroundFetch()
        
        // Initialize flight data service and load cached data
        _ = flightDataService
        
        return true
    }
    
    // Setup background fetch capability
    private func setupBackgroundFetch() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    // Handle background fetch
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        var fetchResult = UIBackgroundFetchResult.noData
        var didComplete = false
        
        // Create a publisher-subscriber relationship to monitor for changes
        let cancellable = flightDataService.$hasChanges.sink { hasChanges in
            if hasChanges && !didComplete {
                fetchResult = .newData
                didComplete = true
                completionHandler(fetchResult)
            }
        }
        
        // Fetch the latest flight data
        flightDataService.fetchFlightData()
        
        // Set a timeout to ensure the completion handler gets called
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            if !didComplete {
                didComplete = true
                cancellable.cancel()
                completionHandler(fetchResult)
            }
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Refresh flight data when app becomes active
        flightDataService.fetchFlightData()
    }

    // Called when APNs has assigned a device token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("APNs device token received: \(deviceToken)")
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("Firebase registration token: \(token)")
        sendFCMTokenToServer(token: token)
    }

    // This function sends the FCM token to your backend endpoint.
    func sendFCMTokenToServer(token: String) {
        // Retrieve current user uid from Firebase Auth.
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No current user, cannot send FCM token.")
            return
        }

        let db = Firestore.firestore()
        db.collection("user").document(uid).setData(["fcm_token": token], merge: true) { error in
            if let error = error {
                print("Error saving FCM token to Firestore: \(error.localizedDescription)")
            } else {
                print("FCM token saved directly to Firestore for uid: \(uid)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notifications while app is in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
    
    // Handle notification response
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Check if it's a flight update notification
        if response.notification.request.identifier == "flightUpdate" {
            // You could post a notification to navigate to the flight details screen
            NotificationCenter.default.post(name: NSNotification.Name("ShowFlightUpdates"), object: nil)
        }
        
        completionHandler()
    }
}
