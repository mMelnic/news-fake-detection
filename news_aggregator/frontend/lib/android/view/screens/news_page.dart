import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/android/model/news.dart';
import '../../model/news_helper.dart';
import '../../route/slide_page_route.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/news_card.dart';
import '../widgets/news_filter_sheet.dart';
import 'news_detail_page.dart';

class NewsPage extends StatefulWidget {
  final Function? openDrawer;
  
  const NewsPage({super.key, this.openDrawer});

  @override
  NewsPageState createState() => NewsPageState();
}

class NewsPageState extends State<NewsPage> with TickerProviderStateMixin {
  List<News> news = NewsHelper.allCategoriesNews;
  late TabController _categoryTabController;

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(length: 7, vsync: this);
  }

  _changeTab(index) {
    setState(() {
      _categoryTabController.index = index;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _categoryTabController.dispose();
  }

  showFilter() {
    showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return NewsFilterSheet(); // Replace with your news filter sheet widget
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leadingIcon: SvgPicture.asset(
          'assets/icons/Menu.svg',
          color: Colors.white,
        ),
        onPressedLeading: () {
          widget.openDrawer?.call();
        },
        title: Text(
          'News',
          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showFilter();
            },
            icon: Icon(Icons.sort_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: true,
              controller: _categoryTabController,
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              labelColor: Colors.black,
              unselectedLabelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              unselectedLabelColor: Colors.black.withOpacity(0.6),
              indicatorColor: Colors.transparent,
              onTap: _changeTab,
              tabs: [
                Tab(text: 'All categories'),
                Tab(text: 'News'),
                Tab(text: 'Food'),
                Tab(text: 'Sports'),
                Tab(text: 'Fashion'),
              ],
            ),
            IndexedStack(
              index: _categoryTabController.index,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childAspectRatio: NewsCard.itemWidth / NewsCard.itemHeight,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 10,
                  children: List.generate(news.length, (index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          SlidePageRoute(
                            child: NewsDetailPage(data: news[index]),
                          ),
                        );
                      },
                      child: NewsCard(data: news[index]),
                    );
                  }),
                ),
                // Add other category pages here
              ],
            ),
          ],
        ),
      ),
    );
  }
}
