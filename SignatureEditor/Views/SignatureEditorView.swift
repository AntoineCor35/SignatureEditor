import SwiftUI
import WebKit

struct SignatureEditorView: View {
    @ObservedObject var viewModel: SignatureViewModel
    var signature: Signature
    
    @State private var localHtmlContent: String
    @State private var localAttributedText: NSAttributedString
    @State private var isDirty: Bool = false
    @State private var htmlEditorWebView: WKWebView?
    
    init(viewModel: SignatureViewModel, signature: Signature) {
        self.viewModel = viewModel
        self.signature = signature
        _localHtmlContent = State(initialValue: signature.htmlContent)
        _localAttributedText = State(initialValue: signature.content)
    }
    
    // Cette fonction est appelée lorsque la vue apparaît ou lorsque la signature change
    private func updateLocalContent() {
        localHtmlContent = signature.htmlContent
        localAttributedText = signature.content
        isDirty = signature.isDirty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête
            Text("Édition de signature: \(signature.name)")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Zone de contenu
            VStack {
                TabView {
                    // Onglet prévisualisation
                    VStack {
                        Text("Prévisualisation")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        HtmlPreview(htmlContent: localHtmlContent)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    .padding()
                    .tabItem {
                        Label("Prévisualisation", systemImage: "eye")
                    }
                    
                    // Onglet Texte Riche (utilisant TinyMCEAttributedEditorView)
                    TinyMCEAttributedEditorView(attributedText: $localAttributedText, onSave: {
                        // Mise à jour et sauvegarde de la signature
                        viewModel.updateSignature(id: signature.id, content: localAttributedText, htmlContent: localHtmlContent)
                        viewModel.saveSignature(id: signature.id)
                        isDirty = false
                    })
                    .onChange(of: localAttributedText) { _, _ in
                        isDirty = true
                    }
                    .padding()
                    .tabItem {
                        Label("Éditeur Texte Riche", systemImage: "textformat")
                    }
                    
                    // Onglet HTML avec CodeMirror
                    VStack(spacing: 10) {
                        HStack {
                            Text("Éditeur HTML (CodeMirror)")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                // Formater le HTML avec CodeMirror
                                if let webView = htmlEditorWebView {
                                    webView.evaluateJavaScript("formatHTML();") { _, error in
                                        if let error = error {
                                            print("Erreur lors du formatage: \(error.localizedDescription)")
                                        } else {
                                            isDirty = true
                                        }
                                    }
                                }
                            }) {
                                Label("Formater", systemImage: "text.alignleft")
                            }
                            .help("Formater le code HTML")
                            
                            Button(action: {
                                // Actualiser la prévisualisation
                                if let webView = htmlEditorWebView {
                                    webView.evaluateJavaScript("getContent();") { result, error in
                                        if let content = result as? String {
                                            localHtmlContent = content
                                            viewModel.updateSignature(id: signature.id, content: localAttributedText, htmlContent: content)
                                            isDirty = true
                                        }
                                    }
                                }
                            }) {
                                Label("Appliquer", systemImage: "arrow.clockwise")
                            }
                            .help("Appliquer les changements et actualiser la prévisualisation")
                        }
                        .padding(.horizontal)
                        
                        HtmlEditor(htmlContent: $localHtmlContent)
                            .onChange(of: localHtmlContent) { _, _ in
                                isDirty = true
                            }
                            .onAppear {
                                // On attend un peu pour s'assurer que la WebView est bien chargée
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // Trouver la WebView à partir de la hiérarchie des vues
                                    if let window = NSApplication.shared.windows.first,
                                       let contentView = window.contentView,
                                       let webView = findWebView(in: contentView) {
                                        self.htmlEditorWebView = webView
                                    }
                                }
                            }
                    }
                    .padding()
                    .tabItem {
                        Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Barre de statut
            HStack {
                Text("ID: \(signature.signatureID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isDirty {
                    Text("Modifié")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.trailing, 5)
                }
                
                Button("Sauvegarder") {
                    // Récupérer le contenu HTML actuel de l'éditeur CodeMirror
                    if let webView = htmlEditorWebView {
                        webView.evaluateJavaScript("getContent();") { result, error in
                            if let content = result as? String {
                                localHtmlContent = content
                                viewModel.updateSignature(id: signature.id, content: localAttributedText, htmlContent: content)
                                viewModel.saveSignature(id: signature.id)
                                isDirty = false
                            } else {
                                // Sauvegarde avec les valeurs actuelles si l'éditeur n'est pas accessible
                                viewModel.updateSignature(id: signature.id, content: localAttributedText, htmlContent: localHtmlContent)
                                viewModel.saveSignature(id: signature.id)
                                isDirty = false
                            }
                        }
                    } else {
                        // Sauvegarde avec les valeurs actuelles si l'éditeur n'est pas accessible
                        viewModel.updateSignature(id: signature.id, content: localAttributedText, htmlContent: localHtmlContent)
                        viewModel.saveSignature(id: signature.id)
                        isDirty = false
                    }
                }
                .disabled(!isDirty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear(perform: updateLocalContent)
        .onChange(of: signature.id) { _, _ in
            updateLocalContent()
        }
    }
    
    // Fonction pour rechercher la WebView dans la hiérarchie des vues
    private func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        
        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }
        
        return nil
    }
} 