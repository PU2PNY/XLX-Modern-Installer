# Certificados nativos do XLX Modern

O sistema de Certificados faz parte do próprio dashboard XLX Modern.
Não depende de repositório, hook ou instalador externo.

## Funcionamento

- a emissão exige participação registrada no refletor;
- cada certificado recebe um ID individual;
- a API calcula uma assinatura HMAC com segredo local, nunca publicado no GitHub;
- o QR Code contém a URL pública de validação com `validar=<id>&token=<assinatura>`;
- a página nativa consulta a API e confirma **válido** ou **inválido**;
- a comparação da assinatura usa `hash_equals()`;
- dados e segredo ficam fora do webroot em `/var/lib/xlx-certificates` e `/etc/xlx-certificates/secret`.

O QR usa a própria rota universal do painel (`?page=certificado`) e funciona em HTTP ou HTTPS conforme o servidor estiver disponível.
