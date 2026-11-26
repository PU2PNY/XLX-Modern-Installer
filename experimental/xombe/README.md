# Xombe V7 — ganho controlado DMR/YSF → D-STAR (2026-11-26)

**Estado:** V7 ativo no XLX026. O pedido de duplicar o ganho V6 (+6 dB adicionais) foi testado, mas rejeitado por clipping. V7 aplica +2 dB adicionais sobre V6, total +8 dB em relação ao padrão upstream, somente em AMBE+2 → AMBE.

## Direção e ganho

- DMR/YSF → D-STAR: +8 dB total (V7); +2 dB adicionais sobre V6.
- D-STAR → DMR/YSF: mantém o ajuste anterior de -0.5 log2.
- Ganho padrão da biblioteca = zero; somente o AMBED direto opt-in configura ganho.
- A mesma direção AMBE+2 → AMBE atende DMR e YSF; teste sintético disponível nesta homologação foi DMR. Escuta YSF real pós-V7 permanece pendente.
- A tentativa de +6 dB adicionais sobre V6 gerou 1.029 amostras clipadas em 32.000; +3 dB adicionais gerou 9 amostras clipadas. Não usar esses níveis.

## Fontes fixadas

- PP5PK XLX-SoftAMBE_Installer: `eff797298744f3b2e1db7bb5b9424db18a03827b`; patch SHA Git blob `dca3f9015edf017458f192b744c5b78889769258`.
- PP5PK XLXD: `f10f91bdc5c19ad5b435d96a6595f945403e093a`.
- x0rro/xombe: `2f0a8e744645b51c1749a39c8a4ee581fef1f20a`, licença MIT.
- XLX026 adapter/gain: `ambed-adapter-v4.patch`, `xombe-gain-v4.patch` e V7 source edits documentados no `build.sh`.

## Rebuild

Em Debian 12 de laboratório, como usuário sem privilégios, com git, CMake, make, GCC/G++ e Python 3:

```bash
bash build.sh /tmp/xombe-v7-build
```

O script verifica hashes, aplica o adapter V4 e o ganho V4, aplica as alterações V7 por âncoras de código verificadas, executa CMake/CTest (88 testes) e compila AMBED. Não instala nem inicia serviços.

## Evidência

- DOC: fontes e commits pinados; xombe MIT.
- SW: build V7 e CTest 88/88 PASS com ganho opt-in desligado por padrão na suíte.
- ENV: 200 quadros AMBE+2 sintéticos: V6 RMS -13.32 dBFS; V7 -11.19 dBFS, pico 32680/32768, zero amostras clipadas.
- ENV: +3 dB adicionais clipou 9/32000 amostras; +6 dB adicionais clipou 1029/32000.
- PROD: V7 ativo, AMBED PID 1201360, XLXD PID 1298 preservado, UDP ping PASS. Serviço enabled. Reiniciado somente AMBED após confirmar ausência de streams.
- HW: confirmação auditiva pós-V7 em rádios reais ainda pendente. Teste sintético não é validação RF.

## Estado de produção e rollback

- Serviço: `xlx-softambe.service` executa `/opt/xlx-softambe/bin/ambed-xombe-gain-v7-plus2db-20261126` via drop-in `/etc/systemd/system/xlx-softambe.service.d/90-xombe-approved.conf`.
- `xlx-softambe.service` enabled; `xlx-unified-voice.service` disabled para evitar conflito.
- XLXD, painel e banco não foram alterados/reiniciados.
- Backup privado: `/opt/xlx026-backups/CODEC_AUDIT_BASELINE_20261126_094909Z/xombe-v7-prechange`.
- V6 permanece em `/opt/xlx-softambe/bin/ambed-xombe-gain-v6-20261126`, SHA-256 `bdd50354eab01005f3724089abab55fa226725836e1e66e44f8087db0339f64b`.
- Rollback: aguardar ausência de streams, restaurar `prior-approved.conf`, apontar ExecStart para V6, daemon-reload, reiniciar somente AMBED e verificar ping. Não reiniciar XLXD.
- Não marcar qualidade RF como aprovada até o operador confirmar a escuta.

