import SwiftUI
import WebKit

struct HtmlPreview: NSViewRepresentable {
    var htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        // Configuration simplifiée pour éviter les problèmes de WebKit
        let preferences = WKPreferences()
        
        // Utiliser la nouvelle API pour désactiver JavaScript
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = false
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.defaultWebpagePreferences = webpagePreferences
        configuration.suppressesIncrementalRendering = false
        
        // Créer la vue web avec la configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        
        // Désactiver les fonctionnalités avancées
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        
        // Définir le délégué pour gérer les erreurs
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Simplifier le contenu HTML pour éviter les problèmes de rendu
        let safeHtmlContent = sanitizeHtml(htmlContent)
        
        // Charger le contenu HTML de manière sécurisée
        DispatchQueue.main.async {
            // Forcer le fond blanc pour la prévisualisation
            webView.setValue(true, forKey: "drawsBackground")
            webView.setValue(NSColor.white, forKey: "backgroundColor")
            
            // Utiliser loadHTMLString avec un baseURL nil pour éviter les problèmes réseau
            webView.loadHTMLString(safeHtmlContent, baseURL: nil)
        }
    }
    
    // Fonction pour nettoyer et simplifier le HTML
    private func sanitizeHtml(_ html: String) -> String {
        // Vérifier si le HTML contient déjà les balises de base
        var safeHtml = html
        
        // Ajouter un style CSS minimal
        let cssStyle = """
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            margin: 0;
            padding: 10px;
            word-wrap: break-word;
            overflow-wrap: break-word;
            background-color: white !important;
            color: black !important;
        }
        img {
            max-width: 100%;
            height: auto;
        }
        * {
            color: inherit;
        }
        </style>
        """
        
        // S'assurer que le HTML est bien formé
        if !safeHtml.contains("<html") {
            safeHtml = "<html><head>\(cssStyle)</head><body>\(safeHtml)</body></html>"
        } else if !safeHtml.contains("<head") {
            safeHtml = safeHtml.replacingOccurrences(of: "<html>", with: "<html><head>\(cssStyle)</head>")
        } else if !safeHtml.contains("<style") {
            // Insérer le CSS dans la balise head existante
            if let headEndRange = safeHtml.range(of: "</head>") {
                safeHtml.insert(contentsOf: cssStyle, at: headEndRange.lowerBound)
            }
        }
        
        return safeHtml
    }
    
    // Coordinateur pour gérer les événements de navigation
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HtmlPreview
        
        init(_ parent: HtmlPreview) {
            self.parent = parent
        }
        
        // Gérer les échecs de navigation
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
            
            // Charger un contenu de secours simple
            let fallbackHTML = """
            <html><body style="font-family: -apple-system; padding: 20px;">
            <p>Impossible d'afficher le contenu HTML.</p>
            <p>Erreur: \(error.localizedDescription)</p>
            </body></html>
            """
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }
        
        // Gérer la fin du chargement
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView content loaded successfully")
        }
    }
}

// Alternative plus simple utilisant NSTextView pour les cas où WebKit pose problème
struct SimpleHtmlPreview: NSViewRepresentable {
    var htmlContent: String
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.drawsBackground = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isSelectable = true
        return textView
    }
    
    func updateNSView(_ textView: NSTextView, context: Context) {
        // Convertir le HTML en NSAttributedString
        if let data = htmlContent.data(using: .utf8) {
            do {
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
                let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
                DispatchQueue.main.async {
                    textView.textStorage?.setAttributedString(attributedString)
                }
            } catch {
                print("Erreur lors de la conversion HTML: \(error)")
                DispatchQueue.main.async {
                    textView.string = "Erreur d'affichage: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Prévisualisation dans une fenêtre plus grande
struct HtmlPreviewWindow: View {
    var htmlContent: String
    @Environment(\.presentationMode) var presentationMode
    @State private var useSimplePreview = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Mode simplifié", isOn: $useSimplePreview)
                    .padding(.leading)
                
                Spacer()
                
                Button("Fermer") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            if useSimplePreview {
                SimpleHtmlPreview(htmlContent: htmlContent)
                    .padding()
            } else {
                HtmlPreview(htmlContent: htmlContent)
                    .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
} 