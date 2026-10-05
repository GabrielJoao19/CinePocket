import 'package:flutter/material.dart';

/// Modelo simples com dados MOCK (será substituído pela API do TMDB depois).
class Movie {
  final String title;
  final String originalTitle;
  final int year;
  final List<String> genres;
  final double rating;
  final String duration;
  final String ageRating;
  final String savedAt;
  final List<Color> colors; // cores do placeholder do pôster

  const Movie({
    required this.title,
    this.originalTitle = '',
    required this.year,
    required this.genres,
    required this.rating,
    this.duration = '',
    this.ageRating = '',
    this.savedAt = '',
    required this.colors,
  });
}

const featuredMovies = <Movie>[
  Movie(
    title: 'Duna: Parte 2',
    originalTitle: 'Dune: Part Two',
    year: 2024,
    genres: ['Ficção Científica', 'Aventura', 'Drama'],
    rating: 8.8,
    duration: '2h 46m',
    ageRating: '14+',
    colors: [Color(0xFF1B1B2F), Color(0xFFD9822B)],
  ),
  Movie(
    title: 'Oppenheimer',
    year: 2023,
    genres: ['Biografia', 'Drama'],
    rating: 8.9,
    duration: '3h 00m',
    colors: [Color(0xFF111111), Color(0xFF6B5B45)],
  ),
  Movie(
    title: 'Pobres Criaturas',
    year: 2023,
    genres: ['Comédia', 'Ficção Científica'],
    rating: 8.1,
    duration: '2h 21m',
    colors: [Color(0xFF1F2A44), Color(0xFF8FA6C9)],
  ),
];

const popularMovies = <Movie>[
  Movie(
    title: 'The Batman',
    year: 2022,
    genres: ['Ação', 'Policial'],
    rating: 8.7,
    ageRating: 'Classificação 14',
    colors: [Color(0xFF0E1A26), Color(0xFF4A6275)],
  ),
  Movie(
    title: 'Interestelar',
    year: 2014,
    genres: ['Aventura', 'Ficção'],
    rating: 8.6,
    ageRating: 'Classificação 10',
    colors: [Color(0xFF2B1D0E), Color(0xFFC8943F)],
  ),
  Movie(
    title: 'Coringa',
    year: 2019,
    genres: ['Crime', 'Drama'],
    rating: 8.5,
    ageRating: 'Classificação 16',
    colors: [Color(0xFF1A1A1A), Color(0xFF5A4A3A)],
  ),
  Movie(
    title: 'Homem-Aranha: ...',
    year: 2023,
    genres: ['Animação', 'Ação'],
    rating: 8.9,
    ageRating: 'Classificação 10',
    colors: [Color(0xFF0B1730), Color(0xFF2E4A7D)],
  ),
];

const favoriteMovies = <Movie>[
  Movie(
    title: 'O Poderoso Chefão',
    year: 1972,
    genres: ['Crime', 'Drama'],
    rating: 9.2,
    savedAt: 'Salvo em 14 Out, 2024',
    colors: [Color(0xFF1A1208), Color(0xFF8A6A3A)],
  ),
  Movie(
    title: 'Interestelar',
    year: 2014,
    genres: ['Ficção Científica', 'Aventura'],
    rating: 8.7,
    savedAt: 'Salvo em 28 Set, 2024',
    colors: [Color(0xFF14243A), Color(0xFFE0A96A)],
  ),
  Movie(
    title: 'Batman: O Cavaleiro das Trevas',
    year: 2008,
    genres: ['Ação', 'Policial'],
    rating: 9.0,
    savedAt: 'Salvo em 19 Ago, 2024',
    colors: [Color(0xFF0B0F18), Color(0xFF3D4A5C)],
  ),
  Movie(
    title: 'Pulp Fiction: Tempo de Violência',
    year: 1994,
    genres: ['Crime', 'Cult'],
    rating: 8.9,
    savedAt: 'Salvo em 05 Ago, 2024',
    colors: [Color(0xFF3A2A06), Color(0xFFD6A81E)],
  ),
  Movie(
    title: 'A Viagem de Chihiro',
    year: 2001,
    genres: ['Animação', 'Fantasia'],
    rating: 8.6,
    savedAt: 'Salvo em 12 Jul, 2024',
    colors: [Color(0xFF1B2A4A), Color(0xFFD97A3A)],
  ),
];

class CastMember {
  final String name;
  final String character;
  const CastMember(this.name, this.character);
}

const castMembers = <CastMember>[
  CastMember('Timothée Chalamet', 'Paul Atreides'),
  CastMember('Zendaya', 'Chani'),
  CastMember('Austin Butler', 'Feyd-Rautha'),
];
