//
//  ContentView.swift
//  SignatureEditor
//
//  Created by Antoine Cormier on 07/03/2025.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var signatureViewModel = SignatureViewModel()
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            // Panneau gauche - Liste des signatures
            SignatureListView(viewModel: signatureViewModel)
            
            // Panneau principal
            ZStack {
                if let selectedSignatureID = signatureViewModel.selectedSignatureID,
                   let signature = signatureViewModel.signatures.first(where: { $0.id == selectedSignatureID }) {
                    SignatureEditorView(viewModel: signatureViewModel, signature: signature)
                        .id(selectedSignatureID) // Force la mise à jour de la vue quand l'ID change
                } else {
                    VStack {
                        Text("Sélectionnez une signature dans la liste")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.default, value: signatureViewModel.selectedSignatureID) // Ajoute une animation lors du changement
        }
        .navigationTitle("Éditeur de Signatures")
        .frame(minWidth: 800, minHeight: 600)
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Erreur"),
                message: Text(signatureViewModel.errorMessage ?? "Une erreur inconnue s'est produite"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: signatureViewModel.showError) { _, newValue in
            if newValue {
                showingErrorAlert = true
                signatureViewModel.showError = false
            }
        }
        .sheet(isPresented: $signatureViewModel.showPermissionsExplanation) {
            PermissionsExplanationView(
                onClose: {
                    signatureViewModel.closePermissionsExplanation()
                },
                onSelectDirectory: {
                    signatureViewModel.showPermissionsExplanation = false
                    signatureViewModel.selectSignaturesDirectoryManually()
                }
            )
        }
        .onAppear {
            setupAppAppearance()
        }
    }
    
    // Configure l'apparence de base de l'application
    private func setupAppAppearance() {
        // S'assurer que la fenêtre a une taille correcte
        NSApp.windows.first?.setFrame(NSRect(x: 0, y: 0, width: 1000, height: 700), display: true)
        
        // Centrer la fenêtre à l'écran
        NSApp.windows.first?.center()
        
        // Configure la barre d'outils avec les fonctionnalités courantes
        let toolbar = NSToolbar(identifier: "SignatureEditorToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        
        NSApp.windows.first?.toolbar = toolbar
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
