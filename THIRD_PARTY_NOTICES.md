# Third-Party Notices / Avisos de Terceiros

O **XLX Modern Installer** combina código próprio, automação, documentação e integração com projetos da comunidade de rádio digital. Esta página concentra as atribuições e licenças de terceiros, separadas da apresentação visual do instalador e do painel público.

As referências abaixo são mantidas por transparência técnica e cumprimento das licenças aplicáveis. Elas não precisam aparecer como créditos visuais no painel moderno nem na interface normal de instalação.

## XLX / XLXD

- Projeto: **XLX Multiprotocol Gateway Reflector Server**
- Autores originais: Jean-Luc Deltombe — LX3JL e Luc Engelmann — LX1IQ
- Repositório: https://github.com/LX3JL/xlxd
- Licença upstream: GPL-3.0 / licenças GPL conforme informado pelo projeto original

A licença MIT deste repositório **não substitui** a licença do XLXD.

## PP5PK / XLX_Installer

- Autor/mantenedor: Daniel K. — PP5PK
- Repositório: https://github.com/PP5PK/XLX_Installer
- Uso neste projeto: base técnica revisada para instalação e referência de arquitetura

Os arquivos provenientes ou derivados diretamente desse projeto preservam os avisos e condições aplicáveis ao upstream.

## XLXEcho

- Projeto: **XLXEcho**
- Repositório: https://github.com/narspt/XLXEcho
- Uso: serviço opcional de eco/parrot para testes de áudio

## Certbot

- Projeto: **Certbot / Let's Encrypt client**
- Site: https://certbot.eff.org/
- Uso: referência para configuração de HTTPS/SSL quando aplicável

## YSF registration

- Serviço: https://dvref.com/
- Uso: referência opcional para operadores que desejem registrar/listar um refletor YSF conforme a arquitetura utilizada

## OP25 / mbelib — laboratório do bridge Helix

A integração experimental `experimental/helix-bridge/` não inclui código OP25/mbelib neste repositório. Para reproduzir o backend legado em laboratório foram inspecionados:
- **OP25** — `boatbod/op25`, commit `71abcd0ead32f86f51615ea6cc8a6a4dba4c949a`; os arquivos usados no laboratório exibem avisos GPLv3-or-later.
- **mbelib** — `szechyjs/mbelib`, commit `9a04ed5c78176a9965f3d43f7aa1b1f5330e771f`; os arquivos inspecionados possuem seu próprio aviso/licença.
- **Histórico PROD recuperado** — o backup do transcoder de 2026-09-08 preserva `boatbod/op25@28f2c40645deca3f8c2d529d27d0df2555ed287a`, usado na investigação que produziu o binário atualmente ativo. O commit de laboratório acima é mais recente e serve apenas à reprodução ENV do bridge Helix; não deve ser confundido com a proveniência do binário PROD.

Esses componentes pertencem ao backend de codec legado externo ao núcleo Helix. Uma eventual distribuição de binário que os incorpore deve cumprir as licenças upstream aplicáveis. Licença de copyright não resolve, por si só, questões de patente/marca de codecs legados.

## Regra de licenciamento

Quando um componente de terceiro estiver incluído, referenciado ou baixado durante a instalação, prevalece a licença original daquele componente. A licença MIT na raiz deste repositório cobre somente o material original do XLX Modern Installer que não esteja sujeito a outra licença.

---

# English summary

Third-party and upstream attribution is intentionally centralized in this documentation and in the relevant source files instead of being presented as visual credits in the modern dashboard or normal installer UI. Third-party components keep their original copyright and license terms. The root MIT license applies only to original XLX Modern Installer material that is not otherwise covered. XLXD remains subject to its upstream GPL licensing, and referenced projects such as PP5PK/XLX_Installer and XLXEcho retain their own terms.
