import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';

class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  ConsumerState<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<LocationResult> _searchResults = [];
  bool _isLoading = false;
  bool _isLocatingGPS = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await ref.read(locationServiceProvider).searchAutocomplete(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _selectLocation(LocationResult location) async {
    await ref.read(activeBrowsingLocationProvider.notifier).changeLocation(location);
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _useGPSLocation() async {
    setState(() {
      _isLocatingGPS = true;
    });

    final success = await ref.read(activeBrowsingLocationProvider.notifier).locateAndSetGPS();
    
    if (mounted) {
      setState(() {
        _isLocatingGPS = false;
      });
      if (success) {
        context.pop();
      } else {
        final stateValue = ref.read(activeBrowsingLocationProvider);
        final errorMessage = stateValue.error?.toString() ?? 'Failed to get GPS location. Please check permissions.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentLocationsAsync = ref.watch(recentLocationsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? AppColors.textSecondary : AppColors.textHint;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Location',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search city, town, or area...',
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: hintColor),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // GPS and Results section
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use Current Location Button
                  ListTile(
                    onTap: _isLocatingGPS ? null : _useGPSLocation,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: _isLocatingGPS
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      'Use Current GPS Location',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    subtitle: const Text('Uses device GPS to find nearby shops'),
                    trailing: Icon(Icons.chevron_right, color: hintColor),
                  ),
                  const Divider(),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.location_off, size: 48, color: hintColor),
                            const SizedBox(height: 12),
                            Text(
                              'No locations found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hintColor),
                            ),
                            const SizedBox(height: 4),
                            const Text('Try searching for another town or check spelling', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else if (_searchResults.isNotEmpty) ...[
                    // Search Results
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 8.0),
                      child: Text(
                        'Search Results',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hintColor),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final location = _searchResults[index];
                        return ListTile(
                          onTap: () => _selectLocation(location),
                          leading: Icon(Icons.location_on_outlined, color: hintColor),
                          title: Text(
                            location.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            location.formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // Recent Locations
                    recentLocationsAsync.when(
                      data: (recents) {
                        if (recents.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                              child: Text(
                                'Recent Locations',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hintColor),
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recents.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final location = recents[index];
                                return ListTile(
                                  onTap: () => _selectLocation(location),
                                  leading: Icon(Icons.history, color: hintColor),
                                  title: Text(
                                    location.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    location.formattedAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
