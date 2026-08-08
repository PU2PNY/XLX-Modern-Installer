/* ==========================================================
   XLX026_MOBILE_MENU_V4
   Controle independente e definitivo
   ========================================================== */

(() => {

    'use strict';

    const MQ = window.matchMedia('(max-width: 820px)');

    function iniciar(){

        const header =
            document.querySelector('.universal-header');

        if (!header) return;


        const button =
            header.querySelector('.menu-toggle');

        const nav =
            header.querySelector('.universal-nav');

        if (!button || !nav) return;


        /*
         * Remove controles mobile experimentais anteriores,
         * caso algum JS antigo tenha criado esses elementos.
         */

        header
            .querySelectorAll(
                '.xlx026-mobile-menu-button,'
                + '.xlx026-mobile-togglebar'
            )
            .forEach(el => el.remove());


        function limparClassesAntigas(){

            nav.classList.remove(
                'open',
                'xlx026-mobile-open',
                'xlx026-mobile-open-v3'
            );
        }


        function fechar(){

            limparClassesAntigas();

            nav.classList.remove(
                'xlx026-v4-open'
            );

            button.textContent = 'MENU';

            button.setAttribute(
                'aria-expanded',
                'false'
            );

            button.setAttribute(
                'aria-label',
                'Abrir menu'
            );
        }


        function abrir(){

            limparClassesAntigas();

            nav.classList.add(
                'xlx026-v4-open'
            );

            button.textContent = 'FECHAR';

            button.setAttribute(
                'aria-expanded',
                'true'
            );

            button.setAttribute(
                'aria-label',
                'Fechar menu'
            );
        }


        function sincronizar(){

            if (MQ.matches){

                /*
                 * REGRA PRINCIPAL:
                 * toda entrada/reload no mobile comeca fechada.
                 */

                fechar();

            } else {

                limparClassesAntigas();

                nav.classList.remove(
                    'xlx026-v4-open'
                );

                /*
                 * Desktop permanece como era.
                 */
                button.textContent = '☰';

                button.setAttribute(
                    'aria-expanded',
                    'false'
                );
            }
        }


        /*
         * Captura=true + stopImmediatePropagation:
         *
         * impede o listener antigo de .open de disputar
         * o clique com nosso V4.
         */

        button.addEventListener(
            'click',
            event => {

                if (!MQ.matches) return;

                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();

                if (
                    nav.classList.contains(
                        'xlx026-v4-open'
                    )
                ){

                    fechar();

                } else {

                    abrir();
                }
            },
            true
        );


        /*
         * Ao selecionar uma pagina,
         * recolhe o menu antes da navegacao.
         */

        nav.addEventListener(
            'click',
            event => {

                if (!MQ.matches) return;

                const link =
                    event.target.closest('a');

                if (!link) return;

                fechar();
            },
            true
        );


        document.addEventListener(
            'keydown',
            event => {

                if (
                    MQ.matches
                    && event.key === 'Escape'
                ){

                    fechar();
                }
            }
        );


        if (typeof MQ.addEventListener === 'function'){

            MQ.addEventListener(
                'change',
                sincronizar
            );

        } else if (
            typeof MQ.addListener === 'function'
        ){

            MQ.addListener(
                sincronizar
            );
        }


        /*
         * Estado inicial.
         */

        sincronizar();

    }


    /*
     * O app.js antigo pode registrar seu codigo em
     * DOMContentLoaded antes de nos.
     *
     * Nosso listener e registrado depois dele;
     * portanto executamos por ultimo e limpamos seu estado.
     */

    if (document.readyState === 'loading'){

        document.addEventListener(
            'DOMContentLoaded',
            iniciar,
            { once:true }
        );

    } else {

        iniciar();
    }

})();

/* FIM XLX026_MOBILE_MENU_V4 */
