import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MySliverAppBar extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final TextEditingController filter;
  MySliverAppBar({required this.expandedHeight, required this.filter});
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    var searchBarOffset = expandedHeight - shrinkOffset - 20;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          child: Image.network(
            'assets/mainBackImage.jpg',
            fit: BoxFit.cover,
          ),
        ),
        (shrinkOffset < expandedHeight - 20)
            ? Positioned(
                top: searchBarOffset,
                left: MediaQuery.of(context).size.width / 4,
                child: Card(
                  elevation: 10,
                  child: SizedBox(
                    height: 40,
                    width: MediaQuery.of(context).size.width / 2,
                    child: CupertinoTextField(
                      controller: filter,
                      keyboardType: TextInputType.text,
                      placeholder: 'Search',
                      placeholderStyle: TextStyle(
                        color: Color(0xffC4C6CC),
                        fontSize: 14.0,
                        fontFamily: 'Brutal',
                      ),
                      prefix: Padding(
                        padding: const EdgeInsets.fromLTRB(5.0, 5.0, 0.0, 5.0),
                        child: Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                margin: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width / 4,
                    vertical: (kToolbarHeight - 40) / 4),
                child: Card(
                  elevation: 10,
                  child: CupertinoTextField(
                    controller: filter,
                    keyboardType: TextInputType.text,
                    placeholder: 'Search',
                    placeholderStyle: TextStyle(
                      color: Color(0xffC4C6CC),
                      fontSize: 14.0,
                      fontFamily: 'Brutal',
                    ),
                    prefix: Padding(
                      padding: const EdgeInsets.fromLTRB(5.0, 5.0, 0.0, 5.0),
                      child: Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => kToolbarHeight;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}
