import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:internet_file/internet_file.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/media_utils.dart';
import 'package:item_rdc_admin/util/links.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Visionneuse de documents : aperçu IMMÉDIAT, sans téléchargement complet.
///
/// - Google Drive => page `/preview` diffusée en continu.
/// - Autres PDF   => visionneuse en ligne (rendu côté serveur).
/// - "Lecteur natif" (menu) => ancien mode pdfx, en secours.
class PdfViewer extends StatefulWidget {
  final String url;
  final String title;
  const PdfViewer({super.key, required this.url, required this.title});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  WebViewController? _web;
  late final String _viewUrl;
  late final String _originHost;

  int _progress = 0;
  bool _error = false;
  bool _native = false;
  PdfControllerPinch? _pdf;

  @override
  void initState() {
    super.initState();
    _viewUrl = MediaUtils.documentViewUrl(widget.url);
    _originHost = Uri.tryParse(MediaUtils.clean(widget.url))?.host ?? '';

    // Sur le web (Chrome) il n'y a pas de WebView : ouverture dans un onglet.
    if (kIsWeb) return;

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && mounted) {
              setState(() => _error = true);
            }
          },
          onNavigationRequest: _onNavigation,
        ),
      )
      ..loadRequest(Uri.parse(_viewUrl));
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
      return NavigationDecision.navigate;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return NavigationDecision.prevent;
    }
    final host = uri.host.toLowerCase();
    final trusted =
        host.endsWith('google.com') ||
        host.endsWith('googleusercontent.com') ||
        host.endsWith('gstatic.com') ||
        host.endsWith('googleapis.com') ||
        (_originHost.isNotEmpty && host == _originHost.toLowerCase());
    if (trusted) return NavigationDecision.navigate;

    // Lien externe : on l'ouvre hors de l'application.
    launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  void _reload() {
    setState(() {
      _error = false;
      _progress = 0;
    });
    _web?.loadRequest(Uri.parse(_viewUrl));
  }

  void _openNative() {
    _pdf?.dispose();
    setState(() {
      _native = true;
      _pdf = PdfControllerPinch(
        document: PdfDocument.openData(
          InternetFile.get(MediaUtils.directUrl(widget.url)),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = !kIsWeb && !_native && !_error && _progress < 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'reload':
                  setState(() => _native = false);
                  _reload();
                case 'browser':
                  openExternalLink(context, MediaUtils.directUrl(widget.url));
                case 'native':
                  _openNative();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reload',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh_rounded),
                  title: Text("Reload"),
                ),
              ),
              PopupMenuItem(
                value: 'browser',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.open_in_browser_rounded),
                  title: Text("Open in browser"),
                ),
              ),
              PopupMenuItem(
                value: 'native',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf_rounded),
                  title: Text("Native PDF reader"),
                ),
              ),
            ],
          ),
        ],
        bottom: loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 3,
                  color: AppColors.brandSoft,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: _native ? _buildNative() : _buildWeb(loading),
    );
  }

  Widget _buildWeb(bool loading) {
    if (kIsWeb) {
      return EmptyState(
        icon: Icons.open_in_new_rounded,
        title: "Open the document",
        message: "The embedded preview is not available in the browser.",
        action: FilledButton.icon(
          onPressed: () => openExternalLink(context, _viewUrl),
          icon: const Icon(Icons.open_in_browser_rounded),
          label: const Text("Open in a new tab"),
        ),
      );
    }
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Cannot display the document",
        message: "Check your connection, or that the link is shared publicly.",
        action: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  openExternalLink(context, MediaUtils.directUrl(widget.url)),
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text("Browser"),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _web!)),
        if (loading)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _progress < 100 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const IconBadge(icon: Icons.description_rounded, size: 72),
                      const SizedBox(height: 16),
                      Text(
                        "Opening document…",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNative() {
    return PdfViewPinch(
      controller: _pdf!,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: "Cannot read file",
          message: error.toString(),
        ),
      ),
    );
  }
}
