@JS()
library native_scroll;

import 'package:flutter/widgets.dart';
import 'package:js/js.dart';
import 'dart:html';
import 'dart:ui' as ui;

class NativeScrollBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  const NativeScrollBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  _NativeScrollBuilderState createState() => _NativeScrollBuilderState();
}

class _NativeScrollBuilderState extends State<NativeScrollBuilder> {
  static int _globalId = 0;

  late String _viewId;
  late ScrollController _scrollController;

  final _heightDiv = DivElement();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _globalId++;
    _viewId = 'native-scroll-view-$_globalId';

    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (_) {
        // Create a scroll container - this is a <div> with scrolling overflow.
        // When it scroll, the Flutter ScrollController gets updated.
        return DivElement()
          ..id = _viewId
          ..style.overflow = 'scroll'
          ..style.width = '100%'
          ..style.height = '100%'
          // We need to cancel scroll events to stop them getting to Flutter
          ..onWheel.listen((event) => event.stopPropagation())
          ..onMouseWheel.listen((event) => event.stopPropagation())
          ..onScroll.listen((event) {
            final target = event.target as DivElement;
            _onNativeScroll(target.scrollTop);
          })
          ..append(_heightDiv);
      },
    );

    _scrollController.addListener(_onFlutterScroll);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _setScrollHeight();

      _scrollController.position.addListener(() {
        _setScrollHeight();
      });
    });
  }

  void _onFlutterScroll() {
    // There was a scroll in Flutter (e.g. scrollController.jumpTo called)
    // We need to update our shadow HTML scrolling elements
    _setScrollHeight();

    _heightDiv.scrollTop = _scrollController.position.pixels.toInt();
  }

  void _onNativeScroll(int scrollTop) {
    // There was a scroll in HTML land, update Flutter
    _scrollController.jumpTo(scrollTop.toDouble());
  }

  double? _lastScrollHeight;

  void _setScrollHeight() {
    // This updates a child <div> to have the same height
    // as the scroll contents from Flutter

    final scrollContentsHeight = _scrollController.position.viewportDimension +
        _scrollController.position.maxScrollExtent;

    if (scrollContentsHeight != _lastScrollHeight) {
      _lastScrollHeight = scrollContentsHeight;
      _heightDiv.style.height = '${scrollContentsHeight}px';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: widget.builder(context, _scrollController),
        ),
        HtmlElementView(viewType: _viewId),
      ],
    );
  }
}
