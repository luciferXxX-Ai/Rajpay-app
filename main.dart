import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

void main() => runApp(const RajpayApp());

class Api {
  static String baseUrl = defaultApiUrl;
  static String? token;

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static dynamic decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final data = jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? (data['detail'] ?? 'Request failed') : 'Request failed';
      throw Exception(message);
    }
    return data;
  }

  static Future<dynamic> get(String path) async =>
      decode(await http.get(Uri.parse('$baseUrl$path'), headers: headers));

  static Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      decode(await http.post(Uri.parse('$baseUrl$path'),
          headers: headers, body: jsonEncode(body)));
}

class RajpayApp extends StatelessWidget {
  const RajpayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rajpay Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1457C5)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    Api.token = prefs.getString('token');
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Api.token == null ? const AuthPage() : const HomePage();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool register = false;
  bool busy = false;

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (register) {
        await Api.post('/auth/register', {
          'email': email.text.trim(),
          'full_name': name.text.trim(),
          'password': password.text,
        });
      }
      final result = await Api.post('/auth/login', {
        'email': email.text.trim(),
        'password': password.text,
      });
      Api.token = result['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', Api.token!);
      if (mounted) Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.account_balance_wallet, size: 72, color: Color(0xFF1457C5)),
              const SizedBox(height: 12),
              Text('Rajpay', textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(register ? 'Create your account' : 'Sign in to continue',
                textAlign: TextAlign.center),
              const SizedBox(height: 28),
              if (register) ...[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
              ],
              TextField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Password (minimum 8 characters)')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy ? const CircularProgressIndicator() : Text(register ? 'Create account' : 'Login'),
              ),
              TextButton(
                onPressed: busy ? null : () => setState(() => register = !register),
                child: Text(register ? 'Already registered? Login' : 'New user? Create account'),
              ),
              const SizedBox(height: 12),
              const Text('Demo client. Payments are simulated by the backend.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Api.token = null;
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const ProductsTab(), const OrdersTab(), ProfileTab(onLogout: logout)];
    return Scaffold(
      appBar: AppBar(title: const Text('Rajpay'), actions: [
        IconButton(onPressed: logout, icon: const Icon(Icons.logout), tooltip: 'Logout'),
      ]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  late Future<List<dynamic>> future;
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<dynamic>> load() async => List<dynamic>.from(await Api.get('/products'));
  Future<void> refresh() async => setState(() => future = load());

  Future<void> order(dynamic product) async {
    try {
      final order = await Api.post('/orders', {'product_id': product['id'], 'quantity': 1});
      final payment = await Api.post('/payments/${order['id']}/initiate', {});
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Order created'),
        content: Text('Order #${order['id']} created. Demo payment #${payment['id']} is ${payment['status']}. No real money was charged.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return ListView(children: [
          Padding(padding: const EdgeInsets.all(24), child: Text('Could not load products: ${snapshot.error}')),
          Center(child: TextButton(onPressed: refresh, child: const Text('Retry'))),
        ]);
        final items = snapshot.data ?? [];
        if (items.isEmpty) return ListView(children: const [
          SizedBox(height: 120), Center(child: Text('No products yet. Add products using the admin API.')),
        ]);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final p = items[i];
            return Card(child: ListTile(
              title: Text(p['name'] ?? 'Product'),
              subtitle: Text('${p['description'] ?? ''}\nStock: ${p['stock']}'),
              isThreeLine: true,
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('₹${((p['price_paise'] as num) / 100).toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                SizedBox(height: 30, child: FilledButton(
                  onPressed: (p['stock'] ?? 0) > 0 ? () => order(p) : null,
                  child: const Text('Buy'),
                )),
              ]),
            ));
          },
        );
      },
    ),
  );
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  late Future<List<dynamic>> future;
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<dynamic>> load() async => List<dynamic>.from(await Api.get('/orders'));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
      final orders = snapshot.data ?? [];
      if (orders.isEmpty) return const Center(child: Text('No orders yet'));
      return ListView.builder(
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final o = orders[i];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.receipt)),
            title: Text('Order #${o['id']}'),
            subtitle: Text('Qty: ${o['quantity']} • ${o['status']}'),
            trailing: Text('₹${((o['total_paise'] as num) / 100).toStringAsFixed(2)}'),
          );
        },
      );
    },
  );
}

class ProfileTab extends StatelessWidget {
  final VoidCallback onLogout;
  const ProfileTab({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Api.get('/me'),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Could not load profile: ${snapshot.error}'));
      final user = snapshot.data;
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 12),
          Text(user['full_name'] ?? '', style: Theme.of(context).textTheme.titleLarge),
          Text(user['email'] ?? ''),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Logout')),
        ]),
      ));
    },
  );
}
