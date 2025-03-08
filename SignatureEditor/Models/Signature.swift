import Foundation
import WebKit
import AppKit

struct Signature: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    let filename: String
    let signatureID: String
    var name: String
    var content: NSAttributedString
    var htmlContent: String
    var isDirty: Bool = false
    
    static func == (lhs: Signature, rhs: Signature) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: UUID = UUID(), fileURL: URL, signatureID: String, name: String, content: NSAttributedString, htmlContent: String) {
        self.id = id
        self.fileURL = fileURL
        self.filename = fileURL.lastPathComponent
        self.signatureID = signatureID
        self.name = name
        self.content = content
        self.htmlContent = htmlContent
    }
}

// Extension pour gérer les opérations de fichier
extension Signature {
    
    // Stocke le dossier sélectionné manuellement par l'utilisateur
    private static var userSelectedSignaturesDirectory: URL?
    
    // Méthode de diagnostic pour analyser le fichier AllSignatures.plist
    static func analyzeAllSignaturesPlist() {
        guard let signaturesDir = findSignaturesDirectory() else {
            print("Dossier de signatures non trouvé")
            return
        }
        
        let allSignaturesPlistURL = signaturesDir.appendingPathComponent("AllSignatures.plist")
        if !FileManager.default.fileExists(atPath: allSignaturesPlistURL.path) {
            print("Fichier AllSignatures.plist non trouvé dans \(signaturesDir.path)")
            return
        }
        
        print("Analyse du fichier AllSignatures.plist...")
        
        do {
            let plistData = try Data(contentsOf: allSignaturesPlistURL)
            if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                print("Fichier AllSignatures.plist chargé avec succès")
                print("Taille du fichier: \(plistData.count) octets")
                
                // Afficher la structure complète
                printPlistStructure(plist: plist)
                
                // Rechercher spécifiquement les signatures
                if let signaturesByAccount = plist["SignaturesByAccountID"] as? [String: Any] {
                    print("\nComptes trouvés: \(signaturesByAccount.keys.joined(separator: ", "))")
                    
                    var totalSignatures = 0
                    
                    for (accountID, accountSignatures) in signaturesByAccount {
                        if let accountDict = accountSignatures as? [String: Any],
                           let signaturesList = accountDict["SignaturesList"] as? [[String: Any]] {
                            print("\nCompte \(accountID): \(signaturesList.count) signatures")
                            totalSignatures += signaturesList.count
                            
                            // Afficher les détails de chaque signature
                            for (index, signature) in signaturesList.enumerated() {
                                print("  Signature #\(index+1):")
                                for (key, value) in signature {
                                    print("    - \(key): \(value)")
                                }
                                
                                // Vérifier si le fichier de signature existe
                                if let signatureID = signature["SignatureID"] as? String {
                                    let signatureURL = signaturesDir.appendingPathComponent("\(signatureID).mailsignature")
                                    let webarchiveURL = signaturesDir.appendingPathComponent("\(signatureID).webarchive")
                                    
                                    if FileManager.default.fileExists(atPath: signatureURL.path) {
                                        print("    ✅ Fichier trouvé: \(signatureURL.lastPathComponent)")
                                    } else if FileManager.default.fileExists(atPath: webarchiveURL.path) {
                                        print("    ✅ Fichier trouvé: \(webarchiveURL.lastPathComponent)")
                                    } else {
                                        print("    ❌ AUCUN FICHIER TROUVÉ pour cette signature!")
                                    }
                                }
                            }
                        }
                    }
                    
                    print("\nTotal des signatures trouvées: \(totalSignatures)")
                } else {
                    print("Aucune signature trouvée dans le fichier AllSignatures.plist")
                }
            } else {
                print("Impossible de parser le fichier AllSignatures.plist comme un dictionnaire")
            }
        } catch {
            print("Erreur lors de l'analyse du fichier AllSignatures.plist: \(error)")
        }
    }
    
    // Permet à l'utilisateur de sélectionner manuellement le dossier des signatures
    // Cette méthode ne doit JAMAIS être appelée directement depuis un thread secondaire
    static func selectSignaturesDirectoryManually() -> URL? {
        // Règle de sécurité : cette méthode doit être appelée depuis le thread principal
        precondition(Thread.isMainThread, "Cette méthode doit être appelée sur le thread principal")
        
        let openPanel = NSOpenPanel()
        openPanel.title = "Sélectionnez le dossier des signatures Mail"
        openPanel.message = "Naviguez vers ~/Library/Mail/V10/MailData/Signatures"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = false
        
        // Essayer de définir le répertoire initial sur le dossier des signatures
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let suggestedPath = homeDir.appendingPathComponent("Library/Mail/V10/MailData/Signatures")
        if FileManager.default.fileExists(atPath: suggestedPath.path) {
            openPanel.directoryURL = suggestedPath
        }
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            print("Dossier sélectionné manuellement: \(selectedURL.path)")
            
            // Créer un signet de sécurité pour ce dossier (pour contourner le sandbox)
            do {
                let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "SignaturesDirectoryBookmark")
                print("Signet de sécurité créé avec succès pour le dossier des signatures")
            } catch {
                print("Erreur lors de la création du signet de sécurité: \(error)")
            }
            
            userSelectedSignaturesDirectory = selectedURL
            
            // Vérifions s'il contient des fichiers .mailsignature
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: selectedURL, includingPropertiesForKeys: nil)
                
                // Afficher TOUS les fichiers pour diagnostic
                print("TOUS les fichiers dans le dossier sélectionné:")
                for file in contents {
                    print(" - \(file.lastPathComponent) (extension: \(file.pathExtension))")
                }
                
                // Détecter si ce sont de vrais fichiers de signature
                let mailsignatureFiles = contents.filter { $0.pathExtension.lowercased() == "mailsignature" }
                let webarchiveFiles = contents.filter { $0.pathExtension.lowercased() == "webarchive" }
                let plistFiles = contents.filter { $0.pathExtension.lowercased() == "plist" }
                
                print("Fichiers .mailsignature: \(mailsignatureFiles.count)")
                print("Fichiers .webarchive: \(webarchiveFiles.count)")
                print("Fichiers .plist: \(plistFiles.count)")
                
                // Essayons de déterminer le format réel des signatures Mail
                let potentialSignatureFiles = contents.filter { 
                    let filename = $0.lastPathComponent
                    return filename.contains("signature") || filename.count >= 30
                }
                
                print("Fichiers potentiels de signature: \(potentialSignatureFiles.count)")
                for file in potentialSignatureFiles {
                    print(" - \(file.lastPathComponent)")
                }
                
                // Si aucun fichier .mailsignature n'est trouvé, mais qu'il y a des .webarchive, modifions notre approche
                if mailsignatureFiles.isEmpty && !webarchiveFiles.isEmpty {
                    print("Nous allons utiliser les fichiers .webarchive au lieu des .mailsignature")
                }
            } catch {
                print("Erreur lors de la lecture du dossier sélectionné: \(error)")
            }
            
            return selectedURL
        }
        
        return nil
    }
    
    // Recherche le bon dossier de signatures dans Mail
    static func findSignaturesDirectory() -> URL? {
        // Si l'utilisateur a déjà sélectionné un dossier, l'utiliser en priorité
        if let userDir = userSelectedSignaturesDirectory {
            print("Utilisation du dossier de signatures sélectionné manuellement: \(userDir.path)")
            
            // Vérifier si nous avons besoin de réactiver le signet de sécurité
            if !userDir.startAccessingSecurityScopedResource() {
                print("Impossible d'accéder au dossier avec le signet de sécurité existant")
                
                // Essayer de restaurer le signet
                if let bookmarkData = UserDefaults.standard.data(forKey: "SignaturesDirectoryBookmark") {
                    do {
                        var isStale = false
                        let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                        
                        if isStale {
                            print("Le signet est périmé, il faut le recréer")
                            // Demander à l'utilisateur de sélectionner à nouveau le dossier
                            return nil
                        } else {
                            if resolvedURL.startAccessingSecurityScopedResource() {
                                print("Signet restauré avec succès")
                                userSelectedSignaturesDirectory = resolvedURL
                                return resolvedURL
                            } else {
                                print("Impossible d'accéder au dossier même après restauration du signet")
                            }
                        }
                    } catch {
                        print("Erreur lors de la restauration du signet: \(error)")
                    }
                }
            } else {
                print("Accès au dossier sécurisé réussi")
                return userDir
            }
        }
        
        print("Recherche du dossier de signatures...")
        
        // Essayons d'accéder au chemin complet avec les droits d'accès
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let directMailPath = homeDir.appendingPathComponent("Library/Mail/V10/MailData/Signatures")
        
        var isDir: ObjCBool = false
        
        print("Vérification du chemin direct: \(directMailPath.path)")
        
        if FileManager.default.fileExists(atPath: directMailPath.path, isDirectory: &isDir), isDir.boolValue {
            print("Le dossier existe, vérifions les permissions...")
            
            // Vérifions les permissions
            if FileManager.default.isReadableFile(atPath: directMailPath.path) {
                print("Le dossier est lisible!")
                
                // Vérifions s'il contient des fichiers .mailsignature
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: directMailPath, includingPropertiesForKeys: nil)
                    let signatures = contents.filter { $0.pathExtension.lowercased() == "mailsignature" }
                    
                    // Si aucune signature .mailsignature, essayons .webarchive
                    if signatures.isEmpty {
                        let webarchives = contents.filter { $0.pathExtension.lowercased() == "webarchive" }
                        if !webarchives.isEmpty {
                            print("Trouvé \(webarchives.count) fichiers .webarchive au lieu de .mailsignature")
                            return directMailPath
                        }
                    } else {
                        print("Nombre de signatures trouvées: \(signatures.count)")
                        for signature in signatures {
                            print(" - \(signature.lastPathComponent)")
                        }
                        return directMailPath
                    }
                    
                    // Si nous n'avons trouvé ni .mailsignature ni .webarchive, affichons tous les fichiers
                    print("Aucun fichier de signature standard trouvé. Contenu du dossier:")
                    for file in contents {
                        print(" - \(file.lastPathComponent) (extension: \(file.pathExtension))")
                    }
                } catch {
                    print("Erreur lors de la lecture du dossier: \(error)")
                }
            } else {
                print("Le dossier n'est pas lisible! Problème de permissions.")
            }
        } else {
            print("Le chemin direct n'existe pas ou n'est pas un dossier.")
        }
        
        // Méthode alternative avec les URLs de système
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        
        print("Recherche via les URLs système: \(libraryURL.path)")
        
        // Définir spécifiquement le chemin pour Mail V10 que vous utilisez
        let directPath = libraryURL.appendingPathComponent("Mail/V10/MailData/Signatures")
        isDir = false
        
        print("Vérification du chemin via libraryURL: \(directPath.path)")
        
        if FileManager.default.fileExists(atPath: directPath.path, isDirectory: &isDir), isDir.boolValue {
            print("Dossier de signatures trouvé directement: \(directPath.path)")
            
            // Vérifions s'il contient des fichiers .mailsignature
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: directPath, includingPropertiesForKeys: nil)
                let signatures = contents.filter { $0.pathExtension.lowercased() == "mailsignature" }
                
                // Si aucune signature .mailsignature, essayons .webarchive
                if signatures.isEmpty {
                    let webarchives = contents.filter { $0.pathExtension.lowercased() == "webarchive" }
                    if !webarchives.isEmpty {
                        print("Trouvé \(webarchives.count) fichiers .webarchive au lieu de .mailsignature")
                        return directPath
                    }
                } else {
                    print("Nombre de signatures trouvées via libraryURL: \(signatures.count)")
                    return directPath
                }
                
                // Si nous n'avons trouvé ni .mailsignature ni .webarchive, affichons tous les fichiers
                print("Aucun fichier de signature standard trouvé. Contenu du dossier:")
                for file in contents {
                    print(" - \(file.lastPathComponent) (extension: \(file.pathExtension))")
                }
            } catch {
                print("Erreur lors de la lecture du dossier via libraryURL: \(error)")
            }
        }
        
        // IMPORTANT: Ne PAS demander à l'utilisateur de sélectionner un dossier automatiquement
        // Car nous sommes peut-être sur un thread secondaire
        // Le viewModel s'occupera de demander à l'utilisateur de sélectionner le dossier si nécessaire
        print("Aucun dossier de signatures trouvé automatiquement.")
        return nil
    }
    
    // Charge toutes les signatures depuis le dossier de signatures
    static func loadAllSignatures() -> [Signature] {
        var signatures = [Signature]()
        guard let signaturesDir = findSignaturesDirectory() else {
            print("Dossier de signatures non trouvé")
            return signatures
        }
        
        // Vérifier si AllSignatures.plist existe
        let allSignaturesPlistURL = signaturesDir.appendingPathComponent("AllSignatures.plist")
        if FileManager.default.fileExists(atPath: allSignaturesPlistURL.path) {
            print("Fichier AllSignatures.plist trouvé, tentative de chargement...")
            
            // Charger les signatures depuis AllSignatures.plist
            if let loadedSignatures = loadSignaturesFromAllSignaturesPlist(plistURL: allSignaturesPlistURL, signaturesDir: signaturesDir) {
                signatures.append(contentsOf: loadedSignatures)
                print("Signatures chargées depuis AllSignatures.plist: \(loadedSignatures.count)")
                
                // Si nous avons réussi à charger des signatures, retourner le résultat
                if !signatures.isEmpty {
                    // Libérer l'accès au dossier sécurisé si nécessaire
                    if let userDir = userSelectedSignaturesDirectory {
                        userDir.stopAccessingSecurityScopedResource()
                        print("Accès au dossier sécurisé terminé")
                    }
                    return signatures
                }
            }
        }
        
        // Si AllSignatures.plist n'existe pas ou est vide, continuer avec la méthode traditionnelle
        // Essayer d'abord avec les fichiers .mailsignature
        let fileURLs = (try? FileManager.default.contentsOfDirectory(at: signaturesDir, includingPropertiesForKeys: nil, options: [])) ?? []
        var signatureURLs = fileURLs.filter { $0.pathExtension.lowercased() == "mailsignature" }
        
        // Si aucun fichier .mailsignature n'est trouvé, essayer avec .webarchive
        if signatureURLs.isEmpty {
            signatureURLs = fileURLs.filter { $0.pathExtension.lowercased() == "webarchive" }
            print("Utilisation des fichiers .webarchive au lieu de .mailsignature")
        }
        
        if signatureURLs.isEmpty {
            print("Aucun fichier de signature trouvé! Voici tous les fichiers présents:")
            for fileURL in fileURLs {
                let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = fileAttributes?[.size] as? Int ?? 0
                print(" - \(fileURL.lastPathComponent) (extension: \(fileURL.pathExtension)) taille: \(fileSize)")
                
                // Pour les fichiers sans extension claire, essayons de les lire pour voir leur contenu
                if fileURL.pathExtension.isEmpty || fileURL.pathExtension.count <= 2 {
                    if let data = try? Data(contentsOf: fileURL, options: .alwaysMapped),
                       let content = String(data: data.prefix(200), encoding: .utf8) {
                        print("   Aperçu: \(content.prefix(100))...")
                    }
                }
            }
            
            // Essayons en dernier recours de détecter les signatures par leur contenu
            print("Essai de détection de signatures par leur contenu...")
            for fileURL in fileURLs.filter({ !$0.lastPathComponent.hasSuffix(".plist") }) {
                if let signature = tryToLoadAsSignature(fileURL: fileURL, dirURL: signaturesDir) {
                    signatures.append(signature)
                    print("Signature détectée: \(signature.name)")
                }
            }
            
            // Libérer l'accès au dossier sécurisé si nécessaire
            if let userDir = userSelectedSignaturesDirectory {
                userDir.stopAccessingSecurityScopedResource()
                print("Accès au dossier sécurisé terminé")
            }
            
            return signatures
        }
        
        // Charger les signatures à partir des URLs trouvées
        for url in signatureURLs {
            if let signature = tryToLoadAsSignature(fileURL: url, dirURL: signaturesDir) {
                signatures.append(signature)
            }
        }
        
        // Libérer l'accès au dossier sécurisé si nécessaire
        if let userDir = userSelectedSignaturesDirectory {
            userDir.stopAccessingSecurityScopedResource()
            print("Accès au dossier sécurisé terminé")
        }
        
        return signatures
    }
    
    // Charge les signatures depuis le fichier AllSignatures.plist
    private static func loadSignaturesFromAllSignaturesPlist(plistURL: URL, signaturesDir: URL) -> [Signature]? {
        do {
            let plistData = try Data(contentsOf: plistURL)
            guard let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                print("Format de AllSignatures.plist invalide")
                return nil
            }
            
            // Afficher la structure du plist pour diagnostic
            printPlistStructure(plist: plist)
            
            var signatures: [Signature] = []
            
            // Structure attendue: SignaturesByAccountID -> AccountID -> SignaturesList -> [Signatures]
            if let signaturesByAccount = plist["SignaturesByAccountID"] as? [String: Any] {
                for (accountID, accountSignatures) in signaturesByAccount {
                    print("Traitement des signatures pour le compte: \(accountID)")
                    
                    if let accountSignaturesDict = accountSignatures as? [String: Any] {
                        // Afficher toutes les clés disponibles pour ce compte
                        print("  Clés disponibles pour ce compte: \(accountSignaturesDict.keys.joined(separator: ", "))")
                        
                        if let signaturesList = accountSignaturesDict["SignaturesList"] as? [[String: Any]] {
                            print("  Nombre de signatures trouvées: \(signaturesList.count)")
                            
                            for (index, signatureInfo) in signaturesList.enumerated() {
                                print("  Signature #\(index+1):")
                                // Afficher toutes les clés disponibles pour cette signature
                                print("    Clés disponibles: \(signatureInfo.keys.joined(separator: ", "))")
                                
                                if let signatureID = signatureInfo["SignatureID"] as? String {
                                    print("    ID: \(signatureID)")
                                    
                                    // Chercher le fichier de signature correspondant
                                    let signatureURL = signaturesDir.appendingPathComponent("\(signatureID).mailsignature")
                                    let webarchiveURL = signaturesDir.appendingPathComponent("\(signatureID).webarchive")
                                    
                                    var fileURL: URL? = nil
                                    if FileManager.default.fileExists(atPath: signatureURL.path) {
                                        fileURL = signatureURL
                                        print("    Fichier trouvé: \(signatureURL.lastPathComponent)")
                                    } else if FileManager.default.fileExists(atPath: webarchiveURL.path) {
                                        fileURL = webarchiveURL
                                        print("    Fichier trouvé: \(webarchiveURL.lastPathComponent)")
                                    } else {
                                        print("    AUCUN FICHIER TROUVÉ pour cette signature!")
                                    }
                                    
                                    if let fileURL = fileURL {
                                        if let signature = loadSignatureWithMetadata(signatureURL: fileURL, metadata: signatureInfo) {
                                            signatures.append(signature)
                                            print("    Signature chargée avec succès: \(signature.name)")
                                        } else {
                                            print("    ÉCHEC du chargement de la signature!")
                                        }
                                    }
                                } else {
                                    print("    Pas d'ID trouvé pour cette signature!")
                                }
                            }
                        } else {
                            print("  Pas de liste de signatures trouvée pour ce compte!")
                        }
                    }
                }
            } else {
                print("Clé 'SignaturesByAccountID' non trouvée dans AllSignatures.plist")
                // Essayer de trouver d'autres clés de premier niveau
                print("Clés de premier niveau disponibles: \(plist.keys.joined(separator: ", "))")
            }
            
            return signatures
        } catch {
            print("Erreur lors du chargement de AllSignatures.plist: \(error)")
            return nil
        }
    }
    
    // Fonction utilitaire pour afficher la structure d'un plist
    private static func printPlistStructure(plist: [String: Any], indent: String = "") {
        print("\(indent)Structure du plist:")
        
        for (key, value) in plist {
            if let dict = value as? [String: Any] {
                print("\(indent)- \(key): [Dictionary]")
                printPlistStructure(plist: dict, indent: indent + "  ")
            } else if let array = value as? [Any] {
                print("\(indent)- \(key): [Array] (\(array.count) éléments)")
                if !array.isEmpty {
                    if let firstItem = array.first as? [String: Any] {
                        print("\(indent)  Premier élément:")
                        printPlistStructure(plist: firstItem, indent: indent + "    ")
                    } else {
                        print("\(indent)  Type du premier élément: \(type(of: array.first!))")
                    }
                }
            } else {
                print("\(indent)- \(key): \(value) (\(type(of: value)))")
            }
        }
    }
    
    // Charge une signature avec les métadonnées extraites de AllSignatures.plist
    private static func loadSignatureWithMetadata(signatureURL: URL, metadata: [String: Any]) -> Signature? {
        let signatureID = signatureURL.deletingPathExtension().lastPathComponent
        
        // Extraire le nom de la signature des métadonnées
        var name = "Signature sans nom"
        if let signatureName = metadata["SignatureName"] as? String {
            name = signatureName
        }
        
        // Charger le contenu HTML depuis le fichier signature
        guard let signatureData = try? Data(contentsOf: signatureURL) else {
            print("Impossible de lire les données du fichier signature pour \(signatureID)")
            return nil
        }
        
        var htmlContent = ""
        var attributedContent = NSAttributedString(string: "")
        
        // Détecter le type de fichier et extraire le contenu HTML
        if signatureURL.pathExtension.lowercased() == "webarchive" {
            // Format webarchive
            do {
                if let webarchive = try PropertyListSerialization.propertyList(from: signatureData, options: [], format: nil) as? [String: Any],
                   let mainResource = webarchive["WebMainResource"] as? [String: Any],
                   let webResourceData = mainResource["WebResourceData"] as? Data,
                   let htmlString = String(data: webResourceData, encoding: .utf8) {
                    htmlContent = htmlString
                    
                    // Convertir le HTML en NSAttributedString
                    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ]
                    
                    attributedContent = try NSAttributedString(data: webResourceData, options: options, documentAttributes: nil)
                } else {
                    print("Format webarchive invalide pour \(signatureID)")
                    return nil
                }
            } catch {
                print("Erreur lors de la conversion du webarchive en HTML pour \(signatureID): \(error)")
                return nil
            }
        } else {
            // Format HTML direct
            if let htmlString = String(data: signatureData, encoding: .utf8) {
                htmlContent = htmlString
                
                // Convertir le HTML en NSAttributedString
                do {
                    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ]
                    attributedContent = try NSAttributedString(data: signatureData, options: options, documentAttributes: nil)
                } catch {
                    print("Erreur lors de la conversion HTML en AttributedString pour \(signatureID): \(error)")
                    
                    // Fallback à un texte simple
                    attributedContent = NSAttributedString(string: htmlString)
                }
            } else {
                print("Impossible de décoder le contenu HTML pour \(signatureID)")
                return nil
            }
        }
        
        return Signature(
            fileURL: signatureURL,
            signatureID: signatureID,
            name: name,
            content: attributedContent,
            htmlContent: htmlContent
        )
    }
    
    // Essaie de charger un fichier comme signature même sans plist associé
    private static func tryToLoadAsSignature(fileURL: URL, dirURL: URL) -> Signature? {
        do {
            let signatureID = fileURL.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: fileURL)
            
            // Vérifier si c'est du HTML ou un format binaire
            if let htmlContent = String(data: data, encoding: .utf8) {
                // Vérifier si c'est un fichier HTML valide
                let isHTML = htmlContent.contains("<html") || 
                             htmlContent.contains("<body") || 
                             htmlContent.contains("<div") ||
                             htmlContent.contains("<p>") ||
                             htmlContent.contains("<table") ||
                             htmlContent.contains("<!DOCTYPE")
                
                if isHTML {
                    print("Le fichier \(fileURL.lastPathComponent) semble être un fichier HTML valide")
                    
                    // Essayer de détecter un titre/nom pour la signature
                    var name = "Signature sans titre"
                    
                    // Méthode 1: Chercher dans la balise title
                    if let titleStart = htmlContent.range(of: "<title>"),
                       let titleEnd = htmlContent.range(of: "</title>") {
                        let startIndex = titleStart.upperBound
                        let endIndex = titleEnd.lowerBound
                        if startIndex < endIndex {
                            name = String(htmlContent[startIndex..<endIndex])
                        }
                    }
                    
                    // Méthode 2: Chercher dans le premier paragraphe ou div
                    if name == "Signature sans titre" {
                        if let firstParagraph = extractFirstTextContent(from: htmlContent) {
                            name = firstParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
                            if name.count > 30 {
                                name = String(name.prefix(30)) + "..."
                            }
                        }
                    }
                    
                    // Méthode 3: Utiliser le nom du fichier
                    if name == "Signature sans titre" {
                        name = "Signature: \(fileURL.deletingPathExtension().lastPathComponent)"
                    }
                    
                    // Créer un NSAttributedString à partir du HTML
                    var attributedContent: NSAttributedString
                    do {
                        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                            .documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue
                        ]
                        attributedContent = try NSAttributedString(data: data, options: options, documentAttributes: nil)
                    } catch {
                        print("Erreur lors de la conversion HTML en AttributedString: \(error)")
                        attributedContent = NSAttributedString(string: "Erreur de conversion")
                    }
                    
                    return Signature(
                        fileURL: fileURL,
                        signatureID: signatureID,
                        name: name,
                        content: attributedContent,
                        htmlContent: htmlContent
                    )
                }
            }
            
            // Vérifier si c'est un webarchive
            if fileURL.pathExtension.lowercased() == "webarchive" {
                // Essayer de traiter comme un webarchive
                if let webarchive = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let mainResource = webarchive["WebMainResource"] as? [String: Any],
                   let webResourceData = mainResource["WebResourceData"] as? Data,
                   let htmlContent = String(data: webResourceData, encoding: .utf8) {
                    
                    print("Le fichier \(fileURL.lastPathComponent) est un webarchive valide")
                    
                    // Essayer de détecter un titre/nom pour la signature
                    var name = "Signature sans titre"
                    
                    // Méthode 1: Chercher dans la balise title
                    if let titleStart = htmlContent.range(of: "<title>"),
                       let titleEnd = htmlContent.range(of: "</title>") {
                        let startIndex = titleStart.upperBound
                        let endIndex = titleEnd.lowerBound
                        if startIndex < endIndex {
                            name = String(htmlContent[startIndex..<endIndex])
                        }
                    }
                    
                    // Méthode 2: Chercher dans le premier paragraphe ou div
                    if name == "Signature sans titre" {
                        if let firstParagraph = extractFirstTextContent(from: htmlContent) {
                            name = firstParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
                            if name.count > 30 {
                                name = String(name.prefix(30)) + "..."
                            }
                        }
                    }
                    
                    // Méthode 3: Utiliser le nom du fichier
                    if name == "Signature sans titre" {
                        name = "Signature: \(fileURL.deletingPathExtension().lastPathComponent)"
                    }
                    
                    // Créer un NSAttributedString à partir du HTML
                    var attributedContent: NSAttributedString
                    do {
                        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                            .documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue
                        ]
                        attributedContent = try NSAttributedString(data: webResourceData, options: options, documentAttributes: nil)
                    } catch {
                        print("Erreur lors de la conversion HTML en AttributedString: \(error)")
                        attributedContent = NSAttributedString(string: "Erreur de conversion")
                    }
                    
                    return Signature(
                        fileURL: fileURL,
                        signatureID: signatureID,
                        name: name,
                        content: attributedContent,
                        htmlContent: htmlContent
                    )
                }
            }
            
            // Vérifier si c'est un fichier texte simple
            if let textContent = String(data: data, encoding: .utf8), 
               !textContent.isEmpty && textContent.count < 10000 {
                print("Le fichier \(fileURL.lastPathComponent) semble être un fichier texte simple")
                
                // Créer un nom à partir du contenu
                var name = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.count > 30 {
                    name = String(name.prefix(30)) + "..."
                }
                
                // Si le nom est vide, utiliser le nom du fichier
                if name.isEmpty {
                    name = "Signature: \(fileURL.deletingPathExtension().lastPathComponent)"
                }
                
                // Créer un HTML simple à partir du texte
                let htmlContent = "<html><body>\(textContent.replacingOccurrences(of: "\n", with: "<br>"))</body></html>"
                
                // Créer un NSAttributedString
                let attributedContent = NSAttributedString(string: textContent)
                
                return Signature(
                    fileURL: fileURL,
                    signatureID: signatureID,
                    name: name,
                    content: attributedContent,
                    htmlContent: htmlContent
                )
            }
        } catch {
            print("Erreur lors de l'analyse du fichier \(fileURL.lastPathComponent): \(error)")
        }
        
        return nil
    }
    
    // Fonction utilitaire pour extraire le premier contenu texte d'un HTML
    private static func extractFirstTextContent(from html: String) -> String? {
        // Chercher le premier paragraphe
        if let pStart = html.range(of: "<p"),
           let pEnd = html.range(of: "</p>", range: pStart.upperBound..<html.endIndex) {
            let content = html[pStart.upperBound..<pEnd.lowerBound]
            // Nettoyer les balises HTML
            return content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        
        // Chercher le premier div
        if let divStart = html.range(of: "<div"),
           let divEnd = html.range(of: "</div>", range: divStart.upperBound..<html.endIndex) {
            let content = html[divStart.upperBound..<divEnd.lowerBound]
            // Nettoyer les balises HTML
            return content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        
        // Chercher le premier span
        if let spanStart = html.range(of: "<span"),
           let spanEnd = html.range(of: "</span>", range: spanStart.upperBound..<html.endIndex) {
            let content = html[spanStart.upperBound..<spanEnd.lowerBound]
            // Nettoyer les balises HTML
            return content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        
        // Chercher n'importe quel texte entre balises body
        if let bodyStart = html.range(of: "<body"),
           let bodyEnd = html.range(of: "</body>", range: bodyStart.upperBound..<html.endIndex) {
            let content = html[bodyStart.upperBound..<bodyEnd.lowerBound]
            // Prendre les 100 premiers caractères et nettoyer les balises HTML
            let cleaned = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            if !cleaned.isEmpty {
                return String(cleaned.prefix(100))
            }
        }
        
        return nil
    }
    
    // Charge une signature individuelle à partir de ses fichiers
    static func loadSignature(signatureURL: URL, plistURL: URL) -> Signature? {
        let signatureID = signatureURL.deletingPathExtension().lastPathComponent
        
        // Charger les métadonnées depuis le .plist
        guard let plistData = try? Data(contentsOf: plistURL) else {
            print("Impossible de lire les données du fichier .plist pour \(signatureID)")
            return nil
        }
        
        var name = "Signature sans nom"
        do {
            if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
               let signatureName = plist["SignatureName"] as? String {
                name = signatureName
            } else {
                print("Format de plist invalide ou nom de signature absent pour \(signatureID)")
            }
        } catch {
            print("Erreur lors de la lecture du plist pour \(signatureID): \(error)")
        }
        
        // Charger le contenu HTML depuis le fichier signature
        guard let signatureData = try? Data(contentsOf: signatureURL) else {
            print("Impossible de lire les données du fichier signature pour \(signatureID)")
            return nil
        }
        
        var htmlContent = ""
        var attributedContent = NSAttributedString(string: "")
        
        // Détecter le type de fichier et extraire le contenu HTML
        if signatureURL.pathExtension.lowercased() == "webarchive" {
            // Format webarchive
            do {
                if let webarchive = try PropertyListSerialization.propertyList(from: signatureData, options: [], format: nil) as? [String: Any],
                   let mainResource = webarchive["WebMainResource"] as? [String: Any],
                   let webResourceData = mainResource["WebResourceData"] as? Data,
                   let htmlString = String(data: webResourceData, encoding: .utf8) {
                    htmlContent = htmlString
                    
                    // Convertir le HTML en NSAttributedString
                    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ]
                    
                    attributedContent = try NSAttributedString(data: webResourceData, options: options, documentAttributes: nil)
                } else {
                    print("Format webarchive invalide pour \(signatureID)")
                    return nil
                }
            } catch {
                print("Erreur lors de la conversion du webarchive en HTML pour \(signatureID): \(error)")
                return nil
            }
        } else {
            // Format HTML direct
            if let htmlString = String(data: signatureData, encoding: .utf8) {
                htmlContent = htmlString
                
                // Convertir le HTML en NSAttributedString
                do {
                    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ]
                    attributedContent = try NSAttributedString(data: signatureData, options: options, documentAttributes: nil)
                } catch {
                    print("Erreur lors de la conversion HTML en AttributedString pour \(signatureID): \(error)")
                    
                    // Fallback à un texte simple
                    attributedContent = NSAttributedString(string: htmlString)
                }
            } else {
                print("Impossible de décoder le contenu HTML pour \(signatureID)")
                return nil
            }
        }
        
        return Signature(
            fileURL: signatureURL,
            signatureID: signatureID,
            name: name,
            content: attributedContent,
            htmlContent: htmlContent
        )
    }
    
    // Sauvegarde la signature
    func save() throws {
        print("Début de la sauvegarde de la signature: \(signatureID) - \(name)")
        print("Fichier signature: \(fileURL.path)")
        
        // Vérifier si nous avons besoin d'accéder au dossier sécurisé
        let directoryURL = fileURL.deletingLastPathComponent()
        var didStartAccess = false
        
        // Si le dossier est sécurisé, commencer l'accès
        if directoryURL == Signature.userSelectedSignaturesDirectory {
            didStartAccess = directoryURL.startAccessingSecurityScopedResource()
            print("Accès au dossier sécurisé démarré: \(didStartAccess)")
        }
        
        // Assurons-nous de toujours libérer l'accès à la fin
        defer {
            if didStartAccess {
                print("Libération de l'accès au dossier sécurisé")
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // DIAGNOSTIC: Aperçu du contenu HTML que nous allons sauvegarder
        print("APERÇU DU CONTENU HTML À SAUVEGARDER:")
        let previewLength = min(200, htmlContent.count)
        let htmlPreview = String(htmlContent.prefix(previewLength))
        print(htmlPreview + (htmlContent.count > previewLength ? "..." : ""))
        
        // Convertir le NSAttributedString en HTML
        var htmlData: Data
        do {
            print("Conversion de l'AttributedString en HTML...")
            let options: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html
            ]
            htmlData = try self.content.data(from: NSRange(location: 0, length: self.content.length), documentAttributes: options)
            print("Conversion réussie, taille des données HTML: \(htmlData.count) octets")
            
            // DIAGNOSTIC: Vérifier que le HTML généré correspond à notre contenu HTML stocké
            if let generatedHTML = String(data: htmlData, encoding: .utf8) {
                let generatedHashValue = generatedHTML.hash
                let storedHashValue = htmlContent.hash
                print("Hash du HTML généré: \(generatedHashValue)")
                print("Hash du HTML stocké: \(storedHashValue)")
                print("Les HTML sont identiques: \(generatedHashValue == storedHashValue)")
                
                if generatedHashValue != storedHashValue {
                    print("ATTENTION: Le HTML généré diffère du HTML stocké!")
                    // Utilisons le HTML stocké pour s'assurer que nous sauvegardons exactement ce que nous voulons
                    if let storedData = htmlContent.data(using: .utf8) {
                        htmlData = storedData
                        print("Utilisation du HTML stocké à la place, nouvelle taille: \(htmlData.count) octets")
                    }
                }
            }
        } catch {
            print("ERREUR lors de la conversion en HTML: \(error.localizedDescription)")
            throw NSError(domain: "SignatureEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossible de convertir le contenu en HTML: \(error.localizedDescription)"])
        }
        
        // S'assurer que le HTML est valide
        guard let _ = String(data: htmlData, encoding: .utf8) else {
            print("ERREUR: Impossible de convertir les données HTML en chaîne")
            throw NSError(domain: "SignatureEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impossible de convertir les données HTML en chaîne"])
        }
        
        // Essayer de rendre le fichier signature modifiable avant la sauvegarde
        print("Tentative de rendre le fichier signature modifiable...")
        
        // Vérifier si le fichier existe avant d'essayer de modifier ses attributs
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("Le fichier signature existe: \(fileExists)")
        
        if fileExists {
            do {
                try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: fileURL.path)
                print("Fichier signature rendu modifiable")
            } catch {
                print("Avertissement: Impossible de modifier les attributs du fichier signature: \(error.localizedDescription)")
                // Continuer malgré l'erreur, nous allons essayer d'écrire quand même
            }
        }
        
        // Sauvegarder le contenu de la signature
        print("Sauvegarde du contenu de la signature...")
        
        // Si c'est un fichier webarchive, le mettre à jour correctement
        if fileURL.pathExtension.lowercased() == "webarchive" {
            print("Sauvegarde au format webarchive...")
            // Construire le format webarchive
            let webResourceDict: [String: Any] = [
                "WebResourceData": htmlData,
                "WebResourceFrameName": "",
                "WebResourceMIMEType": "text/html",
                "WebResourceTextEncodingName": "UTF-8",
                "WebResourceURL": "about:blank"
            ]
            
            let webArchiveDict: [String: Any] = [
                "WebMainResource": webResourceDict,
                "WebSubresources": []
            ]
            
            do {
                let webarchiveData = try PropertyListSerialization.data(
                    fromPropertyList: webArchiveDict,
                    format: .binary,
                    options: 0
                )
                
                // DIAGNOSTIC: vérifier les permissions d'écriture
                let directoryPath = fileURL.deletingLastPathComponent().path
                if let directoryAttributes = try? FileManager.default.attributesOfItem(atPath: directoryPath) {
                    print("Permissions du dossier: \(directoryAttributes)")
                }
                
                try webarchiveData.write(to: fileURL, options: .atomic)
                print("Fichier webarchive sauvegardé avec succès")
                
                // DIAGNOSTIC: vérifier que le fichier a bien été modifié
                if let savedData = try? Data(contentsOf: fileURL) {
                    print("Taille du fichier après sauvegarde: \(savedData.count) octets")
                    print("La sauvegarde a bien eu lieu: \(savedData.count == webarchiveData.count)")
                }
            } catch {
                print("ERREUR lors de la sauvegarde du webarchive: \(error.localizedDescription)")
                throw error
            }
        } else {
            // Écrire directement en HTML dans le fichier .mailsignature
            print("Sauvegarde au format HTML direct...")
            do {
                // DIAGNOSTIC: vérifier les permissions d'écriture
                let directoryPath = fileURL.deletingLastPathComponent().path
                if let directoryAttributes = try? FileManager.default.attributesOfItem(atPath: directoryPath) {
                    print("Permissions du dossier: \(directoryAttributes)")
                }
                
                try htmlData.write(to: fileURL, options: .atomic)
                print("Fichier HTML sauvegardé avec succès")
                
                // DIAGNOSTIC: vérifier que le fichier a bien été modifié
                if let savedData = try? Data(contentsOf: fileURL) {
                    print("Taille du fichier après sauvegarde: \(savedData.count) octets")
                    print("La sauvegarde a bien eu lieu: \(savedData.count == htmlData.count)")
                    
                    // Vérifier que le contenu HTML est bien celui que nous voulions sauvegarder
                    if let savedHTML = String(data: savedData, encoding: .utf8) {
                        let savedHashValue = savedHTML.hash
                        let originalHashValue = htmlContent.hash
                        print("Hash du HTML sauvegardé: \(savedHashValue)")
                        print("Hash du HTML original: \(originalHashValue)")
                        print("Correspondance exacte: \(savedHashValue == originalHashValue)")
                    }
                }
            } catch {
                print("ERREUR lors de la sauvegarde du HTML: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Protéger le fichier signature en le rendant en lecture seule
        do {
            try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: fileURL.path)
            print("Fichier signature mis en lecture seule pour protection")
        } catch {
            print("Avertissement: Impossible de rendre le fichier signature en lecture seule: \(error.localizedDescription)")
            print("L'application Mail pourrait écraser ce fichier.")
        }
        
        print("Sauvegarde de la signature terminée avec succès")
    }
    
    // Crée une nouvelle signature
    static func createNewSignature(name: String, content: NSAttributedString) throws -> Signature {
        guard let signaturesDir = findSignaturesDirectory() else {
            throw NSError(domain: "SignatureEditor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Dossier de signatures non trouvé"])
        }
        
        // Vérifier si nous avons besoin d'accéder au dossier sécurisé
        var didStartAccess = false
        
        // Si le dossier est sécurisé, commencer l'accès
        if signaturesDir == userSelectedSignaturesDirectory {
            didStartAccess = signaturesDir.startAccessingSecurityScopedResource()
            print("Accès au dossier sécurisé démarré pour création: \(didStartAccess)")
        }
        
        // Assurons-nous de toujours libérer l'accès à la fin
        defer {
            if didStartAccess {
                signaturesDir.stopAccessingSecurityScopedResource()
                print("Accès au dossier sécurisé terminé après création")
            }
        }
        
        let signatureID = UUID().uuidString
        print("Création d'une nouvelle signature avec l'ID: \(signatureID)")
        
        // Détecter le format des signatures existantes
        var useWebarchive = false
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: signaturesDir, includingPropertiesForKeys: nil)
            let webarchives = contents.filter { $0.pathExtension.lowercased() == "webarchive" }
            useWebarchive = !webarchives.isEmpty
            print("Format détecté: \(useWebarchive ? "webarchive" : "mailsignature")")
        } catch {
            print("Erreur lors de la détection du format: \(error)")
        }
        
        let signatureURL: URL
        if useWebarchive {
            signatureURL = signaturesDir.appendingPathComponent("\(signatureID).webarchive")
        } else {
            signatureURL = signaturesDir.appendingPathComponent("\(signatureID).mailsignature")
        }
        
        print("Fichier signature à créer: \(signatureURL.path)")
        
        // Convertir le NSAttributedString en HTML
        let htmlData: Data
        do {
            print("Conversion de l'AttributedString en HTML...")
            let options: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html
            ]
            htmlData = try content.data(from: NSRange(location: 0, length: content.length), documentAttributes: options)
            print("Conversion réussie, taille des données HTML: \(htmlData.count) octets")
        } catch {
            print("ERREUR lors de la conversion en HTML: \(error.localizedDescription)")
            throw NSError(domain: "SignatureEditor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Impossible de convertir le contenu en HTML: \(error.localizedDescription)"])
        }
        
        // Écrire le fichier signature
        do {
            if useWebarchive {
                // Construire le format webarchive
                print("Sauvegarde au format webarchive...")
                let webResourceDict: [String: Any] = [
                    "WebResourceData": htmlData,
                    "WebResourceFrameName": "",
                    "WebResourceMIMEType": "text/html",
                    "WebResourceTextEncodingName": "UTF-8",
                    "WebResourceURL": "about:blank"
                ]
                
                let webArchiveDict: [String: Any] = [
                    "WebMainResource": webResourceDict,
                    "WebSubresources": []
                ]
                
                let webarchiveData = try PropertyListSerialization.data(
                    fromPropertyList: webArchiveDict,
                    format: .binary,
                    options: 0
                )
                
                try webarchiveData.write(to: signatureURL, options: .atomic)
                print("Fichier webarchive créé avec succès")
            } else {
                // Écrire directement en HTML
                print("Sauvegarde au format HTML direct...")
                try htmlData.write(to: signatureURL, options: .atomic)
                print("Fichier HTML créé avec succès")
            }
            
            // Protéger le fichier signature en le rendant en lecture seule
            do {
                try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: signatureURL.path)
                print("Fichier signature mis en lecture seule pour protection")
            } catch {
                print("Avertissement: Impossible de rendre le fichier signature en lecture seule: \(error.localizedDescription)")
                print("L'application Mail pourrait écraser ce fichier.")
            }
            
            // Convertir htmlData en String pour l'utiliser comme htmlContent
            let htmlContent = String(data: htmlData, encoding: .utf8) ?? ""
            
            return Signature(
                fileURL: signatureURL,
                signatureID: signatureID,
                name: name,
                content: content,
                htmlContent: htmlContent
            )
        } catch {
            // En cas d'erreur, essayer de nettoyer les fichiers partiellement créés
            try? FileManager.default.removeItem(at: signatureURL)
            
            throw NSError(domain: "SignatureEditor", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "Impossible de créer le fichier de signature: \(error.localizedDescription)",
                NSUnderlyingErrorKey: error
            ])
        }
    }
    
    // Convertir du HTML en NSAttributedString
    static func htmlToAttributedString(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            return try NSAttributedString(data: data, options: options, documentAttributes: nil)
        } catch {
            print("Erreur lors de la conversion HTML en AttributedString: \(error)")
            return nil
        }
    }
    
    // Convertir un NSAttributedString en HTML
    static func attributedStringToHtml(_ attributedString: NSAttributedString) -> String? {
        do {
            let options: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html
            ]
            
            let htmlData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: options)
            
            if let html = String(data: htmlData, encoding: .utf8) {
                return html
            }
        } catch {
            print("Erreur lors de la conversion AttributedString en HTML: \(error)")
        }
        
        return nil
    }
}