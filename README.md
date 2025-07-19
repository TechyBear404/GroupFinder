# GroupFinder Enhanced

Un addon GroupFinder amélioré pour World of Warcraft 1.12 (Vanilla) avec de nombreuses fonctionnalités avancées.

## Nouvelles Fonctionnalités

### 🔧 Corrections majeures

- ✅ Correction de l'API obsolète (event handlers WoW 1.12)
- ✅ Correction de la gestion des canaux de chat
- ✅ Correction du XML malformé
- ✅ Gestion d'erreurs robuste

### 🚀 Fonctionnalités ajoutées

- **Persistance des données** : Les groupes sont sauvegardés entre les sessions
- **Nettoyage automatique** : Suppression automatique des groupes expirés (1 heure par défaut)
- **Interface améliorée** : Labels, tooltips, boutons de fermeture
- **Validation des entrées** : Vérification des champs obligatoires et limites de caractères
- **Commandes slash étendues** : Plus d'options de gestion
- **Reconnexion automatique** : Rejoint automatiquement le canal LFG si déconnecté
- **Gestion des doublons** : Évite les groupes en double du même leader
- **Tooltips informatifs** : Informations détaillées au survol des groupes
- **Horodatage** : Affichage de l'âge des annonces de groupe

## Commandes

### Commandes slash

- `/groupfinder` ou `/gf` - Ouvre/ferme la fenêtre principale
- `/gf clear` - Supprime vos propres groupes
- `/gf clearall` - Supprime tous les groupes
- `/gf cleanup` - Force le nettoyage des groupes expirés
- `/gf help` - Affiche l'aide des commandes

### Interface utilisateur

- **Créer un groupe** : Bouton pour ouvrir la fenêtre de création
- **Actualiser** : Actualise manuellement la liste des groupes
- **Nettoyer** : Supprime les groupes expirés
- **Effacer mes groupes** : Supprime uniquement vos annonces

## Utilisation

1. **Installation** : Placez le dossier dans `Interface/AddOns/`
2. **Première utilisation** : L'addon rejoint automatiquement le canal "LookingForGroup"
3. **Créer un groupe** :
   - Cliquez sur "Create Group"
   - Cliquez sur le bouton d'instance pour sélectionner dans la liste
   - Remplissez les rôles nécessaires
   - Ajoutez une description optionnelle
   - Cliquez "Create Group"
4. **Filtrer les groupes** : Utilisez les boutons All, Dungeon, Raid, PvP, Other
5. **Rejoindre un groupe** : Cliquez sur une annonce pour chuchoter au leader
6. **Gestion** : Utilisez les boutons pour nettoyer et gérer vos annonces

## Configuration

L'addon sauvegarde automatiquement ses paramètres dans `GroupFinderDB` :

```lua
GroupFinderDB = {
    groups = {}, -- Liste des groupes
    settings = {
        autoCleanup = true,    -- Nettoyage automatique activé
        cleanupTimer = 3600,   -- Durée avant expiration (secondes)
        maxGroups = 50         -- Nombre maximum de groupes stockés
    }
}
```

## Fonctionnalités techniques

### Gestion des canaux

- Rejoint automatiquement le canal "LookingForGroup"
- Reconnexion automatique en cas de déconnexion
- Gestion correcte des numéros de canaux

### Persistance

- Sauvegarde automatique des groupes
- Nettoyage périodique (toutes les 5 minutes)
- Limitation du nombre de groupes stockés

### Interface

- Fenêtres redimensionnables et déplaçables
- Tooltips avec informations détaillées
- Validation des entrées en temps réel
- Messages d'erreur colorés

### Performance

- Gestion optimisée des boutons d'interface
- Nettoyage automatique de la mémoire
- Timer de mise à jour efficace

## Changelog

### Version 2.0

- Refonte complète du code
- Correction de tous les bugs majeurs
- Ajout de nombreuses nouvelles fonctionnalités
- Interface utilisateur complètement redessinée
- Système de persistance des données
- Nettoyage automatique des groupes expirés

### Version 0.1 (Originale)

- Fonctionnalité de base de recherche de groupe
- Interface simple
- Pas de persistance

## Support

Cet addon est compatible avec World of Warcraft 1.12 (Vanilla).

## Crédits

- Version originale : YourName
- Version améliorée : Enhanced by Roo
- Compatible avec WoW 1.12 Vanilla
