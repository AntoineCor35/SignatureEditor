import SwiftUI

struct SignatureListView: View {
    @ObservedObject var viewModel: SignatureViewModel
    @State private var showingNewSignatureSheet = false
    @State private var newSignatureName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre de titre avec boutons
            HStack {
                Text("Signatures")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.selectSignaturesDirectoryManually()
                }) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Sélectionner le dossier de signatures")
                
                Button(action: {
                    viewModel.analyzeAllSignaturesPlist()
                }) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .help("Analyser le fichier AllSignatures.plist")
                
                Button(action: {
                    showingNewSignatureSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .help("Nouvelle signature")
                
                Button(action: {
                    viewModel.loadSignatures()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Actualiser")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Séparateur
            Divider()
            
            if viewModel.isLoading {
                ProgressView("Chargement...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.signatures.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Aucune signature trouvée")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Pour des raisons de sécurité, macOS ne permet pas aux applications d'accéder directement au dossier des signatures de Mail.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chemin du dossier des signatures :")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("~/Library/Mail/V10/MailData/Signatures")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)
                    
                    Button("Sélectionner le dossier des signatures") {
                        viewModel.selectSignaturesDirectoryManually()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 5)
                    
                    Text("Note : Le dossier Library est masqué par défaut. Utilisez Cmd+Shift+. pour afficher les fichiers cachés.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 5)
                    
                    Button("Créer une nouvelle signature") {
                        showingNewSignatureSheet = true
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Liste des signatures
                List(viewModel.signatures) { signature in
                    SignatureRow(
                        signature: signature,
                        isSelected: viewModel.selectedSignatureID == signature.id,
                        onSelect: {
                            viewModel.selectedSignatureID = signature.id
                        },
                        onDelete: {
                            viewModel.deleteSignature(id: signature.id)
                        }
                    )
                }
                .frame(minWidth: 220)
                .listStyle(SidebarListStyle())
            }
        }
        .sheet(isPresented: $showingNewSignatureSheet) {
            NewSignatureSheet(isPresented: $showingNewSignatureSheet, viewModel: viewModel)
        }
    }
}

// Élément de ligne pour une signature
struct SignatureRow: View {
    let signature: Signature
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(signature.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text(signature.signatureID)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Indicateur de modification
            if signature.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contextMenu {
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Supprimer la signature"),
                message: Text("Êtes-vous sûr de vouloir supprimer \(signature.name) ? Cette action est irréversible."),
                primaryButton: .destructive(Text("Supprimer")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// Feuille pour créer une nouvelle signature
struct NewSignatureSheet: View {
    @Binding var isPresented: Bool
    let viewModel: SignatureViewModel
    
    @State private var signatureName = "Ma signature"
    @State private var initialContent = NSAttributedString(
        string: "Votre signature ici",
        attributes: [
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 14)
        ]
    )
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Nouvelle signature")
                .font(.headline)
            
            TextField("Nom de la signature", text: $signatureName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Text("Contenu de la signature")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            RichTextEditor(attributedText: $initialContent)
                .frame(height: 200)
            
            HStack {
                Button("Annuler") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Créer") {
                    viewModel.createNewSignature(name: signatureName, content: initialContent)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(signatureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
} 