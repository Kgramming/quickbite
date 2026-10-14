/// Curated food imagery for QuickBite.
///
/// The backend seed data provides no image URLs, so the app maps restaurant
/// and menu-item names to verified, relevant food photographs (Unsplash CDN,
/// all URLs verified returning HTTP 200 as of 2026-10-13).
///
/// If the backend later provides `image_url`, that always takes precedence —
/// see [QuickBiteImages.forRestaurant] and [QuickBiteImages.forMenuItem].
///
/// Performance: use [QuickBiteImages.imageProvider] with a `cacheWidth` matching the display
/// size so the codec decodes at (roughly) the rendered size instead of the
/// full download size. Pair it with the `w` parameter so the CDN also sends
/// a smaller file.
import 'package:flutter/painting.dart';

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
  static const _paneer = 'photo-1631452180519-c014fe946bc7'; // paneer tikka
  static const _vadaPav =
      'photo-1606755962773-d324e0a13086'; // vada pav / burger-like
  static const _kebab = 'photo-1599487488170-d11ec9c172f0'; // kebab skewers
  static const _indianCurry =
      'photo-1585937421612-70a008356fbe'; // indian curry bowl
  static const _burger = 'photo-1568901346375-23c9450c58cd'; // burger
  static const _sushi = 'photo-1579871494447-9811cf80d66c'; // sushi platter
  static const _chinese =
      'photo-1585032226651-759b368d7246'; // noodle bowl
  static const _dessert =
      'photo-1551024506-0bccd828d307'; // chocolate dessert

  static String _u(String photoId, {int w = 800}) =>
      '$_base/$photoId?w=$w&q=80&auto=format&fit=crop';

  /// Restaurant hero images keyed by restaurant ID, with name fallback.
  ///
  /// [w] is the Unsplash request width. Use ~600 for grid cards, 800 for
  /// heroes/carousels.
  static String forRestaurant({
    required String restaurantId,
    required String restaurantName,
    String? backendImageUrl,
    int w = 800,
  }) {
    if (backendImageUrl != null && backendImageUrl.isNotEmpty) {
      return backendImageUrl;
    }
    switch (restaurantId) {
      case 'rest_biryani':
        return _u(_biryani, w: w);
      case 'rest_pizza':
        return _u(_pizza, w: w);
      case 'rest_dosa':
        return _u(_dosa, w: w);
      case 'rest_chinese':
        return _u(_chinese, w: w);
      case 'rest_burger':
        return _u(_burger, w: w);
      case 'rest_north':
        return _u(_indianCurry, w: w);
      case 'rest_sushi':
        return _u(_sushi, w: w);
      case 'rest_dessert':
        return _u(_dessert, w: w);
      default:
        return _u(_forCuisine(restaurantName), w: w);
    }
  }

  /// Menu-item images: backend URL first, then keyword matching.
  static String forMenuItem({
    required String itemName,
    String? backendImageUrl,
    int w = 400,
  }) {
    if (backendImageUrl != null && backendImageUrl.isNotEmpty) {
      return backendImageUrl;
    }
    final n = itemName.toLowerCase();
    if (n.contains('biryani')) return _u(_biryani, w: w);
    if (n.contains('dosa') || n.contains('idli') || n.contains('vada')) {
      return _u(_dosa, w: w);
    }
    if (n.contains('pizza') || n.contains('garlic bread')) {
      return _u(_pizza, w: w);
    }
    if (n.contains('paneer')) return _u(_paneer, w: w);
    if (n.contains('kebab') || n.contains('tikka') || n.contains('tangdi')) {
      return _u(_kebab, w: w);
    }
    if (n.contains('samosa')) return _u(_samosa, w: w);
    if (n.contains('burger') || n.contains('vada pav')) {
      return _u(_vadaPav, w: w);
    }
    if (n.contains('tiramisu') || n.contains('gulab jamun')) {
      return _u(_indianThali, w: w);
    }
    if (n.contains('coffee')) return _u(_indianCurry, w: w);
    if (n.contains('raita')) return _u(_indianCurry, w: w);
    return _u(_indianCurry, w: w);
  }

  /// Builds the [ImageProvider] widgets should use for [url].
  ///
  /// When [cacheWidth] is given the image is decoded at that width, which
  /// keeps the in-memory image cache entry shared between every widget (and
  /// `precacheImage` calls) using the same URL + width. Use the same
  /// [cacheWidth] for the widget and its precache call.
  static ImageProvider imageProvider(String url, {int? cacheWidth}) {
    final base = NetworkImage(url);
    if (cacheWidth == null) return base;
    return ResizeImage(base, width: cacheWidth);
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
