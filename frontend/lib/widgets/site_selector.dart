// lib/widgets/site_selector.dart
import 'package:flutter/material.dart';
import '../services/data_service.dart';

class SiteSelectorBottomSheet extends StatelessWidget {
  final int currentSiteIndex;
  final Function(int) onSiteSelected;
  final DataService dataService;

  const SiteSelectorBottomSheet({
    Key? key,
    required this.currentSiteIndex,
    required this.onSiteSelected,
    required this.dataService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Retail Site',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: dataService.retailSites.length,
              itemBuilder: (context, index) {
                final site = dataService.retailSites[index];
                return ListTile(
                  title: Text(site['name']!),
                  subtitle: Text(site['url']!, overflow: TextOverflow.ellipsis),
                  selected: index == currentSiteIndex,
                  onTap: () {
                    Navigator.pop(context);
                    onSiteSelected(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}