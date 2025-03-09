import SwiftUI
import InfomaniakRichHTMLEditor

/// Une vue qui intègre l'éditeur InfomaniakRichHTMLEditor pour les signatures HTML
struct InfomaniakRichEditorView: View {
    @Binding var htmlContent: String
    var onSave: (() -> Void)?
    @State private var isModified = false
    @StateObject private var textAttributes = TextAttributes()
    
    var body: some View {
        VStack {
            // Barre de contrôle avec bouton de sauvegarde
            if onSave != nil {
                HStack {
                    Spacer()
                    Button(action: {
                        onSave?()
                        isModified = false
                    }) {
                        Label("Enregistrer", systemImage: "checkmark.circle")
                    }
                    .disabled(!isModified)
                    .keyboardShortcut("s", modifiers: [.command])
                }
                .padding(.horizontal)
            }
            
            // Utiliser la signature correcte avec textAttributes obligatoire
            RichHTMLEditor(html: $htmlContent, textAttributes: textAttributes)
                .onChange(of: htmlContent) { _, _ in
                    isModified = true
                }
                .frame(minHeight: 300)
                .padding()
        }
        .onChange(of: htmlContent) { _, _ in
            isModified = false
        }
    }
} 