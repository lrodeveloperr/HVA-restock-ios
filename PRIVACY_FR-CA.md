# Politique de confidentialité de Télécommande TV

**Date d’entrée en vigueur : 8 septembre 2026**

Télécommande TV n’envoie aucun renseignement personnel à WorksBien Studios Inc. L’app ne comporte aucun compte exploité par le développeur, aucune publicité, aucun outil d’analyse, aucun suivi et aucun service infonuagique.

## Réseau local

L’app utilise le réseau local pour trouver un téléviseur compatible et communiquer directement avec celui-ci. Les réponses de détection sont des données réseau non fiables. L’utilisateur choisit un téléviseur et termine le jumelage au moyen du NIP affiché avant de le contrôler. Les commandes et le texte saisi circulent de l’appareil Apple au téléviseur sélectionné; WorksBien Studios ne les reçoit pas. Le logiciel du fabricant traite ce trafic selon ses propres pratiques.

Lors du premier jumelage, les téléviseurs compatibles présentent un certificat local autosigné qui ne peut pas être vérifié par une autorité de certification publique pour l’adresse privée du téléviseur. L’app fait temporairement confiance uniquement au point d’accès privé sélectionné pour l’échange du NIP affiché à l’écran, puis enregistre cette identité de certificat lorsque le NIP est accepté. Cette mesure protège la continuité des connexions suivantes, mais elle ne peut pas établir indépendamment l’identité du téléviseur contre un attaquant actif lors du premier jumelage. Jumelez seulement sur un réseau privé auquel vous faites confiance.

## Données enregistrées sur l’appareil

L’adresse IPv4 privée, le port et le nom du téléviseur sélectionné, le jeton de jumelage émis par le téléviseur et l’identité de son certificat sont stockés comme éléments réservés à cet appareil dans le trousseau iOS. L’UUID client généré par l’app et la préférence de retour haptique sont conservés dans les préférences locales. **Oublier ce téléviseur** demande la suppression de l’adresse, du jeton et de l’identité d’un téléviseur. **Supprimer toutes les données de téléviseur** demande la suppression de toutes les adresses, de tous les jetons et certificats ainsi que de l’UUID client généré par l’app. Une commande distincte permet de réinitialiser l’identité lorsque le certificat du téléviseur change.

## Achats

Apple traite l’essai gratuit de 1 jour et le déverrouillage complet facultatif à achat unique. L’app consulte dans StoreKit l’identifiant et le type de produit vérifiés, la date d’achat, l’état actuel du droit ou de la révocation et le prix localisé afin de déterminer si la télécommande est accessible. L’essai dure 24 heures, ne se renouvelle pas et n’entraîne aucuns frais automatiques. Le développeur ne reçoit aucun renseignement de carte de paiement.

## Communication et conservation

WorksBien Studios ne reçoit, ne vend et ne partage pas les données locales décrites. Elles demeurent sur l’appareil jusqu’à ce que l’utilisateur emploie les commandes de suppression, qu’iOS retire le stockage applicable ou que l’appareil soit effacé. Apple et le fabricant du téléviseur peuvent traiter des données séparément dans le cadre de leurs services ou appareils.

## Enfants

L’app n’est pas conçue pour recueillir des renseignements sur les enfants et n’envoie sciemment aucun renseignement d’utilisateur à WorksBien Studios.

## Modifications et coordonnées

Les modifications importantes seront indiquées par la mise à jour de la politique et de sa date d’entrée en vigueur.

WorksBien Studios Inc.  
`https://worksbienstudios.com/customerservice`

Télécommande TV est indépendante et n’est ni affiliée à Vizio, Inc. ni approuvée par celle-ci.
