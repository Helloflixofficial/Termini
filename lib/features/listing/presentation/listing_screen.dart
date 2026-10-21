import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/responsive_layout.dart';

final listingMarketProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/api/crypto/markets');
  return Map<String, dynamic>.from(response.data as Map);
});

final listingChartProvider = FutureProvider.autoDispose
    .family<List<List<double>>, ({String coinId, int days})>((
      ref,
      query,
    ) async {
      final dio = ref.watch(apiClientProvider);
      final response = await dio.get(
        '/api/crypto/coins/${Uri.encodeComponent(query.coinId)}/chart',
        queryParameters: {'days': query.days},
      );
      final body = Map<String, dynamic>.from(response.data as Map);
      return (body['prices'] as List? ?? const [])
          .whereType<List>()
          .where((point) => point.length > 1)
          .map(
            (point) => [
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ],
          )
          .toList(growable: false);
    });

final listingCoinProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, coinId) async {
      final dio = ref.watch(apiClientProvider);
      final response = await dio.get(
        '/api/crypto/coins/${Uri.encodeComponent(coinId)}',
      );
      final rows = response.data as List? ?? const [];
      return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
    });

class ListingScreen extends ConsumerStatefulWidget {
  const ListingScreen({super.key});

  @override
  ConsumerState<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends ConsumerState<ListingScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'All';
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _favorites =
            preferences.getStringList('crypto_watchlist')?.toSet() ?? {},
      );
    }
  }

  Future<void> _toggleFavorite(String coinId) async {
    final updated = Set<String>.from(_favorites);
    if (!updated.add(coinId)) updated.remove(coinId);
    setState(() => _favorites = updated);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('crypto_watchlist', updated.toList());
  }

  List<Map<String, dynamic>> _visibleCoins(List<dynamic> source) {
    final query = _query.trim().toLowerCase();
    final coins = source
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((coin) {
          final matchesSearch =
              query.isEmpty ||
              '${coin['name']} ${coin['symbol']}'.toLowerCase().contains(query);
          final change = _asDouble(coin['price_change_percentage_24h']) ?? 0;
          final matchesFilter = switch (_filter) {
            'Gainers' => change > 0,
            'Losers' => change < 0,
            'Watchlist' => _favorites.contains(coin['id']),
            _ => true,
          };
          return matchesSearch && matchesFilter;
        })
        .toList();
    if (_filter == 'Gainers') {
      coins.sort(
        (a, b) => (_asDouble(b['price_change_percentage_24h']) ?? 0).compareTo(
          _asDouble(a['price_change_percentage_24h']) ?? 0,
        ),
      );
    } else if (_filter == 'Losers') {
      coins.sort(
        (a, b) => (_asDouble(a['price_change_percentage_24h']) ?? 0).compareTo(
          _asDouble(b['price_change_percentage_24h']) ?? 0,
        ),
      );
    }
    return coins;
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(listingMarketProvider);
    final scheme = Theme.of(context).colorScheme;
    return ResponsiveLayout(
      title: 'Listing',
      currentRoute: '/listing',
      body: market.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MarketError(
          message: _friendlyError(error),
          onRetry: () => ref.invalidate(listingMarketProvider),
        ),
        data: (data) {
          final global = data['global'] is Map
              ? Map<String, dynamic>.from(data['global'] as Map)
              : <String, dynamic>{};
          final trending = (data['trending'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          final coins = _visibleCoins(data['markets'] as List? ?? const []);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(listingMarketProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              itemCount: coins.length + 5,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PageHeading(updatedAt: data['updatedAt']?.toString());
                }
                if (index == 1) return _GlobalStats(global: global);
                if (index == 2) {
                  return _TrendingStrip(items: trending, onTap: _openCoin);
                }
                if (index == 3) {
                  return _MarketControls(
                    controller: _searchController,
                    filter: _filter,
                    onQuery: (value) => setState(() => _query = value),
                    onFilter: (value) => setState(() => _filter = value),
                  );
                }
                if (index == 4) {
                  return _MarketTableHeader(color: scheme.onSurfaceVariant);
                }
                final coin = coins[index - 5];
                return _CoinMarketRow(
                  coin: coin,
                  favorite: _favorites.contains(coin['id']),
                  onFavorite: () => _toggleFavorite(coin['id'].toString()),
                  onTap: () => _openCoin(coin),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openCoin(Map<String, dynamic> coin) {
    final id = coin['id']?.toString();
    if (id != null && id.isNotEmpty) context.push('/listing/$id', extra: coin);
  }
}

class ListingCoinScreen extends ConsumerStatefulWidget {
  final String coinId;
  final Map<String, dynamic>? initialCoin;

  const ListingCoinScreen({super.key, required this.coinId, this.initialCoin});

  @override
  ConsumerState<ListingCoinScreen> createState() => _ListingCoinScreenState();
}

class _ListingCoinScreenState extends ConsumerState<ListingCoinScreen> {
  int _days = 7;
  int? _selectedPoint;

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(listingMarketProvider);
    final coin =
        _findCoin(market.valueOrNull, widget.coinId) ??
        ref.watch(listingCoinProvider(widget.coinId)).valueOrNull ??
        widget.initialCoin;
    final scheme = Theme.of(context).colorScheme;
    final chart = ref.watch(
      listingChartProvider((coinId: widget.coinId, days: _days)),
    );
    final name = coin?['name']?.toString() ?? _titleFromId(widget.coinId);
    return ResponsiveLayout(
      title: name,
      currentRoute: '/listing/${widget.coinId}',
      body: coin == null && market.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.refresh(listingMarketProvider.future),
                  ref.refresh(
                    listingChartProvider((coinId: widget.coinId, days: _days))
                        .future,
                  ),
                  ref.refresh(listingCoinProvider(widget.coinId).future),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                children: [
                  _CoinIdentity(coin: coin ?? const {}, fallbackName: name),
                  const SizedBox(height: 18),
                  _ChartPanel(
                    coin: coin ?? const {},
                    days: _days,
                    chart: chart,
                    selectedPoint: _selectedPoint,
                    onRange: (days) => setState(() {
                      _days = days;
                      _selectedPoint = null;
                    }),
                    onPoint: (index) => setState(() => _selectedPoint = index),
                  ),
                  const SizedBox(height: 16),
                  _DetailMetrics(
                    coin: coin ?? const {},
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  _LearningNote(),
                ],
              ),
            ),
    );
  }
}

Map<String, dynamic>? _findCoin(Map<String, dynamic>? data, String id) {
  final rows = data?['markets'];
  if (rows is! List) return null;
  for (final row in rows.whereType<Map>()) {
    if (row['id'] == id) return Map<String, dynamic>.from(row);
  }
  return null;
}

class _PageHeading extends StatelessWidget {
  final String? updatedAt;
  const _PageHeading({this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = DateTime.tryParse(updatedAt ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crypto market',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  updated == null
                      ? 'Prices and market data at a glance'
                      : 'Prices and market data · updated ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.circle, size: 8, color: Color(0xFF1DB47A)),
          const SizedBox(width: 6),
          Text(
            'Live data',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalStats extends StatelessWidget {
  final Map<String, dynamic> global;
  const _GlobalStats({required this.global});

  @override
  Widget build(BuildContext context) {
    final marketCap = _asDouble((global['total_market_cap'] as Map?)?['usd']);
    final volume = _asDouble((global['total_volume'] as Map?)?['usd']);
    final btc = _asDouble((global['market_cap_percentage'] as Map?)?['btc']);
    final active = _asInt(global['active_cryptocurrencies']);
    final cards = [
      _StatData(
        'Total market cap',
        _compactMoney(marketCap),
        Icons.account_balance_wallet_outlined,
      ),
      _StatData(
        '24h trading volume',
        _compactMoney(volume),
        Icons.swap_horiz_rounded,
      ),
      _StatData(
        'Bitcoin dominance',
        btc == null ? '—' : '${btc.toStringAsFixed(1)}%',
      ),
      _StatData(
        'Active currencies',
        active == null ? '—' : _compactNumber(active),
      ),
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _StatCard(data: cards[index]),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  const _StatData(
    this.label,
    this.value, [
    this.icon = Icons.query_stats_rounded,
  ]);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 205,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 15, color: scheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TrendingStrip extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onTap;
  const _TrendingStrip({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox(height: 12);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 17, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending now',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(items.length, 8),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final thumb = item['thumb']?.toString();
                return ActionChip(
                  avatar: thumb == null
                      ? const Icon(Icons.bolt_rounded, size: 16)
                      : CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(thumb),
                        ),
                  label: Text(
                    '${item['symbol'] ?? item['name'] ?? 'Coin'}'.toUpperCase(),
                  ),
                  onPressed: () => onTap(item),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.surfaceContainerLow,
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: .5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketControls extends StatelessWidget {
  final TextEditingController controller;
  final String filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onFilter;
  const _MarketControls({
    required this.controller,
    required this.filter,
    required this.onQuery,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: 'Search coins by name or ticker',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 11),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'All',
                  label: Text('All'),
                  icon: Icon(Icons.public_rounded),
                ),
                ButtonSegment(
                  value: 'Gainers',
                  label: Text('Gainers'),
                  icon: Icon(Icons.trending_up_rounded),
                ),
                ButtonSegment(
                  value: 'Losers',
                  label: Text('Losers'),
                  icon: Icon(Icons.trending_down_rounded),
                ),
                ButtonSegment(
                  value: 'Watchlist',
                  label: Text('Watchlist'),
                  icon: Icon(Icons.star_outline_rounded),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (selected) => onFilter(selected.first),
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketTableHeader extends StatelessWidget {
  final Color color;
  const _MarketTableHeader({required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 7, 8, 3),
    child: Row(
      children: [
        Expanded(flex: 5, child: Text('ASSET', style: _tableLabel(color))),
        Expanded(
          flex: 3,
          child: Text(
            'PRICE',
            textAlign: TextAlign.right,
            style: _tableLabel(color),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            '24H',
            textAlign: TextAlign.right,
            style: _tableLabel(color),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'MARKET CAP',
            textAlign: TextAlign.right,
            style: _tableLabel(color),
          ),
        ),
        const SizedBox(width: 34),
      ],
    ),
  );
}

TextStyle _tableLabel(Color color) => TextStyle(
  fontSize: 9,
  letterSpacing: 1,
  color: color,
  fontWeight: FontWeight.w800,
);

class _CoinMarketRow extends StatelessWidget {
  final Map<String, dynamic> coin;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  const _CoinMarketRow({
    required this.coin,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = _asDouble(coin['price_change_percentage_24h']) ?? 0;
    final color = change >= 0
        ? const Color(0xFF159A68)
        : const Color(0xFFE0505A);
    final image = coin['image']?.toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .35),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${coin['market_cap_rank'] ?? '—'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (image != null)
                    CachedNetworkImage(
                      imageUrl: image,
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                      memCacheWidth: 90,
                      placeholder: (_, _) =>
                          const SizedBox(width: 30, height: 30),
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.currency_bitcoin_rounded, size: 26),
                    )
                  else
                    const Icon(Icons.currency_bitcoin_rounded, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coin['name']?.toString() ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          (coin['symbol']?.toString() ?? '').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _money(_asDouble(coin['current_price'])),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _compactMoney(_asDouble(coin['market_cap'])),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
            SizedBox(
              width: 34,
              child: IconButton(
                tooltip: favorite
                    ? 'Remove from watchlist'
                    : 'Add to watchlist',
                visualDensity: VisualDensity.compact,
                onPressed: onFavorite,
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: favorite
                      ? const Color(0xFFF2AE38)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinIdentity extends StatelessWidget {
  final Map<String, dynamic> coin;
  final String fallbackName;
  const _CoinIdentity({required this.coin, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = _asDouble(coin['price_change_percentage_24h']) ?? 0;
    final icon = coin['image']?.toString();
    return Row(
      children: [
        if (icon != null)
          CachedNetworkImage(
            imageUrl: icon,
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            memCacheWidth: 144,
            errorWidget: (_, _, _) =>
                const Icon(Icons.currency_bitcoin_rounded, size: 42),
          )
        else
          const Icon(Icons.currency_bitcoin_rounded, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      fallbackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (coin['symbol']?.toString() ?? '').toUpperCase(),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Rank #${coin['market_cap_rank'] ?? '—'} · USD market',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Text(
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: change >= 0
                ? const Color(0xFF159A68)
                : const Color(0xFFE0505A),
          ),
        ),
      ],
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final Map<String, dynamic> coin;
  final int days;
  final AsyncValue<List<List<double>>> chart;
  final int? selectedPoint;
  final ValueChanged<int> onRange;
  final ValueChanged<int?> onPoint;
  const _ChartPanel({
    required this.coin,
    required this.days,
    required this.chart,
    required this.selectedPoint,
    required this.onRange,
    required this.onPoint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentPrice = _asDouble(coin['current_price']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Price history',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _money(currentPrice),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          chart.when(
            loading: () => const SizedBox(
              height: 235,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 235,
              child: Center(
                child: Text(_friendlyError(error), textAlign: TextAlign.center),
              ),
            ),
            data: (points) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  _selectedPrice(points, selectedPoint) ?? _money(currentPrice),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  _selectedTime(points, selectedPoint) ?? _rangeLabel(days),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _InteractivePriceChart(
                    points: points,
                    onSelected: onPoint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: [
              for (final range in const [
                (1, '1D'),
                (7, '1W'),
                (30, '1M'),
                (90, '3M'),
                (365, '1Y'),
              ])
                ChoiceChip(
                  label: Text(range.$2),
                  selected: days == range.$1,
                  onSelected: (_) => onRange(range.$1),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractivePriceChart extends StatefulWidget {
  final List<List<double>> points;
  final ValueChanged<int?> onSelected;
  const _InteractivePriceChart({
    required this.points,
    required this.onSelected,
  });

  @override
  State<_InteractivePriceChart> createState() => _InteractivePriceChartState();
}

class _InteractivePriceChartState extends State<_InteractivePriceChart> {
  int? _selected;
  void _select(Offset position, Size size) {
    if (widget.points.isEmpty) return;
    final index = ((position.dx / size.width) * (widget.points.length - 1))
        .round()
        .clamp(0, widget.points.length - 1);
    setState(() => _selected = index);
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, 180);
      return GestureDetector(
        onTapDown: (details) => _select(details.localPosition, size),
        onHorizontalDragUpdate: (details) =>
            _select(details.localPosition, size),
        child: CustomPaint(
          size: size,
          painter: _PriceChartPainter(
            points: widget.points,
            selected: _selected,
            color: Theme.of(context).colorScheme.primary,
            gridColor: Theme.of(context).dividerColor.withValues(alpha: .35),
          ),
        ),
      );
    },
  );
}

class _PriceChartPainter extends CustomPainter {
  final List<List<double>> points;
  final int? selected;
  final Color color;
  final Color gridColor;
  const _PriceChartPainter({
    required this.points,
    required this.selected,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final area = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - inset * 2),
      math.max(0, size.height - inset * 2),
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
    }
    if (points.length < 2) return;
    final values = points.map((point) => point[1]).toList();
    final minimum = values.reduce((a, b) => math.min(a, b).toDouble());
    final maximum = values.reduce((a, b) => math.max(a, b).toDouble());
    final span = maximum - minimum;
    Offset offsetAt(int index) => Offset(
      area.left + area.width * index / (points.length - 1),
      area.bottom -
          (span == 0 ? .5 : (values[index] - minimum) / span) * area.height,
    );
    final line = Path()..moveTo(offsetAt(0).dx, offsetAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final previous = offsetAt(i - 1);
      final next = offsetAt(i);
      final middle = (previous.dx + next.dx) / 2;
      line.cubicTo(middle, previous.dy, middle, next.dy, next.dx, next.dy);
    }
    final fill = Path.from(line)
      ..lineTo(area.right, area.bottom)
      ..lineTo(area.left, area.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .22), color.withValues(alpha: .01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(area),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (selected != null && selected! < points.length) {
      final point = offsetAt(selected!);
      canvas.drawLine(
        Offset(point.dx, area.top),
        Offset(point.dx, area.bottom),
        Paint()
          ..color = color.withValues(alpha: .45)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 5, Paint()..color = color);
      canvas.drawCircle(
        point,
        8,
        Paint()..color = color.withValues(alpha: .18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.color != color ||
      old.gridColor != gridColor;
}

class _DetailMetrics extends StatelessWidget {
  final Map<String, dynamic> coin;
  final Color color;
  const _DetailMetrics({required this.coin, required this.color});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Market cap', _compactMoney(_asDouble(coin['market_cap']))),
      ('24h volume', _compactMoney(_asDouble(coin['total_volume']))),
      ('24h high', _money(_asDouble(coin['high_24h']))),
      ('24h low', _money(_asDouble(coin['low_24h']))),
      (
        'Circulating supply',
        _compactNumber(_asDouble(coin['circulating_supply'])),
      ),
      ('All-time high', _money(_asDouble(coin['ath']))),
      ('All-time low', _money(_asDouble(coin['atl']))),
      (
        'Fully diluted value',
        _compactMoney(_asDouble(coin['fully_diluted_valuation'])),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market details',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          for (final item in metrics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LearningNote extends StatelessWidget {
  const _LearningNote();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Market prices change quickly. This page is for learning and information, not investment advice. Check data time and do your own research.',
              style: TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _MarketError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.query_stats_rounded, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Market data is unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final message =
        (error.response?.data is Map ? error.response?.data['error'] : null)
            ?.toString();
    if (message != null && message.isNotEmpty) return message;
    if (error.response?.statusCode == 503) {
      return 'Add the CoinGecko key to the Vercel environment to load market data.';
    }
    if (error.response?.statusCode == 429) {
      return 'CoinGecko is rate limiting requests. Wait a moment and try again.';
    }
  }
  return 'Check your connection and the Vercel CoinGecko environment setting, then try again.';
}

String? _selectedPrice(List<List<double>> points, int? index) =>
    index == null || index >= points.length ? null : _money(points[index][1]);
String? _selectedTime(List<List<double>> points, int? index) =>
    index == null || index >= points.length
    ? null
    : DateTime.fromMillisecondsSinceEpoch(points[index][0].round())
          .toLocal()
          .toString()
          .substring(0, 16);
String _rangeLabel(int days) => switch (days) {
  1 => 'Last 24 hours',
  7 => 'Last 7 days',
  30 => 'Last 30 days',
  90 => 'Last 90 days',
  _ => 'Last year',
};
String _titleFromId(String value) => value
    .split('-')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
double? _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
int? _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
String _money(double? value) {
  if (value == null) return '—';
  if (value >= 1000) {
    return '\$${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+\.)'), (_) => ',')}';
  }
  if (value >= 1) return '\$${value.toStringAsFixed(2)}';
  if (value >= .01) return '\$${value.toStringAsFixed(4)}';
  return '\$${value.toStringAsPrecision(4)}';
}

String _compactMoney(double? value) {
  if (value == null) return '—';
  if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
  if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
  return _money(value);
}

String _compactNumber(num? value) {
  if (value == null) return '—';
  if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
  return value.toStringAsFixed(0);
}
