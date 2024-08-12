<#
Description : ce script permet de définir automatiquement la priorité d'un ticket GLPI ainsi que de fournir une première réponse via une IA
Usage : vous auriez besoin d'un GLPI avec l'API et un compte ayant les bons droits. de l'application Ollama ainsi que deux modèles "GLPIa" qui donnera la priorité et "GLPIaresponse" qui répondra aux tickets
Auteur : Alexandre TABOIN https://taboin.fr
Usage de l'IA : Oui, Chat-GPT 4o et mistral-codestral
Dépendances : OLLAMA et son API https://ollama.com/
Version : 24.08.2
Révision : 
        - 24.07.1 (31/07/2024) : Version Initiale fonctionnelle
        - 24.08.1 (05/08/2024) : Correction du bug empêchant le script de dépasser les 48 tickets
        - 24.08.2 (31/07/2024) : Ajout d'une seconde IA visant à aider les techniciens en les mettant sur une piste 
#>

function Clean-ResponseContent {
    param (
        [string]$inputString
    )

    # Décode les entités HTML
    $decodedContent = [System.Web.HttpUtility]::HtmlDecode($inputString)

    # Utiliser des expressions régulières pour supprimer les balises HTML
    $cleanedContent = $decodedContent -replace "<.*?>", ""

    # Supprimer les espaces en excès et normaliser les nouvelles lignes
    $cleanedContent = $cleanedContent -replace "\s{2,}", " " -replace "`r`n", "`n"

    return $cleanedContent.Trim()
}

# Définir les paramètres de l'API et les jetons
$apiUrl = "http://adresse_de_votre_glpi/glpi/apirest.php"
$appToken = "Token de l'application a créer dans GLPI"
$userToken = "Token du premier utilisateur qui va modifier le ticket et répondre a l'utilisateur"

# Jeton d'API du second utilisateur pour GLPIaide
$userTokenGlpiaide = "Token du second utilisateur qui va répondre en privé pour aider les tech"

# Charger l'assembly System.Net.Http pour utiliser HttpClient
Add-Type -AssemblyName "System.Net.Http"

while ($true) {
    $currentTime = Get-Date
    if ($currentTime.Hour -ge 17) {
        Write-Output "Il est après 17h. Arrêt du serveur."
        #Stop-Computer
        Write-Output "Ou pas..." #Je n'arrive pas à faire démarrer ce serveur HP via l'API du coup j'ai désactivé l'arrêt du serveur en commentant la commande "break" qui as pour but d'arrêter le script
        #break
    }

    try {
        # Obtenir le jeton de session pour le premier utilisateur
        $sessionTokenUrl = "$apiUrl/initSession"
        $sessionTokenBody = @{
            user_token = $userToken
        }
        $sessionTokenResponse = Invoke-RestMethod -Uri $sessionTokenUrl -Method Post -Body ($sessionTokenBody | ConvertTo-Json) -ContentType "application/json" -Headers @{ "app-token" = $appToken }
        $sessionToken = $sessionTokenResponse.session_token

        # Obtenir le jeton de session pour le second utilisateur
        $sessionTokenBodyGlpiaide = @{
            user_token = $userTokenGlpiaide
        }
        $sessionTokenResponseGlpiaide = Invoke-RestMethod -Uri $sessionTokenUrl -Method Post -Body ($sessionTokenBodyGlpiaide | ConvertTo-Json) -ContentType "application/json" -Headers @{ "app-token" = $appToken }
        $sessionTokenGlpiaide = $sessionTokenResponseGlpiaide.session_token
    } catch {
        Write-Error "Erreur lors de l'obtention des jetons de session: $_"
        Start-Sleep -Seconds 300
        continue
    }

    $startTicket = 0
    $ticketBatchSize = 30
    $retryFlag = $false

    while ($true) {
        try {
            # Obtenir la liste des tickets par lot de 30
            $ticketsUrl = "$apiUrl/Ticket?range=$startTicket-" + ($startTicket + $ticketBatchSize - 1)
            $ticketsResponse = Invoke-RestMethod -Uri $ticketsUrl -Method Get -ContentType "application/json" -Headers @{ "app-token" = $appToken; "session-token" = $sessionToken }
            $tickets = $ticketsResponse

            if ($tickets.Length -eq 0) {
                Write-Output "Aucun ticket trouvé dans la plage $startTicket à " + ($startTicket + $ticketBatchSize - 1) + ". Recherche de la prochaine plage."
                break
            }

            # Traiter chaque ticket
            foreach ($ticket in $tickets) {
                $ticketId = $ticket.id

                try {
                    # Obtenir les détails du ticket
                    $ticketUrl = "$apiUrl/Ticket/$ticketId"
                    $ticketResponse = Invoke-RestMethod -Uri $ticketUrl -Method Get -ContentType "application/json" -Headers @{ "app-token" = $appToken; "session-token" = $sessionToken }

                    # Passer le traitement si la source du ticket est déjà "IA" (8)
                    if ($ticketResponse.requesttypes_id -eq 8) {
                        Write-Output ("Skipping Ticket ID {0}: Source is already 'IA'" -f $ticketId)
                        continue
                    }

                    # Extraire le contenu du ticket
                    $ticketContent = $ticketResponse.content

                    # Nettoyer le contenu du ticket
                    $cleanedTicketContent = Clean-ResponseContent -inputString $ticketContent

                    # Étape 1 : Gestion de la priorité par glpia
                    $glpiaUrl = "http://localhost:11434/api/generate"
                    $glpiaBody = @{
                        model = "glpia"
                        prompt = $cleanedTicketContent
                        stream = $false
                    }

                    $glpiaResponse = Invoke-RestMethod -Uri $glpiaUrl -Method Post -Body ($glpiaBody | ConvertTo-Json) -ContentType "application/json"

                    # Convertir le contenu de la réponse glpia en objet personnalisé
                    $glpiaResponseObject = $glpiaResponse.response

                    # Définir les valeurs possibles
                    $possibleValues = @("urgent", "haut", "moyen", "bas", "information")

                    # Extraire la valeur de la réponse glpia
                    $glpiaResponseValue = $glpiaResponseObject

                    # Vérifier si la valeur de la réponse glpia correspond à l'une des valeurs possibles
                    $matchedValue = $possibleValues | Where-Object { $glpiaResponseValue -like "*$_*" }

                    # Déterminer la priorité en fonction de la sortie glpia
                    $priority = switch ($matchedValue) {
                        "information" { 1 }
                        "bas"        { 2 }
                        "moyen"      { 3 }
                        "haut"       { 4 }
                        "urgent"     { 5 }
                        default      { throw "Invalid AI output: $matchedValue" }
                    }

                    # Modifier la priorité du ticket et la source de la demande
                    $ticketUrl = "$apiUrl/Ticket/$ticketId"
                    $ticketBody = @{
                        input = @{
                            id = $ticketId
                            priority = $priority
                            requesttypes_id = 8  # Définir la source de la demande sur "IA"
                        }
                    }
                    $ticketResponse = Invoke-RestMethod -Uri $ticketUrl -Method Put -Body ($ticketBody | ConvertTo-Json) -ContentType "application/json" -Headers @{ "app-token" = $appToken; "session-token" = $sessionToken }

                    # Étape 2 : Réponse par glpiaresponse
                    $glpiaresponseUrl = "http://localhost:11434/api/generate"
                    $glpiaresponseBody = @{
                        model = "glpiaresponse"
                        prompt = $cleanedTicketContent
                        stream = $false
                    }

                    $glpiaresponseResponse = Invoke-RestMethod -Uri $glpiaresponseUrl -Method Post -Body ($glpiaresponseBody | ConvertTo-Json) -ContentType "application/json"

                    # Convertir le contenu de la réponse glpiaresponse en objet personnalisé
                    $glpiaresponseContent = $glpiaresponseResponse.response

                    # Préparer le contenu JSON pour ajouter un suivi
                    $followupContent = $glpiaresponseContent

                    # Créer le JSON Body pour le suivi
                    $followupJsonBody = @{
                        input = @{
                            tickets_id = $ticketId
                            content = $followupContent
                            is_private = 0  # Définit le suivi comme public
                        }
                    } | ConvertTo-Json -Depth 3

                    # Créer un client HTTP
                    $client = New-Object System.Net.Http.HttpClient

                    # Définir les en-têtes de la requête
                    $client.DefaultRequestHeaders.Add("app-token", $appToken)
                    $client.DefaultRequestHeaders.Add("session-token", $sessionToken)

                    # Créer le contenu de la requête
                    $requestContent = New-Object System.Net.Http.StringContent($followupJsonBody, [System.Text.Encoding]::UTF8, "application/json")

                    # Préparer la requête
                    $requestUri = "$apiUrl/TicketFollowup"
                    $requestMessage = New-Object System.Net.Http.HttpRequestMessage
                    $requestMessage.Method = [System.Net.Http.HttpMethod]::Post
                    $requestMessage.RequestUri = $requestUri
                    $requestMessage.Content = $requestContent

                    # Envoyer la requête
                    try {
                        $response = $client.SendAsync($requestMessage).Result
                        $responseBody = $response.Content.ReadAsStringAsync().Result

                        # Afficher la réponse brute avec des retours à la ligne
                        Write-Output ("Follow-up Response:`n{0}" -f $responseBody)
                    } catch {
                        Write-Error ("Failed to add follow-up for Ticket ID {0}" -f $ticketId)
                        Write-Error ($_.Exception.Message)
                    }

                    # Étape 3 : Réponse privée par GLPIaide
                    $glpiaideUrl = "http://localhost:11434/api/generate"
                    $glpiaideBody = @{
                        model = "glpiaide"
                        prompt = $cleanedTicketContent
                        stream = $false
                    }
                    
                    $glpiaideResponse = Invoke-RestMethod -Uri $glpiaideUrl -Method Post -Body ($glpiaideBody | ConvertTo-Json) -ContentType "application/json"
                    
                    # Convertir le contenu de la réponse GLPIaide en objet personnalisé
                    $glpiaideContent = $glpiaideResponse.response
                    
                    # Préparer le contenu JSON pour ajouter un suivi privé
                    $followupJsonBodyPrivate = @{
                        input = @{
                            tickets_id = $ticketId
                            content = $glpiaideContent
                            is_private = 1  # Définit le suivi comme privé
                        }
                    } | ConvertTo-Json -Depth 3
                    
                    # Envoyer la requête pour ajouter un suivi privé avec le second jeton
                    try {
                        # Créer un nouveau HttpRequestMessage pour la requête privée
                        $requestMessagePrivate = New-Object System.Net.Http.HttpRequestMessage
                        $requestMessagePrivate.Method = [System.Net.Http.HttpMethod]::Post
                        $requestMessagePrivate.RequestUri = "$apiUrl/TicketFollowup"
                        
                        # Ajouter les en-têtes pour la requête privée
                        $client.DefaultRequestHeaders.Remove("session-token")
                        $client.DefaultRequestHeaders.Add("session-token", $sessionTokenGlpiaide)
                        
                        # Ajouter le contenu JSON au message de requête privé
                        $requestContentPrivate = New-Object System.Net.Http.StringContent($followupJsonBodyPrivate, [System.Text.Encoding]::UTF8, "application/json")
                        $requestMessagePrivate.Content = $requestContentPrivate
                        
                        # Envoyer la requête privée
                        $responsePrivate = $client.SendAsync($requestMessagePrivate).Result
                        $responseBodyPrivate = $responsePrivate.Content.ReadAsStringAsync().Result
                    
                        # Afficher la réponse brute avec des retours à la ligne
                        Write-Output ("Private Follow-up Response:`n{0}" -f $responseBodyPrivate)
                    } catch {
                        Write-Error ("Failed to add private follow-up for Ticket ID {0}" -f $ticketId)
                        Write-Error ($_.Exception.Message)
                    }

                    # Déboguer : afficher les informations
                    Write-Output ("Ticket ID: {0}" -f $ticketId)
                    Write-Output ("Cleaned Content: {0}" -f $cleanedTicketContent)
                    Write-Output ("Matched Value: {0}" -f $matchedValue)
                    Write-Output ("Priority: {0}" -f $priority)
                    Write-Output ("AI Response (glpia): {0}" -f $glpiaResponseValue)
                    Write-Output ("Follow-up Response (glpiaresponse): {0}" -f $glpiaresponseContent)
                    Write-Output ("Private Follow-up Response (glpiaide): {0}" -f $glpiaideContent)

                } catch {
                    Write-Error ("Erreur lors du traitement du ticket ID {0}: $_" -f $ticketId)
                    continue
                }
            }

            # Augmenter le startTicket pour la prochaine itération
            $startTicket += $ticketBatchSize
        } catch {
            if ($_.Exception.Message -match '["ERROR_RANGE_EXCEED_TOTAL","Provided range exceed total count of data: 24; Afficher la documentation dans votre navigateur à http://localhost/glpi/apirest.php/#ERROR_RANGE_EXCEED_TOTAL"]') {
                Write-Output "Plage de tickets dépassée, retour à la première plage."
                $startTicket = 0
                break
            }
            Write-Error "Erreur lors de l'obtention de la liste des tickets: $_"
            Start-Sleep -Seconds 30
            continue
        }
    }

    if (-not $retryFlag) {
        # Attendre 30 secondes avant la prochaine itération
        Write-Output "Attente de 30 secondes avant la prochaine itération."
        Start-Sleep -Seconds 30
    }
}
