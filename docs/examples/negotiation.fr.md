# Une négociation, avec Claude dans la pièce

[English](negotiation.md) · **Français**

Un appel de test avec Pip et Claude Code, réalisé le 11 octobre 2026. Le client est fictif et chaque réplique de
l'appel était écrite à l'avance ; les notes et le résumé de Claude sont recopiés ici **sans retouche**.

**Comment le test a été fait.** Un script a écrit les 15 répliques de l'appel dans `agent-feed.md` au rythme de la
parole, comme le fait Pip (pas de son ici : ajoute les 1 à 3 s de transcription d'un vrai appel). L'agent était une
nouvelle session Claude Code (2.1.295, Sonnet 5.5, recherche web autorisée) qui a reçu le brief ci-dessous et le prompt
du README. Les répliques « Toi » étaient écrites à l'avance aussi : elles ne suivent pas les notes de Claude. Le test
montre donc ce que l'agent a repéré et proposé, pas comment l'appel se serait terminé si tu l'avais écouté.

## Le brief donné à Claude avant l'appel

> Je suis Sacha, vidéaste freelance (sachapraljak.com). Dans une minute, j'ai un appel avec Atelier Lune, une marque de céramique qui veut une vidéo de lancement. Mes formules : Essentielle 490 € (une vidéo de 30 s, voix off FR ou EN, 2 tours de retours), Complète 990 € (la vidéo + 3 formats courts pour les stories et les Reels). Mon objectif : signer, idéalement la Complète, avec un paiement à 30 jours maximum.

## L'appel, et ce que Pip a soufflé

| | Réplique | Pip a soufflé | Après |
|---|---|---|---|
| 0:00 | **Eux:** Bonjour Sacha, merci de prendre le temps. | | |
| 0:04 | **Toi:** Avec plaisir. Vous lancez une nouvelle collection, c'est ça ? | | |
| 0:09 | **Eux:** Oui, notre collection d'hiver sort le 15 novembre, et on veut une vidéo pour Instagram. | Instagram, sortie 15/11: Complète colle (Reels+stories). Demande date de livraison. | 4.9 s |
| 0:15 | **Eux:** On hésite entre deux options : une vidéo de 30 secondes seule, ou la vidéo plus trois formats courts pour les stories. | Ils hésitent: vise la Complète. Sur Instagram, stories/Reels = l'usage principal. | 3.7 s |
| 0:20 | **Toi:** D'accord. Vous avez déjà des images de vos pièces ? | | |
| 0:24 | **Eux:** On a des photos, mais aucune vidéo. | Aucune vidéo: tournage requis? Cadre-le (lieu, nb de pièces) avant de donner le prix. | 3.9 s |
| 0:29 | **Eux:** Notre budget, c'est 800 euros maximum. | Budget 800 < 990. Pas de remise sèche: Complète allégée (2 formats) ou Essentielle. | 5.4 s |
| 0:34 | **Toi:** Ça laisse de la marge sur la formule de base. | | |
| 0:40 | **Eux:** Par contre, vous pourriez nous facturer à 90 jours ? C'est ce qu'on fait avec tous nos prestataires. | 90 j interdit en B2B (max 60 j, L441-10, vérifié). Vise 30 j ou acompte 50%. | 17.7 s |
| 0:44 | **Toi:** Je regarde ça. | | |
| 0:49 | **Eux:** Et il nous faudrait la vidéo pour le 10 novembre au plus tard. | Livraison 10/11 = 4 sem. Tournage + 2 tours: fixe les dates de retours par écrit. | 8.6 s |
| 0:54 | **Eux:** Il faudrait aussi des sous-titres, enfin peut-être, on verra. | Sous-titres = hors formules et flou ("peut-être"): fixe-les en option payante. | 6.0 s |
| 1:00 | **Eux:** Donc si je résume : trois formats courts à 100 euros chacun plus la vidéo à 490, ça fait 700 euros. | Calcul faux: 490 + 3×100 = 790, pas 700. Corrige-les. Tes formats = 500 € (3), pas 300. | 5.5 s |
| 1:05 | **Toi:** Je vous envoie un devis demain. | | |
| 1:09 | **Eux:** Parfait, merci, à bientôt. | | |

Les secondes sont mesurées entre la réplique qui appelait la note et le moment où la note a été écrite. Claude a fait une recherche web pendant l'appel, sur le paiement à 90 jours.

## Le résumé écrit par Claude à la fin de l'appel (`summary.md`)

> # Atelier Lune — appel du 11/10/2026
>
> ## Résumé
> - Atelier Lune (céramique) lance une collection d'hiver le 15/11. Vidéo pour Instagram.
> - Ils hésitent entre la vidéo 30 s seule (Essentielle, 490 €) et la vidéo + 3 formats courts stories (Complète, 990 €).
> - Ils ont des photos, aucune vidéo. Le tournage n'a pas été clarifié.
> - Budget annoncé : 800 € maximum.
> - Livraison demandée au plus tard le 10/11 (environ 4 semaines).
> - Sous-titres évoqués, avec un « peut-être, on verra ». Ils ne sont pas dans les formules.
> - Ils demandent un paiement à 90 jours (« comme avec tous nos prestataires »).
>
> ## Points à surveiller
> - **Arithmétique fausse côté client** : ils ont dit « 3 formats à 100 € + vidéo 490 € = 700 € ». Le total réel de ce calcul est 790 €. De plus, ta Complète vaut 990 € (les 3 formats = 500 €, pas 300 €). Je n'ai pas vu dans le flux que quelqu'un l'ait corrigé.
> - **Paiement à 90 jours** : au-dessus de ton objectif (30 j max) et au-dessus du plafond légal B2B de 60 jours à compter de la date de facture (art. L441-10 Code de commerce). Vérifié sur des sources secondaires (Agicap, GoCardless), pas sur Légifrance. À relire avant de l'écrire dans un devis.
> - **Aucune signature ni engagement** à la fin de l'appel : seulement un devis promis pour demain. Je n'ai pas vu de réponse sur la formule choisie.
> - **Tournage** : non cadré (lieu, nombre de pièces, qui produit les images). Il peut changer le prix et le délai.
> - **Sous-titres** : hors formules. À chiffrer en option, sinon risque de dérive de périmètre.
>
> ## Décisions
> - Aucune décision ferme prise pendant l'appel.
> - Sacha envoie un devis demain (12/10/2026).
>
> ## Prochaines étapes
> 1. Décider de la formule à proposer. Mon avis (jugement, pas un fait) : Complète 990 € ne rentre pas dans 800 € sans changer le périmètre. Options : Complète allégée (2 formats) autour de 800 €, ou Essentielle 490 € + formats en option. Pas de remise sèche sur le périmètre actuel.
> 2. Dans le devis : corriger le calcul (790 ≠ 700), cadrer le tournage, chiffrer les sous-titres en option.
> 3. Paiement : proposer 30 j, ou acompte (ex. 50 % à la commande) + solde à 30 j. Refuser 90 j.
> 4. Planning : fixer par écrit les dates de tournage, de livraison des 2 tours de retours et de livraison finale pour tenir le 10/11.
> 5. Demander une date de réponse au client (le lancement est le 15/11, le délai est serré).
