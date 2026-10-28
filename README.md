# Relais — réponses automatiques aux tickets GLPI

![Version](https://img.shields.io/badge/version-4.17.0-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue) ![GLPI](https://img.shields.io/badge/GLPI-10+-orange) ![Ollama](https://img.shields.io/badge/Ollama-local-green)

**Relais** répond aux tickets GLPI avec un modèle local piloté par Ollama. `Myrtille.ps1` propose une réponse publique sous la voix de **Myrtille** et un suivi privé destiné aux techniciens sous la voix de **Perceval**.

- **Version du script :** 4.17.0
- **Auteur :** Alexandre TABOIN — [taboin.fr](https://taboin.fr) *(indiqué dans l'en-tête du script)*
- **Dépôt :** [github.com/AlexandreTaboin/automatic-GLPI-ticket-response-using-llm](https://github.com/AlexandreTaboin/automatic-GLPI-ticket-response-using-llm) *(référence conservée du README précédent)*

## 🧭 Sommaire

- [Fonctionnement](#fonctionnement)
- [Les deux voix](#les-deux-voix)
- [Outils et sources de savoir](#outils-et-sources-de-savoir)
- [Démarrage rapide](#démarrage-rapide)
- [Installation et prérequis](#installation-et-prérequis)
- [Configuration](#configuration)
- [À adapter chez vous](#à-adapter-chez-vous)
- [Commandes](#commandes)
- [Mémos et migration vers la base GLPI](#mémos-et-migration-vers-la-base-glpi)
- [Sécurité](#sécurité)
- [Fichiers livrés](#fichiers-livrés)
- [Ancienne version 2](#ancienne-version-2)

## ⚙️ Fonctionnement

Le script décrit un agent local : Ollama pilote les outils GLPI et les sources de savoir; la recherche Web passe par SearXNG local. Le script peut lire le ticket et ses pièces jointes, rechercher dans les mémos, la base de connaissances GLPI et les documents internes, puis classer le ticket, fixer sa priorité et ajouter des suivis. Les outils calendrier ne sont proposés que dans le contexte d'une mention technicien et lorsque Graph est configuré. La configuration active aussi les mentions Myrtille, les mémos, la base GLPI et la documentation interne.

`ProcessedMarker` vaut **8** dans la configuration livrée. Vérifiez et adaptez cette valeur à votre instance GLPI avant tout traitement réel.

> [!NOTE]
> `DryRun = $true` par défaut. Conservez ce mode pour vos essais; la configuration et les comportements précis d'écriture dépendent des actions du script.

## 🗣️ Les deux voix

| Voix | Suivi | Rôle |
|---|---|---|
| **Myrtille** | Public | Réponse destinée à l'utilisateur, fondée sur les sources autorisées. |
| **Perceval** | Privé | Diagnostic destiné aux techniciens; le second compte GLPI utilise `GlpiAideToken`. |

Les deux voix sont portées par le modèle indiqué dans `AgentModel` (`qwen3.5:9b` par défaut). Le script se présente comme le remplacement de la chaîne v3 (plusieurs modèles/Modelfiles et injection brute de pages Web).

## 🧰 Outils et sources de savoir

| Source / outil | Usage |
|---|---|
| GLPI | `glpi_get_ticket` relit un ticket; `glpi_classify` définit type et catégorie ITIL; `glpi_set_priority` règle la priorité; `glpi_add_followup` ajoute un suivi public ou privé. |
| Base de connaissances GLPI | `kb_search` recherche des articles et `kb_read` lit un article par identifiant (`EnableGlpiKb = $true`). |
| Documentation interne | `docs_search` recherche et `docs_read` lit un document dans `InternalDocsPath` (`EnableInternalDocs = $true`). |
| Web | `web_search` et `web_fetch` utilisent respectivement SearXNG puis récupèrent le texte d'une page HTTP(S); présents si `EnableWebSearch = $true`. |
| Agenda Microsoft Graph | `calendar_free_slots` et `calendar_create_event`, uniquement en contexte de mention technicien et si le calendrier est configuré et activé. |
| Mémos | La recherche des fiches locales est intégrée au contexte de connaissance; les mémos sont activés par `EnableMemos`. |
| Teams | Le script prend en charge la connexion déléguée du compte Myrtille avec `-TeamsLogin`; ce n'est pas un outil de la liste Ollama ci-dessus. |

Les huit outils GLPI/savoir (GLPI 4, connaissances 4) sont ajoutés selon les fonctions activées; la recherche Web s'ajoute si activée, et les deux outils calendrier sous la condition indiquée. Les paramètres de l'agent comportent également `UseNativeTools = $true`.

Formats traités pour la documentation interne :

- Images : `.png`, `.jpg`, `.jpeg`, `.gif`, `.bmp`, `.webp`, `.tif`, `.tiff`.
- Documents/texte : `.pdf`, `.docx`, `.xlsx`, `.pptx`, `.odt`, `.odp`, `.txt`, `.csv`, `.md`, `.rtf`, `.html`, `.htm`, `.xml`, `.json`, `.ini`, `.log`, `.eml`.
- Formats legacy reconnus comme tels : `.doc`, `.xls`, `.ppt`.

Le script écarte les chemins sous `.git` et `node_modules`, les fichiers temporaires et certains fichiers système (`~$…`, `thumbs.db`, `desktop.ini`), `relais-*.json`/`.txt`, `Myrtille.ps1` et les noms commençant par `start-glpi`. Il exclut aussi tout nom contenant `token`, `secret`, `password`, `credential` ou `apikey`.

`NumCtx = 16384`. Le commentaire de configuration précise que les extraits sont recherchés plutôt qu'injectés en bloc.

## 🚀 Démarrage rapide

1. **Cloner le dépôt** et créer le dossier de documentation interne.
2. **Installer les modèles** avec Ollama.
3. **Renseigner la configuration GLPI** dans le bloc `CONFIGURATION` de `Myrtille.ps1`.
4. Vérifier `ProcessedMarker` et garder `DryRun = $true` pendant les essais.
5. Tester les services et un ticket avant d'envisager un traitement réel.

```powershell
git clone https://github.com/AlexandreTaboin/automatic-GLPI-ticket-response-using-llm.git
cd automatic-GLPI-ticket-response-using-llm
New-Item -ItemType Directory -Path C:\Scripts\Docs -Force
ollama pull qwen3.5:9b
ollama pull qwen2.5vl:7b
```

> [!WARNING]
> `localhost` désigne la machine qui exécute le script. Les exemples Ollama et SearXNG utilisent HTTP local; ne les exposez pas sur un réseau non fiable.

## 🧩 Installation et prérequis

| Composant | Indication |
|---|---|
| PowerShell | Le script exige PowerShell 5.1 (`#requires -Version 5.1`). |
| GLPI | Le README précédent indique GLPI 10+ et l'API REST. Le script utilise l'API REST, mais ne fixe pas de version minimale GLPI dans son en-tête. |
| Comptes GLPI | Le script configure `GlpiUserToken` et `GlpiAideToken`, ainsi qu'un App-Token; prévoyez les accès correspondants dans GLPI. |
| Ollama | URL par défaut `http://localhost:11434`; modèle agent `qwen3.5:9b`. |
| SearXNG | URL par défaut `http://localhost:8888/search`; recherche activée par défaut. |
| Vision | Modèle par défaut `qwen2.5vl:7b`; téléchargement facultatif selon l'usage des images. |

Le script ne déclare pas de procédure d'installation d'Ollama/GLPI : configurez ces services puis ajustez les valeurs ci-dessous à votre environnement.

## 🛠️ Configuration

Les valeurs du tableau sont celles du bloc `$script:Config` du script 4.17.0, sauf l'URL GLPI présentée en HTTPS comme exemple à personnaliser. Les identifiants/valeurs d'exemple ne sont pas des secrets valides. Le script source contient littéralement `http://glpi.exemple.local/apirest.php` comme valeur placeholder; remplacez-la par l'URL réelle de votre instance, en HTTPS.

| Clé | Valeur par défaut dans le script |
|---|---|
| `GlpiApiUrl` | `https://glpi.exemple.local/apirest.php` *(exemple HTTPS; dans le script source, le placeholder par défaut est `http://glpi.exemple.local/apirest.php`)* |
| `GlpiAppToken` | `VOTRE_APP_TOKEN` |
| `GlpiUserToken` | `VOTRE_USER_TOKEN` |
| `GlpiAideToken` | `VOTRE_USER_TOKEN_AIDE` |
| `ProcessedMarker` | `8` |
| `OllamaUrl` | `http://localhost:11434` |
| `AgentModel` | `qwen3.5:9b` |
| `UseNativeTools` | `$true` |
| `Think` | `$false` |
| `NumCtx` | `16384` |
| `SearxngUrl` | `http://localhost:8888/search` |
| `EnableWebSearch` | `$true` |
| `WebResultsCount` / `WebPageMaxChars` / `WebPageMaxFetch` | `4` / `2500` / `3` |
| `SearchLanguage` / `ShowSources` | `'fr'` / `$true` |
| `MaxToolRounds` / `AgentTimeoutSec` / `PollIntervalSec` | `15` / `1800000` / `30` |
| `LogFile` / `MemoryFile` | `C:\Scripts\GLPI_Agent.log` / `C:\Scripts\GLPI_LastTicket.txt` |
| `DevMode` / `DryRun` | `$false` / `$true` |
| `EnableCalendar` | `$false` |
| `GraphTenantId` / `GraphClientId` | `00000000-0000-0000-0000-000000000000` *(chacun)* |
| `GraphClientSecret` | `VOTRE_SECRET_CLIENT` |
| `GraphOrganizerUpn` | `assistant@exemple.fr` |
| `GraphTechUpns` | `technicien.un@exemple.fr`, `technicien.deux@exemple.fr` |
| `GraphTimezone` | `Romance Standard Time` |
| `GraphSlotMinutes` / `GraphSetupMinutes` / `GraphDaysAhead` / `GraphMaxSlots` | `60` / `15` / `10` / `4` |
| `GraphMorningStart` / `GraphMorningEnd` | `08:30` / `12:00` |
| `GraphAfternoonStart` / `GraphAfternoonEnd` | `13:30` / `17:00` |
| `EnableMyrtilleMentions` / `EnableMemos` | `$true` / `$true` |
| `EnableGlpiKb` / `GlpiKbMaxHits` / `GlpiKbCacheMin` / `GlpiKbCatalogMax` | `$true` / `4` / `20` / `2500` |
| `EnableInternalDocs` / `InternalDocsPath` | `$true` / `C:\Scripts\Docs` |
| `DocsMaxHits` / `DocsExcerptChars` / `DocsIndexChars` / `DocsMaxFiles` | `3` / `700` / `5000` / `400` |
| `EnableTeams` | `$false` |
| `MyrtilleMail` | `assistant@exemple.fr` |
| `TeamsAllowedMails` | `technicien.un@exemple.fr`, `technicien.deux@exemple.fr` |
| `TeamsGlpiNames` | `technicien.un@exemple.fr` → `Prenom NOM` |
| `VisionModel` | `qwen2.5vl:7b` |
| `MaxTicketImages` / `MaxTicketFiles` | `3` / `4` |
| `MaxFileBytes` / `MaxFileChars` / `VisionTimeoutSec` | `6000000` / `4000` / `18000` |

Exemple à personnaliser (conserver les URL locales en HTTP) :

```powershell
# Extrait du hashtable de configuration de Myrtille.ps1
GlpiApiUrl = 'https://glpi.exemple.local/apirest.php'
GlpiAppToken = 'VOTRE_APP_TOKEN'
GlpiUserToken = 'VOTRE_USER_TOKEN'
GlpiAideToken = 'VOTRE_USER_TOKEN_AIDE'
ProcessedMarker = 8
OllamaUrl = 'http://localhost:11434'
AgentModel = 'qwen3.5:9b'
NumCtx = 16384
SearxngUrl = 'http://localhost:8888/search'
InternalDocsPath = 'C:\Scripts\Docs'
DryRun = $true
DevMode = $false
EnableCalendar = $false
EnableTeams = $false
```

> [!NOTE]
> L'exemple HTTPS ci-dessus est un réglage conseillé à remplacer par l'URL GLPI réelle; dans le source livré, la chaîne littérale placeholder commence par HTTP. Vérifiez donc `GlpiApiUrl` avant usage réel. Le nom de la clé de configuration est bien `SearxngUrl` (et non `SearxUrl`).

## 🧑‍🔧 À adapter chez vous

- `Get-XdematAppCatalog` contient le catalogue xDemat et ses chemins ITIL; adaptez ses entrées à votre environnement.
- `Get-ItilKeywordHint` et `Test-IsOnboardingTicket` contiennent des règles métier et des exemples propres au contexte; personnalisez-les. Le script inclut notamment `formulaire.exemple.fr/todos` comme motif de ticket d'arrivée.
- **Agenda Graph** : `EnableCalendar = $false` par défaut. L'en-tête indique les permissions d'application `Calendars.Read` et `Calendars.ReadWrite` (consentement administrateur), avec tenant, client, secret et UPN d'organisateur à configurer.
- **Teams** : `EnableTeams = $false` par défaut. L'en-tête demande le flux clients publics activé et les permissions déléguées `Chat.ReadWrite`, `User.Read` et `offline_access`, puis la connexion `-TeamsLogin`. Le code demande aussi `User.ReadBasic.All` au moment de l'authentification. Le secret d'application ne permet pas l'envoi des messages Teams.

## 💻 Commandes

Les paramètres ci-dessous sont les paramètres réels du bloc `param()`; les paramètres numériques (`TicketId`, `PreviewKnowledge`, `DumpTicket`) reçoivent un identifiant en argument.

### 🧪 Essais et traitement

```powershell
# Vérifier GLPI, Ollama et SearXNG
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Myrtille.ps1 -Test

# Afficher les connaissances pour un ticket sans modifier GLPI
powershell.exe -File .\Myrtille.ps1 -PreviewKnowledge 1234

# Traiter un ticket précis (DryRun vaut true par défaut)
powershell.exe -File .\Myrtille.ps1 -TicketId 1234

# Un cycle puis sortie
powershell.exe -File .\Myrtille.ps1 -Once
```

### 📋 Options CLI

| Paramètre | Défaut / argument | Effet (résumé du help du script) |
|---|---|---|
| `-Once` | switch | Un cycle puis sortie (planificateur de tâches). |
| `-TicketId` | `0` | Traite un ticket précis et ignore le polling. |
| `-PreviewKnowledge` | `0` | Affiche mémos, articles GLPI et documentation interne du ticket; ne modifie pas GLPI. |
| `-Test` | switch | Vérifie GLPI, Ollama et SearXNG puis quitte. |
| `-AnalyzeCategories` | switch | Classe un échantillon de tickets via Ollama et écrit un rapport CSV. |
| `-AnalyzeLimit` | `80` | Nombre maximal transmis à l'analyse des catégories (défaut du paramètre). |
| `-ClassifyOpen` | switch | Recalcule type et catégorie ITIL sur les tickets ouverts, sans suivi Myrtille. |
| `-ClassifyClosed` | switch | Recalcule type et catégorie ITIL sur les tickets résolus et clos, sans suivi. |
| `-ClassifyLimit` | `400` | Nombre maximal de tickets clos à parcourir. |
| `-DumpTicket` | `0` | Exporte un ticket (texte, photos, catégorie et proposition Relais) pour revue, sans modification GLPI. |
| `-DumpAll` | switch | Exporte tickets ouverts et clos en CSV, Markdown, photos et résumé; sans modification GLPI. |
| `-DumpLimit` | `2000` | Nombre maximal de tickets pour `-DumpAll`. |
| `-DumpVision` | switch | Avec `-DumpAll`, demande aussi la description des photos via le modèle vision. |
| `-BuildMemos` | switch | Résume les tickets résolus et clos en fiches mémo anonymisées (sans nom, e-mail, poste). |
| `-MemoLimit` | `4000` | Nombre maximal de tickets pour `-BuildMemos` dans le bloc `param()`. |
| `-MigrateMemosToKb` | switch | Publie les fiches mémo locales dans la base de connaissances GLPI; les fiches déjà publiées sont ignorées. |
| `-PurgeExcludedMemos` | switch | Retire les fiches d'arrivée d'agent et alertes répétitives antivirus, en local et dans GLPI. |
| `-TeamsLogin` | switch | Connecte une fois le compte Office de Myrtille. |

> [!WARNING]
> L'en-tête d'aide dit `MemoLimit` par défaut **40**, alors que le bloc `param()` fixe **4000**. Le tableau reflète la valeur exécutable du paramètre; cette incohérence est dans le script lui-même. Les paramètres optionnels `AnalyzeLimit`, `DumpAll`, `DumpLimit`, `DumpVision` et `MemoLimit` sont réels même s'ils manquaient dans l'ancien tableau.

Le contexte Ollama est limité par `NumCtx = 16384` selon la configuration par défaut.

## 🗂️ Mémos et migration vers la base GLPI

Les fiches locales sont enregistrées dans **`relais-memos.json`** à côté du répertoire de `MemoryFile`. `-BuildMemos` crée/alimente ces fiches à partir des tickets résolus et clos; `-MigrateMemosToKb` les publie dans la base de connaissances GLPI; `-PurgeExcludedMemos` retire les fiches exclues localement et dans GLPI.

Le script reconnaît les formulations de demande de mémo comme **`/memo`**, `/fiche` et `/retenir` dans un échange. Exemple de demande : « note la solution avec /memo ». Le filtrage retire certains identifiants personnels, mais ne garantit pas l'anonymisation parfaite.

```powershell
powershell.exe -File .\Myrtille.ps1 -BuildMemos
powershell.exe -File .\Myrtille.ps1 -MigrateMemosToKb
powershell.exe -File .\Myrtille.ps1 -PurgeExcludedMemos
```

## 🔐 Sécurité

> [!WARNING]
> **Tokens et secrets** — Ne commitez jamais les jetons, secrets, journaux, fichiers `relais-*.json` ni les documents internes. Employez uniquement des valeurs d'exemple dans la documentation. Si un secret a été publié, révoquez-le dans GLPI ou Entra.

- Gardez `DryRun = $true` pendant la validation.
- L'index documentaire exclut les noms contenant `token`, `secret`, `password`, `credential` ou `apikey`; l'index écarte aussi `Myrtille.ps1` et les fichiers `start-glpi…`.
- Les mémos sont débarrassés de motifs d'e-mail, téléphone, IP, chemins de profils et autres identifiants repérés par le code. Ce traitement n'est pas une garantie d'anonymisation.
- `DevMode = $false` par défaut. Évitez le mode de développement sur un poste partagé.

## 📦 Fichiers livrés

| Fichier | Rôle |
|---|---|
| `Myrtille.ps1` | Script PowerShell; l'en-tête indique version 4.17.0. |
| `readme.html` | Page de documentation du projet (nom référencé par l'ancien README; non confirmé par le script). |
| `README.md` | Documentation Markdown. |
| `.gitignore` | Nom référencé par l'ancien README; règles non vérifiables à partir du seul script. |

## 🕰️ Ancienne version 2

La version du script fourni est **4.17.0**. Son en-tête indique qu'il remplace la chaîne v3 et l'injection brute des pages Web. La mention de l'ancienne v2 (2.26) et des Modelfiles `GLPIa`, `GLPIaresponse` et `glpiaide` provenait de l'ancien README et n'est pas documentée dans le script fourni.
