/* ================================================================
   XLX MODERN — FIXED HEADER V2

   The original header is never resized. A separate fixed bar is created
   outside document flow, avoiding scroll feedback/oscillation.

   IMPORTANT: reflector identity is read from the already-rendered dashboard.
   No reflector number, country or regional label is hardcoded here.
   ================================================================ */

(function () {
    'use strict';

    if (window.__XLX_MODERN_FIXED_HEADER_V2__) {
        return;
    }

    window.__XLX_MODERN_FIXED_HEADER_V2__ = true;

    var DESKTOP = '(min-width: 821px)';

    function cleanText(value) {
        return String(value || '')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function reflectorIdentity(header) {
        var meta = document.querySelector('meta[property="og:site_name"]');
        var fromMeta = meta ? cleanText(meta.getAttribute('content')) : '';
        if (fromMeta) {
            return fromMeta;
        }

        var title = header.querySelector('.universal-copy h1');
        var fromTitle = title ? cleanText(title.textContent) : '';
        if (fromTitle) {
            return fromTitle;
        }

        var logo = header.querySelector('.hero-logo');
        var alt = logo ? cleanText(logo.getAttribute('alt')) : '';
        if (alt) {
            return cleanText(alt.split('—')[0]);
        }

        return 'XLX';
    }

    function init() {
        var header = document.querySelector('section.universal-header');
        if (!header) {
            return;
        }

        var originalNav = header.querySelector('.universal-nav');
        if (!originalNav) {
            return;
        }

        var originalBrand = header.querySelector('.universal-brand');
        var reflectorName = reflectorIdentity(header);

        /* Defensive cleanup from legacy compact-header experiments. */
        header.classList.remove('xlx026-header-compact');

        var fixed = document.createElement('div');
        fixed.className = 'xlx026-fixed-header-v2';
        fixed.setAttribute('aria-hidden', 'true');

        var inner = document.createElement('div');
        inner.className = 'xlx026-fixed-inner-v2';

        var brand = document.createElement('a');
        brand.className = 'xlx026-fixed-brand-v2';
        brand.href = originalBrand
            ? (originalBrand.getAttribute('href') || '/?page=ao-vivo')
            : '/?page=ao-vivo';
        brand.setAttribute('aria-label', reflectorName + ' — Ao vivo');

        var code = document.createElement('span');
        code.className = 'xlx026-fixed-code-v2';
        code.textContent = reflectorName;
        brand.appendChild(code);

        /* Clone the real current navigation, including optional Admin/APRS. */
        var nav = originalNav.cloneNode(true);
        nav.classList.add('xlx026-fixed-nav-v2');
        nav.setAttribute('aria-label', 'Menu principal fixo');

        if (nav.hasAttribute('id')) {
            nav.removeAttribute('id');
        }

        var nodesWithId = nav.querySelectorAll('[id]');
        for (var i = 0; i < nodesWithId.length; i++) {
            nodesWithId[i].removeAttribute('id');
        }

        /* Do not clone interactive buttons into the fixed navigation. */
        var buttons = nav.querySelectorAll('button');
        for (var b = 0; b < buttons.length; b++) {
            if (buttons[b].parentNode) {
                buttons[b].parentNode.removeChild(buttons[b]);
            }
        }

        inner.appendChild(brand);
        inner.appendChild(nav);
        fixed.appendChild(inner);
        document.body.appendChild(fixed);

        var media = window.matchMedia
            ? window.matchMedia(DESKTOP)
            : null;
        var queued = false;

        function update() {
            queued = false;

            var desktop = media && media.matches;
            if (!desktop) {
                fixed.classList.remove('is-visible');
                fixed.setAttribute('aria-hidden', 'true');
                return;
            }

            var rect = header.getBoundingClientRect();
            var show = rect.bottom <= 64;

            if (show) {
                fixed.classList.add('is-visible');
                fixed.setAttribute('aria-hidden', 'false');
            } else {
                fixed.classList.remove('is-visible');
                fixed.setAttribute('aria-hidden', 'true');
            }
        }

        function schedule() {
            if (queued) {
                return;
            }

            queued = true;
            if (window.requestAnimationFrame) {
                window.requestAnimationFrame(update);
            } else {
                window.setTimeout(update, 16);
            }
        }

        window.addEventListener('scroll', schedule, { passive: true });
        window.addEventListener('resize', schedule, false);

        if (media) {
            if (media.addEventListener) {
                media.addEventListener('change', schedule);
            } else if (media.addListener) {
                media.addListener(schedule);
            }
        }

        update();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init, { once: true });
    } else {
        init();
    }
})();
