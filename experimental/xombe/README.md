# Xombe V4 — produção aprovada pelo operador (2026-11-26)

**Estado:** V4 ativo em XLX026, com início automático habilitado. O operador autorizou a adoção. A validação auditiva final em rádios reais após V4 continua pendente; não declarar HW PASS sem essa escuta.

## Direção e ganho

- D-STAR → DMR/YSF: ajuste adicional aplicado por stream com `xombe_xc_set_dstar_to_dmr_gain(-0.5f)`.
- DMR/YSF → D-STAR: comportamento upstream preservado.
- Ganho padrão da biblioteca = zero; somente o AMBED direto opt-in configura ganho.
- O V3 anterior aplicava +0,5 no sentido DMR→D-STAR por engano e falhou 8/88 testes. Foi removido da execução e substituído por V2 enquanto V4 era corrigido. Não usar V3.

## Fontes fixadas

- PP5PK XLX-SoftAMBE_Installer: `eff797298744f3b2e1db7bb5b9424db18a03827b`; patch SHA Git blob `dca3f9015edf017458f192b744c5b78889769258`.
- PP5PK XLXD: `f10f91bdc5c19ad5b435d96a6595f945403e093a`.
- x0rro/xombe: `2f0a8e744645b51c1749a39c8a4ee581fef1f20a`, licença MIT.
- XLX026 adapter/gain: `ambed-adapter-v4.patch`, `xombe-gain-v4.patch`.

## Rebuild

Em Debian 12 de laboratório, como usuário sem privilégios, com git, CMake, make, GCC/G++ e Python 3:

```bash
bash build.sh /tmp/xombe-v4-build
```

O script verifica hashes, aplica patches, executa CMake/CTest (88 testes) e compila AMBED. Não instala nem inicia serviços.

## Evidência

- DOC: fontes e patches pinados; xombe MIT.
- SW: build AMBED V4 PASS; CTest 88/88 PASS com ganho opt-in desligado por padrão.
- ENV: V4 executou 100 frames UDP isolados (50 por direção), duas sessões e sem falha de protocolo.
- PROD: V4 ativo, AMBED PID 1153868, XLXD PID 1298 inalterado; UDP ping PASS. Reiniciado somente AMBED após confirmar ausência de streams ativos.
- OPERATOR: autorização explícita para adoção.
- HW: escuta de rádio após V4 ainda pendente. RMS/sem clipping em amostras sintéticas não prova áudio RF.

## Estado de produção e rollback

- Serviço atual: `xlx-softambe.service` executa o binário Xombe V4 via drop-in persistente `/etc/systemd/system/xlx-softambe.service.d/90-xombe-approved.conf`.
- `xlx-softambe.service` enabled; `xlx-unified-voice.service` disabled para evitar conflito na inicialização.
- XLXD não foi reiniciado.
- Backup privado e configuração anterior: `/opt/xlx026-backups/CODEC_AUDIT_BASELINE_20261126_094909Z/xombe-v4-prechange`; backup de baseline: `.../xombe-approval-prechange`. Não publicar backups privados.
- Para rollback imediato após cessar streams: trocar ExecStart para binário V2, daemon-reload e reiniciar somente AMBED; V2 permanece em `/opt/xlx-softambe/bin/ambed-xombe-gain-v2-20261126`. Para retornar ao caminho xuvd legado, usar o script validado `/opt/xlx026-backups/SOFTAMBE_PRE_SWITCH_20261103_191457Z/ROLLBACK.sh` somente após `--check` e janela sem TX.
- Não atualizar XLXD core nem alterar painel por causa deste codec. Integração do instalador público ainda é um trabalho separado; esta PR publica receita reproduzível e evidência, não uma release completa do instalador.

## Recuperação do Xombe V9 do XLX026

A inspeção de 2026-11-27 correlacionou o executável ativo com o build de laboratório `f59ddbbc4d9e9851d01fd6ea79c2d082780702fd2f0f7a70e1065da3614f5f24`. Para reconstruir, selecione explicitamente o perfil da instância:

```bash
bash build.sh /tmp/xombe-v9-recovery xlx026-v9
```

O perfil aplica o ganho direcional observado nas fontes do binário ativo (`-0.5` e `4.984032904` em log2 de amplitude). Esses valores pertencem à recuperação desse perfil. Use V4 em uma avaliação genérica. A compilação roda CTest e só produz arquivos locais. A qualidade auditiva em rádios reais deve ser avaliada separadamente.
