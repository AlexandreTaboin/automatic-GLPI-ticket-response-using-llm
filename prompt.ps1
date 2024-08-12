<#
Description : Ce script permet de créer des modèles avec prompt personnalisé
Usage : vous auriez besoin d'un GLPI avec l'API et un compte ayant les bons droits. de l'application Ollama ainsi que deux modèles "GLPIa" qui donnera la priorité et "GLPIaresponse" qui répondra aux tickets
Auteur : Alexandre TABOIN https://taboin.fr
Usage de l'IA : Oui, Chat-GPT 4o et mistral-codestral
Dépendances : OLLAMA et son API https://ollama.com/
Version : 24.08.1
Révision : 
        - 24.07.1 (31/07/2024) : Version Initiale fonctionnelle
        - 24.08.1 (09/08/2024) : Ajout d'un 3eme modèle
#>
# Définir l'URL de l'API
$apiUrl = "http://localhost:11434/api/create"

# Créer le corps de la requête
$body = @{
    name = "GLPIa"
    modelfile = "FROM mistral`nSYSTEM Tu es un système intégré au service de ticketing informatique. Ton rôle est de classer automatiquement les demandes des utilisateurs selon leur priorité. Les priorités sont : --urgent--, --haut--, --moyen--, --bas-- et --information-. Réponds uniquement par un de ces 5 mots, sans ajouter d'autres informations. Fais attention à la syntaxe utilisée par les utilisateurs et réponds toujours en français."
}

# Convertir le corps de la requête en JSON
$jsonBody = $body | ConvertTo-Json

# Envoyer la requête POST en utilisant Invoke-RestMethod
$response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonBody -ContentType "application/json"

# Afficher la réponse
$response


# Créer le corps de la requête
$body = @{
    name = "GLPIaresponse"
    modelfile = "FROM mistral-nemo:12b-instruct-2407-q8_0`nSYSTEM Tu es Myrtille, une intelligence artificielle secrétaire intégré au service de ticketing informatique, tu devras le préciser à chaque demande. Tu devras lire des tickets d utilisateurs et leurs demandé des informations si nécessaire. Tu ne peux pas effectuer d actions uniquement répondre au ticket. Tu dois répondre exclusivement en français"
}

# Convertir le corps de la requête en JSON
$jsonBody = $body | ConvertTo-Json

# Envoyer la requête POST en utilisant Invoke-RestMethod
$response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonBody -ContentType "application/json"

# Afficher la réponse
$response


# Créer le corps de la requête
$body = @{
    name = "GLPIaide"
    modelfile = "FROM mistral-nemo:12b-instruct-2407-q8_0`nSYSTEM Tu es Perceval, une intelligence artificielle. Tu vas lire les tickets utilisateurs et donner un premier diagnostic des soucis pour aider des informaticiens. Fait simple sans formules de politesses ni fioritures. Tu ne peux pas effectuer d actions uniquement donner une piste aux informaticiens et répondre exclusivement en français. "
}

# Convertir le corps de la requête en JSON
$jsonBody = $body | ConvertTo-Json

# Envoyer la requête POST en utilisant Invoke-RestMethod
$response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonBody -ContentType "application/json"

# Afficher la réponse
$response
