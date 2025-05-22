import 'package:flutter/material.dart';
import '../models/article.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

// Use conditional imports to handle web-only code
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class ArticleWebViewPage extends StatefulWidget {
  final Article article;
  
  const ArticleWebViewPage({Key? key, required this.article}) : super(key: key);

  @override
  ArticleWebViewPageState createState() => ArticleWebViewPageState();
}

class ArticleWebViewPageState extends State<ArticleWebViewPage> {
  bool _isLoading = true;
  String _viewId = '';
  
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupIframeView();
    }
  }
  
  void _setupIframeView() {
    // Generate a unique ID for this iframe
    _viewId = 'iframe-${DateTime.now().millisecondsSinceEpoch}';
    
    // Register the view factory
    // Use ui_web instead of ui for platformViewRegistry
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframeElement = html.IFrameElement()
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%'
        ..src = widget.article.url;
      
      // Set up loading state management
      iframeElement.onLoad.listen((event) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
      
      return iframeElement;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.article.title.length > 30 
              ? '${widget.article.title.substring(0, 30)}...'
              : widget.article.title
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final url = Uri.parse(widget.article.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: 'Open in Browser',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (kIsWeb && _viewId.isNotEmpty)
            HtmlElementView(viewType: _viewId)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'WebView is only supported on web platform',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final url = Uri.parse(widget.article.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Open in External Browser'),
                  ),
                ],
              ),
            ),
          if (_isLoading && kIsWeb)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}