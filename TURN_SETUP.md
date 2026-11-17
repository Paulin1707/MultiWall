# Configuration du relais TURN MultiWall

MultiWall utilise actuellement STUN pour les connexions directes. Le relais TURN Cloudflare est prévu en complément pour les réseaux mobiles, NAT stricts et pare-feu qui bloquent le trafic pair-à-pair.

## État

- La fonction Supabase `multiwall-turn-credentials` est déployée.
- L'application demande des identifiants TURN temporaires après validation de la session.
- Si les secrets Cloudflare ne sont pas présents, l'application revient automatiquement à STUN.
- Les identifiants TURN ont une durée de vie de 4 heures, supérieure à la durée standard d'une session MultiWall (2 heures).

## Secrets à ajouter dans Supabase

Dans le tableau de bord du projet, ouvrir **Edge Functions → Secrets** et ajouter :

- `CLOUDFLARE_TURN_KEY_ID` : l'identifiant `uid` de la clé TURN Cloudflare.
- `CLOUDFLARE_TURN_API_TOKEN` : le secret `key` retourné lors de la création de cette clé TURN. Ce n'est pas le jeton API général du compte.

Ne jamais placer ces valeurs dans l'application, dans GitHub ou dans une conversation. Elles doivent rester côté serveur dans Supabase.

## Coût à connaître

Cloudflare indique un tarif de **0,05 USD par Go sortant** vers les clients TURN lorsque le service est utilisé sans Cloudflare Realtime SFU. MultiWall utilise une connexion WebRTC pair-à-pair et n'intègre pas ce SFU. Il faut donc valider ce coût avant d'activer le relais en production.

Référence officielle : https://developers.cloudflare.com/realtime/turn/
