// lib/screens/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tdb_closet/product_details.dart';
import 'package:tdb_closet/utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // My Account editing state
  Map<String, dynamic> _editedData = {};
  bool _isEditing = false;

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      _user = user;
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _userData = userDoc.data()!;
        _editedData = Map<String, dynamic>.from(_userData!);
        _firstNameController.text = _userData?['firstName'] ?? '';
        _lastNameController.text = _userData?['lastName'] ?? '';
        _emailController.text = _userData?['email'] ?? user.email ?? '';
        _phoneController.text = _userData?['phone'] ?? '';
        _addressController.text = _userData?['savedAddress'] ?? '';
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;

    // Validation
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('First name is required')));
      return;
    }
    if (_emailController.text.trim().isEmpty ||
        !RegExp(
          r'^[^@]+@[^@]+\.[^@]+',
        ).hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    setState(() {
      _isEditing = false;
    });

    try {
      final updateData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'savedAddress': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(_user!.uid).update(updateData);

      _userData = updateData;
      _editedData = Map<String, dynamic>.from(_userData!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Save profile error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
      setState(() {
        _isEditing = true;
      });
    }
  }

  void _cancelEdit() {
    if (_userData != null) {
      _firstNameController.text = _userData?['firstName'] ?? '';
      _lastNameController.text = _userData?['lastName'] ?? '';
      _emailController.text = _userData?['email'] ?? _user?.email ?? '';
      _phoneController.text = _userData?['phone'] ?? '';
      _addressController.text = _userData?['savedAddress'] ?? '';
      _editedData = Map<String, dynamic>.from(_userData!);
    }
    setState(() {
      _isEditing = false;
    });
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _removeFromWishlist(String productId) async {
    if (_user == null) return;
    try {
      await _firestore
          .collection('wishlist')
          .doc(_user!.uid)
          .collection('items')
          .doc(productId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from wishlist'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Wishlist remove error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove item')));
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Yes, Log Out',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: DhemiColors.white,
        appBar: AppBar(backgroundColor: DhemiColors.royalPurple),
        body: Center(
          child: CircularProgressIndicator(color: DhemiColors.royalPurple),
        ),
      );
    }

    final displayName = _userData?['firstName'] ?? _user?.displayName ?? 'User';
    final email = _userData?['email'] ?? _user?.email ?? '';
    final memberSince =
        _user?.metadata.creationTime?.year ?? DateTime.now().year;

    return Scaffold(
      backgroundColor: DhemiColors.white,
      appBar: AppBar(
        title: Text("Profile", style: DhemiText.bodyLarge),
        backgroundColor: DhemiColors.white,
        centerTitle: true,
        foregroundColor: DhemiColors.royalPurple,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              10.h,
              // Profile Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: DhemiColors.royalPurple.withOpacity(.15),
                    child: const Icon(
                      Icons.person,
                      color: DhemiColors.royalPurple,
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: DhemiText.bodyLarge.copyWith(
                            color: DhemiColors.black,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "Member since $memberSince",
                          style: DhemiText.bodySmall.copyWith(
                            color: DhemiColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isEditing ? Icons.close : Icons.edit,
                      color: DhemiColors.royalPurple,
                    ),
                    onPressed: _isEditing ? _cancelEdit : _toggleEditMode,
                  ),
                ],
              ),
              20.h,

              // My Account Section
              _buildMyAccountSection(),

              20.h,

              // Order History
              Text(
                'Order History',
                style: DhemiText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              12.h,
              _buildOrderHistory(),

              20.h,

              // Wishlist
              Text(
                'Wishlist',
                style: DhemiText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              12.h,
              _buildWishlist(),

              20.h,

              // Logout
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text(
                  "Logout",
                  style: DhemiText.bodyMedium.copyWith(color: Colors.red),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showLogoutDialog,
              ),

              30.h,

              // Newsletter
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DhemiColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "Subscribe to our newsletter",
                      style: DhemiText.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    10.h,
                    Text(
                      "Get updates on new arrivals, sales and exclusive offers",
                      style: DhemiText.bodySmall.copyWith(
                        color: DhemiColors.gray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    20.h,
                    DhemiWidgets.button(
                      label: "Subscribe Now",
                      onPressed: () {},
                      fontSize: 16,
                      horizontalPadding: 32,
                      verticalPadding: 16,
                      minHeight: 48,
                    ),
                  ],
                ),
              ),
              30.h,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyAccountSection() {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DhemiColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DhemiColors.gray300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Account',
              style: DhemiText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            16.h,
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
            ),
            12.h,
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
            ),
            12.h,
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            12.h,
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Phone'),
            ),
            12.h,
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Saved Address',
                hintText: 'Optional',
              ),
            ),
            20.h,
            Row(
              children: [
                Expanded(
                  child: DhemiWidgets.button(
                    label: 'Cancel',
                    onPressed: _cancelEdit,
                    minHeight: 48,
                  ),
                ),
                8.w,
                Expanded(
                  child: DhemiWidgets.button(
                    label: 'Save Changes',
                    onPressed: _saveProfile,
                    minHeight: 48,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return ListTile(
        leading: const Icon(Icons.person, color: DhemiColors.royalPurple),
        title: Text('My Account', style: DhemiText.bodyMedium),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _toggleEditMode,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_userData?['firstName'] ?? _userData?['lastName']) != null)
              Text(
                '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}'
                    .trim(),
              ),
            if ((_userData?['email'] as String?)?.isNotEmpty == true)
              Text(_userData?['email']),
            if ((_userData?['phone'] as String?)?.isNotEmpty == true)
              Text(_userData?['phone']),
          ].where((e) => e != null).toList(),
        ),
      );
    }
  }

  // ✅ FIXED: Safe number handling in Order History
  Widget _buildOrderHistory() {
    if (_user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('userId', isEqualTo: _user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: DhemiColors.royalPurple),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: DhemiText.bodySmall.copyWith(color: Colors.red),
          );
        }

        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'No orders yet',
              style: DhemiText.body.copyWith(color: DhemiColors.gray600),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;
            final orderId = data['orderId'] as String? ?? '—';

            // 🔧 FIXED: Convert Firestore double → int safely
            final total = (data['total'] as num?)?.toInt() ?? 0;

            final status = data['orderStatus'] as String? ?? 'unknown';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            String statusText = status;
            Color statusColor = DhemiColors.gray600;
            if (status == 'confirmed') {
              statusText = 'Confirmed';
              statusColor = Colors.green;
            } else if (status == 'shipped') {
              statusText = 'Shipped';
              statusColor = DhemiColors.royalPurple;
            } else if (status == 'delivered') {
              statusText = 'Delivered';
              statusColor = Colors.green;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                onTap: () => _showOrderDetails(data),
                title: Text(
                  'Order #$orderId',
                  style: DhemiText.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    4.h,
                    Text(
                      '${(data['items'] as List?)?.length ?? 0} item${(data['items'] as List?)?.length == 1 ? '' : 's'} • ₦$total',
                      style: DhemiText.bodySmall.copyWith(
                        color: DhemiColors.gray700,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        'Placed on ${DhemiUtils.formatDate(createdAt)}',
                        style: DhemiText.bodySmall.copyWith(
                          color: DhemiColors.gray600,
                        ),
                      ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: DhemiText.bodySmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DhemiColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final items = (order['items'] as List?) ?? [];
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: DhemiColors.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                20.h,
                Text(
                  'Order Details',
                  style: DhemiText.headlineSmall.copyWith(fontSize: 22),
                ),
                20.h,
                _buildDetailRow('Order ID', order['orderId'] ?? '—'),
                _buildDetailRow('Status', order['orderStatus'] ?? '—'),
                _buildDetailRow(
                  'Date',
                  DhemiUtils.formatDate(
                    (order['createdAt'] as Timestamp?)?.toDate(),
                  ),
                ),

                // 🔧 FIXED: Safe total conversion
                _buildDetailRow(
                  'Total',
                  '₦${(order['total'] as num?)?.toInt() ?? 0}',
                ),

                _buildDetailRow(
                  'Delivery',
                  order['deliveryOption'] == 'delivery'
                      ? 'Home Delivery'
                      : 'Pickup',
                ),
                _buildDetailRow('Address', order['deliveryAddress'] ?? '—'),
                20.h,
                Text(
                  'Items (${items.length})',
                  style: DhemiText.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                12.h,

                // 🔧 FIXED: Safe item price & quantity
                ...items.map((item) {
                  final name = item['name'] as String? ?? '—';
                  final price = (item['price'] as num?)?.toInt() ?? 0;
                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                  final size = item['size'] as String?;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: DhemiText.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (size != null)
                                Text('Size: $size', style: DhemiText.bodySmall),
                              Text(
                                '₦$price × $qty',
                                style: DhemiText.bodySmall.copyWith(
                                  color: DhemiColors.gray700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text('₦${price * qty}', style: DhemiText.bodyMedium),
                      ],
                    ),
                  );
                }),
                30.h,
                Center(
                  child: DhemiWidgets.button(
                    label: 'Close',
                    onPressed: Navigator.of(context).pop,
                    fontSize: 16,
                    horizontalPadding: 48,
                    minHeight: 48,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: DhemiText.bodySmall.copyWith(color: DhemiColors.gray600),
          ),
          8.w,
          Expanded(
            child: Text(
              value,
              style: DhemiText.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Safe number handling in Wishlist
  Widget _buildWishlist() {
    if (_user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('wishlist')
          .doc(_user!.uid)
          .collection('items')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: DhemiColors.royalPurple),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: DhemiText.bodySmall.copyWith(color: Colors.red),
          );
        }

        final items = snapshot.data?.docs ?? [];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 60,
                  color: DhemiColors.gray400,
                ),
                12.h,
                Text(
                  'Your wishlist is empty',
                  style: DhemiText.body.copyWith(color: DhemiColors.gray600),
                ),
                8.h,
                Text(
                  'Add items you love for later!',
                  style: DhemiText.bodySmall.copyWith(
                    color: DhemiColors.gray500,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            final data = doc.data() as Map<String, dynamic>;
            final productId = doc.id;
            final name = data['name'] as String? ?? '—';

            // 🔧 FIXED: Safe price conversion
            final price = (data['price'] as num?)?.toInt() ?? 0;

            final image = data['image'] as String?;

            return Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (data.containsKey('productId') || image != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailsPage(product: data),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: DhemiColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DhemiColors.gray200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: image != null
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    image,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) =>
                                            progress == null
                                            ? child
                                            : const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                    errorBuilder: (context, error, stack) =>
                                        Container(
                                          color: DhemiColors.gray100,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: DhemiColors.gray400,
                                          ),
                                        ),
                                  ),
                                )
                              : const SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      color: DhemiColors.gray400,
                                    ),
                                  ),
                                ),
                        ),
                        8.h,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DhemiText.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              4.h,
                              Text(
                                '₦$price',
                                style: DhemiText.bodyMedium.copyWith(
                                  color: DhemiColors.royalPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _removeFromWishlist(productId),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: DhemiColors.gray700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Keep your DhemiUtils helper (already correct)
class DhemiUtils {
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
