import SwiftUI

// Un placeholder simple pour l'éditeur de texte riche qui sera développé plus tard
struct RichTextEditor: View {
    @Binding var attributedText: NSAttributedString
    
    var body: some View {
        VStack {
            Text("Éditeur de Texte Riche (À venir)")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
            
            // Afficher simplement le texte pour l'instant
            Text(attributedText.string)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .cornerRadius(5)
        }
    }
}

// Placeholder pour la barre d'outils de formatage
struct RichTextToolbar: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(["B", "I", "U", "Couleur", "Lien"], id: \.self) { tool in
                Button(tool) {
                    // Fonctionnalité à implémenter
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
    }
} 