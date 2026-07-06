enum CategoryType { income, expense, transfer }

class DefaultCategory {
  final String id;
  final String name;
  final String icon;
  final String color;
  final CategoryType type;
  final String? description;

  const DefaultCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.description,
  });
}

class DefaultHoliday {
  final int month;
  final int day;
  final String name;

  const DefaultHoliday({
    required this.month,
    required this.day,
    required this.name,
  });
}

class SeedDataConstants {
  static const List<DefaultCategory> defaultCategories = [
    // Incomes
    DefaultCategory(
      id: 'cat_opening_balance',
      name: 'Saldo Inicial',
      icon: 'account_balance_wallet',
      color: '#9E9E9E',
      type: CategoryType.income,
      description:
          'Saldo inicial inserido ao criar uma conta ou ajustar saldo manual.',
    ),
    DefaultCategory(
      id: 'cat_salary',
      name: 'Salário',
      icon: 'money',
      color: '#4CAF50',
      type: CategoryType.income,
      description:
          'Receitas provenientes de salário recorrente, remuneração fixa ou pagamentos trabalhistas.',
    ),
    DefaultCategory(
      id: 'cat_freelance',
      name: 'Freelance',
      icon: 'work',
      color: '#8BC34A',
      type: CategoryType.income,
      description: 'Rendas extras, serviços autônomos ou projetos esporádicos.',
    ),
    DefaultCategory(
      id: 'cat_investments_yield',
      name: 'Rendimentos',
      icon: 'trending_up',
      color: '#009688',
      type: CategoryType.income,
      description:
          'Rendimentos de investimentos, dividendos, juros de poupança ou outras aplicações.',
    ),
    DefaultCategory(
      id: 'cat_thirteenth_salary',
      name: '13º Salário',
      icon: 'paid',
      color: '#66BB6A',
      type: CategoryType.income,
      description:
          'Décimo terceiro salário, bônus anual ou participação nos lucros (PLR).',
    ),
    DefaultCategory(
      id: 'cat_retirement_benefits',
      name: 'Aposentadoria e Benefícios',
      icon: 'elderly',
      color: '#26A69A',
      type: CategoryType.income,
      description:
          'Aposentadoria, pensão, auxílios do INSS ou outros benefícios sociais.',
    ),
    DefaultCategory(
      id: 'cat_gifts_received',
      name: 'Presentes Recebidos',
      icon: 'card_giftcard',
      color: '#4DB6AC',
      type: CategoryType.income,
      description: 'Presentes em dinheiro, doações recebidas ou heranças.',
    ),
    DefaultCategory(
      id: 'cat_sales',
      name: 'Vendas',
      icon: 'storefront',
      color: '#7CB342',
      type: CategoryType.income,
      description: 'Venda de itens usados, produtos ou serviços eventuais.',
    ),
    DefaultCategory(
      id: 'cat_other_income',
      name: 'Outras Receitas',
      icon: 'account_balance',
      color: '#43A047',
      type: CategoryType.income,
      description:
          'Receitas diversas que não se enquadram nas demais categorias.',
    ),
    // Expenses
    DefaultCategory(
      id: 'cat_housing',
      name: 'Moradia',
      icon: 'home',
      color: '#F44336',
      type: CategoryType.expense,
      description:
          'Despesas gerais relacionadas à moradia, condomínio, taxas, reformas ou utilidades.',
    ),
    DefaultCategory(
      id: 'cat_rent',
      name: 'Aluguel',
      icon: 'house',
      color: '#E53935',
      type: CategoryType.expense,
      description:
          'Pagamento mensal de aluguel ou financiamento imobiliário residencial.',
    ),
    DefaultCategory(
      id: 'cat_condo_fee',
      name: 'Condomínio',
      icon: 'apartment',
      color: '#D32F2F',
      type: CategoryType.expense,
      description: 'Taxa de condomínio mensal.',
    ),
    DefaultCategory(
      id: 'cat_electricity',
      name: 'Energia Elétrica',
      icon: 'bolt',
      color: '#EF5350',
      type: CategoryType.expense,
      description: 'Conta de luz.',
    ),
    DefaultCategory(
      id: 'cat_water_bill',
      name: 'Água',
      icon: 'water_drop',
      color: '#EF9A9A',
      type: CategoryType.expense,
      description: 'Conta de água e saneamento.',
    ),
    DefaultCategory(
      id: 'cat_internet_phone',
      name: 'Internet e Telefone',
      icon: 'wifi',
      color: '#FF7043',
      type: CategoryType.expense,
      description: 'Internet, telefonia fixa ou móvel.',
    ),
    DefaultCategory(
      id: 'cat_gas_bill',
      name: 'Gás',
      icon: 'heat_pump',
      color: '#FFAB91',
      type: CategoryType.expense,
      description: 'Conta de gás encanado ou botijão.',
    ),
    DefaultCategory(
      id: 'cat_food',
      name: 'Alimentação',
      icon: 'restaurant',
      color: '#FF9800',
      type: CategoryType.expense,
      description:
          'Gastos com supermercado, restaurantes, feiras, delivery ou lanches rápidos.',
    ),
    DefaultCategory(
      id: 'cat_transport',
      name: 'Transporte',
      icon: 'directions_car',
      color: '#2196F3',
      type: CategoryType.expense,
      description:
          'Gastos com combustível, transporte público, carros por aplicativo, pedágio ou manutenção de veículos.',
    ),
    DefaultCategory(
      id: 'cat_fuel',
      name: 'Combustível',
      icon: 'local_gas_station',
      color: '#1E88E5',
      type: CategoryType.expense,
      description: 'Gasolina, etanol, diesel ou recarga elétrica.',
    ),
    DefaultCategory(
      id: 'cat_parking_tolls',
      name: 'Estacionamento e Pedágio',
      icon: 'local_atm',
      color: '#42A5F5',
      type: CategoryType.expense,
      description: 'Estacionamento, pedágios e zona azul.',
    ),
    DefaultCategory(
      id: 'cat_vehicle_maintenance',
      name: 'Manutenção Veicular',
      icon: 'build',
      color: '#1565C0',
      type: CategoryType.expense,
      description: 'Revisões, reparos, seguro e IPVA do veículo.',
    ),
    DefaultCategory(
      id: 'cat_health',
      name: 'Saúde',
      icon: 'favorite',
      color: '#E91E63',
      type: CategoryType.expense,
      description:
          'Despesas com planos de saúde, farmácia, consultas médicas, dentistas ou exames.',
    ),
    DefaultCategory(
      id: 'cat_education',
      name: 'Educação',
      icon: 'school',
      color: '#9C27B0',
      type: CategoryType.expense,
      description:
          'Gastos com mensalidades escolares, faculdade, cursos, livros ou materiais educativos.',
    ),
    DefaultCategory(
      id: 'cat_leisure',
      name: 'Lazer',
      icon: 'movie',
      color: '#FFC107',
      type: CategoryType.expense,
      description:
          'Despesas com cinema, viagens, shows, festas, hobbies ou entretenimento em geral.',
    ),
    DefaultCategory(
      id: 'cat_clothing',
      name: 'Vestuário',
      icon: 'checkroom',
      color: '#795548',
      type: CategoryType.expense,
      description:
          'Gastos com roupas, sapatos, acessórios ou itens de vestuário.',
    ),
    DefaultCategory(
      id: 'cat_pets',
      name: 'Pets',
      icon: 'pets',
      color: '#6D4C41',
      type: CategoryType.expense,
      description:
          'Ração, veterinário, banho e tosa ou outros cuidados com animais de estimação.',
    ),
    DefaultCategory(
      id: 'cat_subscriptions',
      name: 'Assinaturas',
      icon: 'subscriptions',
      color: '#5E35B1',
      type: CategoryType.expense,
      description:
          'Streaming, aplicativos, revistas ou outros serviços por assinatura.',
    ),
    DefaultCategory(
      id: 'cat_shopping',
      name: 'Compras',
      icon: 'shopping_bag',
      color: '#8D6E63',
      type: CategoryType.expense,
      description:
          'Compras diversas, eletrônicos, itens para casa ou variados.',
    ),
    DefaultCategory(
      id: 'cat_personal_care',
      name: 'Cuidados Pessoais',
      icon: 'spa',
      color: '#EC407A',
      type: CategoryType.expense,
      description: 'Salão de beleza, barbearia, cosméticos e higiene pessoal.',
    ),
    DefaultCategory(
      id: 'cat_insurance',
      name: 'Seguros',
      icon: 'security',
      color: '#455A64',
      type: CategoryType.expense,
      description:
          'Seguro de vida, residencial ou outros seguros não veiculares.',
    ),
    DefaultCategory(
      id: 'cat_gifts_given',
      name: 'Presentes e Doações',
      icon: 'card_giftcard',
      color: '#AB47BC',
      type: CategoryType.expense,
      description:
          'Presentes oferecidos, doações e contribuições beneficentes.',
    ),
    DefaultCategory(
      id: 'cat_taxes_fees',
      name: 'Impostos e Taxas',
      icon: 'receipt_long',
      color: '#546E7A',
      type: CategoryType.expense,
      description:
          'IPTU, taxas governamentais, tarifas bancárias ou cartoriais.',
    ),
    DefaultCategory(
      id: 'cat_travel',
      name: 'Viagens',
      icon: 'flight',
      color: '#00ACC1',
      type: CategoryType.expense,
      description: 'Passagens, hospedagem e demais gastos com viagens.',
    ),
    DefaultCategory(
      id: 'cat_children',
      name: 'Filhos e Crianças',
      icon: 'child_care',
      color: '#F06292',
      type: CategoryType.expense,
      description:
          'Fraldas, brinquedos, escola infantil e demais gastos com filhos.',
    ),
    DefaultCategory(
      id: 'cat_other_expense',
      name: 'Outras Despesas',
      icon: 'category',
      color: '#757575',
      type: CategoryType.expense,
      description:
          'Despesas diversas que não se enquadram nas demais categorias.',
    ),
    // Transfers
    DefaultCategory(
      id: 'cat_transfer',
      name: 'Transferência',
      icon: 'swap_horiz',
      color: '#9E9E9E',
      type: CategoryType.transfer,
      description:
          'Movimentação de fundos entre contas próprias ou ajustes de transferência interna.',
    ),
  ];

  // (parentId, childId) pairs for the many-to-many junction table
  static const List<(String, String)> defaultCategoryRelationships = [
    ('cat_housing', 'cat_rent'),
    ('cat_housing', 'cat_condo_fee'),
    ('cat_housing', 'cat_electricity'),
    ('cat_housing', 'cat_water_bill'),
    ('cat_housing', 'cat_internet_phone'),
    ('cat_housing', 'cat_gas_bill'),
    ('cat_transport', 'cat_fuel'),
    ('cat_transport', 'cat_parking_tolls'),
    ('cat_transport', 'cat_vehicle_maintenance'),
  ];

  static const List<DefaultHoliday> nationalHolidays = [
    DefaultHoliday(month: 1, day: 1, name: 'Confraternização Universal'),
    DefaultHoliday(month: 4, day: 21, name: 'Tiradentes'),
    DefaultHoliday(month: 5, day: 1, name: 'Dia do Trabalhador'),
    DefaultHoliday(month: 9, day: 7, name: 'Independência do Brasil'),
    DefaultHoliday(month: 10, day: 12, name: 'Nossa Senhora Aparecida'),
    DefaultHoliday(month: 11, day: 2, name: 'Finados'),
    DefaultHoliday(month: 11, day: 15, name: 'Proclamação da República'),
    DefaultHoliday(month: 12, day: 25, name: 'Natal'),
  ];
}
