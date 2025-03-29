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

        return true
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
    // Alternatively, you could write the token directly to Firestore here.
    func sendFCMTokenToServer(token: String) {
        // Retrieve current user uid from Firebase Auth.
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No current user, cannot send FCM token.")
            return
        }

        // Option 1: Send to backend via secure endpoint.
//        let urlString = "https://your-api-url.com/user/\(uid)/fcm-token"
//        guard let url = URL(string: urlString) else { return }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.setValue("Bearer \(uid)", forHTTPHeaderField: "Authorization")
//
//        let body = ["token": token]
//        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else { return }
//        request.httpBody = httpBody
//
//        let task = URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Error sending FCM token: \(error.localizedDescription)")
//            } else if let response = response as? HTTPURLResponse, response.statusCode == 200 {
//                print("FCM token sent successfully to server.")
//            } else {
//                print("Unexpected response when sending FCM token.")
//            }
//        }
//        task.resume()

        // Option 2: Directly write to Firestore (uncomment if you prefer this approach)

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
}
