# Incidents Rudder.io - session essai gratuit 2026-05-13

Consignation chronologique des incidents rencontres cote editeur Rudder.io
pendant la demande de licence d'essai gratuite 30 jours.

A transmettre a Robinson Maigne (Solutions Engineer, robinson.m@rudder.io)
pour escalade equipe support / infra.

Demandeur : <admin> Dubook (<admin>@example.com), homelab <homelab>.
Login fourni : ppfnetworkppf

---

## Incident #1 - Mail transactionnel bloque par stack mail destinataire

**Quand :** 2026-05-13 10:40-10:51 (heure Paris)

**Quoi :**
Le mail de confirmation d'enregistrement de la demande d'essai
(From: Robinson Maigne <robinson.m@rudder.io>, sujet "Votre demande
d'essai gratuit de Rudder") a ete :

1. **Rejete temporairement (450 4.7.1)** par postfix du destinataire
   a 10:40:54, message d'erreur "Client host rejected: cannot find
   your reverse hostname, [185.211.120.244]". Le PTR et le FCrDNS
   etaient pourtant valides, donc transient DNS du resolver
   destinataire. Mailjet a retry (comportement attendu).

2. **Bloque comme SPAM** a 10:51:33 lors du retry par
   SpamAssassin/amavis destinataire avec un score de **121.94**
   (threshold 6.21). Mis en quarantaine, non livre dans la
   boite <admin>.

**Cause cote destinataire :**
Le score elevé venait essentiellement de regles locales chez le
destinataire ciblant l'infrastructure mass-mailing Mailjet :

    USER_IN_BLACKLIST = 100   (blacklist_from *@*.bnc3.mailjet.com)
    MAILJET_ENVELOPE  = 50    (Return-Path *@*.bnc3.mailjet.com)
    MAILJET_MSGID     = 50    (Message-ID *@*.mailjet.com)

**Conclusion / suggestion editeur :**
Rudder.io envoie des mails transactionnels critiques (licences,
support, factures, resets de mot de passe) par Mailjet qui est une
infrastructure mass-mailing partagee a faible reputation.
**Recommandation :** distinguer le canal transactionnel
(licence, support, password reset = mail.rudder.io dedie ou
similaire avec PTR rudder.io) du canal marketing/newsletter
(qui peut rester sur Mailjet).

Beaucoup de stacks anti-spam blacklistent Mailjet par defaut.
Probleme structurel, pas un cas isole.

---

## Incident #2 - Mot de passe initial avec caracteres non-ASCII

**Quand :** 2026-05-13 entre 11:00 et 11:30 (heure Paris, apres
demande de reset depuis le portail support.rudder.io)

**Quoi :**
Le portail a envoye un mail "votre nouveau mot de passe" contenant
un password genere automatiquement compose de caracteres
non-ASCII (Latin Extended) :

    Pass : ¨w¯"x&ÖË8(!ÿÀ{~MG8âùEú

Caracteres problematiques : ¨ ¯ Ö Ë ÿ À â ù ú etc.

**Cause probable :**
Generation aleatoire d'octets binaires sans filtrage ASCII-safe
(typique d'un `openssl rand` sans option `-base64` ou similaire).
Les octets 0x80-0xFF sont ensuite interpretes comme Latin-1 puis
re-encodes en UTF-8 dans le mail HTML, ce qui altere irreversiblement
certains octets selon les MUA et clients de l'utilisateur.

**Conclusion / suggestion editeur :**
Generer les mots de passe d'auto-provisioning avec uniquement des
caracteres ASCII imprimables (a-z, A-Z, 0-9, ponctuation standard),
exemple `pwgen -s 24 1` ou `openssl rand -base64 18`. Les bytes 8-bit
sont fondamentalement incompatibles avec un transport mail multi-MUA.

---

## Incident #3 - Login impossible apres reset par lien

**Quand :** 2026-05-13 entre 11:30 et 12:00 (heure Paris)

**Quoi :**
1. L'utilisateur a clique sur le lien "Cliquez ici pour reinitialiser
   votre mot de passe" (URL avec token resetbytoken=3vUCACkjiqcXCyW...).
2. Page de definition d'un nouveau mot de passe affichee.
3. Nouveau password defini par l'utilisateur, conforme aux regles
   du portail.
4. Confirmation portail : "Votre mot de passe a ete change".
5. Tentative de connexion immediate sur https://support.rudder.io
   avec :
   - User Name : `ppfnetworkppf` (le login fourni initialement)
   - Password : le nouveau password ASCII-safe defini a l'etape 3
6. Resultat : **"Incorrect login/password, please try again."**
7. Plusieurs tentatives, idem.
8. Tentative avec User Name = `<admin>@example.com` : meme rejet.

**Cause :** inconnue, ressemble a un bug de synchronisation entre
le password store du portail (iTop powered by Combodo) et le
backend d'authentification. Le password est confirme cote portail
mais le login suivant ne le reconnait pas.

**Conclusion / suggestion editeur :**
Investigation iTop / module d'auth necessaire cote Rudder.io. En
l'etat, le workflow "Forgot password -> Reset by link -> Login"
est CASSE pour ce compte (et peut-etre d'autres).

---

## Etat actuel (2026-05-13 12:00)

Demandeur **bloque** :
- Compte cree, login fourni : `ppfnetworkppf`
- Mot de passe initial inutilisable (encoding)
- Reset par lien inutilisable (login post-reset echoue)
- Licence non recuperee
- Pas d'acces au portail support pour ouvrir un ticket
- Pas de canal alternatif de licence dans le mail initial (juste
  un texte "vous recevrez votre licence dans environ 30 minutes")

**Workaround propose :** mail direct a Robinson Maigne pour
demander :
1. soit l'envoi de la licence par mail (canal HTTPS direct,
   sans portail)
2. soit le reset manuel du compte cote admin avec un mot de
   passe alphanum communique en clair (a renouveler par
   l'utilisateur ensuite).

Mail envoye le 2026-05-13 ~12:00.

---

## Cote homelab destinataire - mesures correctives appliquees

Pour permettre la reception future des mails Rudder.io (transactionnels
notamment licence) sans passer par la quarantaine :

- SpamAssassin sur <frontend> : scores des regles MAILJET_ENVELOPE et
  MAILJET_MSGID baisses de 50 a 2 chacun, et la regle
  `blacklist_from *@*.bnc3.mailjet.com` (score 100 sur
  USER_IN_BLACKLIST) commentee.
- Score total Mailjet : 200 -> 4.
- Conservation d'un tag negatif (4 pts) pour rester vigilant
  vis-a-vis du spam Mailjet generique.

Backup : `/etc/spamassassin/local.cf.13_05_2026` sur <frontend>.

---

## Impact business

- 2 jours minimum perdus sur le projet d'evaluation Rudder
  Enterprise (homelab + 8 noeuds Linux + 2 Windows).
- Si bloquage non resolu sous 24h, abandon de l'essai et evaluation
  d'alternatives (Ansible + scripts custom pour Windows, Salt,
  Puppet, CFEngine self-hosted...).
