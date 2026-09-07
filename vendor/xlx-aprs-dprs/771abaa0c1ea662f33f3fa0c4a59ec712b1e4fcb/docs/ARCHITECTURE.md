# Arquitetura

```text
Rádio / hotspot
      │
      │ D-STAR / DExtra / Slow Data
      ▼
   XLXD módulo B
      │
      │ cliente independente
      ▼
xlx-aprs-dprs.service
      │
      ├── SQLite de estado
      ├── snapshot público
      ├── socket local do operador
      │
      └── APRS-IS (opcional)
                │
                ▼
        rotate.aprs2.net
```

A interface web lê somente:

- o snapshot público pela API `digital-lab.php`;
- o banco local de contas e o socket Unix pela API autenticada `digital-lab-operator.php`.

O gateway não injeta código no processo XLXD e não depende de alterar o banco principal do refletor.

## Diretórios

```text
/opt/xlx-aprs-dprs/
  xlx_aprs_dprs.py
  backup.sh

/etc/xlx-aprs-dprs/
  config.json
  install.env

/var/lib/xlx-aprs-dprs/
  digital-lab.sqlite
  accounts.sqlite
  public.json
  operator.sock
  operator-rate.json

<dashboard>/aprs-dprs/
  index.php
  digital-lab-native.php
  api/
  assets/
```

## Bancos

O gateway cria automaticamente as tabelas operacionais:

- `status`;
- `stations`;
- `events`;
- `messages`.

O instalador cria o banco de autenticação com:

- `accounts`;
- `remember_tokens`;
- `audit_log`.

Nenhum banco real é distribuído no repositório.
