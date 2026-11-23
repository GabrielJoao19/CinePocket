/// Modelo de filme retornado pela API protegida do CinePocket.
class Movie {
  final String id;
  final String title;
  final String originalTitle;
  final int year;
  final List<String> genres;
  final double rating;
  final String duration;
  final String director;
  final String description;

  const Movie({
    this.id = '',
    required this.title,
    this.originalTitle = '',
    required this.year,
    this.genres = const [],
    required this.rating,
    this.duration = '',
    this.director = '',
    this.description = '',
  });

  factory Movie.fromJson(dynamic json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['title'] is! String ||
        (json['title'] as String).trim().isEmpty ||
        json['year'] is! int ||
        json['rating'] is! num) {
      throw const FormatException();
    }
    return Movie(
      id: json['id'],
      title: json['title'],
      year: json['year'],
      rating: (json['rating'] as num).toDouble(),
      originalTitle:
          json['original_title'] is String ? json['original_title'] : '',
      director: json['director'] is String ? json['director'] : '',
      description: json['description'] is String ? json['description'] : '',
      duration: json['duration'] is String ? json['duration'] : '',
      genres: json['genres'] is List &&
              (json['genres'] as List).every((g) => g is String)
          ? List<String>.from(json['genres'])
          : const [],
    );
  }
}
