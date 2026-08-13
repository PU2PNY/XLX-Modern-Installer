# XLX Certificate Generator (opcional)

O sistema de Certificados foi separado do núcleo do XLX Modern e agora vive no repositório independente `PU2PNY/XLX-Certificate-Generator`.

## Durante a instalação completa

Após o dashboard e o diretório de indicativos serem instalados, o instalador pergunta:

```text
Deseja instalar também o módulo opcional de Certificados? [s/N]:
```

Para automação não interativa, defina:

```bash
sudo env XLX_CERTIFICATES_MODE=yes bash install.sh
```

ou:

```bash
sudo env XLX_CERTIFICATES_MODE=no bash install.sh
```

Valores aceitos: `ask`, `yes` e `no` (além de equivalentes simples como `sim`/`não`).

## Instalação individual posterior

O componente também pode ser instalado separadamente pelo próprio repositório `XLX-Certificate-Generator`. O painel moderno deve estar atualizado e conter o hook `XLX_CERTIFICATES_OPTIONAL_HOOK_V1`.

O integrador interno do XLX Modern usa um commit fixado e verifica:

- commit aprovado do repositório externo;
- SHA-256 do `install.sh`;
- SHA-256 do `MANIFEST.sha256`;
- manifesto de todos os arquivos do módulo;
- sintaxe Bash, PHP e JavaScript quando os runtimes estão disponíveis.

## Pin atual

```text
Repository: PU2PNY/XLX-Certificate-Generator
Commit: 30722407eb2bd98adab7a67a7bb74ae83859e0e9
install.sh SHA-256: 7a1e3d6420a590ce24be5774e92cb115dbdf150fb6d0bc53690379360c9363a8
MANIFEST.sha256 SHA-256: 705224e997a7cabecaf7e9e8bcb2683484ea4db43364b17bbacf176df204e44c
```

## Dados privados

O repositório público não contém:

- certificados emitidos;
- registros de emissão;
- chave HMAC;
- bancos de dados;
- credenciais;
- configuração privada de produção.

Esses itens continuam no servidor e são preservados durante atualizações.

## Compatibilidade

O hook do painel é inerte quando o módulo não está instalado. A rota `certificado`, os assets e os scripts só são ativados quando os arquivos obrigatórios do módulo estão presentes.
