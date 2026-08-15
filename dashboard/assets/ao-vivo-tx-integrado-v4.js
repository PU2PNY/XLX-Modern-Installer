/*
 * XLX026 — TX INTEGRADO V4
 *
 * Somente apresentação.
 *
 * NÃO:
 * - consulta APIs;
 * - cria polling;
 * - altera valores;
 * - interfere no standby;
 * - interfere no histórico.
 *
 * Apenas move o elemento MTR já criado pelo mtr.js para
 * dentro do respectivo card vermelho.
 */

(() => {
    'use strict';

    if (window.__XLX026_TX_INTEGRADO_V4__) {
        return;
    }

    window.__XLX026_TX_INTEGRADO_V4__ = true;

    const grid =
        document.getElementById('moduleGrid');

    if (!grid) {
        return;
    }

    let pending = false;


    function direct(parent, selector) {

        return Array
            .from(parent.children)
            .filter(element =>
                element.matches(selector)
            );
    }


    function integrate() {

        /*
         * Standby não possui MTR.
         * Portanto, não sofre nenhuma alteração.
         */

        direct(grid, ':scope > *').forEach(stack => {

            /*
             * Estrutura criada atualmente pelo mtr.js:
             *
             * stack
             * ├── .mtr-mini
             * └── .tx-card.live.tx-v30
             */

            const card =
                Array
                    .from(stack.children)
                    .find(element =>
                        element.matches(
                            '.tx-card.live.tx-v30'
                        )
                    );

            const mtr =
                Array
                    .from(stack.children)
                    .find(element =>
                        element.matches(
                            '.mtr-mini'
                        )
                    );

            if (!card || !mtr) {
                return;
            }

            let dock =
                Array
                    .from(card.children)
                    .find(element =>
                        element.matches(
                            '.xlx026-mtr-dock-v4'
                        )
                    );

            if (!dock) {

                dock =
                    document.createElement('div');

                dock.className =
                    'xlx026-mtr-dock-v4';

                /*
                 * Depois do spectrum.
                 *
                 * Nenhuma informação é removida.
                 */
                card.appendChild(dock);
            }

            if (mtr.parentElement !== dock) {
                dock.appendChild(mtr);
            }

            stack.classList.add(
                'xlx026-tx-stack-v4'
            );
        });
    }


    function schedule() {

        if (pending) {
            return;
        }

        pending = true;

        requestAnimationFrame(() => {

            pending = false;

            integrate();
        });
    }


    /*
     * Observa somente moduleGrid.
     *
     * Sem timer.
     * Sem polling adicional.
     */
    const observer =
        new MutationObserver(schedule);

    observer.observe(
        grid,
        {
            childList: true,
            subtree: true,
        }
    );

    schedule();

})();
