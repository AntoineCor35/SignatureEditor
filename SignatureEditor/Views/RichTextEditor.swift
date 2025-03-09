import SwiftUI
import WebKit

/// Un éditeur de texte riche simple basé sur TinyMCE
struct RichTextEditor: NSViewRepresentable {
    /// Le contenu HTML à afficher et modifier
    @Binding var htmlContent: String
    
    // Mode de fonctionnement
    private var useAttributedText: Bool = false
    
    // Pour le mode attributedText (API de compatibilité)
    private var attributedText: Binding<NSAttributedString>?
    
    /// Callback appelé lorsque le contenu HTML change
    var onHtmlChange: ((String) -> Void)?
    
    /// Callback appelé lorsque le contenu AttributedString change
    var onAttributedTextChange: ((NSAttributedString) -> Void)?
    
    /// Initialisation avec htmlContent
    init(htmlContent: Binding<String>, onHtmlChange: ((String) -> Void)? = nil) {
        self._htmlContent = htmlContent
        self.attributedText = nil
        self.onHtmlChange = onHtmlChange
        self.onAttributedTextChange = nil
        self.useAttributedText = false
    }
    
    /// Initialisation avec attributedText (API de compatibilité)
    init(attributedText: Binding<NSAttributedString>, onTextChange: ((NSAttributedString) -> Void)? = nil) {
        self._htmlContent = .constant("")
        self.attributedText = attributedText
        self.onHtmlChange = nil
        self.onAttributedTextChange = onTextChange
        self.useAttributedText = true
    }
    
    /// Créer la vue native (WKWebView)
    func makeNSView(context: Context) -> WKWebView {
        // Configuration de base de WebKit
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        
        // Configurer le contrôleur de contenu pour la communication JS->Swift
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "tinyMCECallback")
        
        // Créer la WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Charger l'éditeur TinyMCE
        loadTinyMCEEditor(webView: webView)
        
        return webView
    }
    
    /// Mettre à jour la vue native lorsque les données SwiftUI changent
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Si on utilise attributedText, on doit convertir en HTML
        let contentToSet: String
        if useAttributedText, let attrText = attributedText?.wrappedValue {
            contentToSet = attributedStringToHtml(attrText) ?? ""
        } else {
            contentToSet = htmlContent
        }
        
        // Mettre à jour le contenu HTML uniquement si l'éditeur est prêt
        // et si le contenu a changé depuis l'extérieur ET qu'il ne provient pas de l'éditeur lui-même
        if context.coordinator.isEditorReady && 
           context.coordinator.lastReceivedHtml != contentToSet &&
           !context.coordinator.isUpdatingFromEditor {
            // Garder trace que la mise à jour est initiée depuis Swift
            context.coordinator.lastExternalContent = contentToSet
            setHtmlContent(webView: webView, html: contentToSet)
        }
    }
    
    /// Créer le coordinateur pour gérer les événements et la communication
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Coordinateur pour gérer les délégations et la communication JS<->Swift
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: RichTextEditor
        var isEditorReady = false
        var lastReceivedHtml = ""
        var lastExternalContent = ""
        var isUpdatingFromEditor = false
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }
        
        /// Recevoir les messages de JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any] else { 
                print("Message reçu, mais pas sous forme de dictionnaire")
                return 
            }
            
            if let type = dict["type"] as? String {
                switch type {
                case "editorReady":
                    // L'éditeur est prêt, on peut définir le contenu initial
                    isEditorReady = true
                    print("TinyMCE est prêt")
                    
                    DispatchQueue.main.async {
                        let initialContent: String
                        if self.parent.useAttributedText, 
                           let attrText = self.parent.attributedText?.wrappedValue {
                            initialContent = self.parent.attributedStringToHtml(attrText) ?? ""
                        } else {
                            initialContent = self.parent.htmlContent
                        }
                        
                        self.setHtmlContent(webView: message.webView, html: initialContent)
                    }
                    
                case "contentChange":
                    // Le contenu a changé dans l'éditeur
                    if let content = dict["content"] as? String {
                        // Vérifier si le contenu a réellement changé pour éviter les boucles
                        if self.lastReceivedHtml != content && self.lastExternalContent != content {
                            self.isUpdatingFromEditor = true
                            self.lastReceivedHtml = content
                            
                            DispatchQueue.main.async {
                                if self.parent.useAttributedText {
                                    // Convertir le HTML en attributedText
                                    if let attributedString = self.htmlToAttributedString(content),
                                       let binding = self.parent.attributedText {
                                        binding.wrappedValue = attributedString
                                        self.parent.onAttributedTextChange?(attributedString)
                                    }
                                } else {
                                    // Mettre à jour le HTML directement
                                    self.parent.htmlContent = content
                                    self.parent.onHtmlChange?(content)
                                }
                                
                                // Réinitialiser le flag après la mise à jour
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.isUpdatingFromEditor = false
                                }
                            }
                        }
                    }
                    
                case "log":
                    // Message de log depuis JavaScript
                    if let msg = dict["message"] as? String {
                        print("TinyMCE Log: \(msg)")
                    }
                    
                case "error":
                    // Erreur depuis JavaScript
                    if let msg = dict["message"] as? String {
                        print("TinyMCE Error: \(msg)")
                    }
                    
                default:
                    print("Type de message non géré: \(type)")
                }
            }
        }
        
        /// La WebView a fini de charger
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView chargée")
        }
        
        /// Erreur lors du chargement de la WebView
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Erreur de navigation: \(error)")
        }
        
        /// Définir le contenu HTML dans l'éditeur
        func setHtmlContent(webView: WKWebView?, html: String) {
            guard let webView = webView else { return }
            
            // Échapper le HTML pour l'injecter en JavaScript
            let escapedHtml = html.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            
            // Appeler la fonction JavaScript pour définir le contenu
            let script = "setEditorContent(\"\(escapedHtml)\");"
            webView.evaluateJavaScript(script) { (_, error) in
                if let error = error {
                    print("Erreur lors de la définition du contenu: \(error)")
                }
            }
        }
        
        // Convertir du HTML en NSAttributedString
        func htmlToAttributedString(_ html: String) -> NSAttributedString? {
            guard let data = html.data(using: .utf8) else { return nil }
            
            do {
                return try NSAttributedString(data: data,
                                             options: [.documentType: NSAttributedString.DocumentType.html,
                                                       .characterEncoding: String.Encoding.utf8.rawValue],
                                             documentAttributes: nil)
            } catch {
                print("Erreur de conversion HTML → NSAttributedString: \(error)")
                return nil
            }
        }
    }
    
    /// Charger TinyMCE dans la WebView
    private func loadTinyMCEEditor(webView: WKWebView) {
        let htmlContent = createTinyMCEHtml()
        
        // Utiliser le répertoire Resources comme base URL pour charger les ressources
        if let resourcesURL = Bundle.main.resourceURL {
            webView.loadHTMLString(htmlContent, baseURL: resourcesURL)
        } else {
            // Fallback si le dossier de ressources n'est pas trouvé
            webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://localhost"))
        }
    }
    
    /// Définir le contenu HTML dans l'éditeur
    private func setHtmlContent(webView: WKWebView, html: String) {
        let coordinator = makeCoordinator()
        coordinator.setHtmlContent(webView: webView, html: html)
    }
    
    // Convertir un NSAttributedString en HTML
    private func attributedStringToHtml(_ attributedString: NSAttributedString) -> String? {
        guard attributedString.length > 0 else {
            return "<p><br></p>"
        }
        
        do {
            let documentAttributes = [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.html]
            let htmlData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), 
                                                    documentAttributes: documentAttributes)
            if let htmlString = String(data: htmlData, encoding: .utf8) {
                return htmlString
            }
        } catch {
            print("Erreur de conversion NSAttributedString → HTML: \(error)")
        }
        
        return "<p><br></p>"
    }
    
    /// Créer le HTML pour initialiser TinyMCE
    private func createTinyMCEHtml() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Éditeur de signature</title>
            
            <!-- Chargement de TinyMCE depuis les ressources locales -->
            <script src="tinymce/js/tinymce/tinymce.min.js"></script>
            
            <style>
                html, body {
                    height: 100%;
                    margin: 0;
                    padding: 0;
                    overflow: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                }
                #editor {
                    height: 100%;
                    width: 100%;
                    display: block;
                    padding: 0;
                    margin: 0;
                    border: none;
                }
                .tox-tinymce {
                    border: none !important;
                }
                .tox-statusbar {
                    display: none !important;
                }
            </style>
        </head>
        <body>
            <!-- Textarea pour l'éditeur -->
            <textarea id="editor"></textarea>
            
            <script>
                // Variables globales
                let editor = null;
                let isEditorReady = false;
                
                // Fonction pour envoyer des messages à Swift
                function sendToSwift(type, data = {}) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tinyMCECallback) {
                        const message = { type, ...data };
                        window.webkit.messageHandlers.tinyMCECallback.postMessage(message);
                    }
                }
                
                // Fonction de log avec envoi à Swift
                function log(message) {
                    console.log(message);
                    sendToSwift('log', { message });
                }
                
                // Intercepter les erreurs JavaScript
                window.onerror = function(message, source, lineno, colno, error) {
                    sendToSwift('error', { message, source, lineno, colno });
                    return true;
                };
                
                // Initialiser TinyMCE
                document.addEventListener('DOMContentLoaded', function() {
                    log('Initialisation de TinyMCE...');
                    
                    if (typeof tinymce === 'undefined') {
                        log('Erreur: TinyMCE n\\'est pas chargé');
                        return;
                    }
                    
                    // Configuration de TinyMCE avec des plugins de base
                    tinymce.init({
                        selector: '#editor',
                        plugins: 'inlinecss',
                        // Barre d'outils personnalisée pour l'éditeur de signature
                        toolbar: 'undo redo | blocks fontfamily fontsize | bold italic underline strikethrough | ' + 
                                 'link image media table | align lineheight | bullist numlist | ' + 
                                 'emoticons charmap | removeformat',
                        menubar: false,
                        statusbar: false,
                        height: '100%',
                        width: '100%',
                        branding: false,
                        resize: false,
                        elementpath: false,
                        promotion: false,
                        paste_data_images: true,
                        convert_urls: false,
                        relative_urls: false,
                        remove_script_host: false,
                        // Options pour le chargement rapide et l'apparence
                        skin: 'oxide',
                        icons: 'default',
                        setup: function(ed) {
                            editor = ed;
                            
                            // Quand l'éditeur est initialisé
                            editor.on('init', function() {
                                isEditorReady = true;
                                log('TinyMCE initialisé avec succès');
                                sendToSwift('editorReady');
                                
                                // Mettre le focus sur l'éditeur
                                setTimeout(function() {
                                    editor.focus();
                                }, 100);
                            });
                            
                            // Quand le contenu change
                            editor.on('input change keyup paste ExecCommand', function() {
                                if (isEditorReady) {
                                    const content = editor.getContent();
                                    sendToSwift('contentChange', { content });
                                }
                            });
                        }
                    }).catch(function(err) {
                        log('Erreur d\\'initialisation: ' + err.message);
                    });
                });
                
                // Fonction pour définir le contenu HTML
                function setEditorContent(html) {
                    if (editor && isEditorReady) {
                        editor.setContent(html);
                        log('Contenu défini: ' + html.length + ' caractères');
                        return true;
                    } else {
                        log('Éditeur non prêt, impossible de définir le contenu');
                        return false;
                    }
                }
                
                // Fonction pour récupérer le contenu HTML
                function getEditorContent() {
                    if (editor && isEditorReady) {
                        return editor.getContent();
                    } else {
                        return "";
                    }
                }
            </script>
        </body>
        </html>
        """
    }
}

/// Une vue qui intègre l'éditeur TinyMCE avec du HTML
struct TinyMCEEditorView: View {
    @Binding var htmlContent: String
    var onSave: (() -> Void)?
    
    var body: some View {
        RichTextEditor(htmlContent: $htmlContent, onHtmlChange: { newContent in
            // Gestion optionnelle des changements de contenu
            print("Contenu HTML modifié: \(newContent.prefix(20))...")
        })
        .frame(minHeight: 300)
    }
}

/// Une vue qui intègre l'éditeur TinyMCE avec du NSAttributedString
struct TinyMCEAttributedEditorView: View {
    @Binding var attributedText: NSAttributedString
    var onSave: (() -> Void)?
    
    var body: some View {
        RichTextEditor(attributedText: $attributedText, onTextChange: { newText in
            // Gestion optionnelle des changements de contenu
            print("Contenu AttributedString modifié: \(newText.string.prefix(20))...")
        })
        .frame(minHeight: 300)
    }
}
