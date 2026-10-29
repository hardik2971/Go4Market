import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/cart_fx.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';

/// Search with voice. A phrase like "milk, bread and eggs" is split into terms and each term
/// gets its own result row with one-tap "add best match" for fast multi-product shopping.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initial = '', this.voice = false});
  final String initial;
  final bool voice;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<String> _terms = [];
  Future<List<List<Product>>>? _results;
  String _sort = 'relevance';

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) {
      _ctl.text = widget.initial;
      _run(widget.initial);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.voice) {
        _voice();
      } else if (widget.initial.isEmpty) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () => _run(v, save: false));
  }

  void _run(String q, {bool save = true}) {
    final t = q.trim();
    if (t.isEmpty) {
      setState(() {
        _query = '';
        _results = null;
      });
      return;
    }
    if (save) AppPrefs.instance.addRecentSearch(t);
    final terms = splitSearchTerms(t);
    final multi = terms.length > 1;
    setState(() {
      _query = t;
      _terms = multi ? terms : [t];
      _results = Future.wait(_terms.map((e) => Catalog.search(e))).then((l) {
        for (final r in l) {
          Session.instance.remember(r);
        }
        return l;
      });
    });
  }

  Future<void> _voice() async {
    FocusScope.of(context).unfocus();
    final text = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (_) => const _VoiceSheet(),
    );
    if (text != null && text.trim().isNotEmpty) {
      _ctl.text = text;
      _run(text);
    }
  }

  List<Product> _sorted(List<Product> l) {
    if (_sort == 'relevance') return l;
    final c = List<Product>.from(l);
    Catalog.sortLocal(c, _sort);
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Hero(
            tag: 'search-bar',
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _ctl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (v) => _run(v),
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_ctl.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _ctl.clear();
                          _run('');
                          _focus.requestFocus();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(onPressed: _voice, icon: const Icon(Icons.mic_rounded, color: G4MColors.primary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        actions: const [CartAction()],
      ),
      body: AnimatedSwitcher(
        duration: G4MMotion.standard,
        child: _results == null ? _idle(context) : _resultsView(context),
      ),
    );
  }

  Widget _idle(BuildContext context) {
    final recent = AppPrefs.instance.recentSearches;
    const trending = ['Milk', 'Bread', 'Eggs', 'Paracetamol', 'Biryani', 'Earbuds', 'Atta', 'Chocolate'];
    return ListView(key: const ValueKey('idle'), padding: const EdgeInsets.all(16), children: [
      AppCard(
        color: context.softPrimary,
        onTap: _voice,
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: G4MColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.mic_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Shop by voice', style: context.text.titleMedium),
              Text('Say "milk, bread and eggs" to find them all at once', style: context.text.bodySmall),
            ]),
          ),
        ]),
      ).stagger(0),
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('Recent searches', style: context.text.titleMedium)),
          TextButton(onPressed: () => setState(AppPrefs.instance.clearRecentSearches), child: const Text('Clear')),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, r) in recent.indexed)
            ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 16),
              label: Text(r),
              onPressed: () {
                _ctl.text = r;
                _run(r);
              },
            ).stagger(i, dy: 0),
        ]),
      ],
      const SizedBox(height: 20),
      Text('Trending', style: context.text.titleMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (i, t) in trending.indexed)
          ActionChip(
            avatar: const Icon(Icons.trending_up_rounded, size: 16, color: G4MColors.accent),
            label: Text(t),
            onPressed: () {
              _ctl.text = t;
              _run(t);
            },
          ).stagger(i, dy: 0),
      ]),
    ]);
  }

  Widget _resultsView(BuildContext context) => FutureBuilder<List<List<Product>>>(
        key: ValueKey(_query),
        future: _results,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => _run(_query));
          if (!snap.hasData) return const SingleChildScrollView(child: ProductGridSkeleton());
          final groups = snap.data!;
          if (_terms.length > 1) return _multi(context, groups);
          final list = _sorted(groups.first);
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results for "$_query"',
              message: 'Try another word, or request this product and we will try to stock it.',
            );
          }
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  Expanded(child: Text('${list.length} results', style: context.text.titleSmall)),
                  DropdownButton<String>(
                    value: _sort,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(value: 'relevance', child: Text('Relevance')),
                      DropdownMenuItem(value: 'price_asc', child: Text('Price: low to high')),
                      DropdownMenuItem(value: 'price_desc', child: Text('Price: high to low')),
                      DropdownMenuItem(value: 'rating', child: Text('Top rated')),
                      DropdownMenuItem(value: 'discount', child: Text('Biggest discount')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'relevance'),
                  ),
                ]),
              ),
            ),
            SliverProductGrid(products: list, scope: 'search'),
          ]);
        },
      );

  Widget _multi(BuildContext context, List<List<Product>> groups) {
    final best = [for (final g in groups) g.where((p) => p.inStock).firstOrNull];
    final addable = best.whereType<Product>().toList();
    return ListView(key: const ValueKey('multi'), padding: const EdgeInsets.only(bottom: 32), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AppCard(
          color: context.softPrimary,
          child: Row(children: [
            const Icon(Icons.checklist_rounded, color: G4MColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Found ${addable.length} of ${groups.length} items from your list',
                  style: context.text.titleSmall),
            ),
            Builder(
              builder: (bctx) => FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: addable.isEmpty
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        flyToCart(bctx, addable.first.image);
                        for (final p in addable) {
                          final vid = p.variants.isEmpty ? 'default' : p.variants.first.id;
                          final q = Session.instance.qtyOf(p.id, vid);
                          await Session.instance.setQty(p, q + 1, variantId: vid);
                        }
                        if (bctx.mounted) bctx.toast('Added ${addable.length} items to cart');
                      },
                child: const Text('Add all'),
              ),
            ),
          ]),
        ),
      ).stagger(0),
      for (var i = 0; i < groups.length; i++) ...[
        SectionHeader(
          '"${_terms[i]}"',
          subtitle: groups[i].isEmpty ? 'No match found' : '${groups[i].length} matches',
          onViewAll: groups[i].length > 1
              ? () {
                  _ctl.text = _terms[i];
                  _run(_terms[i]);
                }
              : null,
        ),
        if (groups[i].isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('We could not find "${_terms[i]}". Try a different word.', style: context.text.bodySmall),
          )
        else
          ProductCarousel(products: groups[i].take(10).toList(), scope: 'vs-$i'),
      ],
    ]);
  }
}

/// Listening sheet with a pulsing mic and live transcript.
class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  final _stt = SpeechToText();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  String _text = '';
  String _status = 'Starting…';
  double _level = 0;
  bool _available = false, _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _available = await _stt.initialize(
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() => _status = _text.isEmpty ? 'Didn\'t catch that. Tap the mic to try again.' : 'Got it');
            if (_text.isNotEmpty && !_done) _finish();
          }
        },
        onError: (e) {
          if (mounted) setState(() => _status = e.errorMsg == 'error_no_match' ? 'Didn\'t catch that. Tap to retry.' : 'Mic error: ${e.errorMsg}');
        },
      );
    } catch (_) {
      _available = false;
    }
    if (!mounted) return;
    if (!_available) {
      setState(() => _status = 'Voice search is not available. Check microphone permission.');
      return;
    }
    _listen();
  }

  Future<void> _listen() async {
    setState(() {
      _status = 'Listening… say one or more products';
      _text = '';
    });
    final loc = AppPrefs.instance.locale.languageCode == 'hi' ? 'hi_IN' : 'en_IN';
    await _stt.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _text = r.recognizedWords);
        if (r.finalResult && _text.isNotEmpty) _finish();
      },
      onSoundLevelChange: (l) => _level = ((l + 2) / 12).clamp(0.0, 1.0),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.search,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        localeId: loc,
      ),
    );
  }

  void _finish() {
    if (_done) return;
    _done = true;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) Navigator.of(context).pop(_text);
    });
  }

  @override
  void dispose() {
    _stt.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_status, textAlign: TextAlign.center, style: context.text.titleMedium),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _available && !_stt.isListening ? _listen : null,
              child: SizedBox(
                width: 150,
                height: 150,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => CustomPaint(
                    painter: _RipplePainter(_pulse.value, _stt.isListening ? .6 + _level * .4 : .2),
                    child: Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: G4MColors.heroGradient,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: G4MColors.primary.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSize(
              duration: G4MMotion.standard,
              child: Text(
                _text.isEmpty ? 'e.g. "milk, bread and eggs"' : '"$_text"',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(color: _text.isEmpty ? context.muted : context.ink, fontSize: 20),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _text.isEmpty ? null : () => Navigator.of(context).pop(_text),
                  child: const Text('Search'),
                ),
              ),
            ]),
          ]),
        ),
      );
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t, this.intensity);
  final double t, intensity;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final r = 38 + p * (size.width / 2 - 38);
      canvas.drawCircle(
        c,
        r,
        Paint()..color = G4MColors.primary.withValues(alpha: (1 - p) * .25 * intensity),
      );
    }
    canvas.drawCircle(c, 38 + 6 * math.sin(t * math.pi * 2) * intensity, Paint()..color = G4MColors.primary.withValues(alpha: .12));
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t || old.intensity != intensity;
}
