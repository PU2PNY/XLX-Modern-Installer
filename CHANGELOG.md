# Changelog / Histórico de mudanças

All notable project changes are recorded here before a public release.

Todas as mudanças relevantes do projeto são registradas aqui antes de uma versão pública.

## Unreleased / Não lançado

### Added / Adicionado

- controlled XLX installer wrapper for Debian 12;
- pre-flight `--check` validation;
- preventive backup and SHA-256 verification;
- protection against overwriting an active XLXD installation;
- separate modern-dashboard installation workflow;
- dashboard language selection at installation time: Portuguese, English, Spanish, French, German and Italian;
- install-time dashboard translation builder and translation catalogs;
- multilingual dashboard language/SEO metadata generation;
- bilingual Portuguese/English project documentation;
- dedicated installation, update/recovery, firewall, file/log and post-installation guides;
- real XLX Modern Dashboard screenshot in the documentation;
- MIT license for original repository portions and third-party notices;
- bilingual security, contribution and support documentation;
- read-only `scripts/health-check.sh` utility;
- verified `scripts/backup-production.sh` utility;
- GitHub Actions validation for Bash, PHP, translation catalogs, language builds and basic secret patterns.

### Changed / Alterado

- README structure expanded for installation, maintenance, recovery and search discoverability;
- credits now link directly to related upstream projects and external resources;
- dashboard installer accepts `--lang=pt-BR|en|es|fr|de|it`;
- top-level installer forwards the selected dashboard language;
- documentation now separates firewall, file locations and post-installation topics into focused guides.

### Safety / Segurança

- the full installer refuses to overwrite a detected active XLXD deployment;
- maintenance guidance follows diagnose → backup → minimal change → validate → rollback;
- documentation warns against publishing credentials, private keys, user databases and production backups;
- CI includes a basic sensitive-token/private-key pattern guard.

### Pending before public release / Pendente antes da publicação

- complete final sensitive-data audit;
- verify CI on the final commit;
- review repository About description, website and topics;
- run a final installation test on a clean Debian 12 staging VPS;
- run dashboard-only installation tests in at least Portuguese and English;
- select the first public semantic version/tag.
