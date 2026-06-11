import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BrowserApp());
}

// ── Palette ───────────────────────────────────────────────────────────────────
class C {
  static const bg          = Color(0xFF0A0F1E);
  static const surface     = Color(0xFF111827);
  static const card        = Color(0xFF161F32);
  static const cardHover   = Color(0xFF1C2840);
  static const border      = Color(0xFF1E2D4A);
  static const borderFaint = Color(0xFF141E33);
  static const blue        = Color(0xFF2563EB);
  static const blueGlow    = Color(0x252563EB);
  static const cyan        = Color(0xFF06B6D4);
  static const t1          = Color(0xFFF1F5FB);
  static const t2          = Color(0xFF8B9FC0);
  static const t3          = Color(0xFF3D5278);
  static const green       = Color(0xFF10B981);
  static const greenGlow   = Color(0x1510B981);
  static const red         = Color(0xFFEF4444);
}

// ── App ───────────────────────────────────────────────────────────────────────
class BrowserApp extends StatelessWidget {
  const BrowserApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Браузер',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(
        primary: C.blue, secondary: C.cyan, surface: C.surface),
    ),
    home: const BrowserShell(),
  );
}

// ── Browser Shell ─────────────────────────────────────────────────────────────
class BrowserShell extends StatefulWidget {
  const BrowserShell({super.key});
  @override
  State<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends State<BrowserShell> {
  final List<_BTab> _tabs = [
    _BTab(title: 'Новая вкладка', url: '', isHome: true),
  ];
  int _activeTab = 0;

  final _urlCtrl  = TextEditingController();
  final _urlFocus = FocusNode();
  bool _urlEditing = false;
  bool _isSecure   = true;
  bool _isLoading  = false;
  double _loadProgress = 0;

  final Map<int, List<String>> _history      = {};
  final Map<int, int>          _historyIndex = {};

  @override
  void initState() {
    super.initState();
    _urlFocus.addListener(() => setState(() => _urlEditing = _urlFocus.hasFocus));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  _BTab get _current => _tabs[_activeTab];

  String _normalizeUrl(String s) {
    s = s.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('ipfs://') || s.startsWith('dweb://') ||
        s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.contains('.') && !s.contains(' ')) return 'https://$s';
    return 'https://duckduckgo.com/?q=${Uri.encodeComponent(s)}';
  }

  String _titleFromUrl(String url) {
    try { final u = Uri.parse(url); return u.host.isNotEmpty ? u.host : url; }
    catch (_) { return url; }
  }

  String _displayUrl(String url) {
    try {
      final u = Uri.parse(url);
      return u.host + (u.path.length > 1 ? u.path : '');
    } catch (_) { return url; }
  }

  bool get _canGoBack {
    final idx = _historyIndex[_activeTab] ?? -1; return idx > 0;
  }
  bool get _canGoForward {
    final h = _history[_activeTab] ?? []; final i = _historyIndex[_activeTab] ?? -1;
    return i < h.length - 1;
  }

  Future<void> _simulateLoad() async {
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;
      setState(() => _loadProgress = i / 10);
    }
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _navigate(String input) {
    final url = _normalizeUrl(input);
    if (url.isEmpty) return;
    setState(() {
      _tabs[_activeTab] = _BTab(title: _titleFromUrl(url), url: url, isHome: false);
      _isSecure = url.startsWith('https') || url.startsWith('ipfs') || url.startsWith('dweb');
      _urlCtrl.text = url;
      _isLoading = true;
      _loadProgress = 0;
    });
    _urlFocus.unfocus();
    _simulateLoad();

    final hist = _history[_activeTab] ?? [];
    final idx  = _historyIndex[_activeTab] ?? -1;
    final nh   = hist.sublist(0, idx + 1)..add(url);
    _history[_activeTab]      = nh;
    _historyIndex[_activeTab] = nh.length - 1;
  }

  void _goBack() {
    if (!_canGoBack) return;
    final idx = _historyIndex[_activeTab]! - 1;
    _historyIndex[_activeTab] = idx;
    final url = _history[_activeTab]![idx];
    setState(() {
      _tabs[_activeTab] = _BTab(title: _titleFromUrl(url), url: url, isHome: false);
      _urlCtrl.text = url;
      _isLoading = true; _loadProgress = 0;
    });
    _simulateLoad();
  }

  void _goForward() {
    if (!_canGoForward) return;
    final idx = _historyIndex[_activeTab]! + 1;
    _historyIndex[_activeTab] = idx;
    final url = _history[_activeTab]![idx];
    setState(() {
      _tabs[_activeTab] = _BTab(title: _titleFromUrl(url), url: url, isHome: false);
      _urlCtrl.text = url;
      _isLoading = true; _loadProgress = 0;
    });
    _simulateLoad();
  }

  void _reload() {
    if (_current.url.isEmpty) return;
    setState(() { _isLoading = true; _loadProgress = 0; });
    _simulateLoad();
  }

  void _newTab() {
    setState(() {
      _tabs.add(_BTab(title: 'Новая вкладка', url: '', isHome: true));
      _activeTab = _tabs.length - 1;
      _urlCtrl.clear();
      _isLoading = false;
    });
  }

  void _closeTab(int i) {
    if (_tabs.length == 1) { _newTab(); return; }
    setState(() {
      _tabs.removeAt(i);
      if (_activeTab >= _tabs.length) _activeTab = _tabs.length - 1;
    });
    _urlCtrl.text = _tabs[_activeTab].isHome ? '' : _tabs[_activeTab].url;
  }

  void _switchTab(int i) {
    setState(() => _activeTab = i);
    _urlCtrl.text = _tabs[i].isHome ? '' : _tabs[i].url;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: C.card,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: C.border)),
      content: Text(msg, style: const TextStyle(color: C.t1, fontSize: 13)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MenuSheet(
        onNewTab:    () { Navigator.pop(context); _newTab(); },
        onReload:    () { Navigator.pop(context); _reload(); },
        onHistory:   () { Navigator.pop(context); _snack('История — в разработке'); },
        onBookmark:  () { Navigator.pop(context); _snack('Закладки — в разработке'); },
        onDownloads: () { Navigator.pop(context); _snack('Загрузки — в разработке'); },
        onSettings:  () { Navigator.pop(context); _snack('Настройки — в разработке'); },
        onPrivate:   () { Navigator.pop(context); _snack('Приватный режим — в разработке'); },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        // ── Tab strip
        _TabStrip(
          tabs: _tabs, activeTab: _activeTab,
          onSwitch: _switchTab, onClose: _closeTab, onNew: _newTab,
        ),
        // ── Navigation bar
        _NavBar(
          urlCtrl: _urlCtrl, urlFocus: _urlFocus,
          editing: _urlEditing, isSecure: _isSecure,
          isLoading: _isLoading, canBack: _canGoBack, canFwd: _canGoForward,
          onBack: _goBack, onFwd: _goForward, onReload: _reload,
          onNavigate: _navigate, onMenu: _openMenu,
          hint: _current.url.isEmpty ? '' : _displayUrl(_current.url),
        ),
        // ── Progress
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isLoading ? 2 : 0,
          child: LinearProgressIndicator(
            value: _loadProgress,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation(C.blue),
          ),
        ),
        // ── Page
        Expanded(child: _current.isHome
            ? _HomePage(onNavigate: _navigate)
            : _WebPage(url: _current.url, isLoading: _isLoading)),
      ]),
    );
  }
}

// ── Tab Strip ─────────────────────────────────────────────────────────────────
class _TabStrip extends StatelessWidget {
  final List<_BTab> tabs;
  final int activeTab;
  final ValueChanged<int> onSwitch, onClose;
  final VoidCallback onNew;
  const _TabStrip({required this.tabs, required this.activeTab,
    required this.onSwitch, required this.onClose, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      height: 42 + top,
      color: C.surface,
      padding: EdgeInsets.only(top: top),
      child: Row(children: [
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 8),
            itemCount: tabs.length,
            itemBuilder: (_, i) => _TabChip(
              tab: tabs[i], active: i == activeTab,
              onTap: () => onSwitch(i), onClose: () => onClose(i),
            ),
          ),
        ),
        InkWell(
          onTap: onNew,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: C.card,
              border: Border.all(color: C.border),
            ),
            child: const Icon(Icons.add_rounded, color: C.t2, size: 17),
          ),
        ),
      ]),
    );
  }
}

class _TabChip extends StatelessWidget {
  final _BTab tab;
  final bool active;
  final VoidCallback onTap, onClose;
  const _TabChip({required this.tab, required this.active, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 180),
      height: 36,
      margin: const EdgeInsets.only(right: 2, top: 3, bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? C.bg : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: active ? Border.all(color: C.border) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? C.blue : C.t3,
          ),
          child: const Icon(Icons.language_rounded, size: 8, color: Colors.white),
        ),
        const SizedBox(width: 7),
        Flexible(child: Text(tab.title,
          style: TextStyle(
            color: active ? C.t1 : C.t3,
            fontSize: 12,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
        )),
        const SizedBox(width: 6),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(4),
          child: Icon(Icons.close_rounded, size: 13,
            color: active ? C.t2 : C.t3),
        ),
      ]),
    ),
  );
}

// ── Nav Bar ────────────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final TextEditingController urlCtrl;
  final FocusNode urlFocus;
  final bool editing, isSecure, isLoading, canBack, canFwd;
  final VoidCallback onBack, onFwd, onReload, onMenu;
  final ValueChanged<String> onNavigate;
  final String hint;

  const _NavBar({
    required this.urlCtrl, required this.urlFocus, required this.editing,
    required this.isSecure, required this.isLoading, required this.canBack,
    required this.canFwd, required this.onBack, required this.onFwd,
    required this.onReload, required this.onNavigate, required this.onMenu,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    color: C.surface,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Row(children: [
      _NBtn(Icons.arrow_back_ios_new_rounded, canBack, onBack),
      const SizedBox(width: 2),
      _NBtn(Icons.arrow_forward_ios_rounded,  canFwd,  onFwd),
      const SizedBox(width: 2),
      _NBtn(isLoading ? Icons.close_rounded : Icons.refresh_rounded, true, onReload),
      const SizedBox(width: 8),
      Expanded(child: _AddressBar(
        ctrl: urlCtrl, focus: urlFocus, editing: editing,
        isSecure: isSecure, hint: hint, onSubmit: onNavigate,
      )),
      const SizedBox(width: 8),
      _NBtn(Icons.more_vert_rounded, true, onMenu),
    ]),
  );
}

class _NBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NBtn(this.icon, this.enabled, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(width: 34, height: 36,
      child: Icon(icon, size: 16, color: enabled ? C.t2 : C.t3)),
  );
}

class _AddressBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool editing, isSecure;
  final String hint;
  final ValueChanged<String> onSubmit;
  const _AddressBar({required this.ctrl, required this.focus, required this.editing,
    required this.isSecure, required this.hint, required this.onSubmit});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    height: 36,
    decoration: BoxDecoration(
      color: editing ? C.card : C.bg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: editing ? C.blue : C.border, width: editing ? 1.5 : 1),
      boxShadow: editing
          ? [const BoxShadow(color: C.blueGlow, blurRadius: 12, spreadRadius: 1)]
          : [],
    ),
    child: Row(children: [
      const SizedBox(width: 12),
      Icon(isSecure ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
        size: 12, color: isSecure ? C.green : C.t3),
      const SizedBox(width: 7),
      Expanded(child: TextField(
        controller: ctrl, focusNode: focus,
        style: const TextStyle(color: C.t1, fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none, isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: hint.isEmpty ? 'Поиск или адрес' : hint,
          hintStyle: TextStyle(color: hint.isEmpty ? C.t3 : C.t2, fontSize: 13),
        ),
        onSubmitted: onSubmit,
        textInputAction: TextInputAction.go,
      )),
      if (editing && ctrl.text.isNotEmpty)
        GestureDetector(
          onTap: () => ctrl.clear(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.close_rounded, size: 13, color: C.t3),
          ),
        )
      else
        const SizedBox(width: 12),
    ]),
  );
}

// ── Home Page ─────────────────────────────────────────────────────────────────
class _HomePage extends StatefulWidget {
  final ValueChanged<String> onNavigate;
  const _HomePage({required this.onNavigate});
  @override State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  // Tracker toggle — зберігається в пам'яті (імітує localStorage).
  // TODO: замінити на виклик Rust-бекенду через FFI / platform channel
  bool _trackersBlocked = true;

  // Wallet — hardcoded mock, два стани перемикаються кнопкою
  bool _walletConnected = true;
  static const String _walletAddress = '0x71C...3a9';
  static const String _walletBalance = '1.284 ETH';
  static const String _walletUsd    = '≈ \$4 321.00';

  final _shortcuts = const [
    _SC('IPFS',      'ipfs.io',           Icons.storage_rounded,       C.cyan),
    _SC('ENS',       'app.ens.domains',   Icons.language_rounded,      C.blue),
    _SC('Uniswap',   'app.uniswap.org',   Icons.swap_horiz_rounded,    C.cyan),
    _SC('Lens',      'lens.xyz',          Icons.rss_feed_rounded,      C.blue),
    _SC('Mirror',    'mirror.xyz',        Icons.article_outlined,      C.cyan),
    _SC('Radicle',   'app.radicle.xyz',   Icons.hub_outlined,          C.blue),
    _SC('DWeb',      'dweb.link',         Icons.cloud_outlined,        C.cyan),
    _SC('Search',    'duckduckgo.com',    Icons.search_rounded,        C.blue),
  ];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: Stack(
      children: [
        Container(
          color: C.bg,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(children: [
              _HomeLogo(),
              const SizedBox(height: 20),
              _StatusPill(),
              const SizedBox(height: 32),
              _Section(
                label: 'Быстрый доступ',
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, childAspectRatio: 0.88,
                    mainAxisSpacing: 10, crossAxisSpacing: 10,
                  ),
                  itemCount: _shortcuts.length,
                  itemBuilder: (_, i) => _SCTile(
                    sc: _shortcuts[i],
                    onTap: () => widget.onNavigate(_shortcuts[i].url),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _Section(label: 'Сеть', child: _NetCard()),
              const SizedBox(height: 16),
              // ── Tracker toggle card
              _TrackerToggleCard(
                value: _trackersBlocked,
                onChanged: (v) => setState(() => _trackersBlocked = v),
              ),
            ]),
          ),
        ),
        // ── Wallet widget — bottom-right corner
        Positioned(
          right: 16, bottom: 16,
          child: _WalletWidget(
            connected: _walletConnected,
            address: _walletAddress,
            balance: _walletBalance,
            usd: _walletUsd,
            onConnect: () => setState(() => _walletConnected = true),
            onDisconnect: () => setState(() => _walletConnected = false),
          ),
        ),
      ],
    ),
  );
}

class _HomeLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [C.blue, C.cyan],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: C.blue.withOpacity(0.28), blurRadius: 18, spreadRadius: 3)],
      ),
      child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
    ),
    const SizedBox(height: 12),
    const Text('Браузер', style: TextStyle(
      color: C.t1, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
    const SizedBox(height: 4),
    const Text('Децентрализованный · Приватный',
      style: TextStyle(color: C.t3, fontSize: 11, letterSpacing: 0.2)),
  ]);
}

class _StatusPill extends StatefulWidget {
  @override State<_StatusPill> createState() => _StatusPillState();
}
class _StatusPillState extends State<_StatusPill> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _a = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: C.greenGlow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.green.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
          shape: BoxShape.circle, color: C.green,
          boxShadow: [BoxShadow(color: C.green.withOpacity(0.7 * _a.value), blurRadius: 6)],
        )),
        const SizedBox(width: 8),
        const Text('P2P · 142 узла · Tor активен',
          style: TextStyle(color: C.green, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
      ]),
    ),
  );
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
        color: C.t3, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _SCTile extends StatefulWidget {
  final _SC sc;
  final VoidCallback onTap;
  const _SCTile({required this.sc, required this.onTap});
  @override State<_SCTile> createState() => _SCTileState();
}
class _SCTileState extends State<_SCTile> {
  bool _p = false;
  @override Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      decoration: BoxDecoration(
        color: _p ? C.cardHover : C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _p ? widget.sc.color.withOpacity(0.4) : C.border),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.sc.color.withOpacity(0.12),
          ),
          child: Icon(widget.sc.icon, color: widget.sc.color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(widget.sc.name, style: const TextStyle(
          color: C.t1, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

class _NetCard extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border),
    ),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.shield_outlined, color: C.cyan, size: 14),
        const SizedBox(width: 7),
        const Text('Защита активна', style: TextStyle(color: C.t1, fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: C.greenGlow, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: C.green.withOpacity(0.3))),
          child: const Text('ON', style: TextStyle(color: C.green, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 10),
      const Divider(color: C.borderFaint, height: 1),
      const SizedBox(height: 10),
      _NRow(Icons.block_rounded,         'Заблокировано',  '3 491',  C.red),
      const SizedBox(height: 7),
      _NRow(Icons.people_outline_rounded,'P2P узлов',      '142',    C.cyan),
      const SizedBox(height: 7),
      _NRow(Icons.inventory_2_outlined,  'Кэш IPFS',       '2.1 ГБ', C.blue),
    ]),
  );
}
class _NRow extends StatelessWidget {
  final IconData icon; final String l, v; final Color c;
  const _NRow(this.icon, this.l, this.v, this.c);
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: c, size: 13), const SizedBox(width: 8),
    Text(l, style: const TextStyle(color: C.t2, fontSize: 11)),
    const Spacer(),
    Text(v, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

// ── Web Page — Markdown viewer ────────────────────────────────────────────────
// Отримує сирий текст/Markdown з децентралізованої мережі та рендерить його.
// _mockFetch імітує мережевий запит; замінити на реальний IPFS/DWeb-клієнт.
class _WebPage extends StatefulWidget {
  final String url;
  final bool isLoading;
  const _WebPage({required this.url, required this.isLoading});
  @override State<_WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<_WebPage> {
  String? _content;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  @override
  void didUpdateWidget(_WebPage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _fetchContent();
  }

  Future<void> _fetchContent() async {
    if (widget.url.isEmpty) return;
    setState(() { _fetching = true; _content = null; });
    // TODO: замінити на реальний виклик IPFS/DWeb/P2P-клієнта.
    // Очікується що мережа повертає сирий Markdown-рядок.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _content = _mockMarkdown(widget.url);
    });
  }

  /// Тимчасова заглушка — повертає демо-Markdown для будь-якого URL.
  /// Замінити на `await ipfsClient.fetchString(url)` або аналог.
  String _mockMarkdown(String url) => '''
# Вміст із децентралізованої мережі

> Сторінка завантажена з: `$url`

Цей браузер отримує **сирий Markdown** із P2P-мережі та рендерить його
безпосередньо — без центрального сервера.

## Можливості

- Підтримка **жирного** та _курсиву_
- Вбудовані `code snippets`
- Списки та вкладені елементи
- Посилання та цитати

## Приклад коду

```dart
final content = await ipfs.cat(cid);
setState(() => _content = content);
```

## Посилання

[IPFS Docs](https://docs.ipfs.tech) · [ENS](https://ens.domains) · [DWeb](https://dweb.link)

---

*Завантажено через Nexus Browser — приватно, без цензури.*
''';

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || _fetching) {
      return const Center(
        child: CircularProgressIndicator(color: C.blue, strokeWidth: 2));
    }
    if (_content == null || _content!.isEmpty) {
      return const Center(
        child: Text('Немає вмісту', style: TextStyle(color: C.t3, fontSize: 13)));
    }
    return _MarkdownView(content: _content!);
  }
}

// ── Markdown View ─────────────────────────────────────────────────────────────
class _MarkdownView extends StatelessWidget {
  final String content;
  const _MarkdownView({required this.content});

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: content,
      selectable: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [md.EmojiSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
      ),
      styleSheet: _mdStyleSheet(),
      onTapLink: (text, href, title) {
        // TODO: передати href у _navigate() через callback
        debugPrint('Tap link: $href');
      },
    );
  }

  /// Кастомні стилі Markdown під темну палітру C.*
  MarkdownStyleSheet _mdStyleSheet() => MarkdownStyleSheet(
    // ── Фон
    blockquoteDecoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(4),
      border: const Border(left: BorderSide(color: C.cyan, width: 3)),
    ),
    codeblockDecoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: C.border),
    ),

    // ── Заголовки
    h1: const TextStyle(
      color: C.t1, fontSize: 26, fontWeight: FontWeight.w700,
      letterSpacing: -0.5, height: 1.3),
    h2: const TextStyle(
      color: C.t1, fontSize: 21, fontWeight: FontWeight.w600,
      letterSpacing: -0.3, height: 1.35),
    h3: const TextStyle(
      color: C.t1, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
    h4: const TextStyle(
      color: C.t2, fontSize: 15, fontWeight: FontWeight.w600),
    h5: const TextStyle(
      color: C.t2, fontSize: 13, fontWeight: FontWeight.w600),
    h6: const TextStyle(
      color: C.t3, fontSize: 12, fontWeight: FontWeight.w600),

    // ── Відступи заголовків
    h1Padding: const EdgeInsets.only(top: 24, bottom: 8),
    h2Padding: const EdgeInsets.only(top: 20, bottom: 6),
    h3Padding: const EdgeInsets.only(top: 16, bottom: 4),

    // ── Основний текст
    p: const TextStyle(color: C.t2, fontSize: 14, height: 1.75),
    pPadding: const EdgeInsets.only(bottom: 10),

    // ── Жирний / курсив
    strong: const TextStyle(color: C.t1, fontWeight: FontWeight.w600),
    em: TextStyle(color: C.t2.withOpacity(0.9), fontStyle: FontStyle.italic),

    // ── Інлайн-код
    code: const TextStyle(
      color: C.cyan, fontSize: 12.5,
      fontFamily: 'monospace', backgroundColor: Color(0xFF1A2540)),

    // ── Блок коду
    codeblockPadding: const EdgeInsets.all(16),
    codeblockAlign: WrapAlignment.start,

    // ── Цитата
    blockquote: const TextStyle(color: C.t2, fontSize: 14, height: 1.6),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

    // ── Списки
    listBullet: const TextStyle(color: C.cyan, fontSize: 14),
    listBulletPadding: const EdgeInsets.only(right: 8),
    listIndent: 20,

    // ── Посилання
    a: const TextStyle(
      color: C.blue, decoration: TextDecoration.underline,
      decorationColor: C.blue),

    // ── Горизонтальна лінія
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: C.border, width: 1))),

    // ── Таблиця
    tableHead: const TextStyle(color: C.t1, fontWeight: FontWeight.w600, fontSize: 13),
    tableBody: const TextStyle(color: C.t2, fontSize: 13),
    tableBorder: TableBorder.all(color: C.border, width: 1),
    tableHeadAlign: TextAlign.left,
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

// ── Menu Bottom Sheet ─────────────────────────────────────────────────────────
class _MenuSheet extends StatelessWidget {
  final VoidCallback onNewTab, onReload, onHistory, onBookmark,
                     onDownloads, onSettings, onPrivate;
  const _MenuSheet({required this.onNewTab, required this.onReload,
    required this.onHistory, required this.onBookmark,
    required this.onDownloads, required this.onSettings, required this.onPrivate});

  @override Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      border: Border(top: BorderSide(color: C.border)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 32, height: 3,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2))),
      Row(children: [
        _MT(Icons.add_rounded,          'Новая вкладка', onNewTab),
        const SizedBox(width: 10),
        _MT(Icons.privacy_tip_outlined, 'Приватная',     onPrivate),
        const SizedBox(width: 10),
        _MT(Icons.refresh_rounded,      'Обновить',      onReload),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MT(Icons.history_rounded,         'История',   onHistory),
        const SizedBox(width: 10),
        _MT(Icons.bookmark_border_rounded, 'Закладки',  onBookmark),
        const SizedBox(width: 10),
        _MT(Icons.download_outlined,       'Загрузки',  onDownloads),
      ]),
      const SizedBox(height: 10),
      InkWell(
        onTap: onSettings,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: C.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.border)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.settings_outlined, color: C.t2, size: 17),
            SizedBox(width: 8),
            Text('Настройки', style: TextStyle(color: C.t2, fontSize: 13)),
          ]),
        ),
      ),
    ]),
  );
}

class _MT extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _MT(this.icon, this.label, this.onTap);
  @override Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: C.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border)),
      child: Column(children: [
        Icon(icon, color: C.t2, size: 18),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: C.t2, fontSize: 10)),
      ]),
    ),
  ));
}

// ── Tracker Toggle Card ───────────────────────────────────────────────────────
// Стан зберігається в пам'яті (_HomePageState._trackersBlocked).
// localStorage-семантика: значення живе протягом сесії і не скидається
// при навігації між вкладками всередині додатку.
// TODO: підключити до Rust-бекенду через platform channel / FFI.
class _TrackerToggleCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TrackerToggleCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: value ? C.green.withOpacity(0.35) : C.border,
        width: value ? 1.5 : 1,
      ),
      boxShadow: value
          ? [BoxShadow(color: C.green.withOpacity(0.06), blurRadius: 16, spreadRadius: 2)]
          : [],
    ),
    child: Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? C.green.withOpacity(0.14) : C.border.withOpacity(0.3),
        ),
        child: Icon(
          value ? Icons.shield_rounded : Icons.shield_outlined,
          color: value ? C.green : C.t3, size: 18,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Блокування трекерів та реклами',
            style: TextStyle(color: C.t1, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              key: ValueKey(value),
              value ? 'Увімкнено — захист активний' : 'Вимкнено — трекери не блокуються',
              style: TextStyle(
                color: value ? C.green : C.t3,
                fontSize: 11,
              ),
            ),
          ),
        ],
      )),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 46, height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: value ? C.green : C.t3.withOpacity(0.3),
            border: Border.all(
              color: value ? C.green.withOpacity(0.5) : C.border,
            ),
          ),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: value ? 22 : 2, top: 2,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    ]),
  );
}

// ── Wallet Widget ─────────────────────────────────────────────────────────────
// Два стани: підключено / відключено.
// Hardcoded змінні: _walletAddress, _walletBalance, _walletUsd.
// TODO: замінити на реальний Web3-провайдер (WalletConnect / MetaMask).
class _WalletWidget extends StatefulWidget {
  final bool connected;
  final String address, balance, usd;
  final VoidCallback onConnect, onDisconnect;
  const _WalletWidget({
    required this.connected, required this.address, required this.balance,
    required this.usd, required this.onConnect, required this.onDisconnect,
  });
  @override State<_WalletWidget> createState() => _WalletWidgetState();
}

class _WalletWidgetState extends State<_WalletWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ac;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    alignment: Alignment.bottomRight,
    child: GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _expanded ? 200 : 48,
        height: _expanded && widget.connected ? 130 : (_expanded ? 96 : 48),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(_expanded ? 16 : 24),
          border: Border.all(
            color: widget.connected
                ? C.cyan.withOpacity(0.4)
                : C.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.connected
                  ? C.cyan.withOpacity(0.12)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 16, spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_expanded ? 16 : 24),
          child: _expanded ? _expandedContent() : _collapsedIcon(),
        ),
      ),
    ),
  );

  Widget _collapsedIcon() => Center(
    child: Stack(alignment: Alignment.center, children: [
      Icon(Icons.account_balance_wallet_outlined,
        color: widget.connected ? C.cyan : C.t3, size: 22),
      if (widget.connected)
        Positioned(
          right: 8, top: 8,
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: C.green,
              border: Border.all(color: C.card, width: 1.5),
            ),
          ),
        ),
    ]),
  );

  Widget _expandedContent() {
    if (!widget.connected) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, color: C.t3, size: 16),
              const SizedBox(width: 8),
              const Text('Гаманець', style: TextStyle(
                color: C.t2, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: const Icon(Icons.close_rounded, color: C.t3, size: 14)),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.onConnect,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.blue, C.cyan]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Підключити гаманець',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: C.green,
                boxShadow: [BoxShadow(color: C.green.withOpacity(0.6), blurRadius: 4)]),
            ),
            const SizedBox(width: 6),
            const Text('Підключено', style: TextStyle(
              color: C.green, fontSize: 10, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _expanded = false),
              child: const Icon(Icons.close_rounded, color: C.t3, size: 14)),
          ]),
          const SizedBox(height: 8),
          const Divider(color: C.borderFaint, height: 1),
          const SizedBox(height: 8),
          Text(widget.address, style: const TextStyle(
            color: C.cyan, fontSize: 12, fontWeight: FontWeight.w600,
            letterSpacing: 0.3, fontFamily: 'monospace')),
          const SizedBox(height: 6),
          Text(widget.balance, style: const TextStyle(
            color: C.t1, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(widget.usd, style: const TextStyle(color: C.t3, fontSize: 10)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: widget.onDisconnect,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: C.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.red.withOpacity(0.3)),
              ),
              child: const Text('Відключити',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.red, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────
class _BTab {
  final String title, url;
  final bool isHome;
  const _BTab({required this.title, required this.url, required this.isHome});
}

class _SC {
  final String name, url;
  final IconData icon;
  final Color color;
  const _SC(this.name, this.url, this.icon, this.color);
}