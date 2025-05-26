import 'package:flutter/material.dart';
import 'package:frontend/theme/app_theme.dart';
import 'home_drawer.dart';

class DrawerUserController extends StatefulWidget {
  const DrawerUserController({
    super.key,
    this.drawerWidth = 250,
    this.screenView,
    this.menuView,
    this.animatedIconData = AnimatedIcons.arrow_menu,
    this.drawerIsOpen,
    this.onCategorySelectionChanged,
  });

  final double drawerWidth;
  final Widget? screenView;
  final Function(bool)? drawerIsOpen;
  final AnimatedIconData? animatedIconData;
  final Widget? menuView;
  final Function(Map<String, bool>)? onCategorySelectionChanged;

  @override
  DrawerUserControllerState createState() => DrawerUserControllerState();
}

class DrawerUserControllerState extends State<DrawerUserController>
    with TickerProviderStateMixin {
  late ScrollController scrollController;
  late AnimationController iconAnimationController;
  double scrolloffset = 0.0;

  @override
  void initState() {
    super.initState();

    iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 0),
    )..animateTo(1.0);

    scrollController = ScrollController(initialScrollOffset: widget.drawerWidth)
      ..addListener(() {
        if (scrollController.offset <= 0 && scrolloffset != 1.0) {
          setState(() {
            scrolloffset = 1.0;
            widget.drawerIsOpen?.call(true);
          });
          iconAnimationController.animateTo(0.0);
        } else if (scrollController.offset >= widget.drawerWidth &&
            scrolloffset != 0.0) {
          setState(() {
            scrolloffset = 0.0;
            widget.drawerIsOpen?.call(false);
          });
          iconAnimationController.animateTo(1.0);
        } else {
          setState(() {
            scrolloffset = scrollController.offset / widget.drawerWidth;
          });
        }
      });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scrollController.jumpTo(widget.drawerWidth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode =
        MediaQuery.of(context).platformBrightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLightMode ? AppTheme.white : AppTheme.nearlyBlack,
      body: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: widget.drawerWidth + MediaQuery.of(context).size.width,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: widget.drawerWidth,
                height: MediaQuery.of(context).size.height,
                child: HomeDrawer(
                  iconAnimationController: iconAnimationController,
                  onCategorySelectionChanged: widget.onCategorySelectionChanged,
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Container(
                  decoration: BoxDecoration(
                    color: isLightMode ? Colors.white : AppTheme.nearlyBlack,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppTheme.grey.withOpacity(0.6),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: widget.screenView,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onDrawerClick() {
    if (scrollController.offset != 0.0) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      scrollController.animateTo(
        widget.drawerWidth,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
  }
}