# Migration de TinyMCE vers Infomaniak Rich HTML Editor

Ce document décrit les étapes pour migrer l'éditeur de signature depuis TinyMCE vers la bibliothèque Swift Rich HTML Editor d'Infomaniak.

## Étapes de migration

1. Ajouter le package Swift Rich HTML Editor à votre projet

   - Ouvrir le projet dans Xcode
   - Menu File > Add Packages...
   - Entrer l'URL: https://github.com/Infomaniak/swift-rich-html-editor.git
   - Sélectionner la version souhaitée (dernière version recommandée)
   - Ajouter à la cible SignatureEditor

2. Remplacer l'éditeur TinyMCE par InfomaniakRichEditor

   - La classe TinyMCEAttributedEditorView a été remplacée par InfomaniakRichEditorView
   - Le nouveau composant utilise directement le HTML au lieu de NSAttributedString
   - La conversion HTML <-> NSAttributedString est gérée automatiquement

3. Nettoyage (à effectuer)
   - Supprimer les fichiers liés à TinyMCE qui ne sont plus nécessaires
   - Supprimer la classe RichTextEditor.swift qui contenait l'intégration TinyMCE
   - Conserver uniquement les fichiers nécessaires pour le nouvel éditeur

## Avantages de la nouvelle implémentation

- Intégration native avec SwiftUI
- Pas besoin de WebView et de JavaScript
- Meilleure performance et stabilité
- Maintien actif avec prise en charge des dernières fonctionnalités de SwiftUI
- API plus simple et plus intuitive

## Modifications nécessaires à la compilation

1. Ajouter InfomaniakRichHTMLEditor dans les imports des fichiers qui l'utilisent
2. Si le projet utilise une version ancienne de SwiftUI, vérifier la compatibilité et mettre à jour si nécessaire
3. Adapter les interfaces qui utilisaient directement TinyMCE

## Ressources utiles

- [Repository GitHub de swift-rich-html-editor](https://github.com/Infomaniak/swift-rich-html-editor)
- [Documentation InfomaniakRichHTMLEditor](https://github.com/Infomaniak/swift-rich-html-editor/tree/main/Sources/InfomaniakRichHTMLEditor)
