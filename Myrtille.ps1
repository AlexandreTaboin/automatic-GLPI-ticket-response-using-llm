<#
Description : Ce script permet de définir automatiquement la priorité d'un ticket GLPI ainsi que de fournir une première réponse via une IA
Usage : Nécessite GLPI avec API, Ollama avec les modèles "GLPIa", "GLPIaresponse" et "glpiaide"
Auteur : Alexandre TABOIN https://taboin.fr
Usage de l'IA : Oui, Chat-GPT 4o, mistral-codestral et Claude OPUS 4.6
Version : 2.26.02
Révision : 
        - 1.24.07 (31/07/2024) : Version Initiale fonctionnelle
        - 2.26.02 (17/02/2026) : Optimisation complète, gestion des tickets clos, logging amélioré
#>

#region CONFIGURATION
$Script:Config = @{
    ApiUrl           = "http://serveurglpi.local/glpi/apirest.php"
    AppToken         = "Token"
    UserToken        = "Token"
    GlpiaideToken    = "Token"
    OllamaUrl        = "http://localhost:11434/api/generate"
    Models           = @{
        Priority = "GLPIa"
        Response = "GLPIaresponse"
        Aide     = "glpiaide"
    }
    ProcessedMarker  = 8
    RetryDelay       = 30
    OllamaTimeout    = 9000        
    LogFile          = "C:\Scripts\GLPI_Process.log"
    MemoryFile       = "C:\Scripts\GLPI_LastTicket.txt"
}
#endregion

#region FONCTIONS UTILITAIRES

#Utile pour du débug, pas besoin en prod
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error")]
        [string]$Level = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry  = "[$timestamp][$Level] $Message"
    Add-Content -Path $Script:Config.LogFile -Value $logEntry -ErrorAction SilentlyContinue

    switch ($Level) {
        "Info"    { Write-Host $logEntry -ForegroundColor Gray }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
    }
}

function Initialize-Session {
    param([string]$UserToken, [string]$Label = "")
    try {
        $response = Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/initSession" `
            -Method Get `
            -Headers @{
                "app-token"       = $Script:Config.AppToken
                "Authorization"   = "user_token $UserToken"
            }

        if ($response.session_token) {
            Write-Log "Session $Label ouverte" -Level Success
            return $response.session_token
        }
    }
    catch {
        Write-Log "Erreur session ${Label}: $($_.Exception.Message)" -Level Error
    }
    return $null
}

function Close-GLPISession {
    param([string]$SessionToken, [string]$Label = "")
    if (-not $SessionToken) { return }
    try {
        Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/killSession" `
            -Method Get `
            -Headers @{
                "app-token"     = $Script:Config.AppToken
                "session-token" = $SessionToken
            } | Out-Null
        Write-Log "Session $Label fermée" -Level Info
    }
    catch {
        Write-Log "Erreur fermeture ${Label}: $($_.Exception.Message)" -Level Warning
    }
}

function Get-AuthHeaders {
    param([string]$SessionToken)
    return @{
        "app-token"     = $Script:Config.AppToken
        "session-token" = $SessionToken
    }
}

function Get-LastProcessedId {
    if (Test-Path $Script:Config.MemoryFile) {
        $content = Get-Content $Script:Config.MemoryFile -Raw
        if ($content -and $content.Trim() -match '^\d+$') { return [int]$content.Trim() }
    }
    return 0
}

function Save-LastProcessedId {
    param([int]$Id)
    $Id.ToString() | Set-Content -Path $Script:Config.MemoryFile -Force
}

function Convert-MarkdownToHtml {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "<p>Aucune réponse générée.</p>" }

    $lines   = $Text -split "`n"
    $result  = @()
    $inTable = $false
    $tableRows = @()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Détection lignes de tableau markdown
        if ($trimmed -match '^\|(.+)\|$') {
            $cells = ($trimmed -split '\|' | Where-Object { $_.Trim() -ne '' }) | ForEach-Object { $_.Trim() }

            # Ignorer les lignes séparateur (|---|---|)
            if ($trimmed -match '^\|[\s\-:\|]+\|$') { continue }

            if (-not $inTable) {
                $inTable   = $true
                $tableRows = @()
            }
            $tableRows += ,@($cells)
            continue
        }

        # Si on sort d'un tableau
        if ($inTable) {
            $html = "<table border='1' style='border-collapse:collapse;padding:4px;'>"
            for ($i = 0; $i -lt $tableRows.Count; $i++) {
                $tag  = if ($i -eq 0) { "th" } else { "td" }
                $html += "<tr>"
                foreach ($cell in $tableRows[$i]) {
                    $html += "<$tag style='padding:4px;'>$cell</$tag>"
                }
                $html += "</tr>"
            }
            $html += "</table>"
            $result += $html
            $inTable   = $false
            $tableRows = @()
        }

        # Titres
        if ($trimmed -match '^###\s+(.+)$')    { $result += "<p><b><i>$($Matches[1])</i></b></p>"; continue }
        if ($trimmed -match '^##\s+(.+)$')     { $result += "<h3>$($Matches[1])</h3>"; continue }
        if ($trimmed -match '^#\s+(.+)$')      { $result += "<h2>$($Matches[1])</h2>"; continue }

        # Listes à puces
        if ($trimmed -match '^\*\s+(.+)$' -or $trimmed -match '^\-\s+(.+)$') {
            $result += "<li>$($Matches[1])</li>"
            continue
        }

        # Ligne vide
        if ([string]::IsNullOrWhiteSpace($trimmed)) { $result += "<br>"; continue }

        # Ligne normale
        $result += "<p>$trimmed</p>"
    }

    # Fermer tableau en cours
    if ($inTable -and $tableRows.Count -gt 0) {
        $html = "<table border='1' style='border-collapse:collapse;padding:4px;'>"
        for ($i = 0; $i -lt $tableRows.Count; $i++) {
            $tag  = if ($i -eq 0) { "th" } else { "td" }
            $html += "<tr>"
            foreach ($cell in $tableRows[$i]) {
                $html += "<$tag style='padding:4px;'>$cell</$tag>"
            }
            $html += "</tr>"
        }
        $html += "</table>"
        $result += $html
    }

    $output = ($result -join "`n")

    # Inline markdown
    $output = [regex]::Replace($output, '\*\*(.+?)\*\*', '<b>$1</b>')
    $output = [regex]::Replace($output, '\*(.+?)\*', '<i>$1</i>')
    $output = [regex]::Replace($output, '`(.+?)`', '<code>$1</code>')

    return $output
}

function Clean-HtmlForJson {
    param([string]$Text)
    # Nettoyer les caractères problématiques pour JSON
    $Text = $Text -replace '\\', '\\\\'
    $Text = $Text -replace '"', '\"'
    $Text = $Text -replace "`r`n", '\n'
    $Text = $Text -replace "`r", '\n'
    $Text = $Text -replace "`n", '\n'
    $Text = $Text -replace "`t", '\t'
    return $Text
}

#endregion

#region FONCTIONS GLPI

function Get-NewUnprocessedTickets {
    param([string]$SessionToken)

    $headers = Get-AuthHeaders -SessionToken $SessionToken

    $uri = "$($Script:Config.ApiUrl)/search/Ticket?" +
        "criteria[0][field]=12&" +
        "criteria[0][searchtype]=equals&" +
        "criteria[0][value]=1&" +
        "criteria[1][link]=AND&" +
        "criteria[1][field]=9&" +
        "criteria[1][searchtype]=notequals&" +
        "criteria[1][value]=$($Script:Config.ProcessedMarker)&" +
        "forcedisplay[0]=2&" +
        "forcedisplay[1]=1&" +
        "forcedisplay[2]=12&" +
        "forcedisplay[3]=9&" +
        "sort=2&order=ASC&" +
        "range=0-49"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $headers

        if (-not $response.data -or $response.totalcount -eq 0) {
            Write-Log "Aucun ticket nouveau non traité" -Level Info
            return @()
        }

        $tickets = @()
        foreach ($item in $response.data) {
            $tickets += [PSCustomObject]@{
                Id          = [int]$item.'2'
                Title       = $item.'1'
                Status      = $item.'12'
                RequestType = $item.'9'
            }
        }

        Write-Log "$($tickets.Count) ticket(s) nouveau(x) non traité(s) trouvé(s)" -Level Info
        return $tickets
    }
    catch {
        Write-Log "Erreur recherche tickets : $($_.Exception.Message)" -Level Error
        return @()
    }
}

function Get-TicketDetails {
    param(
        [string]$SessionToken,
        [int]$TicketId
    )
    $headers = Get-AuthHeaders -SessionToken $SessionToken
    try {
        $ticket = Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/Ticket/$TicketId" `
            -Method Get `
            -ContentType "application/json" `
            -Headers $headers

        # Nettoyer le contenu HTML de GLPI pour l'envoyer à l'IA
        $cleanContent = $ticket.content -replace '<[^>]+>', ' '
        $cleanContent = $cleanContent -replace '&nbsp;', ' '
        $cleanContent = $cleanContent -replace '&amp;', '&'
        $cleanContent = $cleanContent -replace '&lt;', '<'
        $cleanContent = $cleanContent -replace '&gt;', '>'
        $cleanContent = $cleanContent -replace '\s+', ' '
        $cleanContent = $cleanContent.Trim()

        return @{
            Name    = $ticket.name
            Content = $cleanContent
            Status  = $ticket.status
        }
    }
    catch {
        Write-Log "Erreur lecture ticket $TicketId : $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Update-TicketPriority {
    param(
        [string]$SessionToken,
        [int]$TicketId,
        [int]$Priority
    )
    $headers = Get-AuthHeaders -SessionToken $SessionToken
    try {
        # IMPORTANT : envoyer UNIQUEMENT id + priority, rien d'autre
        $body = @{
            input = @{
                id       = $TicketId
                priority = $Priority
            }
        } | ConvertTo-Json -Depth 3 -Compress

        Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/Ticket/$TicketId" `
            -Method Put `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -ContentType "application/json; charset=utf-8" `
            -Headers $headers | Out-Null

        Write-Log "Priorité du ticket $TicketId mise à $Priority" -Level Success
        return $true
    }
    catch {
        Write-Log "Erreur MAJ priorité ticket $TicketId : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Mark-TicketAsProcessed {
    param(
        [string]$SessionToken,
        [int]$TicketId
    )
    $headers = Get-AuthHeaders -SessionToken $SessionToken
    try {
        # IMPORTANT : envoyer UNIQUEMENT id + requesttypes_id
        $body = @{
            input = @{
                id              = $TicketId
                requesttypes_id = $Script:Config.ProcessedMarker
            }
        } | ConvertTo-Json -Depth 3 -Compress

        Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/Ticket/$TicketId" `
            -Method Put `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -ContentType "application/json; charset=utf-8" `
            -Headers $headers | Out-Null

        Write-Log "Ticket $TicketId marqué comme traité (requesttypes_id=$($Script:Config.ProcessedMarker))" -Level Success
        return $true
    }
    catch {
        Write-Log "Erreur marquage ticket $TicketId : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Add-TicketFollowup {
    param(
        [string]$SessionToken,
        [int]$TicketId,
        [string]$Content,
        [bool]$IsPrivate = $false
    )
    $headers = Get-AuthHeaders -SessionToken $SessionToken

    $privateVal = if ($IsPrivate) { 1 } else { 0 }

    # Méthode 1 : endpoint direct ITILFollowup (GLPI 10.x)
    try {
        $body = @{
            input = @{
                itemtype   = "Ticket"
                items_id   = $TicketId
                content    = $Content
                is_private = $privateVal
            }
        } | ConvertTo-Json -Depth 3

        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/ITILFollowup" `
            -Method Post `
            -Body $bodyBytes `
            -ContentType "application/json; charset=utf-8" `
            -Headers $headers | Out-Null

        $type = if ($IsPrivate) { "privé" } else { "public" }
        Write-Log "Suivi $type ajouté au ticket $TicketId" -Level Success
        return $true
    }
    catch {
        $errorMsg1 = $_.Exception.Message
        Write-Log "Followup méthode 1 échouée: $errorMsg1 - Essai méthode 2..." -Level Warning
    }

    # Méthode 2 : endpoint Ticket/ID/ITILFollowup (ancienne API)
    try {
        $body2 = @{
            input = @{
                tickets_id = $TicketId
                content    = $Content
                is_private = $privateVal
            }
        } | ConvertTo-Json -Depth 3

        $bodyBytes2 = [System.Text.Encoding]::UTF8.GetBytes($body2)

        Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/Ticket/$TicketId/ITILFollowup" `
            -Method Post `
            -Body $bodyBytes2 `
            -ContentType "application/json; charset=utf-8" `
            -Headers $headers | Out-Null

        $type = if ($IsPrivate) { "privé" } else { "public" }
        Write-Log "Suivi $type ajouté au ticket $TicketId (méthode 2)" -Level Success
        return $true
    }
    catch {
        $errorMsg2 = $_.Exception.Message
        Write-Log "Followup méthode 2 échouée: $errorMsg2" -Level Error
    }

    # Méthode 3 : endpoint TicketFollowup (GLPI < 10)
    try {
        $body3 = @{
            input = @{
                tickets_id = $TicketId
                content    = $Content
                is_private = $privateVal
            }
        } | ConvertTo-Json -Depth 3

        $bodyBytes3 = [System.Text.Encoding]::UTF8.GetBytes($body3)

        Invoke-RestMethod `
            -Uri "$($Script:Config.ApiUrl)/TicketFollowup" `
            -Method Post `
            -Body $bodyBytes3 `
            -ContentType "application/json; charset=utf-8" `
            -Headers $headers | Out-Null

        $type = if ($IsPrivate) { "privé" } else { "public" }
        Write-Log "Suivi $type ajouté au ticket $TicketId (méthode 3)" -Level Success
        return $true
    }
    catch {
        Write-Log "ECHEC ajout suivi ticket $TicketId (3 méthodes testées)" -Level Error
        return $false
    }
}

#endregion

#region FONCTIONS IA (OLLAMA)

function Invoke-OllamaModel {
    param(
        [string]$Model,
        [string]$Prompt
    )
    try {
        Write-Log "Appel Ollama modèle '$Model' (timeout: $($Script:Config.OllamaTimeout)s)..." -Level Info

        $body = @{
            model  = $Model
            prompt = $Prompt
            stream = $false
        } | ConvertTo-Json -Depth 3

        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        $ollamaResponse = Invoke-RestMethod `
            -Uri $Script:Config.OllamaUrl `
            -Method Post `
            -Body $bodyBytes `
            -ContentType "application/json; charset=utf-8" `
            -TimeoutSec $Script:Config.OllamaTimeout

        # Gestion multi-objets JSON
        if ($ollamaResponse -is [array]) {
            $combined = ($ollamaResponse | ForEach-Object { $_.response }) -join ""
            Write-Log "Réponse Ollama '$Model' reçue (multi-bloc, $($combined.Length) chars)" -Level Info
            return $combined
        }

        if ($ollamaResponse.response) {
            Write-Log "Réponse Ollama '$Model' reçue ($($ollamaResponse.response.Length) chars)" -Level Info
            return $ollamaResponse.response
        }

        Write-Log "Réponse Ollama '$Model' vide" -Level Warning
        return $null
    }
    catch {
        Write-Log "Erreur Ollama ($Model) : $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Get-AIPriority {
    param([string]$TicketContent)
    $prompt = "Analyse ce ticket et donne uniquement un chiffre de 1 à 6 pour la priorité : $TicketContent"
    $result = Invoke-OllamaModel -Model $Script:Config.Models.Priority -Prompt $prompt

    if ($result -and $result -match '([1-6])') {
        return [int]$Matches[1]
    }
    Write-Log "IA priorité : réponse invalide '$result', défaut 3" -Level Warning
    return 3
}

function Get-AIResponse {
    param([string]$TicketContent)
    $prompt = "Propose une première réponse pour ce ticket IT : $TicketContent"
    return Invoke-OllamaModel -Model $Script:Config.Models.Response -Prompt $prompt
}

function Get-AIAideAnalysis {
    param([string]$TicketContent)
    $prompt = "Analyse ce ticket et propose des pistes de résolution pour le technicien : $TicketContent"
    return Invoke-OllamaModel -Model $Script:Config.Models.Aide -Prompt $prompt
}

#endregion

#region TRAITEMENT PRINCIPAL

function Process-SingleTicket {
    param(
        [hashtable]$Sessions,
        [int]$TicketId,
        [string]$TicketTitle
    )

    Write-Log "--- Traitement ticket #$TicketId : $TicketTitle ---" -Level Info

    # 1. Lire les détails
    $details = Get-TicketDetails -SessionToken $Sessions.Main -TicketId $TicketId
    if (-not $details) {
        Write-Log "Impossible de lire le ticket $TicketId, skip" -Level Error
        return $false
    }

    $fullContent = "$($details.Name) - $($details.Content)"
    Write-Log "Contenu ticket: $($fullContent.Substring(0, [Math]::Min(100, $fullContent.Length)))..." -Level Info

    # 2. Déterminer la priorité via IA
    Write-Log "Analyse priorité par IA..." -Level Info
    $priority = Get-AIPriority -TicketContent $fullContent
    Update-TicketPriority -SessionToken $Sessions.Main -TicketId $TicketId -Priority $priority

    # 3. Générer la réponse publique via IA
    Write-Log "Génération réponse publique par IA..." -Level Info
    $publicResponse = Get-AIResponse -TicketContent $fullContent
    if ($publicResponse) {
        $htmlResponse = Convert-MarkdownToHtml -Text $publicResponse
        Add-TicketFollowup -SessionToken $Sessions.Main -TicketId $TicketId -Content $htmlResponse -IsPrivate $false
    }
    else {
        Write-Log "Pas de réponse publique générée pour ticket $TicketId" -Level Warning
    }

    # 4. Générer l'analyse technique (suivi privé via compte GLPIaide)
    Write-Log "Génération analyse technique par IA..." -Level Info
    $techAnalysis = Get-AIAideAnalysis -TicketContent $fullContent
    if ($techAnalysis) {
        $htmlAnalysis = Convert-MarkdownToHtml -Text $techAnalysis
        Add-TicketFollowup -SessionToken $Sessions.Glpiaide -TicketId $TicketId -Content $htmlAnalysis -IsPrivate $true
    }
    else {
        Write-Log "Pas d'analyse technique générée pour ticket $TicketId" -Level Warning
    }

    # 5. DERNIER : Marquer le ticket comme traité (requesttypes_id = 8)
    # Fait en dernier pour éviter le ping-pong avec les autres PUT
    Start-Sleep -Milliseconds 500
    Mark-TicketAsProcessed -SessionToken $Sessions.Main -TicketId $TicketId

    Write-Log "Ticket #$TicketId traité avec succès (priorité=$priority)" -Level Success
    return $true
}

function Start-TicketProcessing {
    Write-Host ""
    Write-Host ([char]0x2554 + ([string][char]0x2550 * 62) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ("$([char]0x2551)  GLPI - Traitement automatique par IA v2.25.02q          $([char]0x2551)") -ForegroundColor Cyan
    Write-Host ("$([char]0x2551)  Modeles : GLPIa / GLPIaresponse / glpiaide               $([char]0x2551)") -ForegroundColor Cyan
    Write-Host ("$([char]0x2551)  Filtre : Nouveaux tickets (statut 1, source != 8)        $([char]0x2551)") -ForegroundColor Cyan
    Write-Host ("$([char]0x2551)  Marqueur : requesttypes_id = $($Script:Config.ProcessedMarker)                          $([char]0x2551)") -ForegroundColor Cyan
    Write-Host ([char]0x255A + ([string][char]0x2550 * 62) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ""

    while ($true) {
        $sessions = $null
        try {
            Write-Log "=== Nouveau cycle ===" -Level Info

            # Ouvrir les sessions
            $mainSession   = Initialize-Session -UserToken $Script:Config.UserToken -Label "principal"
            $glaideSession = Initialize-Session -UserToken $Script:Config.GlpiaideToken -Label "GLPIaide"

            if (-not $mainSession -or -not $glaideSession) {
                Write-Log "Impossible d'ouvrir les sessions, retry dans $($Script:Config.RetryDelay)s" -Level Error
                # Fermer celles qui ont pu s'ouvrir
                if ($mainSession)   { Close-GLPISession -SessionToken $mainSession -Label "principal" }
                if ($glaideSession) { Close-GLPISession -SessionToken $glaideSession -Label "GLPIaide" }
                Start-Sleep -Seconds $Script:Config.RetryDelay
                continue
            }

            $sessions = @{
                Main     = $mainSession
                Glpiaide = $glaideSession
            }

            # Récupérer les tickets non traités
            $tickets = Get-NewUnprocessedTickets -SessionToken $sessions.Main

            if (-not $tickets -or $tickets.Count -eq 0) {
                Write-Log "Aucun ticket à traiter" -Level Info
            }
            else {
                $totalProcessed = 0
                $totalErrors    = 0
                $lastProcessedId = Get-LastProcessedId

                foreach ($ticket in $tickets) {
                    $ticketId = $ticket.Id

                    # Double sécurité : fichier mémoire
                    if ($ticketId -le $lastProcessedId) {
                        Write-Log "Ticket #$ticketId déjà traité (mémoire), skip" -Level Warning
                        continue
                    }

                    $success = Process-SingleTicket -Sessions $sessions -TicketId $ticketId -TicketTitle $ticket.Title

                    if ($success) {
                        $totalProcessed++
                        Save-LastProcessedId -Id $ticketId
                        $lastProcessedId = $ticketId
                    }
                    else {
                        $totalErrors++
                    }

                    # Pause entre tickets pour ne pas surcharger
                    Start-Sleep -Seconds 2
                }

                Write-Log "Cycle terminé : $totalProcessed traité(s), $totalErrors erreur(s)" -Level Success
            }
        }
        catch {
            Write-Log "Erreur cycle principal : $($_.ToString())" -Level Error
        }
        finally {
            # Toujours fermer les sessions
            if ($sessions) {
                Close-GLPISession -SessionToken $sessions.Main -Label "principal"
                Close-GLPISession -SessionToken $sessions.Glpiaide -Label "GLPIaide"
            }
        }

        Write-Log "Prochain cycle dans $($Script:Config.RetryDelay)s" -Level Info
        Write-Host ("=" * 66) -ForegroundColor DarkGray
        Start-Sleep -Seconds $Script:Config.RetryDelay
    }
}

Start-TicketProcessing
#endregion
