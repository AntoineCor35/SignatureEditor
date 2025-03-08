import SwiftUI
import WebKit
import Combine

// Éditeur HTML utilisant CodeMirror via WebView
struct HtmlEditor: NSViewRepresentable {
    @Binding var htmlContent: String
    
    // Rendre les propriétés publiques
    public init(htmlContent: Binding<String>) {
        self._htmlContent = htmlContent
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // HTML contenant CodeMirror
    private let codeMirrorHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>CodeMirror HTML Editor</title>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/codemirror.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/xml/xml.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/javascript/javascript.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/css/css.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/htmlmixed/htmlmixed.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/edit/closetag.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/edit/matchtags.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/xml-fold.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/edit/closebrackets.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/show-hint.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/xml-hint.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/html-hint.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/display/placeholder.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/js-beautify/1.14.7/beautify-html.min.js"></script>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/codemirror.min.css">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/show-hint.min.css">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/theme/monokai.min.css">
        <style>
            body, html {
                margin: 0;
                padding: 0;
                height: 100%;
                overflow: hidden;
            }
            .CodeMirror {
                height: 100vh;
                font-family: "SF Mono", Monaco, Menlo, Consolas, monospace;
                font-size: 13px;
                line-height: 1.5;
            }
        </style>
    </head>
    <body>
        <textarea id="code-editor"></textarea>
        <script>
            // Initialiser CodeMirror
            var editor = CodeMirror.fromTextArea(document.getElementById("code-editor"), {
                mode: "htmlmixed",
                lineNumbers: true,
                theme: "default",
                autoCloseTags: true,
                autoCloseBrackets: true,
                matchTags: {bothTags: true},
                extraKeys: {"Ctrl-Space": "autocomplete"},
                placeholder: "Entrez votre code HTML ici...",
                lineWrapping: true,
                indentUnit: 4,
                tabSize: 4,
                smartIndent: true,
                autofocus: true
            });
            
            // Communication avec Swift
            editor.on("change", function() {
                // Notifier Swift des changements
                try {
                    window.webkit.messageHandlers.htmlContentChanged.postMessage(editor.getValue());
                } catch (err) {
                    console.error("Erreur lors de l'envoi du message à Swift:", err);
                }
            });
            
            // Fonction pour mettre à jour le contenu depuis Swift
            function updateContent(content) {
                editor.setValue(content);
            }
            
            // Ajouter la fonctionnalité de formatage HTML (utilisant js-beautify)
            CodeMirror.defineExtension("autoFormatRange", function(from, to) {
                var cm = this;
                var text = cm.getRange(from, to);
                var formattedCode = html_beautify(text, {
                    indent_size: 4,
                    wrap_line_length: 0,
                    preserve_newlines: true,
                    max_preserve_newlines: 2,
                    indent_inner_html: true,
                    extra_liners: []
                });
                
                cm.operation(function() {
                    cm.replaceRange(formattedCode, from, to);
                });
            });
            
            // Fonction pour formater le HTML
            function formatHTML() {
                var totalLines = editor.lineCount();
                var lastLineLength = editor.getLine(totalLines - 1).length;
                editor.autoFormatRange(
                    {line: 0, ch: 0},
                    {line: totalLines - 1, ch: lastLineLength}
                );
                
                // Notifier Swift du changement après le formatage
                try {
                    window.webkit.messageHandlers.htmlContentChanged.postMessage(editor.getValue());
                } catch (err) {
                    console.error("Erreur lors de l'envoi du message à Swift:", err);
                }
            }
            
            // Fonction pour obtenir le contenu actuel
            function getContent() {
                return editor.getValue();
            }
        </script>
    </body>
    </html>
    """
    
    func makeNSView(context: Context) -> WKWebView {
        // Configuration de la WebView
        let preferences = WKPreferences()
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        // Activer JavaScript (nécessaire pour CodeMirror)
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        
        // Configurer la communication entre JavaScript et Swift
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "htmlContentChanged")
        configuration.userContentController = userContentController
        
        // Créer la WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Charger le HTML de CodeMirror
        webView.loadHTMLString(codeMirrorHTML, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Mettre à jour le contenu de l'éditeur CodeMirror si nécessaire
        if context.coordinator.lastContent != htmlContent {
            context.coordinator.lastContent = htmlContent
            let escapedContent = htmlContent.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            
            webView.evaluateJavaScript("updateContent(\"\(escapedContent)\");", completionHandler: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinateur pour gérer la communication JavaScript <-> Swift
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HtmlEditor
        var lastContent: String = ""
        
        init(_ parent: HtmlEditor) {
            self.parent = parent
        }
        
        // Gérer les messages de JavaScript vers Swift
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "htmlContentChanged", let content = message.body as? String {
                DispatchQueue.main.async {
                    if self.lastContent != content {
                        self.lastContent = content
                        self.parent.htmlContent = content
                    }
                }
            }
        }
        
        // Navigation terminée
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Initialiser l'éditeur avec le contenu HTML actuel
            let escapedContent = parent.htmlContent.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            
            webView.evaluateJavaScript("updateContent(\"\(escapedContent)\");", completionHandler: nil)
        }
    }
}

// Extension utilitaire pour formater le HTML via CodeMirror
extension HtmlEditor {
    // Fonction pour formater le HTML à partir de Swift
    func formatHtml(_ webView: WKWebView) {
        webView.evaluateJavaScript("formatHTML();", completionHandler: nil)
    }
    
    // Fonction pour obtenir le contenu actuel
    func getContent(_ webView: WKWebView, completion: @escaping (String?) -> Void) {
        webView.evaluateJavaScript("getContent();") { result, error in
            if let error = error {
                print("Erreur lors de la récupération du contenu: \(error)")
                completion(nil)
            } else if let content = result as? String {
                completion(content)
            } else {
                completion(nil)
            }
        }
    }
} 