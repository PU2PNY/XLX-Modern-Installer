
/* ==========================================================
   XLX026_HEADER_UNIFICADO_V1

   Garante botão Bip em todas as páginas.

   AO VIVO:
   preserva o botão funcional já existente.

   OUTRAS PÁGINAS:
   controla a mesma preferência salva em localStorage.
   ========================================================== */

(() => {

    'use strict';

    const STORAGE_KEY =
        'xlx026TxRxSound';


    function enabled(){

        return (
            localStorage.getItem(
                STORAGE_KEY
            ) !== 'disabled'
        );
    }


    function update(button){

        if (!button){
            return;
        }


        const on =
            enabled();


        button.innerHTML =
            '<span aria-hidden="true">'
            + (on ? '🔊' : '🔇')
            + '</span>'
            + '<span>Bip</span>';


        button.classList.toggle(
            'is-off',
            !on
        );


        button.setAttribute(
            'aria-pressed',
            on ? 'true' : 'false'
        );


        button.setAttribute(
            'aria-label',
            on
                ? 'Desativar avisos sonoros'
                : 'Ativar avisos sonoros'
        );


        button.title =
            on
                ? 'Bip ativado'
                : 'Bip desativado';
    }


    function createUniversalButton(nav){

        const button =
            document.createElement(
                'button'
            );


        button.type =
            'button';


        button.className =
            'xlx026-menu-sound-control '
            + 'xlx026-universal-bip';


        update(button);


        button.addEventListener(
            'click',
            event => {

                event.preventDefault();
                event.stopPropagation();


                const next =
                    !enabled();


                if (next){

                    localStorage.removeItem(
                        STORAGE_KEY
                    );

                } else {

                    localStorage.setItem(
                        STORAGE_KEY,
                        'disabled'
                    );
                }


                update(button);
            }
        );


        nav.appendChild(
            button
        );


        return button;
    }


    function start(){

        const nav =
            document.querySelector(
                '.universal-header .universal-nav'
            );


        if (!nav){
            return;
        }


        const page =
            document.body.dataset.page || '';


        /*
         * ----------------------------------------------------
         * AO VIVO
         *
         * Já possui o Bip ligado à função real de áudio.
         * Não tocamos nele.
         * ----------------------------------------------------
         */

        if (page === 'ao-vivo'){

            const existing =
                nav.querySelector(
                    '.xlx026-menu-sound-control'
                );


            if (existing){

                /*
                 * Só adicionamos a classe visual universal,
                 * sem substituir listener ou funcionamento.
                 */

                existing.classList.add(
                    'xlx026-universal-bip'
                );
            }


            return;
        }


        /*
         * ----------------------------------------------------
         * OUTRAS PÁGINAS
         * ----------------------------------------------------
         */

        let button =
            nav.querySelector(
                '.xlx026-universal-bip'
            );


        if (!button){

            button =
                createUniversalButton(
                    nav
                );
        }


        update(button);


        /*
         * Sincroniza caso a preferência seja alterada
         * em outra aba do navegador.
         */

        window.addEventListener(
            'storage',
            event => {

                if (
                    event.key === STORAGE_KEY
                ){

                    update(button);
                }
            }
        );
    }


    if (
        document.readyState ===
        'loading'
    ){

        document.addEventListener(
            'DOMContentLoaded',
            start,
            { once:true }
        );

    } else {

        start();
    }

})();

/* FIM XLX026_HEADER_UNIFICADO_V1 */
