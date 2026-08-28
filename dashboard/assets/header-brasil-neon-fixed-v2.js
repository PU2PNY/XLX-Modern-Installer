/* ================================================================
   XLX026_HEADER_BRASIL_NEON_FIXED_V2

   CORREÇÃO DO LOOP DA V1

   O header original NUNCA muda de tamanho.

   Uma barra fixed independente é criada fora do fluxo do documento.

   Consequência:
   aparecer/desaparecer a barra não altera scrollY nem a altura
   do header original, portanto não existe feedback/oscillação.
   ================================================================ */

(function () {
    'use strict';

    if (window.__XLX026_HEADER_BRASIL_NEON_FIXED_V2__) {
        return;
    }

    window.__XLX026_HEADER_BRASIL_NEON_FIXED_V2__ = true;


    var DESKTOP =
        '(min-width: 821px)';


    function init() {

        var header =
            document.querySelector(
                'section.universal-header'
            );

        if (!header) {
            return;
        }


        var originalNav =
            header.querySelector(
                '.universal-nav'
            );

        if (!originalNav) {
            return;
        }


        /*
         * Limpeza defensiva.
         *
         * Se a V1 deixou a classe compacta por alguma razão,
         * removemos imediatamente.
         */
        header.classList.remove(
            'xlx026-header-compact'
        );


        /*
         * Cria estrutura FIXED totalmente independente.
         */
        var fixed =
            document.createElement('div');

        fixed.className =
            'xlx026-fixed-header-v2';

        fixed.setAttribute(
            'aria-hidden',
            'true'
        );


        var inner =
            document.createElement('div');

        inner.className =
            'xlx026-fixed-inner-v2';


        /*
         * Marca.
         */
        var brand =
            document.createElement('a');

        brand.className =
            'xlx026-fixed-brand-v2';

        brand.href =
            '/ao-vivo';

        brand.setAttribute(
            'aria-label',
            'XLX026 Brasil — Ao vivo'
        );


        var code =
            document.createElement('span');

        code.className =
            'xlx026-fixed-code-v2';

        code.textContent =
            'XLX026';


        var country =
            document.createElement('span');

        country.className =
            'xlx026-fixed-country-v2';

        country.textContent =
            'Brasil';


        brand.appendChild(code);
        brand.appendChild(country);


        /*
         * Clona apenas os LINKS reais do menu atual.
         *
         * A estrutura visual nova será aplicada
         * exclusivamente pelas classes V2.
         */
        var nav =
            originalNav.cloneNode(true);

        nav.classList.add(
            'xlx026-fixed-nav-v2'
        );

        nav.setAttribute(
            'aria-label',
            'Menu principal fixo'
        );


        /*
         * Evita IDs duplicados caso algum seja acrescentado
         * ao menu no futuro.
         */
        if (nav.hasAttribute('id')) {
            nav.removeAttribute('id');
        }

        var nodesWithId =
            nav.querySelectorAll('[id]');

        for (
            var i = 0;
            i < nodesWithId.length;
            i++
        ) {
            nodesWithId[i].removeAttribute('id');
        }


        /*
         * Se houver botão de menu dentro da navegação
         * em alguma versão futura, não clonamos.
         */
        var buttons =
            nav.querySelectorAll(
                'button'
            );

        for (
            var b = 0;
            b < buttons.length;
            b++
        ) {
            if (buttons[b].parentNode) {
                buttons[b].parentNode.removeChild(
                    buttons[b]
                );
            }
        }


        inner.appendChild(brand);
        inner.appendChild(nav);

        fixed.appendChild(inner);

        document.body.appendChild(fixed);


        var media =
            window.matchMedia
                ? window.matchMedia(DESKTOP)
                : null;


        var queued =
            false;


        /*
         * Mostramos a barra quando o header original
         * já está praticamente saindo da viewport.
         *
         * Como o header original nunca é modificado,
         * getBoundingClientRect() permanece estável.
         */
        function update() {

            queued = false;

            var desktop =
                media &&
                media.matches;

            if (!desktop) {

                fixed.classList.remove(
                    'is-visible'
                );

                fixed.setAttribute(
                    'aria-hidden',
                    'true'
                );

                return;
            }


            var rect =
                header.getBoundingClientRect();


            /*
             * A barra fixa entra quando restam apenas
             * aproximadamente 64 px do header original.
             *
             * Não usamos scrollY >= X para decidir e
             * simultaneamente redimensionar o mesmo elemento.
             */
            var show =
                rect.bottom <= 64;


            if (show) {

                fixed.classList.add(
                    'is-visible'
                );

                fixed.setAttribute(
                    'aria-hidden',
                    'false'
                );

            } else {

                fixed.classList.remove(
                    'is-visible'
                );

                fixed.setAttribute(
                    'aria-hidden',
                    'true'
                );
            }
        }


        function schedule() {

            if (queued) {
                return;
            }

            queued = true;

            if (window.requestAnimationFrame) {

                window.requestAnimationFrame(
                    update
                );

            } else {

                window.setTimeout(
                    update,
                    16
                );
            }
        }


        window.addEventListener(
            'scroll',
            schedule,
            { passive: true }
        );


        window.addEventListener(
            'resize',
            schedule,
            false
        );


        if (media) {

            if (media.addEventListener) {

                media.addEventListener(
                    'change',
                    schedule
                );

            } else if (media.addListener) {

                media.addListener(
                    schedule
                );
            }
        }


        update();
    }


    if (
        document.readyState === 'loading'
    ) {

        document.addEventListener(
            'DOMContentLoaded',
            init,
            { once: true }
        );

    } else {

        init();
    }

})();

/* /XLX026_HEADER_BRASIL_NEON_FIXED_V2 */
