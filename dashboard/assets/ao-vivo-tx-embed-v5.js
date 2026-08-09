/*
 * ==========================================================
 * XLX026 — MTR EMBED V5
 *
 * Função:
 * colocar o MTR real dentro da área técnica do card TX,
 * imediatamente antes das caixas:
 *
 * Gateway / Repetidor
 * Protocolo / Módulo
 * Tempo transmitindo
 *
 * NÃO:
 * - faz fetch;
 * - cria polling;
 * - altera mtr.js;
 * - altera app.js;
 * - toca no standby;
 * - toca no histórico.
 * ==========================================================
 */

(() => {
    'use strict';

    if (window.__XLX026_MTR_EMBED_V5__) {
        return;
    }

    window.__XLX026_MTR_EMBED_V5__ = true;

    const grid =
        document.getElementById('moduleGrid');

    if (!grid) {
        return;
    }

    let pending = false;


    /*
     * Descobre qual filho direto do moduleGrid contém
     * determinado card.
     */
    function findStack(card) {

        let node = card;

        while (
            node &&
            node.parentElement &&
            node.parentElement !== grid
        ) {
            node = node.parentElement;
        }

        if (
            node &&
            node.parentElement === grid
        ) {
            return node;
        }

        return null;
    }


    function cleanupOldDocks(card) {

        card
            .querySelectorAll(
                '.xlx026-mtr-dock-v4, .xlx-mtr-dock'
            )
            .forEach(dock => {

                if (
                    !dock.querySelector('.mtr-mini') &&
                    dock.childElementCount === 0
                ) {
                    dock.remove();
                }
            });
    }


    function integrateCard(card) {

        const stack =
            findStack(card);

        if (!stack) {
            return;
        }

        /*
         * IMPORTANTE:
         *
         * querySelector, e não somente children.
         *
         * O MTR atual pode estar dentro de uma estrutura
         * intermediária criada pelo mtr.js.
         */
        const mtr =
            stack.querySelector('.mtr-mini');

        if (!mtr) {
            return;
        }


        const content =
            card.querySelector(
                ':scope > .tx-v30-content'
            );

        if (!content) {
            return;
        }


        let tech =
            content.querySelector(
                ':scope > .xlx026-tech-v5'
            );


        let details =
            content.querySelector(
                ':scope > .tx-v30-details'
            );


        /*
         * Se esta função já organizou o card antes,
         * details já estará dentro de tech.
         */
        if (!details && tech) {

            details =
                tech.querySelector(
                    ':scope > .tx-v30-details'
                );
        }


        /*
         * Fallback defensivo.
         */
        if (!details) {

            details =
                card.querySelector(
                    '.tx-v30-details'
                );
        }


        if (!details) {
            return;
        }


        if (!tech) {

            tech =
                document.createElement('div');

            tech.className =
                'xlx026-tech-v5';


            /*
             * Substitui visualmente a antiga área das caixas.
             *
             * A nova estrutura será:
             *
             * tx-v30-content
             * ├── tx-v30-person
             * └── xlx026-tech-v5
             *     ├── mtr-mini
             *     └── tx-v30-details
             */

            if (details.parentElement === content) {

                content.insertBefore(
                    tech,
                    details
                );

            } else {

                content.appendChild(tech);
            }
        }


        /*
         * O MESMO MTR criado pelo mtr.js é movido.
         * Não é copiado nem recriado.
         */
        if (mtr.parentElement !== tech) {

            tech.insertBefore(
                mtr,
                tech.firstElementChild
            );
        }


        /*
         * Caixas técnicas ficam logo abaixo do MTR.
         */
        if (details.parentElement !== tech) {

            tech.appendChild(details);
        }


        /*
         * Garante a ordem correta:
         *
         * MTR
         * ↓
         * caixas técnicas
         */
        if (tech.firstElementChild !== mtr) {

            tech.insertBefore(
                mtr,
                tech.firstElementChild
            );
        }


        if (mtr.nextElementSibling !== details) {

            tech.insertBefore(
                details,
                mtr.nextElementSibling
            );
        }


        stack.classList.add(
            'xlx026-tx-stack-v5'
        );

        mtr.classList.add(
            'xlx026-mtr-embedded-v5'
        );


        cleanupOldDocks(card);
    }


    function organise() {

        grid
            .querySelectorAll(
                '.tx-card.live.tx-v30'
            )
            .forEach(integrateCard);
    }


    function schedule() {

        if (pending) {
            return;
        }

        pending = true;

        requestAnimationFrame(() => {

            pending = false;

            organise();
        });
    }


    /*
     * Somente observa moduleGrid.
     *
     * Quando uma transmissão inicia, termina ou muda,
     * app.js/mtr.js recriam o conteúdo e essa rotina
     * reorganiza o novo card.
     *
     * Não existe timer adicional.
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
