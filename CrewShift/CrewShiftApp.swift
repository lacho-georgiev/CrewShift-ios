//
//  CrewShiftApp.swift
//  CrewShift
//
//  Created by Lachezar Georgiev on 30.03.25.
//

import SwiftUI
import Firebase
import FirebaseAuth

@main
struct CrewShiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure()
        signInAnonymously()

        print("Firebase initialized")
    }

    var body: some Scene {
        WindowGroup {
            CustomTabView()
        }
    }
    
    
    func signInAnonymously() {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Firebase anonymous sign in failed: \(error.localizedDescription)")
            } else if let user = authResult?.user {
                print("Firebase anonymous sign in succeeded, uid: \(user.uid)")
                // Create the user document immediately
                let db = Firestore.firestore()
                db.collection("user").document(user.uid).setData([:], merge: true) { error in
                    if let error = error {
                        print("Error creating user document: \(error.localizedDescription)")
                    } else {
                        print("User document created for uid: \(user.uid)")
                    }
                }
            }
        }
    }


}
