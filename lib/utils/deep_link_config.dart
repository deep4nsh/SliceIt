// Central config for deep links (no Firebase Dynamic Links)
class DeepLinkConfig {
  // HTTPS base for universal/app links. Point this to your own domain or Firebase Hosting.
  // Example using Firebase Hosting default domain; replace with your custom domain when ready.
  static const String httpBase = 'https://sliceit-124.web.app';

  // Custom scheme for fallback when universal links aren’t available
  static const String customScheme = 'sliceit://';

  static String groupHttp(String groupId, String inviterUid) =>
      '$httpBase/group?id=$groupId&inviter=$inviterUid';

  static String groupScheme(String groupId, String inviterUid) =>
      '${customScheme}group?id=$groupId&inviter=$inviterUid';
}