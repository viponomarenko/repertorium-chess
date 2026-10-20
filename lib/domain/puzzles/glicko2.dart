/// Glicko-2 rating (Glickman, "Example of the Glicko-2 system"), with the
/// limits Lichess uses for puzzle ratings (D-123).
library;

import 'dart:math' as math;

const _scale = 173.7178;

class Glicko {
  const Glicko({this.rating = 1500, this.deviation = 500, this.volatility = 0.09});

  final double rating;
  final double deviation;
  final double volatility;

  static const minDeviation = 45.0;
  static const maxDeviation = 500.0;
  static const maxVolatility = 0.1;
  static const minRating = 400.0;
  static const maxRating = 4000.0;

  /// Lichess marks a rating with "?" while it is this uncertain.
  static const provisionalDeviation = 110.0;

  bool get provisional => deviation >= provisionalDeviation;

  Glicko capped() => Glicko(
    rating: rating.clamp(minRating, maxRating).toDouble(),
    deviation: deviation.clamp(minDeviation, maxDeviation).toDouble(),
    volatility: math.min(volatility, maxVolatility),
  );

  /// Moves [weight] of the way from this rating to [other].
  Glicko towards(Glicko other, double weight) => Glicko(
    rating: rating + (other.rating - rating) * weight,
    deviation: deviation + (other.deviation - deviation) * weight,
    volatility: volatility + (other.volatility - volatility) * weight,
  );

  Map<String, Object?> toJson() => {'r': rating, 'd': deviation, 'v': volatility};

  static Glicko fromJson(Object? j) {
    if (j is! Map) return const Glicko();
    double num_(Object? v, double d) => v is num && v.isFinite ? v.toDouble() : d;
    return Glicko(rating: num_(j['r'], 1500), deviation: num_(j['d'], 500), volatility: num_(j['v'], 0.09)).capped();
  }

  @override
  String toString() => 'Glicko($rating, $deviation, $volatility)';
}

/// One result against [opponent]: 1 a win, 0 a loss, 0.5 a draw.
typedef GlickoGame = ({Glicko opponent, double score});

/// The rating after one rating period with [games].
Glicko glickoUpdate(Glicko player, List<GlickoGame> games, {double tau = 0.75}) {
  final mu = (player.rating - 1500) / _scale;
  final phi = player.deviation / _scale;
  final sigma = player.volatility;
  if (games.isEmpty) {
    final p = math.sqrt(phi * phi + sigma * sigma);
    return Glicko(rating: player.rating, deviation: p * _scale, volatility: sigma);
  }
  double g(double phiJ) => 1 / math.sqrt(1 + 3 * phiJ * phiJ / (math.pi * math.pi));
  double e(double muJ, double phiJ) => 1 / (1 + math.exp(-g(phiJ) * (mu - muJ)));

  var vInv = 0.0;
  var sum = 0.0;
  for (final game in games) {
    final muJ = (game.opponent.rating - 1500) / _scale;
    final phiJ = game.opponent.deviation / _scale;
    final gj = g(phiJ);
    final ej = e(muJ, phiJ);
    vInv += gj * gj * ej * (1 - ej);
    sum += gj * (game.score - ej);
  }
  final v = 1 / vInv;
  final delta = v * sum;

  // New volatility: the Illinois algorithm of step 5.
  final a = math.log(sigma * sigma);
  double f(double x) {
    final ex = math.exp(x);
    final d = phi * phi + v + ex;
    return ex * (delta * delta - phi * phi - v - ex) / (2 * d * d) - (x - a) / (tau * tau);
  }

  const epsilon = 0.000001;
  double hi;
  if (delta * delta > phi * phi + v) {
    hi = math.log(delta * delta - phi * phi - v);
  } else {
    var k = 1;
    while (f(a - k * tau) < 0) {
      k++;
    }
    hi = a - k * tau;
  }
  // A and B of the paper.
  var aa = a;
  var bb = hi;
  var fa = f(aa);
  var fb = f(bb);
  var i = 0;
  while ((bb - aa).abs() > epsilon && i++ < 100) {
    final c = aa + (aa - bb) * fa / (fb - fa);
    final fc = f(c);
    if (fc * fb <= 0) {
      aa = bb;
      fa = fb;
    } else {
      fa /= 2;
    }
    bb = c;
    fb = fc;
  }
  final sigmaNew = math.exp(aa / 2);

  final phiStar = math.sqrt(phi * phi + sigmaNew * sigmaNew);
  final phiNew = 1 / math.sqrt(1 / (phiStar * phiStar) + 1 / v);
  final muNew = mu + phiNew * phiNew * sum;
  return Glicko(rating: muNew * _scale + 1500, deviation: phiNew * _scale, volatility: sigmaNew);
}
