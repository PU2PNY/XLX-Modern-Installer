/* ================================================================
   XLX026_HEADER_BRASIL_NEON_STICKY_V1

   Única função:
   adicionar/remover a classe compacta no desktop conforme rolagem.

   Não toca:
   - APIs
   - cards TX
   - histórico
   - menu mobile
   - sincronização
   ================================================================ */

(function () {
    'use strict';

    if (
        window.__XLX026_HEADER_BRASIL_NEON_STICKY_V1__
    ) {
        return;
    }

    window.__XLX026_HEADER_BRASIL_NEON_STICKY_V1__ = true;

    var DESKTOP_QUERY =
        '(min-width: 821px)';

    var COMPACT_AT =
        96;

    function initHeaderBrasilNeonStickyV1() {

        var header =
            document.querySelector(
                'section.universal-header'
            );

        if (!header) {
            return;
        }

        var mq =
            window.matchMedia
                ? window.matchMedia(DESKTOP_QUERY)
                : null;

        var scheduled = false;

        function isDesktop() {

            if (!mq) {
                return false;
            }

            return !!mq.matches;
        }

        function scrollY() {

            return (
                window.pageYOffset ||
                (
                    document.documentElement
                        ? document.documentElement.scrollTop
                        : 0
                ) ||
                0
            );
        }

        function applyState() {

            scheduled = false;

            var compact =
                isDesktop() &&
                scrollY() >= COMPACT_AT;

            if (compact) {

                if (
                    !header.classList.contains(
                        'xlx026-header-compact'
                    )
                ) {
                    header.classList.add(
                        'xlx026-header-compact'
                    );
                }

            } else {

                if (
                    header.classList.contains(
                        'xlx026-header-compact'
                    )
                ) {
                    header.classList.remove(
                        'xlx026-header-compact'
                    );
                }
            }
        }

        function schedule() {

            if (scheduled) {
                return;
            }

            scheduled = true;

            if (window.requestAnimationFrame) {

                window.requestAnimationFrame(
                    applyState
                );

            } else {

                window.setTimeout(
                    applyState,
                    16
                );
            }
        }

        window.addEventListener(
            'scroll',
            schedule,
            false
        );

        window.addEventListener(
            'resize',
            schedule,
            false
        );

        if (mq) {

            if (mq.addEventListener) {

                mq.addEventListener(
                    'change',
                    schedule
                );

            } else if (mq.addListener) {

                mq.addListener(
                    schedule
                );
            }
        }

        applyState();
    }

    if (
        document.readyState === 'loading'
    ) {

        document.addEventListener(
            'DOMContentLoaded',
            initHeaderBrasilNeonStickyV1,
            { once: true }
        );

    } else {

        initHeaderBrasilNeonStickyV1();
    }

})();

/* /XLX026_HEADER_BRASIL_NEON_STICKY_V1 */
