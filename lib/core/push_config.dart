/// Réglages du relais de notifications (Cloudflare Workers).
///
/// 1. Remplacez l'adresse par celle de VOTRE Worker (voir GUIDE_CLOUDFLARE.md).
/// 2. Remplacez la clé par la même clé secrète que celle saisie dans Cloudflare
///    (variable ADMIN_KEY).
///
/// Ne partagez jamais l'APK de l'application admin : il contient cette clé.
const String kPushRelayUrl = 'https://item-rdc-push.arianefongo.workers.dev';
const String kPushRelayKey = 'al2dIA84CvyMjfZxmBizYPOHU93WRTe1gJnwk6ch';
