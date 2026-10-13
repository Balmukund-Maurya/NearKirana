import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'app_theme.dart';
import 'user_provider.dart';
import 'saved_address_model.dart';
import 'map_selection_screen.dart';

/// Modal bottom sheet for browsing, selecting, and managing multiple saved delivery addresses.
/// Displays real-time store serviceability badges for checkout decisions.
class AddressSelectionBottomSheet extends StatelessWidget {
  final bool isCheckoutMode;

  const AddressSelectionBottomSheet({
    super.key,
    this.isCheckoutMode = false,
  });

  /// Static helper to display the sheet easily
  static Future<SavedAddress?> show(
    BuildContext context, {
    bool isCheckoutMode = false,
  }) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return showModalBottomSheet<SavedAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider<UserProvider>.value(
        value: userProvider,
        child: AddressSelectionBottomSheet(
          isCheckoutMode: isCheckoutMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final addresses = userProvider.savedAddressesList;
    final active = userProvider.activeAddress;

    final double? storeLat = userProvider.storeLat;
    final double? storeLng = userProvider.storeLng;
    final double radiusKm = userProvider.deliveryRadiusKm ?? 5.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title & Add Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Addresses',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      isCheckoutMode
                          ? 'Select address for this order'
                          : 'Manage your saved delivery places',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openAddEditAddressSheet(context, userProvider),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add New'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          // Address List or Empty State
          Flexible(
            child: addresses.isEmpty
                ? _buildEmptyState(context, userProvider)
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    shrinkWrap: true,
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      final bool isSelected = active?.id == address.id;

                      // Evaluate serviceability against current store
                      final serviceability = userProvider.evaluateAddressServiceability(
                        address,
                        storeLat: storeLat,
                        storeLng: storeLng,
                        maxRadiusKm: radiusKm,
                      );

                      return _AddressCard(
                        address: address,
                        isSelected: isSelected,
                        serviceability: serviceability,
                        isCheckoutMode: isCheckoutMode,
                        onSelect: () async {
                          HapticFeedback.lightImpact();
                          await userProvider.selectAddressForCheckout(address);
                          if (context.mounted) {
                            Navigator.pop(context, address);
                          }
                        },
                        onSetDefault: () async {
                          HapticFeedback.lightImpact();
                          await userProvider.setDefaultAddress(address.id);
                        },
                        onEdit: () {
                          _openAddEditAddressSheet(
                            context,
                            userProvider,
                            existingAddress: address,
                          );
                        },
                        onDelete: () => _confirmDelete(context, userProvider, address),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, UserProvider userProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              size: 48,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Addresses Found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Save your Home, Office, or Other delivery locations for faster checkout.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _openAddEditAddressSheet(context, userProvider),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add Delivery Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddEditAddressSheet(
    BuildContext context,
    UserProvider userProvider, {
    SavedAddress? existingAddress,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditAddressSheet(
        existingAddress: existingAddress,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    UserProvider userProvider,
    SavedAddress address,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${address.label} Address?'),
        content: Text(
          'Are you sure you want to delete "${address.formattedAddress}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await userProvider.deleteAddressById(address.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Address list item card displaying badges, coordinates serviceability, and actions
class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final bool isSelected;
  final AddressServiceabilityResult serviceability;
  final bool isCheckoutMode;
  final VoidCallback onSelect;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.serviceability,
    required this.isCheckoutMode,
    required this.onSelect,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.primaryDark
        : (serviceability.isOutOfDeliveryRadius && isCheckoutMode
            ? Colors.orange.shade300
            : Colors.grey.shade200);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryDark.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Label Badge, Default Chip, Radio
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: address.labelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(address.icon, size: 15, color: address.labelColor),
                      const SizedBox(width: 6),
                      Text(
                        address.label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: address.labelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                const Spacer(),
                if (isCheckoutMode)
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.primaryDark : Colors.grey,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Formatted address details
            Text(
              address.formattedAddress,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),

            // Serviceability badge if in checkout mode
            if (isCheckoutMode) ...[
              const SizedBox(height: 10),
              if (serviceability.isServiceable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Text(
                        serviceability.distanceKm > 0
                            ? 'Serviceable (${serviceability.distanceKm} km away)'
                            : 'Serviceable for delivery',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 5),
                      Text(
                        'Outside delivery radius (${serviceability.distanceKm} km > ${serviceability.maxRadiusKm} km)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    child: Text(
                      'Set as Default',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMid,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet form for adding or editing a saved address
class AddEditAddressSheet extends StatefulWidget {
  final SavedAddress? existingAddress;

  const AddEditAddressSheet({
    super.key,
    this.existingAddress,
  });

  @override
  State<AddEditAddressSheet> createState() => _AddEditAddressSheetState();
}

class _AddEditAddressSheetState extends State<AddEditAddressSheet> {
  late String _selectedLabel;
  late TextEditingController _houseNoCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _landmarkCtrl;
  double? _lat;
  double? _lng;
  bool _isDefault = false;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.existingAddress;
    _selectedLabel = addr?.label ?? 'Home';
    _houseNoCtrl = TextEditingController(text: addr?.houseNo ?? '');
    _addressCtrl = TextEditingController(text: addr?.address ?? '');
    _landmarkCtrl = TextEditingController(text: addr?.landmark ?? '');
    _lat = addr?.lat;
    _lng = addr?.lng;
    _isDefault = addr?.isDefault ?? false;
  }

  @override
  void dispose() {
    _houseNoCtrl.dispose();
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentGps() async {
    setState(() => _isLoadingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / Location services.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      _lat = position.latitude;
      _lng = position.longitude;

      // Reverse geocode to prefill locality
      try {
        final placemarks = await placemarkFromCoordinates(_lat!, _lng!);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final locality = '${p.subLocality ?? ''} ${p.locality ?? ''}'.trim();
          if (_addressCtrl.text.isEmpty && locality.isNotEmpty) {
            _addressCtrl.text = locality;
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('GPS coordinates captured successfully.'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _pickOnMap() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final initialLat = _lat ?? userProvider.currentLat ?? userProvider.storeLat ?? 0.0;
    final initialLng = _lng ?? userProvider.currentLng ?? userProvider.storeLng ?? 0.0;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectionScreen(
          initialLat: initialLat,
          initialLng: initialLng,
          isPickingOnly: true,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });

      try {
        final placemarks = await placemarkFromCoordinates(_lat!, _lng!);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final locality = '${p.subLocality ?? ''} ${p.locality ?? ''}'.trim();
          if (locality.isNotEmpty) {
            _addressCtrl.text = locality;
          }
        }
      } catch (_) {}
    }
  }

  void _save(UserProvider userProvider) async {
    final addressText = _addressCtrl.text.trim();
    if (addressText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter street or locality address.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newAddr = SavedAddress(
      id: widget.existingAddress?.id,
      label: _selectedLabel,
      address: addressText,
      houseNo: _houseNoCtrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      lat: _lat,
      lng: _lng,
      isDefault: _isDefault,
    );

    await userProvider.saveAddressModel(newAddr, makeDefault: _isDefault);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Address saved as $_selectedLabel.'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingAddress == null
                      ? 'Add New Address'
                      : 'Edit $_selectedLabel Address',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Label Selector Chips (Home, Office, Other)
            Text(
              'Address Label',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Home', 'Office', 'Other'].map((label) {
                final isSelected = _selectedLabel == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: AppColors.primaryDark.withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primaryDark : AppColors.textDark,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedLabel = label);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // House / Flat No Field
            TextField(
              controller: _houseNoCtrl,
              decoration: InputDecoration(
                labelText: 'House / Flat / Floor No.',
                hintText: 'e.g. Flat 302, Green Heights',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Address / Street Field
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: 'Street, Area or Locality *',
                hintText: 'e.g. Assi Ghat Road, Nagwa',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Landmark Field
            TextField(
              controller: _landmarkCtrl,
              decoration: InputDecoration(
                labelText: 'Nearby Landmark (Optional)',
                hintText: 'e.g. Opposite Shiv Temple',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Map and GPS coordinates buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingGps ? null : _fetchCurrentGps,
                    icon: _isLoadingGps
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Use GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text('Pick on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_lat != null && _lng != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'GPS pinned: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade800),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            // Default Address Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (val) => setState(() => _isDefault = val ?? false),
              title: Text(
                'Set as default delivery address',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _save(userProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Save Address',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
