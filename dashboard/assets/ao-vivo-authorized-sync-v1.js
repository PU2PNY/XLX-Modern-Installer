/* XLX Modern — atividade 24h e correção visual do indicativo TX */
(() => {
  'use strict';

  if (window.__XLX_AUTHORIZED_SYNC_V1__) return;
  window.__XLX_AUTHORIZED_SYNC_V1__ = true;

  /*
   * Compatibilidade com o app.js anterior:
   * troca somente a consulta da página Ao Vivo pelo endpoint de 24 horas.
   */
  const nativeFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    if (
      typeof input === 'string'
      && input.includes('api/status.php?history=150&ts=')
    ) {
      input = input.replace(
        'api/status.php?history=150&ts=',
        'api/status.php?history_hours=24&ts='
      );
    }

    return nativeFetch(input, init);
  };

  /*
   * Exibe até 40 indicativos diferentes e mantém as atividades
   * anteriores do mesmo indicativo no submenu.
   */
  if (typeof historyMarkup === 'function') {
    historyMarkup = function (d) {
      const cutoff =
        Number(
          d.generated_at
          || Math.floor(Date.now() / 1000)
        ) - 86400;

      const rows =
        (d.history || [])
          .filter(
            x =>
              Number(x.started_at || 0)
              >= cutoff
          );

      if (!rows.length) {
        return '<tr><td colspan="8">Nenhuma transmissão registrada nas últimas 24 horas.</td></tr>';
      }

      const groups = new Map();

      rows.forEach((x, index) => {
        const base = historyCallKey(x);
        const key =
          base
          || `SEM-INDICATIVO-${index}`;

        if (!groups.has(key)) {
          groups.set(key, []);
        }

        groups.get(key).push(x);
      });

      return [...groups.entries()]
        .slice(0, 40)
        .map(
          ([callKey, items], groupIndex) => {
            const latest = items[0];
            const previous = items.slice(1);
            const expanded =
              historyExpandedCalls.has(
                callKey
              );

            const previousIds =
              previous.map(
                (_, index) =>
                  historyRowId(
                    callKey,
                    index
                  )
              );

            const mainAttrs =
              `class="history-primary-row${
                expanded
                  ? ' is-expanded'
                  : ''
              }" data-history-call="${
                esc(callKey)
              }"`;

            const main =
              historyRowMarkup(
                latest,
                historyStatusMarkup(
                  latest,
                  callKey,
                  previousIds
                ),
                mainAttrs,
                groupIndex + 1
              );

            const older =
              previous
                .map(
                  (x, index) => {
                    const hidden =
                      expanded
                        ? ''
                        : ' style="display:none!important"';

                    const attrs =
                      `id="${
                        esc(
                          previousIds[
                            index
                          ]
                        )
                      }" class="history-previous-row" data-history-parent="${
                        esc(callKey)
                      }"${hidden}`;

                    return historyRowMarkup(
                      x,
                      onlineBadge(
                        Boolean(x.online)
                      ),
                      attrs,
                      ''
                    );
                  }
                )
                .join('');

            return main + older;
          }
        )
        .join('');
    };
  }

  /*
   * Corrige somente o texto exibido no box vermelho
   * (ex.: PU2PNY D -> PU2PNY-D), sem alterar dados da API.
   */
  function normalizeLiveCallsign(raw) {
    const txt =
      String(raw || '')
        .replace(/\s+/g, ' ')
        .trim()
        .toUpperCase();

    if (!txt) return '';

    const match =
      txt.match(
        /^([A-Z0-9\/]+)\s+([A-Z])$/
      );

    if (match) {
      return match[1] + '-' + match[2];
    }

    return txt;
  }

  function fixLiveTxCard() {
    if (
      !document.body
      || document.body.dataset.page
        !== 'ao-vivo'
    ) {
      return;
    }

    const grid =
      document.getElementById(
        'moduleGrid'
      );

    if (!grid) return;

    grid
      .querySelectorAll(
        '.tx-card.live .callsign'
      )
      .forEach(el => {
        const current =
          String(
            el.textContent || ''
          )
            .replace(/\s+/g, ' ')
            .trim()
            .toUpperCase();

        const fixed =
          normalizeLiveCallsign(
            current
          );

        if (
          fixed
          && fixed !== current
        ) {
          el.textContent = fixed;
        }

        el.style.whiteSpace =
          'nowrap';
        el.style.wordBreak =
          'normal';
        el.style.overflowWrap =
          'normal';
      });
  }

  function startCallsignFix() {
    const grid =
      document.getElementById(
        'moduleGrid'
      );

    if (!grid) return;

    let scheduled = false;

    const scheduleFix = () => {
      if (scheduled) return;
      scheduled = true;

      window.requestAnimationFrame(
        () => {
          scheduled = false;
          fixLiveTxCard();
        }
      );
    };

    fixLiveTxCard();

    const observer =
      new MutationObserver(
        scheduleFix
      );

    observer.observe(
      grid,
      {
        childList: true,
        subtree: true,
        characterData: true,
      }
    );
  }

  /*
   * Se a primeira resposta da API já chegou,
   * redesenha o histórico imediatamente.
   */
  if (
    typeof lastData !== 'undefined'
    && lastData
    && document.getElementById(
      'historyRows'
    )
  ) {
    document.getElementById(
      'historyRows'
    ).innerHTML =
      historyMarkup(lastData);
  }

  if (
    document.readyState ===
    'loading'
  ) {
    document.addEventListener(
      'DOMContentLoaded',
      startCallsignFix,
      { once: true }
    );
  } else {
    startCallsignFix();
  }
})();
