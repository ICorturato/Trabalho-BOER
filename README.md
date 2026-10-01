# Meu Mercado (Trabalho BOER)

Aplicativo de e-commerce e supermercado desenvolvido em **Flutter & Dart**, com funcionalidade completa de **CRUD REST** e integração com a **API Poof** para remoção automática de fundo de imagens por inteligência artificial.

---

## 🚀 Funcionalidades Principais

### 1. CRUD Completo via API REST
Implementação das 4 operações fundamentais com requisições HTTP e serialização JSON:
* **Create (`POST`):** Cadastro de novos produtos com validação de campos obrigatórios e upload de imagens tratadas.
* **Read (`GET`):** Consulta e listagem de produtos com filtros em tempo real, busca textual e visualização de detalhes.
* **Update (`PUT`):** Edição e atualização de preços, custos, estoques, categorias e imagens.
* **Delete (`DELETE`):** Exclusão de itens com diálogo de confirmação.

### 2. Integração com API Poof (Remoção de Fundo por IA)
* Utilização da [API Poof](https://poof.bg) (`POST /v1/remove`) para remover automaticamente o fundo de fotos de produtos capturadas pela câmera ou galeria.
* Renderização com transparência alfa e padrão quadriculado (*checkerboard*) na interface.

### 3. Vendas e Checkout
* Catálogo unificado na tela inicial (*Home*).
* Carrinho de compras com cálculo dinâmico de subtotal, aplicação de cupons de desconto e controle de estoque.
* Finalização de pedidos (*Checkout*) com múltiplos métodos de pagamento (Pix, Cartão de Crédito/Débito, Dinheiro).

### 4. Persistência e Resiliência
* Armazenamento local persistente com `SharedPreferences` / `LocalStorage`.
* Backup e sincronização em nuvem via Cloud Firestore.
* Tratamento de erros de rede, timeouts e respostas HTTP.

---

## 🛠️ Tecnologias Utilizadas

* **Linguagem:** Dart (>= 3.4.0)
* **Framework:** Flutter 3.x (Material Design 3)
* **Comunicação HTTP:** `package:http`
* **Persistência Local:** `package:shared_preferences`
* **Processamento de Imagens:** `package:image` & `package:image_picker`
* **Autenticação e Nuvem:** `firebase_core`, `firebase_auth`, `cloud_firestore`

---

## 📁 Estrutura do Projeto

```
lib/
├── main.dart                      # Inicialização do aplicativo
├── model/                         # Modelos de dados
│   ├── api_product_model.dart     # Entidade do produto REST
│   ├── product_model.dart         # Modelo unificado de produto
│   ├── coupon_model.dart          # Modelo de cupom de desconto
│   └── user_model.dart            # Modelo de usuário
├── services/                      # Camada de serviços (Regra de Negócio e APIs)
│   ├── api_product_service.dart   # Service REST (GET, POST, PUT, DELETE)
│   ├── poof_bg_service.dart       # Service da API Poof (IA Background Remover)
│   ├── cart_service.dart          # Gerenciamento do carrinho de compras
│   ├── checkout_service.dart      # Processamento de pedidos
│   └── user_service.dart          # Gerenciamento de perfil e login
├── screens/                       # Telas do aplicativo
│   ├── home_screen.dart           # Catálogo principal unificado e menu
│   ├── api_products_screen.dart   # Tela de listagem do CRUD REST
│   ├── api_product_form_screen.dart # Formulário de cadastro/edição e IA Poof
│   ├── api_config_dialog.dart     # Configuração de endpoints e chaves de API
│   ├── checkout_screen.dart       # Tela de pagamento e finalização
│   ├── orders_screen.dart         # Histórico de pedidos
│   ├── profile_screen.dart        # Perfil do usuário e navegação
│   └── login_screen.dart          # Autenticação
├── utils/                         # Formatadores e validadores
│   ├── money_input_formatter.dart # Máscara monetária em Real (R$)
│   └── validators.dart            # Validação de formulários
└── widgets/                       # Componentes reutilizáveis
    └── checkerboard_background.dart # Fundo quadriculado para transparência
```

---

## 💻 Como Executar o Projeto

1. Instale as dependências:
```bash
flutter pub get
```

2. Execute o aplicativo (Web / Chrome):
```bash
flutter run -d chrome
```

3. Execute os testes unitários:
```bash
flutter test
```
