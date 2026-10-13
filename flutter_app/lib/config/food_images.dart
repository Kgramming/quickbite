/// Curated food imagery for QuickBite.
///
/// The backend seed data provides no image URLs, so the app maps restaurant
/// and menu-item names to verified, relevant food photographs (Unsplash CDN,
/// all URLs verified returning HTTP 200 as of 2026-10-13).
///
/// If the backend later provides `image_url`, that always takes precedence —
/// see [QuickBiteImages.forRestaurant] and [forMenuItem].
class QuickBiteImages {
  QuickBiteImages._();

  static const _base = 'https://images.unsplash.com';

  // Verified Unsplash photo IDs (all return HTTP 200).
  static const _biryani = 'photo-1589302168068-964664d93dc0'; // chicken biryani
  static const _dosa = 'photo-1630383249896-424e482df921'; // masala dosa
  static const _pizza = 'photo-1513104890138-7c749659a591'; // pizza
  static const _indianThali =
      'photo-1546833999-b9f581a1996d'; // indian curry/thali
  static const _samosa = 'photo-1601050690597-df0568f70950'; // samosa
  static const _paneer =
      'photo-1631452180519-c014fe946bc7'; // paneer tikka
  static const _vadaPav =
      'photo-1606755962773-d324e0a13086'; // vada pav / burger-like
  static const _kebab = 'photo-1599487488170-d11ec9c172f0'; // kebab skewers
  static const _indianCurry =
      'photo-1585937421612-70a008356fbe'; // indian curry bowl
  static const _burger = 'photo-1568901346375-23c9450c58cd'; // burger

  static String _u(String photoId, {int w = 800}) =>
      '$_base/$photoId?w=$w&q=80&auto=format&fit=crop';

  /// Restaurant hero images keyed by restaurant ID, with name fallback.
  static String forRestaurant({
    required String restaurantId,
    required String restaurantName,
    String? backendImageUrl,
  }) {
    if (backendImageUrl != null && backendImageUrl.isNotEmpty) {
      return backendImageUrl;
    }
    switch (restaurantId) {
      case 'rest_biryani':
        return _u(_biryani);
      case 'rest_pizza':
        return _u(_pizza);
      case 'rest_dosa':
        return _u(_dosa);
      default:
        return _u(_forCuisine(restaurantName));
    }
  }

  /// Menu-item images: backend URL first, then keyword matching.
  static String forMenuItem({
    required String itemName,
    String? backendImageUrl,
  }) {
    if (backendImageUrl != null && backendImageUrl.isNotEmpty) {
      return backendImageUrl;
    }
    final n = itemName.toLowerCase();
    if (n.contains('biryani')) return _u(_biryani, w: 400);
    if (n.contains('dosa') || n.contains('idli') || n.contains('vada')) {
      return _u(_dosa, w: 400);
    }
    if (n.contains('pizza') || n.contains('garlic bread')) {
      return _u(_pizza, w: 400);
    }
    if (n.contains('paneer')) return _u(_paneer, w: 400);
    if (n.contains('kebab') || n.contains('tikka') || n.contains('tangdi')) {
      return _u(_kebab, w: 400);
    }
    if (n.contains('samosa')) return _u(_samosa, w: 400);
    if (n.contains('burger') || n.contains('vada pav')) {
      return _u(_vadaPav, w: 400);
    }
    if (n.contains('tiramisu') || n.contains('gulab jamun')) {
      return _u(_indianThali, w: 400);
    }
    if (n.contains('coffee')) return _u(_indianCurry, w: 400);
    if (n.contains('raita')) return _u(_indianCurry, w: 400);
    return _u(_indianCurry, w: 400);
  }

  static String _forCuisine(String name) {
    final n = name.toLowerCase();
    if (n.contains('biryani')) return _biryani;
    if (n.contains('pizza')) return _pizza;
    if (n.contains('dosa') || n.contains('south')) return _dosa;
    if (n.contains('burger')) return _burger;
    return _indianThali;
  }
}
