import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ganti Firebase
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class AddMenuPage extends StatefulWidget {
  const AddMenuPage({super.key});

  @override
  State<AddMenuPage> createState() => _AddMenuPageState();
}

class _AddMenuPageState extends State<AddMenuPage> {
  final supabase = Supabase.instance.client;
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _newToppingController = TextEditingController();

  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;

  String _selectedCategory = "Nasi";

  // Data ini bisa kamu kembangkan untuk masuk ke tabel product_option_values nantinya
  List<Map<String, dynamic>> toppingList = [
    {"name": "Keju", "isSelected": false},
    {"name": "Telur", "isSelected": false},
    {"name": "Susu", "isSelected": false},
    {"name": "Extra Pedas", "isSelected": false},
  ];

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _addNewTopping() {
    if (_newToppingController.text.isNotEmpty) {
      setState(() {
        toppingList.add({
          "name": _newToppingController.text.trim(),
          "isSelected": true,
        });
        _newToppingController.clear();
      });
    }
  }


  // LOGIKA SIMPAN KE SUPABASE
  void _saveToDatabase() async {
    if (_imageFile == null) {
      _showSnackBar("Silahkan pilih gambar terlebih dahulu");
      return;
    }

    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackBar("Nama dan Harga tidak boleh kosong");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload ke Cloudinary (Tetap dipertahankan sesuai kodingan awalmu)
      final cloudinary = CloudinaryPublic('dk1k6g6re', 'images', cache: false);
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_imageFile!.path, resourceType: CloudinaryResourceType.Image),
      );
      String imageUrl = response.secureUrl;

      // 2. Ambil Store ID dari user yang sedang login
      final user = supabase.auth.currentUser;
      final profile = await supabase.from('profiles').select('store_id').eq('id', user!.id).single();
      final String storeId = profile['store_id'];

      // 3. Ambil Category ID berdasarkan nama kategori yang dipilih
      // (Asumsi nama kategori unik per toko)
      final category = await supabase
          .from('categories')
          .select('id')
          .eq('store_id', storeId)
          .eq('name', _selectedCategory)
          .limit(1)
          .maybeSingle();

      // 4. Simpan ke tabel Products
      await supabase.from('products').insert({
        'store_id': storeId,
        'category_id': category != null ? category['id'] : null,
        'name': _nameController.text.trim(),
        'sale_price': double.parse(_priceController.text),
        'stock_quantity': int.parse(_stockController.text),
        'image_url': imageUrl,
        // Kolom 'toppings' di SQL kamu tidak ada, jika ingin disimpan, 
        // gunakan kolom khusus atau simpan ke tabel product_options.
        // Untuk sementara kita abaikan atau kamu bisa tambahkan kolom jsonb di tabel products.
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Menu Berhasil Disimpan", isError: false);
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI tetap sama dengan desain kamu yang sudah bagus
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Menu"),
        backgroundColor: const Color(0xFF001D3D),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 25),
                  _buildTextField(_nameController, "Nama Menu", Icons.fastfood_outlined),
                  const SizedBox(height: 16),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_priceController, "Harga", null, isNumber: true, prefix: "Rp ")),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_stockController, "Stok", null, isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildToppingSection(),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --- WIDGET HELPERS ---
  
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: _imageFile != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, fit: BoxFit.cover))
            : const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData? icon, {bool isNumber = false, String? prefix}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, prefixText: prefix,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: "Kategori", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      items: ["Makanan", "Minuman", "Cemilan"].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  Widget _buildToppingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Kelola Pilihan / Topping:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTextField(_newToppingController, "Tambah pilihan...", null)),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _addNewTopping, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Icon(Icons.add, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 15),
        // List Topping UI... (sama seperti kode lama kamu)
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        onPressed: _saveToDatabase,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text("SIMPAN KE DATABASE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}