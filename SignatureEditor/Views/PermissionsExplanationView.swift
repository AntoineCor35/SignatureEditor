import SwiftUI

struct PermissionsExplanationView: View {
    var onClose: () -> Void
    var onSelectDirectory: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Bienvenue dans SignatureEditor")
                .font(.title)
                .fontWeight(.bold)
            
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
            
            Text("Autorisations nécessaires")
                .font(.headline)
            
            Text("Pour des raisons de sécurité, macOS ne permet pas aux applications d'accéder directement au dossier des signatures de Mail.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Vous devez sélectionner manuellement le dossier des signatures pour autoriser l'application à y accéder.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Comment procéder :")
                    .fontWeight(.bold)
                
                HStack(alignment: .top) {
                    Text("1.")
                    Text("Cliquez sur le bouton \"Sélectionner le dossier des signatures\" ci-dessous")
                }
                
                HStack(alignment: .top) {
                    Text("2.")
                    Text("Dans le sélecteur de fichiers, naviguez vers :")
                }
                
                Text("~/Library/Mail/V10/MailData/Signatures")
                    .font(.system(.body, design: .monospaced))
                    .padding(.leading, 20)
                
                HStack(alignment: .top) {
                    Text("3.")
                    Text("Sélectionnez ce dossier et cliquez sur \"Ouvrir\"")
                }
                
                Text("Note : Le dossier Library est masqué par défaut. Utilisez Cmd+Shift+. pour afficher les fichiers cachés, ou utilisez Cmd+Shift+G et collez le chemin complet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 20) {
                Button("Sélectionner le dossier des signatures") {
                    onSelectDirectory()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Plus tard") {
                    onClose()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding(30)
        .frame(width: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    PermissionsExplanationView(
        onClose: {},
        onSelectDirectory: {}
    )
} 