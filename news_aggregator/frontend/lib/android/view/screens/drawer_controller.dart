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
  });

  final double drawerWidth;
  final Widget? screenView;
  final Function(bool)? drawerIsOpen;
  final AnimatedIconData? animatedIconData;
  final Widget? menuView;

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
          iconAnimationController.animateTo(
            (scrollController.offset / widget.drawerWidth).clamp(0.0, 1.0),
          );
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
          width: MediaQuery.of(context).size.width + widget.drawerWidth,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: widget.drawerWidth,
                height: MediaQuery.of(context).size.height,
                child: AnimatedBuilder(
                  animation: iconAnimationController,
                  builder: (BuildContext context, Widget? child) {
                    return Transform(
                      transform: Matrix4.translationValues(
                        scrollController.offset,
                        0.0,
                        0.0,
                      ),
                      child: HomeDrawer(
                        iconAnimationController: iconAnimationController,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Stack(
                  children: <Widget>[
                    IgnorePointer(
                      ignoring: scrolloffset == 1,
                      child: widget.screenView,
                    ),
                    if (scrolloffset == 1.0) InkWell(onTap: onDrawerClick),
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 8,
                      ),
                      child: SizedBox(
                        width: AppBar().preferredSize.height - 8,
                        height: AppBar().preferredSize.height - 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppBar().preferredSize.height,
                            ),
                            child: Center(
                              child:
                                  widget.menuView ??
                                  AnimatedIcon(
                                    icon:
                                        widget.animatedIconData ??
                                        AnimatedIcons.arrow_menu,
                                    progress: iconAnimationController,
                                    color:
                                        isLightMode
                                            ? AppTheme.dark_grey
                                            : AppTheme.white,
                                  ),
                            ),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              onDrawerClick();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
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