import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Palette (дублюємо тут щоб файл був автономним) ───────────────────────────
// Якщо винесеш C у окремий colors.dart — замінити на import
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

// ── Моделі ────────────────────────────────────────────────────────────────────

/// DID-профіль користувача.
/// TODO: замінити mock-дані на реальний DID-резолвер (did:ethr / did:key / ENS).
class DidProfile {
  final String did;
  final String displayName;
  final String? ensName;
  final String? avatarUrl;
  final bool verified;

  const DidProfile({
    required this.did,
    required this.displayName,
    this.ensName,
    this.avatarUrl,
    this.verified = false,
  });

  String get shortDid {
    if (did.length <= 20) return did;
    return '${did.substring(0, 12)}...${did.substring(did.length - 6)}';
  }
}

/// Децентралізована закладка (IPFS CID або dweb/ipfs адреса).
/// TODO: зберігати у локальному сховищі (Hive / SharedPreferences) або IPFS.
class DWebBookmark {
  final String title;
  final String address; // ipfs://, dweb://, did:, https://
  final BookmarkType type;
  final DateTime addedAt;

  const DWebBookmark({
    required this.title,
    required this.address,
    required this.type,
    required this.addedAt,
  });
}

enum BookmarkType { ipfs, dweb, ens, https }

// ── Mock-дані ─────────────────────────────────────────────────────────────────
// TODO: замінити на завантаження з DID-документа та P2P-сховища.

const _mockProfile = DidProfile(
  did: 'did:ethr:0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
  displayName: 'nexus.user',
  ensName: 'nexus.eth',
  verified: true,
);

final _mockBookmarks = [
  DWebBookmark(
    title: 'IPFS Docs',
    address: 'ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq',
    type: BookmarkType.ipfs,
    addedAt: DateTime(2024, 3, 10),
  ),
  DWebBookmark(
    title: 'Uniswap App',
    address: 'ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco',
    type: BookmarkType.ipfs,
    addedAt: DateTime(2024, 4, 1),
  ),
  DWebBookmark(
    title: 'Mirror.xyz',
    address: 'https://mirror.xyz',
    type: BookmarkType.https,
    addedAt: DateTime(2024, 4, 15),
  ),
  DWebBookmark(
    title: 'ENS Lookup',
    address: 'app.ens.domains',
    type: BookmarkType.ens,
    addedAt: DateTime(2024, 5, 2),
  ),
  DWebBookmark(
    title: 'DWeb Link',
    address: 'dweb://bafkreifjjcie6lypi6ny7amxnfftagclbuxndqonfipmr7yxh53s5b4mmq',
    type: BookmarkType.dweb,
    addedAt: DateTime(2024, 5, 20),
  ),
];

// ── SidebarPanel ──────────────────────────────────────────────────────────────
/// Drawer що слайдає зліва. Містить:
///   • рядок введення хешу/адреси
///   • DID-профіль
///   • список децентралізованих закладок
///
/// Підключення в BrowserShell:
///   Scaffold(
///     drawer: SidebarPanel(onNavigate: _navigate),
///     ...
///   )
class SidebarPanel extends StatefulWidget {
  /// Колбек навігації — передає адресу у браузер.
  final ValueChanged<String> onNavigate;

  const SidebarPanel({super.key, required this.onNavigate});

  @override
  State<SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends State<SidebarPanel>
    with SingleTickerProviderStateMixin {
  final _hashCtrl  = TextEditingController();
  final _hashFocus = FocusNode();
  bool _hashEditing = false;

  // Профіль — mock; TODO: замінити на DID-резолвер
  final DidProfile _profile = _mockProfile;

  // Закладки — mock; TODO: завантажувати з LocalStorage / IPFS
  late List<DWebBookmark> _bookmarks;

  late AnimationController _ac;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _bookmarks = List.from(_mockBookmarks);
    _hashFocus.addListener(
      () => setState(() => _hashEditing = _hashFocus.hasFocus));
    _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.forward();
  }

  @override
  void dispose() {
    _hashCtrl.dispose();
    _hashFocus.dispose();
    _ac.dispose();
    super.dispose();
  }

  void _submitHash() {
    final val = _hashCtrl.text.trim();
    if (val.isEmpty) return;
    widget.onNavigate(val);
    _hashCtrl.clear();
    _hashFocus.unfocus();
    Navigator.of(context).pop(); // закрити drawer після навігації
  }

  void _navigateBookmark(DWebBookmark bm) {
    widget.onNavigate(bm.address);
    Navigator.of(context).pop();
  }

  void _removeBookmark(DWebBookmark bm) {
    setState(() => _bookmarks.remove(bm));
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0), end: Offset.zero,
      ).animate(_slideAnim),
      child: Drawer(
        width: 300,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: C.surface,
            border: Border(right: BorderSide(color: C.border)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Шапка
                _SidebarHeader(profile: _profile),
                const _Divider(),

                // ── Рядок введення хешу / адреси
                _HashInputField(
                  ctrl: _hashCtrl,
                  focus: _hashFocus,
                  editing: _hashEditing,
                  onSubmit: (_) => _submitHash(),
                  onGo: _submitHash,
                ),
                const SizedBox(height: 8),
                const _Divider(),

                // ── Закладки
                Expanded(
                  child: _BookmarksList(
                    bookmarks: _bookmarks,
                    onTap: _navigateBookmark,
                    onRemove: _removeBookmark,
                  ),
                ),

                // ── Футер
                const _SidebarFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Шапка з DID-профілем ──────────────────────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  final DidProfile profile;
  const _SidebarHeader({required this.profile});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Аватар / ідентикон
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [C.blue, C.cyan],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: C.blue.withOpacity(0.25),
                blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.person_outline_rounded,
            color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(profile.displayName,
                style: const TextStyle(
                  color: C.t1, fontSize: 15, fontWeight: FontWeight.w600)),
              if (profile.verified) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded, color: C.cyan, size: 14),
              ],
            ]),
            if (profile.ensName != null) ...[
              const SizedBox(height: 2),
              Text(profile.ensName!,
                style: const TextStyle(color: C.cyan, fontSize: 12)),
            ],
          ],
        )),
      ]),
      const SizedBox(height: 12),

      // DID-адреса з кнопкою копіювання
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: profile.did));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('DID скопійовано'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.border),
          ),
          child: Row(children: [
            const Icon(Icons.fingerprint_rounded, color: C.t3, size: 13),
            const SizedBox(width: 7),
            Expanded(child: Text(profile.shortDid,
              style: const TextStyle(
                color: C.t3, fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
            const Icon(Icons.copy_rounded, color: C.t3, size: 12),
          ]),
        ),
      ),
    ]),
  );
}

// ── Рядок введення хешу/адреси ────────────────────────────────────────────────
class _HashInputField extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool editing;
  final ValueChanged<String> onSubmit;
  final VoidCallback onGo;

  const _HashInputField({
    required this.ctrl, required this.focus, required this.editing,
    required this.onSubmit, required this.onGo,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Перейти за хешем / адресою',
        style: TextStyle(
          color: C.t3, fontSize: 10,
          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: editing ? C.card : C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: editing ? C.blue : C.border,
            width: editing ? 1.5 : 1),
          boxShadow: editing
              ? [const BoxShadow(color: C.blueGlow, blurRadius: 10)]
              : [],
        ),
        child: Row(children: [
          const SizedBox(width: 10),
          const Icon(Icons.tag_rounded, color: C.t3, size: 14),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: ctrl,
            focusNode: focus,
            style: const TextStyle(color: C.t1, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              hintText: 'CID, ipfs://, dweb://, ENS...',
              hintStyle: TextStyle(color: C.t3, fontSize: 12),
            ),
            onSubmitted: onSubmit,
            textInputAction: TextInputAction.go,
          )),
          // Кнопка Go
          GestureDetector(
            onTap: onGo,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [C.blue, C.cyan]),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text('GO',
                style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),
        ]),
      ),
    ]),
  );
}

// ── Список закладок ───────────────────────────────────────────────────────────
class _BookmarksList extends StatelessWidget {
  final List<DWebBookmark> bookmarks;
  final ValueChanged<DWebBookmark> onTap;
  final ValueChanged<DWebBookmark> onRemove;

  const _BookmarksList({
    required this.bookmarks, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Row(children: [
          const Text('ЗАКЛАДКИ',
            style: TextStyle(
              color: C.t3, fontSize: 10,
              fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const Spacer(),
          Text('${bookmarks.length}',
            style: const TextStyle(color: C.t3, fontSize: 10)),
        ]),
      ),
      Expanded(
        child: bookmarks.isEmpty
            ? _EmptyBookmarks()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: bookmarks.length,
                itemBuilder: (_, i) => _BookmarkTile(
                  bookmark: bookmarks[i],
                  onTap: () => onTap(bookmarks[i]),
                  onRemove: () => onRemove(bookmarks[i]),
                ),
              ),
      ),
    ],
  );
}

class _BookmarkTile extends StatefulWidget {
  final DWebBookmark bookmark;
  final VoidCallback onTap, onRemove;
  const _BookmarkTile({
    required this.bookmark, required this.onTap, required this.onRemove});
  @override State<_BookmarkTile> createState() => _BookmarkTileState();
}

class _BookmarkTileState extends State<_BookmarkTile> {
  bool _hovered = false;

  Color get _typeColor {
    switch (widget.bookmark.type) {
      case BookmarkType.ipfs:  return C.cyan;
      case BookmarkType.dweb:  return C.blue;
      case BookmarkType.ens:   return const Color(0xFF8B5CF6); // purple
      case BookmarkType.https: return C.green;
    }
  }

  String get _typeLabel {
    switch (widget.bookmark.type) {
      case BookmarkType.ipfs:  return 'IPFS';
      case BookmarkType.dweb:  return 'DWEB';
      case BookmarkType.ens:   return 'ENS';
      case BookmarkType.https: return 'HTTPS';
    }
  }

  IconData get _typeIcon {
    switch (widget.bookmark.type) {
      case BookmarkType.ipfs:  return Icons.storage_rounded;
      case BookmarkType.dweb:  return Icons.cloud_outlined;
      case BookmarkType.ens:   return Icons.language_rounded;
      case BookmarkType.https: return Icons.lock_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onLongPress: widget.onRemove,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? C.cardHover : C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered ? _typeColor.withOpacity(0.3) : C.border),
        ),
        child: Row(children: [
          // Іконка типу
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _typeColor.withOpacity(0.12),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 13),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.bookmark.title,
                style: const TextStyle(
                  color: C.t1, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(widget.bookmark.address,
                style: const TextStyle(color: C.t3, fontSize: 10),
                overflow: TextOverflow.ellipsis),
            ],
          )),
          const SizedBox(width: 6),
          // Тег типу
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _typeColor.withOpacity(0.25)),
            ),
            child: Text(_typeLabel,
              style: TextStyle(
                color: _typeColor, fontSize: 8, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ),
  );
}

class _EmptyBookmarks extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.bookmark_border_rounded, color: C.t3, size: 32),
      const SizedBox(height: 10),
      const Text('Немає закладок',
        style: TextStyle(color: C.t3, fontSize: 12)),
      const SizedBox(height: 4),
      const Text('Довгий тап на закладці — видалити',
        style: TextStyle(color: C.t3, fontSize: 10)),
    ]),
  );
}

// ── Футер ─────────────────────────────────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: C.border))),
    child: Row(children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: C.green,
          boxShadow: [BoxShadow(
            color: C.green.withOpacity(0.6), blurRadius: 4)],
        ),
      ),
      const SizedBox(width: 8),
      const Text('Nexus Browser · P2P активний',
        style: TextStyle(color: C.t3, fontSize: 10)),
    ]),
  );
}

// ── Розділювач ────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: C.border);
}