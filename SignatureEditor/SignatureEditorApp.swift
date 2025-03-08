//
//  SignatureEditorApp.swift
//  SignatureEditor
//
//  Created by Antoine Cormier on 07/03/2025.
//

import SwiftUI
import AppKit

@main
struct SignatureEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.light)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configuration de l'application au démarrage
        print("Application démarrée")
        
        // Ne pas essayer d'accéder au dossier Mail automatiquement au démarrage
        // car cela peut causer des problèmes de thread si fait en dehors du thread principal
        // Laissons l'utilisateur choisir le dossier via l'interface
    }
}
