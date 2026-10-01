class Validators {
  static String? validarNome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu nome';
    }

    if (value.trim().length < 3) {
      return 'O nome deve ter pelo menos 3 caracteres';
    }

    return null;
  }

  static String? validarTelefone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe seu telefone';
    }

    final numeros = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length != 11) {
      return 'Informe um telefone válido';
    }

    return null;
  }

  static String? validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu e-mail';
    }

    final regex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );

    if (!regex.hasMatch(value.trim())) {
      return 'Informe um e-mail válido';
    }

    return null;
  }

  static String? validarSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha';
    }

    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }

    return null;
  }
}