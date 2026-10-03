# Stereo Tool no XLX026 — arquitetura, segurança e gates

Status: **LAB foundation / não autorizado para processamento em produção**

Data da decisão inicial: 2026-10-02

## 1. Objetivo

Adicionar suporte opcional ao Stereo Tool no domínio PCM do XLX026 sem transformar XLXD, xuvd, DMR, YSF ou D-Star em dependentes do componente proprietário.

A propriedade fundamental é:

> falha, ausência, timeout, licença inválida, preset inválido ou crash do Stereo Tool não pode derrubar o XLXD nem impedir o caminho de áudio legado conhecido-bom.

## 2. Limite desta primeira implantação

Esta etapa instala **nenhum** binário do Stereo Tool e não altera produção.

Ela entrega somente:

- validador estático de artifact fornecido pelo administrador;
- quarentena segura para ZIP;
- identificação por SHA-256;
- validação ELF, arquitetura, GLIBC e símbolos de identidade;
- testes com biblioteca mock open-source/sintética;
- referência de hardening systemd para o futuro worker;
- documentação e gates para as próximas etapas.

Não existe integração no hot path nesta etapa.

## 3. Arquitetura aprovada

A arquitetura de produção pretendida é uma fronteira de processo:

```text
DMR / YSF / D-Star
        |
        v
XLXD / transcoder legado
        |
        v
       PCM
        |
        v
xlx-audio-router
   |          |
   |          +----> bypass PCM original, alinhado em atraso
   |
   +---- Unix socket local ----> xlx-stereotoold
                                  |
                                  v
                              libStereoTool
                                  |
                                  v
                             PCM processado
```

Regras:

- `libStereoTool` nunca é carregada dentro de `xlxd`, PHP/Nginx ou painel web;
- o worker proprietário roda em processo separado;
- data plane usa IPC local, nunca HTTP;
- a web UI nativa do Stereo Tool fica desabilitada;
- o worker não recebe `AF_INET`/`AF_INET6`;
- estado DSP é independente por stream/PTT;
- saturação de capacidade produz bypass, não fila de voz;
- troca de artifact/preset é geracional e não muda um PTT já aberto;
- fallback no meio do PTT é sticky: o restante daquele PTT permanece no caminho original;
- `PROCESS` exige bypass original com atraso equivalente ao DSP antes de qualquer canário real.

## 4. Estados operacionais

| Estado | Áudio entregue | Stereo Tool executa | Permitido hoje? |
|---|---|---:|---:|
| `ORIGINAL` | PCM original | não | sim |
| `SHADOW` | PCM original | sim, cópia assíncrona | somente após gates específicos |
| `PREVIEW` | arquivo/player administrativo | sim | laboratório |
| `PROCESS_CANARY` | processado em escopo restrito | sim | não |
| `PROCESS` | processado + fail-open alinhado | sim | não |
| `EMERGENCY_BYPASS` | PCM original | não | obrigatório antes de canário |

`SHADOW` não autoriza `PROCESS`.

## 5. Artifact Manager

O administrador fornece o artifact. O projeto público não redistribui Stereo Tool.

Pipeline mínimo:

```text
UPLOAD
  -> quarentena
  -> SHA-256
  -> limites de tamanho/quantidade
  -> inspeção ZIP segura
  -> ELF64
  -> arquitetura
  -> GLIBC host/requerida
  -> símbolos de identidade
  -> READY_FOR_SANDBOX
  -> sandbox load test (etapa futura)
  -> audio smoke/benchmark (etapa futura)
  -> READY
```

`READY_FOR_SANDBOX` significa apenas que o arquivo pode seguir para um worker isolado. Não significa licença válida, qualidade aprovada, compatibilidade de SDK ou autorização de produção.

### Limites iniciais

- pacote: 256 MiB;
- conteúdo ZIP descompactado: 1 GiB;
- arquivos dentro do ZIP: 2.000;
- presets `.sts`: limite futuro separado de 10 MiB;
- filename nunca é identidade; SHA-256 é a identidade interna.

### ZIP tratado como hostil

São rejeitados:

- caminho absoluto;
- `../`;
- symlink;
- device/special file;
- escape da quarentena;
- excesso de arquivos/tamanho.

## 6. Propriedade e SDK

O projeto não deve inventar nomes de funções de inicialização, processamento, settings, meters ou presets.

Os símbolos abaixo são usados **somente como sanity check de identidade** na inspeção estática:

- `stereoTool_GetSoftwareVersion`;
- `stereoTool_GetApiVersion`.

A integração runtime só pode ser escrita contra headers/exemplos da versão do SDK efetivamente licenciada e fornecida pelo administrador.

Nenhum header, `.so`, pacote ZIP, chave/licença ou artifact proprietário será commitado ao GitHub sem permissão expressa de redistribuição.

## 7. Licenciamento — bloqueador de produção

Antes de qualquer `PROCESS_CANARY` ou `PROCESS`, deve existir resposta escrita do fornecedor esclarecendo, no mínimo:

1. se um refletor radioamador público pode processar áudio de terceiros;
2. se isso constitui disponibilização da funcionalidade como serviço;
3. como são contadas “instances” quando existem múltiplos contextos/streams;
4. se cada contexto/PTT tem impacto de licença;
5. quais direitos/condições se aplicam ao SDK;
6. se headers podem ser mantidos no nosso código/repositório;
7. regras de backup ativo/passivo;
8. política de uso em servidor público multiusuário.

Sem essa resposta, Stereo Tool permanece laboratório/preview/shadow tecnicamente isolado conforme o que for permitido, nunca processamento de produção.

## 8. Segurança do futuro worker

A unidade de referência em `experimental/stereotool/systemd/` usa, entre outros:

- usuário/grupo dedicados;
- `NoNewPrivileges=yes`;
- `ProtectSystem=strict`;
- `ProtectHome=yes`;
- `PrivateTmp=yes`;
- `PrivateDevices=yes`;
- `RestrictAddressFamilies=AF_UNIX`;
- diretórios de artifacts/presets somente leitura;
- `/run/xlx-audio` como área gravável limitada.

Afinidade de CPU, prioridade realtime e tuning de scheduler não serão ativados por intuição. Só após benchmark demonstrar necessidade e ausência de impacto ao transcoder.

## 9. Contexto por stream

AGC, compressor, gate e outros módulos stateful não podem compartilhar histórico entre operadores simultâneos.

A chave do stream deve conter identidade de sessão suficiente, por exemplo:

```text
protocol + module + source_id + stream_id + generation
```

Um contexto nunca deve ser reciclado para outro PTT sem reset/reinicialização suportada pelo SDK.

O teste de isolamento deve provar que um stream muito alto não altera ganho/dinâmica de outro stream simultâneo muito baixo ou normal.

## 10. Fail-open e atraso

O futuro caminho `PROCESS` precisa manter um ring buffer original com atraso equivalente ao Stereo Tool.

Sem isso, uma falha do DSP no meio do PTT provocaria salto temporal ao trocar para áudio original “adiantado”. Portanto:

```text
processed N-D ----\
                   selector -> encoder
original  N-D ----/
```

Após a primeira falha de DSP em um PTT, o stream entra em `BYPASS_LATCHED` até fechar. Não se volta ao Stereo Tool no meio do mesmo PTT.

## 11. Gates obrigatórios

### GO para sandbox real

- artifact passa inspeção estática;
- SDK oficial disponível;
- permissões/licença permitem o teste;
- worker isolado e sem rede;
- library load/unload exercitado fora de XLXD/xuvd;
- crash não afeta o transcoder.

### GO para SHADOW

- artifact/library/preset validados;
- PCM real inventariado (sample rate, canais, formato, frame size, deadline);
- corpus sintético e real autorizado passa smoke;
- nenhum crash;
- CPU/RAM medidos;
- contextos independentes;
- shadow totalmente assíncrono e descartável;
- rollback do observer demonstrado.

### GO para PROCESS_CANARY

- autorização jurídica/comercial escrita para produção;
- licença runtime válida e sem nag/beep;
- latência dentro do orçamento aprovado;
- fail-open + delay matching testados;
- emergency bypass independente do worker;
- chaos tests passam;
- 72 h de shadow sem impacto;
- restore completo comprovado.

### GO para PROCESS

- canário restrito concluído;
- zero crash atribuível ao DSP;
- zero audio drop atribuível ao DSP;
- zero state leakage;
- memória estável;
- headroom de CPU medido;
- A/B de qualidade aceito;
- rollback demonstrado.

## 12. Testes mínimos

O CI público usa mock, nunca a biblioteca proprietária.

Cobertura obrigatória inclui:

- `.so` mock válido;
- símbolos ausentes;
- arquitetura incompatível;
- GLIBC incompatível;
- ZIP traversal;
- symlink/special file;
- limites de ZIP;
- protocolo IPC malformado (etapa worker);
- timeout/crash/context exhaustion (mock worker);
- 1/2/4/8/12/16/20 streams no benchmark privado;
- kill do worker;
- preset inválido;
- licença inválida;
- restore artifact/preset;
- emergency bypass.

## 13. Relação com Helix

Helix e Stereo Tool não devem ser empilhados automaticamente no hot path.

O XLX026 já possui trabalho Helix em `shadow`, enquanto a confiabilidade de `process` continua com gate próprio. A integração Stereo Tool começa independente e em laboratório. Qualquer comparação futura Helix x Stereo Tool deve usar o mesmo corpus e A/B level-matched, sem assumir que “mais alto” significa melhor.

## 14. Regra de produção

**Nenhuma mudança deste documento autoriza tocar no XLXD/xuvd de produção.**

Promoção futura segue:

```text
decisão
 -> requisito
 -> teste
 -> artifact/rollback
 -> laboratório
 -> shadow
 -> canário
 -> produção
```

Evidência deve continuar classificada separadamente como DOC / SW / ENV / HW / PROD / OPERATOR.
