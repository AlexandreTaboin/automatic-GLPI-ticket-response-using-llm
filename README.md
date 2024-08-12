Français
Gestion Automatisée des Tickets GLPI avec IA
-
Description

Ce projet contient des scripts PowerShell qui permettent d'automatiser la gestion des tickets dans GLPI en utilisant l'intelligence artificielle (IA). Les scripts interagissent avec l'API GLPI pour définir automatiquement la priorité des tickets et fournir une première réponse automatisée aux utilisateurs. De plus, un modèle d'IA aide les techniciens en fournissant un premier diagnostic des tickets.
Fonctionnalités

    Définition automatique de la priorité des tickets via un modèle d'IA.
    Réponse automatisée aux tickets avec un autre modèle d'IA.
    Support aux techniciens avec des suggestions basées sur le contenu des tickets.
    Nettoyage du contenu HTML des réponses pour une meilleure lisibilité.
    Fonctionnement continu avec arrêt automatique après 17h.

Dépendances

    GLPI avec API activée.
    Ollama et son API pour l'utilisation des modèles d'IA.
    Modèles IA : Mistral

Installation

    Clonez le dépôt.
    Configurez vos tokens d'application et d'utilisateur dans les scripts.
    Assurez-vous que GLPI et l'API Ollama sont correctement configurés.
    Exécutez le script script.ps1.

Usage

Ces scripts sont destinés à automatiser la gestion des tickets GLPI dans un environnement IT où l'efficacité et la rapidité de traitement sont cruciales.

--------------------------------------------------------------------------------------------------------------------------------------------------------
-English
Automated GLPI Ticket Management with AI
-
Description

This project contains PowerShell scripts that automate the management of tickets in GLPI using artificial intelligence (AI). The scripts interact with the GLPI API to automatically set ticket priorities and provide an initial automated response to users. Additionally, an AI model helps technicians by providing an initial diagnosis of the tickets.
Features

    Automatic ticket priority assignment via an AI model.
    Automated ticket response using another AI model.
    Support for technicians with suggestions based on ticket content.
    Cleaning of HTML content from responses for better readability.
    Continuous operation with automatic shutdown after 5 PM.

Dependencies

    GLPI with enabled API.
    Ollama and its API for AI model usage.
    AI Models: Mistral.

Installation

    Clone the repository.
    Configure your application and user tokens in the scripts.
    Ensure that GLPI and the Ollama API are correctly configured.
    Run the script.ps1 script.

Usage

These scripts are designed to automate GLPI ticket management in an IT environment where efficiency and quick processing are crucial.
