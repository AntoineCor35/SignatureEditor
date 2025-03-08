import Foundation
import SwiftUI
import Combine

class SignatureViewModel: ObservableObject {
    @Published var signatures: [Signature] = []
    @Published var selectedSignatureID: UUID?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isEditingName: Bool = false
    @Published var showDirectorySelector: Bool = false
    @Published var showPermissionsExplanation: Bool = false
    
    var selectedSignature: Signature? {
        guard let id = selectedSignatureID else { return nil }
        return signatures.first { $0.id == id }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var isFirstLaunch: Bool {
        let key = "HasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: key)
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: key)
        }
        return !hasLaunched
    }
    
    init() {
        // Différer le chargement pour être sûr que l'interface est prête
        DispatchQueue.main.async {
            if self.isFirstLaunch {
                self.showPermissionsExplanation = true
            } else {
                self.loadSignatures()
            }
        }
    }
    
    func loadSignatures() {
        isLoading = true
        errorMessage = nil
        
        // Utiliser un thread en arrière-plan pour le chargement des données
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loadedSignatures = Signature.loadAllSignatures()
            
            // Revenir sur le thread principal pour mettre à jour l'interface
            DispatchQueue.main.async {
                self?.signatures = loadedSignatures
                self?.isLoading = false
                
                // Sélectionne automatiquement la première signature si aucune n'est sélectionnée
                if self?.selectedSignatureID == nil && !loadedSignatures.isEmpty {
                    self?.selectedSignatureID = loadedSignatures.first?.id
                }
                
                if loadedSignatures.isEmpty {
                    self?.errorMessage = "Aucune signature trouvée. Pour des raisons de sécurité macOS, vous devez sélectionner manuellement le dossier des signatures (~/Library/Mail/V10/MailData/Signatures)."
                    self?.showError = true
                    self?.showDirectorySelector = true
                }
            }
        }
    }
    
    func closePermissionsExplanation() {
        showPermissionsExplanation = false
        loadSignatures()
    }
    
    func selectSignaturesDirectoryManually() {
        // S'assurer que nous sommes sur le thread principal pour l'interface utilisateur
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.selectSignaturesDirectoryManually()
            }
            return
        }
        
        // Lance la sélection manuelle (qui doit être sur le thread principal)
        let _ = Signature.selectSignaturesDirectoryManually()
        
        // Recharger les signatures après la sélection manuelle
        self.loadSignatures()
    }
    
    // Méthode originale pour rétrocompatibilité
    func updateSignature(id: UUID, content: NSAttributedString) {
        guard let index = signatures.firstIndex(where: { $0.id == id }) else { return }
        
        signatures[index].content = content
        signatures[index].isDirty = true
        
        // Mettre à jour le HTML
        do {
            guard let htmlData = try? content.data(
                from: NSRange(location: 0, length: content.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            ),
            let htmlString = String(data: htmlData, encoding: .utf8) else {
                errorMessage = "Impossible de convertir le contenu en HTML"
                showError = true
                return
            }
            
            signatures[index].htmlContent = htmlString
        }
    }
    
    // Méthode pour mettre à jour à la fois le contenu et le HTML d'une signature
    func updateSignature(id: UUID, content: NSAttributedString, htmlContent: String) {
        guard let index = signatures.firstIndex(where: { $0.id == id }) else { return }
        
        signatures[index].content = content
        signatures[index].htmlContent = htmlContent
        signatures[index].isDirty = true
    }
    
    func updateSignatureName(id: UUID, name: String) {
        guard let index = signatures.firstIndex(where: { $0.id == id }) else { return }
        
        signatures[index].name = name
        signatures[index].isDirty = true
    }
    
    func saveSignature(id: UUID) {
        guard let index = signatures.firstIndex(where: { $0.id == id }) else { return }
        
        let signature = signatures[index]
        
        // Effectuer la sauvegarde en arrière-plan
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Vérifier le format du fichier de signature (mailsignature ou webarchive)
                let fileExtension = signature.fileURL.pathExtension.lowercased()
                let isValidFormat = fileExtension == "mailsignature" || fileExtension == "webarchive"
                print("Format du fichier signature: \(fileExtension), format valide: \(isValidFormat)")
                
                if !isValidFormat {
                    print("ATTENTION: Le fichier signature n'a pas l'extension .mailsignature ou .webarchive")
                }
                
                // DIAGNOSTIC: Vérifier le contenu actuel du fichier avant modification
                if FileManager.default.fileExists(atPath: signature.fileURL.path) {
                    print("VÉRIFICATION DU CONTENU AVANT MODIFICATION...")
                    
                    // Lire le contenu actuel du fichier
                    do {
                        let currentData = try Data(contentsOf: signature.fileURL)
                        var currentHTML = ""
                        
                        if fileExtension == "webarchive" {
                            // Si c'est un webarchive, extraire le HTML
                            if let webarchive = try PropertyListSerialization.propertyList(from: currentData, options: [], format: nil) as? [String: Any],
                               let mainResource = webarchive["WebMainResource"] as? [String: Any],
                               let webResourceData = mainResource["WebResourceData"] as? Data,
                               let htmlString = String(data: webResourceData, encoding: .utf8) {
                                currentHTML = htmlString
                            }
                        } else {
                            // Si c'est un HTML direct
                            if let htmlString = String(data: currentData, encoding: .utf8) {
                                currentHTML = htmlString
                            }
                        }
                        
                        // Hash du contenu actuel pour comparaison
                        let currentHashValue = currentHTML.hash
                        let newHashValue = signature.htmlContent.hash
                        
                        print("Hash du contenu actuel: \(currentHashValue)")
                        print("Hash du nouveau contenu: \(newHashValue)")
                        print("Les contenus sont différents: \(currentHashValue != newHashValue)")
                        
                        // Vérifier taille du fichier
                        print("Taille du fichier actuel: \(currentData.count) octets")
                        
                        // Vérifier les attributs du fichier
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: signature.fileURL.path) {
                            print("Attributs du fichier: \(attributes)")
                            if let immutable = attributes[.immutable] as? Bool {
                                print("Fichier en lecture seule: \(immutable)")
                            }
                        }
                    } catch {
                        print("Erreur lors de la lecture du fichier pour diagnostic: \(error)")
                    }
                }
                
                // Sauvegarder la signature (la méthode save() s'occupe de rendre le fichier modifiable puis en lecture seule)
                try signature.save()
                
                // DIAGNOSTIC: Vérifier si le fichier a bien été modifié
                print("VÉRIFICATION APRÈS MODIFICATION...")
                if let newData = try? Data(contentsOf: signature.fileURL) {
                    print("Le fichier existe toujours et sa taille est: \(newData.count) octets")
                    
                    // Vérifier que le fichier est bien en lecture seule après la sauvegarde
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: signature.fileURL.path),
                       let immutable = attributes[.immutable] as? Bool {
                        print("Fichier en lecture seule après sauvegarde: \(immutable)")
                    }
                }
                
                // Mettre à jour l'état sur le thread principal
                DispatchQueue.main.async {
                    if let index = self?.signatures.firstIndex(where: { $0.id == id }) {
                        self?.signatures[index].isDirty = false
                    }
                }
            } catch {
                // Gérer l'erreur sur le thread principal
                DispatchQueue.main.async {
                    self?.errorMessage = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
        }
    }
    
    func createNewSignature(name: String, content: NSAttributedString) {
        // Effectuer la création en arrière-plan
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let newSignature = try Signature.createNewSignature(name: name, content: content)
                
                // Mettre à jour l'interface sur le thread principal
                DispatchQueue.main.async {
                    self?.signatures.append(newSignature)
                    self?.selectedSignatureID = newSignature.id
                }
            } catch {
                // Gérer l'erreur sur le thread principal
                DispatchQueue.main.async {
                    self?.errorMessage = "Erreur lors de la création: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
        }
    }
    
    func deleteSignature(id: UUID) {
        // Suppression de l'index non utilisé et garder seulement la signature
        guard let signature = signatures.first(where: { $0.id == id }) else { return }
        
        let fileURL = signature.fileURL
        
        // Effectuer la suppression en arrière-plan
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Vérifier le format du fichier de signature
                let fileExtension = fileURL.pathExtension.lowercased()
                let isValidFormat = fileExtension == "mailsignature" || fileExtension == "webarchive"
                print("Suppression du fichier signature: \(fileURL.lastPathComponent), format valide: \(isValidFormat)")
                
                // Rendre le fichier modifiable avant suppression
                try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: fileURL.path)
                
                // Supprimer le fichier
                try FileManager.default.removeItem(at: fileURL)
                print("Fichier signature supprimé avec succès")
                
                // Mettre à jour le modèle sur le thread principal
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let index = self.signatures.firstIndex(where: { $0.id == id }) {
                        self.signatures.remove(at: index)
                        
                        // Si la signature supprimée était sélectionnée, sélectionner une autre
                        if self.selectedSignatureID == id {
                            self.selectedSignatureID = self.signatures.isEmpty ? nil : self.signatures.first?.id
                        }
                    }
                }
            } catch {
                // Gérer l'erreur sur le thread principal
                DispatchQueue.main.async {
                    self?.errorMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
        }
    }
    
    func importSignature(from fileURL: URL) {
        // TODO: Implémenter l'importation de signature externe
    }
    
    // Analyse le fichier AllSignatures.plist
    func analyzeAllSignaturesPlist() {
        // Utiliser un thread en arrière-plan pour l'analyse
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Appeler la méthode d'analyse
            Signature.analyzeAllSignaturesPlist()
            
            // Revenir sur le thread principal
            DispatchQueue.main.async {
                self?.isLoading = false
            }
        }
    }
} 