// Data models for Lucille Assistant's game-card API (games.go):
// GET /api/game/search, GET /api/game, GET /api/games/marks, POST /api/games/mark.

class GameMark {
  final int appId;
  final String name;
  final String image;
  final String like; // "like" | "dislike" | ""
  final bool wish;

  GameMark({
    required this.name,
    this.appId = 0,
    this.image = '',
    this.like = '',
    this.wish = false,
  });

  factory GameMark.fromJson(Map<String, dynamic> j) => GameMark(
        appId: (j['appid'] as num?)?.toInt() ?? 0,
        name: j['name'] ?? '',
        image: j['image'] ?? '',
        like: j['like'] ?? '',
        wish: j['wish'] ?? false,
      );
}

class SteamHit {
  final int appId;
  final String name;
  final String image;
  final String price;
  final String metascore;
  final GameMark? mark;

  SteamHit({
    required this.appId,
    required this.name,
    this.image = '',
    this.price = '',
    this.metascore = '',
    this.mark,
  });

  factory SteamHit.fromJson(Map<String, dynamic> j) => SteamHit(
        appId: (j['appid'] as num?)?.toInt() ?? 0,
        name: j['name'] ?? '',
        image: j['image'] ?? '',
        price: j['price'] ?? '',
        metascore: j['metascore'] ?? '',
        mark: j['mark'] == null ? null : GameMark.fromJson(j['mark'] as Map<String, dynamic>),
      );
}

class ReviewSample {
  final bool up;
  final String text;
  final int hours;
  ReviewSample({required this.up, required this.text, this.hours = 0});

  factory ReviewSample.fromJson(Map<String, dynamic> j) => ReviewSample(
        up: j['up'] ?? false,
        text: j['text'] ?? '',
        hours: (j['hours'] as num?)?.toInt() ?? 0,
      );
}

class Shot {
  final String thumb;
  final String full;
  Shot({required this.thumb, required this.full});
  factory Shot.fromJson(Map<String, dynamic> j) =>
      Shot(thumb: j['thumb'] ?? '', full: j['full'] ?? '');
}

class GameCard {
  final int appId;
  final String key;
  final String name;
  final String image;
  final String description;
  final String release;
  final List<String> developers;
  final List<String> genres;
  final int metacritic;
  final String price;
  final String reviewWord;
  final int reviewPct;
  final int reviewTotal;
  final List<ReviewSample> samples;
  final List<Shot> screenshots;
  final String webExtract;
  final String webUrl;
  final String lowestEver;
  final String storeUrl;
  final List<String> notes;
  final GameMark? mark;

  GameCard({
    required this.key,
    required this.name,
    this.appId = 0,
    this.image = '',
    this.description = '',
    this.release = '',
    this.developers = const [],
    this.genres = const [],
    this.metacritic = 0,
    this.price = '',
    this.reviewWord = '',
    this.reviewPct = 0,
    this.reviewTotal = 0,
    this.samples = const [],
    this.screenshots = const [],
    this.webExtract = '',
    this.webUrl = '',
    this.lowestEver = '',
    this.storeUrl = '',
    this.notes = const [],
    this.mark,
  });

  factory GameCard.fromJson(Map<String, dynamic> j) => GameCard(
        appId: (j['appid'] as num?)?.toInt() ?? 0,
        key: j['key'] ?? '',
        name: j['name'] ?? '',
        image: j['image'] ?? '',
        description: j['description'] ?? '',
        release: j['release'] ?? '',
        developers: ((j['developers'] as List?) ?? []).cast<String>(),
        genres: ((j['genres'] as List?) ?? []).cast<String>(),
        metacritic: (j['metacritic'] as num?)?.toInt() ?? 0,
        price: j['price'] ?? '',
        reviewWord: j['review_word'] ?? '',
        reviewPct: (j['review_pct'] as num?)?.toInt() ?? 0,
        reviewTotal: (j['review_total'] as num?)?.toInt() ?? 0,
        samples: ((j['review_samples'] as List?) ?? [])
            .map((e) => ReviewSample.fromJson(e as Map<String, dynamic>))
            .toList(),
        screenshots: ((j['screenshots'] as List?) ?? [])
            .map((e) => Shot.fromJson(e as Map<String, dynamic>))
            .toList(),
        webExtract: j['web_extract'] ?? '',
        webUrl: j['web_url'] ?? '',
        lowestEver: j['lowest_ever'] ?? '',
        storeUrl: j['store_url'] ?? '',
        notes: ((j['notes'] as List?) ?? []).cast<String>(),
        mark: j['mark'] == null ? null : GameMark.fromJson(j['mark'] as Map<String, dynamic>),
      );
}
