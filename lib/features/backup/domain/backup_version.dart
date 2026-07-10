/// Metadados de versão e compatibilidade que viajam com cada backup.
///
/// Dois números de versão independentes acompanham um backup e servem a
/// propósitos diferentes na hora de importar:
///
/// - [kBackupFormatVersion]: versão da *estrutura* do envelope de backup (as
///   chaves do JSON, como os dados estão organizados). Deve ser incrementado
///   quando o formato muda de uma forma que importadores antigos não conseguem
///   ler. Importadores rejeitam formatos mais novos que conhecem.
/// - `schema_version`: o `schemaVersion` do Drift com que os dados foram
///   produzidos. É o sinal de compatibilidade real dos *dados*: um backup de um
///   app mais novo (schema maior) contém colunas/tabelas que esta build ainda
///   não modela, então a restauração é rejeitada.
///
/// O backup SQLite não precisa de [kBackupFormatVersion] — o próprio arquivo
/// carrega o `schema_version` nativamente em `PRAGMA user_version`, lido do
/// cabeçalho do arquivo no momento do restore.
const int kBackupFormatVersion = 2;

/// Formato de backup JSON mais antigo que esta build ainda consegue importar.
///
/// Backups com `version` abaixo disto são rejeitados por serem antigos demais.
const int kMinSupportedBackupFormatVersion = 1;

/// Lançada quando um backup não pode ser importado com segurança porque foi
/// gerado por uma versão do BestFin incompatível com a atual.
///
/// Estende [FormatException] para que a UI de backup — que já exibe
/// `FormatException.message` ao usuário — mostre a causa sem tratamento extra.
class BackupIncompatibleException extends FormatException {
  const BackupIncompatibleException(super.message);
}
