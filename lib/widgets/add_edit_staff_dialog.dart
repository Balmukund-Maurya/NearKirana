import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../staff_audit_models.dart';
import '../staff_audit_service.dart';

/// Modal dialog to create or edit a staff member account with roles and granular permissions.
class AddEditStaffDialog extends StatefulWidget {
  final String shopId;
  final StaffMember? existingStaff;
  final StaffAuditService service;

  const AddEditStaffDialog({
    super.key,
    required this.shopId,
    this.existingStaff,
    required this.service,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String shopId,
    StaffMember? existingStaff,
    StaffAuditService? service,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditStaffDialog(
        shopId: shopId,
        existingStaff: existingStaff,
        service: service ?? StaffAuditService(),
      ),
    );
  }

  @override
  State<AddEditStaffDialog> createState() => _AddEditStaffDialogState();
}

class _AddEditStaffDialogState extends State<AddEditStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _pinController;

  late StaffRole _selectedRole;
  late Set<StaffPermission> _selectedPermissions;
  bool _isSaving = false;

  bool get isEditing => widget.existingStaff != null;

  @override
  void initState() {
    super.initState();
    final staff = widget.existingStaff;
    _nameController = TextEditingController(text: staff?.name ?? '');
    _phoneController = TextEditingController(text: staff?.phone ?? '');
    _pinController = TextEditingController(text: staff?.pin ?? '1234');
    _selectedRole = staff?.role ?? StaffRole.cashier;
    _selectedPermissions = staff != null
        ? Set<StaffPermission>.from(staff.permissions)
        : StaffMember.defaultPermissionsForRole(StaffRole.cashier);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onRoleChanged(StaffRole newRole) {
    setState(() {
      _selectedRole = newRole;
      if (newRole != StaffRole.custom) {
        _selectedPermissions = StaffMember.defaultPermissionsForRole(newRole);
      }
    });
  }

  void _togglePermission(StaffPermission perm, bool? enabled) {
    setState(() {
      if (enabled == true) {
        _selectedPermissions.add(perm);
      } else {
        _selectedPermissions.remove(perm);
      }
      _selectedRole = StaffRole.custom;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one permission for this staff member.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (isEditing) {
        await widget.service.updateStaff(
          staffId: widget.existingStaff!.id,
          shopId: widget.shopId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          permissions: _selectedPermissions,
          pin: _pinController.text.trim(),
        );
      } else {
        await widget.service.createStaff(
          shopId: widget.shopId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          permissions: _selectedPermissions,
          pin: _pinController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Staff account updated successfully!' : 'Staff account created successfully!',
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.badge_rounded, color: AppColors.primaryDark, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEditing ? 'Edit Staff Account\n(कर्मचारी विवरण बदलें)' : 'Add Staff Account\n(नया कर्मचारी जोड़ें)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Staff Name
                        const Text(
                          'Staff Full Name (नाम) *',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Ramesh Kumar',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter staff name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Phone and PIN row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mobile Number
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mobile Number (फ़ोन) *',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '10-digit number',
                                      prefixText: '+91 ',
                                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().length != 10) {
                                        return '10 digits required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 4-Digit Quick PIN
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Action PIN (पिन) *',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _pinController,
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '4-digit PIN',
                                      prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().length != 4) {
                                        return '4 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Role Selector
                        const Text(
                          'Designated Role (पद / भूमिका) *',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: StaffRole.values.map((role) {
                            final isSelected = _selectedRole == role;
                            return ChoiceChip(
                              label: Text(
                                role.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primaryDark,
                              backgroundColor: AppColors.surface,
                              onSelected: (_) => _onRoleChanged(role),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Permissions Checklist
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Permissions (अधिकार एवं अनुमतियां) *',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedPermissions.length} selected',
                              style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: StaffPermission.values.map((perm) {
                              final isChecked = _selectedPermissions.contains(perm);
                              return CheckboxListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                value: isChecked,
                                activeColor: AppColors.primaryDark,
                                title: Text(
                                  perm.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                onChanged: (val) => _togglePermission(perm, val),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEditing ? 'Save Changes (अपडेट करें)' : 'Create Staff Account (खाता बनाएं)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
