import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../model/user_model.dart';
import '../services/user_service.dart';
import '../utils/validators.dart';
import 'login_screen.dart';
import 'api_products_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;

  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _modoEdicao = false;
  bool _salvando = false;
  UserModel? _usuarioLocal;

  final telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {
      '#': RegExp(r'[0-9]'),
    },
  );

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuario() async {
    UserModel? usuario;

    try {
      usuario = await _userService.getCurrentUserProfile();
    } catch (error) {
      debugPrint('Não foi possível carregar o perfil: $error');
      usuario = null;
    }

    final usuarioExibido = usuario ?? UserModel(
      name: 'Cliente Meu Mercado',
      phone: '(17) 99999-9999',
      email: _auth.currentUser?.email ?? 'cliente@meumercado.com',
    );

    if (!mounted) return;

    setState(() {
      _usuarioLocal = usuarioExibido;
      _preencherCampos(usuarioExibido);
    });
  }

  void _preencherCampos(UserModel usuario) {
    _nomeController.text = usuario.name;
    _telefoneController.text = usuario.phone;
    _emailController.text = usuario.email;
    _senhaController.clear();
  }

  void _alternarEdicao() {
    setState(() {
      _modoEdicao = !_modoEdicao;
      _senhaController.clear();

      if (!_modoEdicao && _usuarioLocal != null) {
        _preencherCampos(_usuarioLocal!);
      }
    });
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
    });

    try {
      if (_auth.currentUser != null) {
        await _userService.updateUserProfile(
          phone: _telefoneController.text,
        );

        if (_senhaController.text.isNotEmpty) {
          await _userService.updatePassword(_senhaController.text);
        }
      }

      final usuarioAtualizado = UserModel(
        id: _usuarioLocal?.id,
        name: _nomeController.text,
        phone: _telefoneController.text,
        email: _emailController.text,
      );

      if (!mounted) return;

      setState(() {
        _usuarioLocal = usuarioAtualizado;
        _modoEdicao = false;
        _senhaController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar o perfil: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Future<void> _sairDaConta() async {
    try {
      await _userService.signOut();
    } catch (error) {
      debugPrint('Não foi possível sair da conta: $error');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarioLocal == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.green,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _nomeController.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Dados do usuário',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _modoEdicao ? 'Cancelar' : 'Editar',
                          onPressed: _salvando ? null : _alternarEdicao,
                          icon: Icon(
                            _modoEdicao
                                ? Icons.close
                                : Icons.edit_outlined,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nomeController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefoneController,
                      enabled: _modoEdicao && !_salvando,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [telefoneMask],
                      validator: Validators.validarTelefone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      enabled: _modoEdicao && !_salvando,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: (value) {
                        if (!_modoEdicao || value == null || value.isEmpty) {
                          return null;
                        }

                        return Validators.validarSenha(value);
                      },
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        hintText: _modoEdicao
                            ? 'Mínimo de 6 caracteres'
                            : 'Disponível no modo edição',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_modoEdicao) ...[
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _salvando ? null : _salvarAlteracoes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _salvando ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_sync_outlined, color: Colors.green),
                  ),
                  title: const Text('CRUD API REST + Poof BG', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Catálogo online e remoção de fundo por IA'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApiProductsScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _salvando ? null : _sairDaConta,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'SAIR DA CONTA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
