# 🎫 GLPI AI Processor

> **Version 2.26.02 — Local AI**  
> Un script PowerShell qui analyse automatiquement vos tickets GLPI, détermine leur priorité et génère une première réponse technique — le tout via des modèles IA tournant **localement** avec Ollama. Aucune donnée ne quitte votre infrastructure.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![Ollama](https://img.shields.io/badge/Ollama-0.1%2B-black?logo=ollama)](https://ollama.com)
[![GLPI](https://img.shields.io/badge/GLPI-10.x-green)](https://glpi-project.org)

---

## Architecture

```
🎫 GLPI (API REST)  ⟷  ⚙️ Script PS1 (PowerShell 5.1+)  ⟷  🧠 Ollama (3 modèles LLM)
```

---

## ✨ Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| 🎯 **Priorité automatique** | Le modèle `GLPIa` analyse le titre et le contenu du ticket pour attribuer une priorité de 1 à 5, basée sur l'impact et l'urgence. |
| 💬 **Réponse automatique** | Le modèle `GLPIaresponse` génère une première réponse technique et courtoise, avec des pistes de résolution immédiates. |
| 🔍 **Aide technicien** | Le modèle `glpiaide` produit une analyse technique approfondie destinée aux techniciens : diagnostic, causes probables, outils. |
| 🔒 **100% Local** | Toutes les inférences IA sont effectuées via Ollama en local. Aucune donnée sensible ne quitte votre réseau. |
| 🔁 **Traitement continu** | Le script tourne en boucle, détecte les nouveaux tickets et les traite automatiquement avec un système de marquage anti-doublon. |
| 📝 **Logging complet** | Chaque action est tracée dans un fichier de log avec horodatage, niveau de sévérité et détails de l'opération. |

---

## 📋 Prérequis

| Composant | Version | Notes |
|---|---|---|
| **Windows** | 10 / Server 2016+ | PowerShell 5.1 ou supérieur |
| **GLPI** | 10.x | API REST activée + tokens configurés |
| **Ollama** | 0.1+ | Installé localement ou accessible en réseau |
| **RAM** | 16 Go+ | Recommandé pour les modèles Mistral 7B |
| **GPU** | Optionnel | Accélère considérablement l'inférence |

> 💡 **Ollama** peut être installé en quelques secondes depuis [ollama.com](https://ollama.com). Il tourne comme un service local et expose une API REST sur le port `11434`.

---

## 🚀 Installation

### Étape 1 — Cloner le dépôt

```bash
git clone https://github.com/AlexandreTaboin/automatic-GLPI-ticket-response-using-llm.git
cd glpi-ai-processor
```

### Étape 2 — Configurer les tokens GLPI

Ouvrez le script `GLPI_AI_Processor.ps1` et modifiez la section `$Script:Config` avec vos propres valeurs :

```powershell
$Script:Config = @{
    ApiUrl           = "http://votre-glpi.domaine.local/apirest.php"
    AppToken         = "VOTRE_APP_TOKEN_ICI"
    UserToken        = "VOTRE_USER_TOKEN_ICI"
    GlpiaideToken    = "VOTRE_GLPIAIDE_TOKEN_ICI"
    OllamaUrl        = "http://localhost:11434/api/generate"
    # ...
}
```

> ⚠️ **Ne jamais publier vos tokens !** Si vous partagez ce script, remplacez tous les tokens par des valeurs fictives. Consultez la section [Sécurité](#-sécurité) pour les bonnes pratiques.

Pour obtenir les tokens dans GLPI :
- **App-Token** : `Configuration` → `Générale` → `API` → Ajouter un client API
- **User-Token (principal)** : `Administration` → `Utilisateurs` → votre compte → `Clés API distantes`
- **User-Token (GLPIaide)** : Idem pour le compte dédié à l'aide IA

### Étape 3 — Créer les dossiers nécessaires

```powershell
New-Item -ItemType Directory -Path "C:\Scripts" -Force
New-Item -ItemType Directory -Path "C:\Modelfiles" -Force
```

### Étape 4 — Installer Ollama

```bash
# Vérifier qu'Ollama est en cours d'exécution
ollama list

# Télécharger le modèle de base Mistral
ollama pull mistral
```

### Étape 5 — Créer les modèles personnalisés

Suivez les instructions de la section [Modèles Ollama](#-création-des-modèles-ollama) ci-dessous.

---

## 🧠 Création des modèles Ollama

Le script utilise **trois modèles personnalisés** créés à partir de Mistral. Chaque modèle a un rôle spécifique avec des paramètres de température et de génération adaptés.

> 📁 Chaque modèle est défini par un fichier **Modelfile** — un fichier texte contenant les instructions système et les paramètres du modèle. Créez ces fichiers dans `C:\Modelfiles\`.

### 🎯 Modèle GLPIa — Analyse de priorité

Ce modèle est conçu pour retourner **uniquement un chiffre entre 1 et 5**. La température basse (0.1) garantit des réponses déterministes.

| Priorité | Niveau | Description |
|---|---|---|
| **1** | Très basse | Demande d'information, question générale |
| **2** | Basse | Demande de changement mineur, amélioration cosmétique |
| **3** | Moyenne | Dysfonctionnement partiel, un contournement existe |
| **4** | Haute | Service dégradé pour plusieurs utilisateurs, impact métier |
| **5** | Très haute | Service critique totalement indisponible, blocage complet |

**Étape 1 :** Créer le fichier `C:\Modelfiles\Modelfile_GLPIa`

```dockerfile
FROM mistral

SYSTEM """
Tu es un assistant spécialisé dans l'analyse de tickets de support informatique.
Ta seule mission est de déterminer la priorité d'un ticket sur une échelle de 1 à 5.

Échelle de priorité :
1 - Très basse : Demande d'information, question générale
2 - Basse : Demande de changement mineur, amélioration cosmétique
3 - Moyenne : Dysfonctionnement partiel, un contournement existe
4 - Haute : Service dégradé pour plusieurs utilisateurs, impact métier
5 - Très haute : Service critique totalement indisponible, blocage complet

Tu dois répondre UNIQUEMENT par un chiffre entre 1 et 5. Aucun texte, aucune explication.
"""

PARAMETER temperature 0.1
PARAMETER top_p 0.5
PARAMETER num_predict 5
```

**Étape 2 :** Créer le modèle

```bash
ollama create GLPIa -f "C:\Modelfiles\Modelfile_GLPIa"
```

**Étape 3 :** Tester le modèle

```bash
ollama run GLPIa "L'imprimante du 2e étage ne fonctionne plus"
# Résultat attendu : 3

ollama run GLPIa "Serveur de production totalement inaccessible"
# Résultat attendu : 5

ollama run GLPIa "Comment changer mon fond d'écran ?"
# Résultat attendu : 1
```

---

### 💬 Modèle GLPIaresponse — Réponse automatique

Ce modèle génère une **première réponse** destinée à l'utilisateur qui a ouvert le ticket. Le ton est professionnel, courtois et rassurant. La réponse est formatée en HTML pour s'intégrer directement dans GLPI.

**Étape 1 :** Créer le fichier `C:\Modelfiles\Modelfile_GLPIaresponse`

```dockerfile
FROM mistral

SYSTEM """
Tu es un technicien de support informatique de niveau 1 bienveillant et professionnel.
Tu rédiges la première réponse à un ticket de support.

Règles :
- Commence par saluer l'utilisateur et accuser réception de sa demande
- Propose 2 à 3 pistes de résolution simples et concrètes
- Termine en indiquant qu'un technicien prendra le relais si nécessaire
- Utilise un ton courtois et rassurant
- Rédige en français
- Sois concis (150 mots maximum)
- Formate ta réponse en HTML simple (balises <p>, <ul>, <li>, <b>)
"""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_predict 500
```

**Étape 2 :** Créer le modèle

```bash
ollama create GLPIaresponse -f "C:\Modelfiles\Modelfile_GLPIaresponse"
```

**Étape 3 :** Tester le modèle

```bash
ollama run GLPIaresponse "Je n'arrive plus à me connecter à ma boîte mail Outlook"
# Résultat attendu : Un message HTML avec salutation, pistes de résolution et mention de prise en charge
```

---

### 🔍 Modèle glpiaide — Assistance technicien

Ce modèle est **destiné aux techniciens**, pas aux utilisateurs finaux. Il fournit une analyse technique approfondie : catégorisation du problème, causes probables, procédure de diagnostic et outils recommandés.

**Étape 1 :** Créer le fichier `C:\Modelfiles\Modelfile_glpiaide`

```dockerfile
FROM mistral

SYSTEM """
Tu es un ingénieur de support informatique de niveau 2/3 expérimenté.
Tu analyses un ticket de support et fournis une aide technique au technicien assigné.

Structure ta réponse ainsi :
1. CATÉGORIE : Identifie le domaine (réseau, poste de travail, serveur, applicatif, sécurité, messagerie, impression, téléphonie)
2. CAUSES PROBABLES : Liste les 3 causes les plus fréquentes par ordre de probabilité
3. DIAGNOSTIC : Propose une procédure de diagnostic pas à pas
4. OUTILS : Suggère les outils et commandes utiles (PowerShell, CMD, outils GLPI/réseau)
5. ESCALADE : Indique dans quels cas escalader au niveau supérieur

Règles :
- Sois technique et précis
- Utilise du jargon technique approprié
- Rédige en français
- Formate ta réponse en HTML (balises <h4>, <p>, <ul>, <li>, <code>, <b>)
- Maximum 300 mots
"""

PARAMETER temperature 0.4
PARAMETER top_p 0.8
PARAMETER num_predict 800
```

**Étape 2 :** Créer le modèle

```bash
ollama create glpiaide -f "C:\Modelfiles\Modelfile_glpiaide"
```

**Étape 3 :** Tester le modèle

```bash
ollama run glpiaide "Écran bleu BSOD récurrent sur le poste de Mme Dupont, erreur IRQL_NOT_LESS_OR_EQUAL"
# Résultat attendu : analyse structurée avec catégorisation, causes, diagnostic, outils et critères d'escalade
```

---

### Récapitulatif — Création complète des modèles

```bash
# 1. Télécharger le modèle de base
ollama pull mistral

# 2. Créer le modèle d'analyse de priorité
ollama create GLPIa -f "C:\Modelfiles\Modelfile_GLPIa"

# 3. Créer le modèle de réponse automatique
ollama create GLPIaresponse -f "C:\Modelfiles\Modelfile_GLPIaresponse"

# 4. Créer le modèle d'aide technicien
ollama create glpiaide -f "C:\Modelfiles\Modelfile_glpiaide"

# 5. Vérifier que les 3 modèles sont bien créés
ollama list
```

> 📊 **Espace disque :** Le modèle Mistral 7B occupe environ 4 Go. Les 3 modèles personnalisés partagent les mêmes poids de base, donc l'espace total reste d'environ **~4.5 Go**.

### Comparatif des paramètres

| Paramètre | GLPIa | GLPIaresponse | glpiaide | Description |
|---|---|---|---|---|
| `temperature` | 0.1 | 0.7 | 0.4 | Créativité de la réponse (0 = déterministe, 1 = créatif) |
| `top_p` | 0.5 | 0.9 | 0.8 | Diversité du vocabulaire utilisé |
| `num_predict` | 5 | 500 | 800 | Nombre maximum de tokens en sortie |
| **Rôle** | Chiffre 1-5 | Réponse utilisateur | Aide technicien | — |

---

## ⚙️ Configuration

### Paramètres du script

Tous les paramètres sont centralisés dans le bloc `$Script:Config` en haut du script :

| Paramètre | Description | Valeur par défaut |
|---|---|---|
| `ApiUrl` | URL de l'API REST de GLPI | *À configurer* |
| `AppToken` | Token de l'application API dans GLPI | *À configurer* |
| `UserToken` | Token de l'utilisateur principal | *À configurer* |
| `GlpiaideToken` | Token de l'utilisateur GLPIaide | *À configurer* |
| `OllamaUrl` | URL de l'API Ollama | `http://localhost:11434/api/generate` |
| `ProcessedMarker` | Valeur `requesttypes_id` pour marquer les tickets traités | `8` |
| `RetryDelay` | Délai entre chaque cycle de vérification (secondes) | `30` |
| `OllamaTimeout` | Timeout des requêtes Ollama (secondes) | `9000` |
| `LogFile` | Chemin du fichier de logs | `C:\Scripts\GLPI_Process.log` |
| `MemoryFile` | Fichier mémoire du dernier ticket traité | `C:\Scripts\GLPI_LastTicket.txt` |

### Configuration de l'API GLPI

1. **Activer l'API** : `Configuration` → `Générale` → `API` → Activer l'API REST + connexion par user_token
2. **Créer un client API** : Ajoutez un client nommé `GLPI AI Processor`, restreignez l'accès à l'IP du serveur et notez le **App-Token**
3. **Générer les User-Tokens** : `Administration` → `Utilisateurs` → `Clés API distantes` → Régénérer (pour le compte principal et le compte GLPIaide)
4. **Vérifier les droits** :

| Droit | Compte principal | Compte GLPIaide |
|---|---|---|
| Lire les tickets | ✅ | ✅ |
| Modifier les tickets (priorité) | ✅ | ❌ |
| Ajouter des suivis | ✅ | ✅ |
| Voir tous les tickets | ✅ | ✅ |

---

## ▶️ Utilisation

### Lancement manuel

```powershell
# Autoriser l'exécution de scripts (une seule fois)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

# Lancer le script
cd C:\Scripts
.\GLPI_AI_Processor.ps1
```

### Sortie console attendue

```
╔══════════════════════════════════════════════════════════════════╗
║  GLPI - Traitement automatique par IA v2.26.02                  ║
║  Modèles : GLPIa / GLPIaresponse / glpiaide                    ║
║  Filtre  : Nouveaux tickets (statut 1, source ≠ 8)             ║
║  Marqueur: requesttypes_id = 8                                  ║
╚══════════════════════════════════════════════════════════════════╝

[2025-02-17 10:00:01][Info] === Nouveau cycle ===
[2025-02-17 10:00:01][Success] Session principal ouverte
[2025-02-17 10:00:02][Success] Session GLPIaide ouverte
[2025-02-17 10:00:03][Info] Ticket #1542 : "Imprimante HP bloquée 2e étage"
[2025-02-17 10:00:08][Success] → Priorité déterminée : 3 (Moyenne)
[2025-02-17 10:00:15][Success] → Réponse utilisateur ajoutée
[2025-02-17 10:00:22][Success] → Note technique ajoutée
[2025-02-17 10:00:22][Success] Ticket #1542 traité avec succès
[2025-02-17 10:00:22][Info] Cycle terminé : 1 traité(s), 0 erreur(s)
[2025-02-17 10:00:22][Info] Prochain cycle dans 30s
```

### Exécution en tant que tâche planifiée

Pour que le script s'exécute automatiquement au démarrage du serveur :

```powershell
# Créer une tâche planifiée qui démarre le script au boot
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\GLPI_AI_Processor.ps1" `
    -WorkingDirectory "C:\Scripts"

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 365)

Register-ScheduledTask `
    -TaskName "GLPI AI Processor" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User "SYSTEM" `
    -RunLevel Highest
```

> ⏱️ **Note :** Le script tourne en boucle infinie avec un délai de `30 secondes` entre chaque cycle. La tâche planifiée n'a pas besoin de répétition.

### Flux de traitement d'un ticket

```
1. Détection         → Recherche tickets avec status=1 et requesttypes_id ≠ 8
          ↓
2. Analyse priorité  → Envoi du titre au modèle GLPIa → reçoit un chiffre 1-5
          ↓
3. Mise à jour       → PUT sur l'API GLPI pour mettre à jour priority
          ↓
4. Génération réponse → Envoi au modèle GLPIaresponse → HTML de réponse utilisateur
          ↓
5. Ajout suivi       → POST d'un ITILFollowup visible par l'utilisateur
          ↓
6. Aide technicien   → Envoi au modèle glpiaide → note technique interne
          ↓
7. Marquage          → Mise à jour requesttypes_id = 8 pour éviter le retraitement
```

---

## 🔐 Sécurité

> ⚠️ **IMPORTANT :** Ne publiez JAMAIS vos tokens API sur un dépôt public. Si cela arrive accidentellement, **révoquez immédiatement les tokens** dans GLPI et régénérez-en de nouveaux.

### Bonnes pratiques

- Remplacez les tokens par des valeurs fictives (`VOTRE_TOKEN_ICI`) avant de partager le code
- Utilisez un fichier `.gitignore` pour exclure les fichiers sensibles :

```gitignore
# Secrets
.env
*.env

# Fichiers runtime
GLPI_Process.log
GLPI_LastTicket.txt

# Fichiers Windows
Thumbs.db
desktop.ini
```

### Option avancée : Variables d'environnement

```powershell
# Définir les variables d'environnement système (une seule fois, en admin)
[Environment]::SetEnvironmentVariable("GLPI_API_URL", "http://votre-glpi/apirest.php", "Machine")
[Environment]::SetEnvironmentVariable("GLPI_APP_TOKEN", "votre-app-token", "Machine")
[Environment]::SetEnvironmentVariable("GLPI_USER_TOKEN", "votre-user-token", "Machine")
[Environment]::SetEnvironmentVariable("GLPI_AIDE_TOKEN", "votre-aide-token", "Machine")
```

```powershell
# Lecture dans le script
$Script:Config = @{
    ApiUrl        = $env:GLPI_API_URL
    AppToken      = $env:GLPI_APP_TOKEN
    UserToken     = $env:GLPI_USER_TOKEN
    GlpiaideToken = $env:GLPI_AIDE_TOKEN
    # ...
}
```

### Sécurité réseau

- 🔒 Ollama n'expose son API que sur `localhost:11434` par défaut — aucune donnée ne transite sur le réseau
- 🔒 L'API GLPI doit être accessible uniquement depuis le serveur exécutant le script (filtrage IP dans le client API)
- 🔒 Les sessions GLPI sont fermées systématiquement dans un bloc `finally`
- 🔒 Le fichier mémoire (`GLPI_LastTicket.txt`) évite le double traitement en cas de redémarrage

---

## 🔧 Dépannage

| Problème | Cause probable | Solution |
|---|---|---|
| `ERROR_SESSION_TOKEN_MISSING` | Token invalide ou expiré | Régénérer le User-Token dans GLPI |
| `Invoke-RestMethod : Impossible de se connecter` | Ollama non démarré | Lancer `ollama serve` ou vérifier le service |
| Priorité toujours à 3 | Modèle GLPIa mal configuré | Tester avec `ollama run GLPIa "test"` |
| Ticket traité en boucle | Marqueur `requesttypes_id` non appliqué | Vérifier les droits de modification du compte principal |
| Réponse Ollama très lente (>2 min) | Pas de GPU / RAM insuffisante | Augmenter la RAM ou utiliser un modèle plus petit (phi3, tinyllama) |
| `model 'GLPIa' not found` | Modèle non créé | Exécuter `ollama create GLPIa -f ...` |
| Caractères HTML visibles dans GLPI | GLPI n'interprète pas le HTML | Vérifier que le suivi est ajouté avec `content_type=text/html` |
| Le script ne détecte pas les nouveaux tickets | Filtre trop restrictif | Vérifier `status=1` et `requesttypes_id ≠ 8` |

### Commandes de diagnostic

```bash
# Vérifier qu'Ollama répond
curl http://localhost:11434/api/tags

# Lister les modèles installés
ollama list
```

```powershell
# Tester l'API GLPI
Invoke-RestMethod -Uri "http://votre-glpi/apirest.php/" -Method Get

# Voir les logs en temps réel
Get-Content "C:\Scripts\GLPI_Process.log" -Tail 50 -Wait

# Voir le dernier ticket traité
Get-Content "C:\Scripts\GLPI_LastTicket.txt"
```

### Activer les logs détaillés

```powershell
# Décommenter ce bloc pour activer les logs dans le fichier
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error")]
        [string]$Level = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry  = "[$timestamp][$Level] $Message"
    Add-Content -Path $Script:Config.LogFile -Value $logEntry
}
```

---

## 📁 Structure du projet

```
glpi-ai-processor/
├── 📄 GLPI_AI_Processor.ps1        # Script principal
├── 📄 README.md                     # Documentation Markdown
├── 📄 index.html                    # Page de documentation HTML
├── 📄 .gitignore                    # Exclusions Git
├── 📄 LICENSE                       # Licence MIT
│
├── 📁 Modelfiles/
│   ├── 📄 Modelfile_GLPIa           # Modèle analyse de priorité
│   ├── 📄 Modelfile_GLPIaresponse   # Modèle réponse utilisateur
│   └── 📄 Modelfile_glpiaide        # Modèle aide technicien
│
└── 📁 Logs/                         # (non commité) Fichiers runtime
    ├── 📄 GLPI_Process.log          # Logs d'exécution
    └── 📄 GLPI_LastTicket.txt       # Mémoire dernier ticket
```

---

## 📋 Historique des versions

### v2.26.02 — 17 février 2026 *(latest)*

- Optimisation complète du script
- Gestion des tickets clos et déjà traités
- Logging amélioré avec niveaux de sévérité
- Fichier mémoire anti-doublon (`GLPI_LastTicket.txt`)
- Fermeture systématique des sessions (bloc `finally`)
- Pause entre les tickets pour éviter la surcharge

### v1.24.07 — 31 juillet 2024

- Version initiale fonctionnelle
- Analyse de priorité via Ollama
- Réponse automatique aux tickets
- Intégration API GLPI

---

## ⚡ Crédits & Licence

**Auteur :** Alexandre TABOIN — [taboin.fr](https://taboin.fr)

**IA utilisées :** Développement assisté par ChatGPT 4o, Mistral Codestral, Claude Opus

**Licence :** MIT — Libre d'utilisation, modification et redistribution

> 🌐 **100% local & open source.** Ce projet utilise des modèles d'IA locaux via Ollama. Aucune donnée de ticket n'est envoyée vers des services cloud externes.
