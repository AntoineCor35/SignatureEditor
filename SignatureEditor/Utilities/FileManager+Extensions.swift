import Foundation

extension FileManager {
    
    enum FileAccessError: Error {
        case permissionDenied
        case fileNotFound
        case directoryCreationFailed
        case unableToCreateBookmark
        case bookmarkInvalidated
    }
    
    /// Vérifie et demande l'accès au dossier Mail de l'utilisateur
    func requestAccessToMailDirectory() throws -> URL {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let mailURL = libraryURL.appendingPathComponent("Mail")
        
        // Vérifier si le dossier existe
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: mailURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            throw FileAccessError.fileNotFound
        }
        
        // Essayer d'accéder au dossier
        if !checkReadWriteAccess(to: mailURL) {
            // Si l'accès est refusé, essayer de créer un signet pour accès persistant
            try saveBookmark(for: mailURL)
            
            // Si après avoir sauvegardé le signet, l'accès est toujours refusé
            if !checkReadWriteAccess(to: mailURL) {
                throw FileAccessError.permissionDenied
            }
        }
        
        return mailURL
    }
    
    /// Vérifie les autorisations de lecture/écriture pour une URL
    private func checkReadWriteAccess(to url: URL) -> Bool {
        return FileManager.default.isReadableFile(atPath: url.path) && 
               FileManager.default.isWritableFile(atPath: url.path)
    }
    
    /// Sauvegarde un signet de sécurité pour une URL donnée
    private func saveBookmark(for url: URL) throws {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            
            // Stocker le signet dans les préférences utilisateur
            UserDefaults.standard.set(bookmarkData, forKey: "MailDirectoryBookmark")
        } catch {
            throw FileAccessError.unableToCreateBookmark
        }
    }
    
    /// Résout un signet sauvegardé
    func resolveBookmark() throws -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "MailDirectoryBookmark") else {
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Si le signet est périmé, essayer de le mettre à jour
                try saveBookmark(for: url)
            }
            
            // Commencer l'accès de sécurité
            if url.startAccessingSecurityScopedResource() {
                return url
            } else {
                throw FileAccessError.permissionDenied
            }
        } catch {
            throw FileAccessError.bookmarkInvalidated
        }
    }
    
    /// Arrête l'accès à une ressource protégée
    func stopAccess(to url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    /// Rend un fichier accessible en écriture (désactive l'attribut immuable)
    func makeFileWritable(at path: String) throws {
        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: path)
    }
    
    /// Rend un fichier en lecture seule (active l'attribut immuable)
    func makeFileReadOnly(at path: String) throws {
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: path)
    }
} 