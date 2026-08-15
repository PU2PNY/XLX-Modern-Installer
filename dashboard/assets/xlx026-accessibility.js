(function () {
    'use strict';

    if (window.__XLX026_ACCESSIBILITY_V3__) {
        return;
    }

    window.__XLX026_ACCESSIBILITY_V3__ = true;

    var STORAGE_KEY = 'xlx026_accessibility_v3';

    var FONT_VALUES = [
        90,
        100,
        125,
        150,
        175,
        200
    ];

    var state = {
        font: 100,
        contrast: false,
        motion: false,
        links: false,
        controls: false,
        readable: false
    };

    var mutationObserver = null;

    /* ==============================================================
       STORAGE
    ============================================================== */

    function loadState() {
        var raw;
        var parsed;
        var old;

        try {
            raw = localStorage.getItem(STORAGE_KEY);

            if (raw) {
                parsed = JSON.parse(raw);

                if (FONT_VALUES.indexOf(Number(parsed.font)) !== -1) {
                    state.font = Number(parsed.font);
                }

                state.contrast = parsed.contrast === true;
                state.motion = parsed.motion === true;
                state.links = parsed.links === true;
                state.controls = parsed.controls === true;
                state.readable = parsed.readable === true;

                return;
            }

            /*
             * Migração simples das preferências V2.
             */
            raw = localStorage.getItem('xlx026_a11y_v2');

            if (raw) {
                old = JSON.parse(raw);

                if (old.font === -1) {
                    state.font = 90;
                }

                if (old.font === 0) {
                    state.font = 100;
                }

                if (old.font === 1) {
                    state.font = 125;
                }

                if (old.font === 2) {
                    state.font = 150;
                }

                if (old.font === 3) {
                    state.font = 175;
                }

                state.contrast = old.contrast === true;
                state.motion = old.motion === true;
                state.links = old.links === true;
                state.controls = old.controls === true;
                state.readable = old.readable === true;
            }

        } catch (e) {}
    }

    function saveState() {
        try {
            localStorage.setItem(
                STORAGE_KEY,
                JSON.stringify(state)
            );
        } catch (e) {}
    }

    /* ==============================================================
       CLASSES
    ============================================================== */

    function setClass(name, enabled) {
        var root = document.documentElement;

        if (root.classList) {
            root.classList.toggle(name, !!enabled);
            return;
        }

        var current = root.className || '';
        var expression =
            new RegExp(
                '(?:^|\\s)' +
                name +
                '(?!\\S)',
                'g'
            );

        current =
            current
                .replace(expression, '')
                .replace(/\s+/g, ' ')
                .replace(/^\s+|\s+$/g, '');

        if (enabled) {
            current +=
                (current ? ' ' : '') +
                name;
        }

        root.className = current;
    }

    /* ==============================================================
       ESCALA DE TEXTO
       Escala o tamanho computado original.
       Isso também funciona em elementos definidos em px.
    ============================================================== */

    function insideAccessibility(el) {
        var p = el;

        while (p) {
            if (
                p.id === 'xlx-a11y-panel' ||
                p.id === 'xlx-a11y-launcher'
            ) {
                return true;
            }

            p = p.parentNode;
        }

        return false;
    }

    function hasDirectText(el) {
        var tag = String(el.tagName || '').toUpperCase();
        var nodes;
        var i;

        if (
            tag === 'INPUT' ||
            tag === 'SELECT' ||
            tag === 'TEXTAREA' ||
            tag === 'BUTTON' ||
            tag === 'SUMMARY'
        ) {
            return true;
        }

        nodes = el.childNodes;

        for (i = 0; i < nodes.length; i++) {
            if (
                nodes[i].nodeType === 3 &&
                String(nodes[i].nodeValue || '')
                    .replace(/\s+/g, '') !== ''
            ) {
                return true;
            }
        }

        return false;
    }

    function validTextElement(el) {
        var tag;

        if (
            !el ||
            el.nodeType !== 1 ||
            insideAccessibility(el)
        ) {
            return false;
        }

        tag = String(el.tagName || '').toUpperCase();

        if (
            tag === 'SCRIPT' ||
            tag === 'STYLE' ||
            tag === 'NOSCRIPT' ||
            tag === 'SVG' ||
            tag === 'PATH' ||
            tag === 'IMG' ||
            tag === 'VIDEO' ||
            tag === 'AUDIO' ||
            tag === 'CANVAS' ||
            tag === 'BR' ||
            tag === 'HR'
        ) {
            return false;
        }

        return hasDirectText(el);
    }

    function restoreFontElement(el) {
        var original;

        if (
            !el ||
            !el.getAttribute
        ) {
            return;
        }

        if (
            el.getAttribute(
                'data-xlx-a11y-font-managed'
            ) !== '1'
        ) {
            return;
        }

        original = el.getAttribute(
            'data-xlx-a11y-original-inline-font'
        );

        if (
            original === null ||
            original === '__EMPTY__'
        ) {
            el.style.removeProperty('font-size');
        } else {
            el.style.fontSize = original;
        }

        el.removeAttribute(
            'data-xlx-a11y-font-managed'
        );

        el.removeAttribute(
            'data-xlx-a11y-base-font'
        );

        el.removeAttribute(
            'data-xlx-a11y-original-inline-font'
        );
    }

    function scaleFontElement(el, percent) {
        var computed;
        var base;
        var original;

        if (!validTextElement(el)) {
            return;
        }

        if (percent === 100) {
            restoreFontElement(el);
            return;
        }

        if (
            el.getAttribute(
                'data-xlx-a11y-font-managed'
            ) !== '1'
        ) {
            computed =
                window.getComputedStyle
                    ? window.getComputedStyle(el, null)
                    : el.currentStyle;

            if (
                !computed ||
                !computed.fontSize
            ) {
                return;
            }

            base = parseFloat(computed.fontSize);

            if (
                !isFinite(base) ||
                base <= 0
            ) {
                return;
            }

            original = el.style.fontSize;

            el.setAttribute(
                'data-xlx-a11y-original-inline-font',
                original || '__EMPTY__'
            );

            el.setAttribute(
                'data-xlx-a11y-base-font',
                String(base)
            );

            el.setAttribute(
                'data-xlx-a11y-font-managed',
                '1'
            );
        } else {
            base = parseFloat(
                el.getAttribute(
                    'data-xlx-a11y-base-font'
                )
            );
        }

        if (
            !isFinite(base) ||
            base <= 0
        ) {
            return;
        }

        el.style.fontSize =
            (base * percent / 100)
                .toFixed(2) +
            'px';
    }

    function scaleTree(root) {
        var all;
        var i;

        if (!root) {
            return;
        }

        if (
            root.nodeType === 1
        ) {
            scaleFontElement(
                root,
                state.font
            );
        }

        if (!root.querySelectorAll) {
            return;
        }

        all = root.querySelectorAll('*');

        for (i = 0; i < all.length; i++) {
            scaleFontElement(
                all[i],
                state.font
            );
        }
    }

    function applyFontSize() {
        scaleTree(document.body);
    }

    function watchDynamicContent() {
        if (
            !window.MutationObserver ||
            mutationObserver
        ) {
            return;
        }

        mutationObserver =
            new MutationObserver(
                function (mutations) {
                    var i;
                    var j;
                    var added;

                    if (state.font === 100) {
                        return;
                    }

                    for (
                        i = 0;
                        i < mutations.length;
                        i++
                    ) {
                        added =
                            mutations[i].addedNodes;

                        for (
                            j = 0;
                            j < added.length;
                            j++
                        ) {
                            if (
                                added[j].nodeType === 1
                            ) {
                                scaleTree(added[j]);
                            }
                        }
                    }
                }
            );

        mutationObserver.observe(
            document.body,
            {
                childList: true,
                subtree: true
            }
        );
    }

    /* ==============================================================
       ESTADO
    ============================================================== */

    function updateSwitch(name, value) {
        var el =
            document.getElementById(
                'xlx-opt-' + name
            );

        if (el) {
            el.setAttribute(
                'aria-checked',
                value ? 'true' : 'false'
            );
        }
    }

    function applyState(announceChange) {
        var fontValue =
            document.getElementById(
                'xlx-font-value'
            );

        setClass(
            'xlx-a11y-contrast',
            state.contrast
        );

        setClass(
            'xlx-a11y-motion',
            state.motion
        );

        setClass(
            'xlx-a11y-links',
            state.links
        );

        setClass(
            'xlx-a11y-controls',
            state.controls
        );

        setClass(
            'xlx-a11y-readable',
            state.readable
        );

        applyFontSize();

        updateSwitch(
            'contrast',
            state.contrast
        );

        updateSwitch(
            'motion',
            state.motion
        );

        updateSwitch(
            'links',
            state.links
        );

        updateSwitch(
            'controls',
            state.controls
        );

        updateSwitch(
            'readable',
            state.readable
        );

        if (fontValue) {
            fontValue.innerHTML =
                String(state.font) + '%';
        }

        saveState();

        if (announceChange) {
            announce(
                'Preferências de acessibilidade atualizadas.'
            );
        }
    }

    /* ==============================================================
       ARIA STATUS
    ============================================================== */

    function announce(text) {
        var status =
            document.getElementById(
                'xlx-a11y-status'
            );

        if (!status) {
            return;
        }

        status.innerHTML = '';

        setTimeout(
            function () {
                status.appendChild(
                    document.createTextNode(text)
                );
            },
            25
        );
    }

    /* ==============================================================
       CONTEÚDO PRINCIPAL
    ============================================================== */

    function findMainContent() {
        return (
            document.getElementsByTagName(
                'main'
            )[0] ||

            document.querySelector(
                '[role="main"]'
            ) ||

            document.getElementById(
                'main'
            ) ||

            document.getElementById(
                'content'
            ) ||

            document.querySelector(
                '.main-content'
            ) ||

            document.querySelector(
                '.content'
            )
        );
    }

    function createSkipLink() {
        var target =
            findMainContent();

        var skip;

        if (!target) {
            return;
        }

        if (!target.id) {
            target.id =
                'xlx-main-content';
        }

        if (
            !target.getAttribute(
                'tabindex'
            )
        ) {
            target.setAttribute(
                'tabindex',
                '-1'
            );
        }

        skip =
            document.createElement('a');

        skip.id =
            'xlx-a11y-skip';

        skip.href =
            '#' + target.id;

        skip.appendChild(
            document.createTextNode(
                'Pular para o conteúdo principal'
            )
        );

        skip.onclick =
            function () {
                setTimeout(
                    function () {
                        try {
                            target.focus();
                        } catch (e) {}
                    },
                    20
                );
            };

        document.body.insertBefore(
            skip,
            document.body.firstChild
        );
    }

    /* ==============================================================
       MENU
    ============================================================== */

    function validMenu(menu) {
        var p = menu;

        if (!menu) {
            return false;
        }

        while (p) {
            if (
                p.id === 'xlx-a11y-panel' ||
                String(
                    p.tagName || ''
                ).toUpperCase() === 'FOOTER'
            ) {
                return false;
            }

            p = p.parentNode;
        }

        return true;
    }

    function findMenu() {
        var selectors = [
            'header nav ul',
            'header .navbar-nav',
            'header .nav-menu',
            'nav.navbar ul',
            'nav .navbar-nav',
            '.main-nav ul',
            '.main-menu ul',
            '.nav-menu',
            '.navbar-nav',
            'header nav',
            'nav ul'
        ];

        var i;
        var el;

        for (
            i = 0;
            i < selectors.length;
            i++
        ) {
            try {
                el =
                    document.querySelector(
                        selectors[i]
                    );

                if (validMenu(el)) {
                    return el;
                }
            } catch (e) {}
        }

        return null;
    }

    function putLauncherInMenu() {
        var launcher =
            document.getElementById(
                'xlx-a11y-launcher'
            );

        var menu =
            findMenu();

        var tag;
        var holder;

        if (
            !launcher ||
            !menu ||
            launcher.getAttribute(
                'data-in-menu'
            ) === '1'
        ) {
            return;
        }

        tag =
            String(
                menu.tagName || ''
            ).toUpperCase();

        if (
            tag === 'UL' ||
            tag === 'OL'
        ) {
            holder =
                document.createElement('li');

            holder.className =
                'xlx-a11y-menu-holder';

            holder.appendChild(
                launcher
            );

            menu.appendChild(
                holder
            );
        } else {
            menu.appendChild(
                launcher
            );
        }

        launcher.className +=
            ' xlx-a11y-in-menu';

        launcher.setAttribute(
            'data-in-menu',
            '1'
        );
    }

    /* ==============================================================
       INTERFACE
    ============================================================== */

    function optionHTML(id, text) {
        return (
            '<button ' +
                'type="button" ' +
                'class="xlx-a11y-option" ' +
                'role="switch" ' +
                'aria-checked="false" ' +
                'id="xlx-opt-' +
                id +
            '">' +

                '<span>' +
                    text +
                '</span>' +

            '</button>'
        );
    }

    function createInterface() {
        var launcher;
        var trigger;
        var hide;
        var panel;
        var status;

        if (
            document.getElementById(
                'xlx-a11y-launcher'
            )
        ) {
            return;
        }

        launcher =
            document.createElement('div');

        launcher.id =
            'xlx-a11y-launcher';

        trigger =
            document.createElement('button');

        trigger.id =
            'xlx-a11y-trigger';

        trigger.type =
            'button';

        trigger.setAttribute(
            'aria-haspopup',
            'dialog'
        );

        trigger.setAttribute(
            'aria-expanded',
            'false'
        );

        trigger.setAttribute(
            'aria-controls',
            'xlx-a11y-panel'
        );

        trigger.setAttribute(
            'aria-label',
            'Abrir opções de acessibilidade'
        );

        trigger.innerHTML =
            '<span aria-hidden="true">♿</span> ' +
            '<span class="xlx-a11y-trigger-text">' +
                'Acessibilidade' +
            '</span>';

        hide =
            document.createElement('button');

        hide.id =
            'xlx-a11y-hide';

        hide.type =
            'button';

        hide.setAttribute(
            'aria-label',
            'Ocultar o botão de acessibilidade desta página'
        );

        hide.setAttribute(
            'title',
            'Ocultar desta página'
        );

        hide.innerHTML =
            '&times;';

        launcher.appendChild(
            trigger
        );

        launcher.appendChild(
            hide
        );

        panel =
            document.createElement('div');

        panel.id =
            'xlx-a11y-panel';

        panel.hidden =
            true;

        panel.setAttribute(
            'role',
            'dialog'
        );

        panel.setAttribute(
            'aria-labelledby',
            'xlx-a11y-title'
        );

        panel.innerHTML =
            '<div class="xlx-a11y-head">' +

                '<strong id="xlx-a11y-title">' +
                    '♿ Acessibilidade' +
                '</strong>' +

                '<button ' +
                    'type="button" ' +
                    'id="xlx-a11y-close" ' +
                    'aria-label="Fechar painel de acessibilidade">' +
                    '&times;' +
                '</button>' +

            '</div>' +

            '<div class="xlx-a11y-body">' +

                '<p class="xlx-a11y-description">' +
                    'Personalize a visualização do XLX026. ' +
                    'A voz das conexões e os bips de transmissão não são alterados.' +
                '</p>' +

                '<span class="xlx-a11y-label">' +
                    'Tamanho do texto' +
                '</span>' +

                '<div class="xlx-a11y-font-controls">' +

                    '<button ' +
                        'type="button" ' +
                        'id="xlx-font-down" ' +
                        'aria-label="Diminuir tamanho do texto">' +
                        'A−' +
                    '</button>' +

                    '<button ' +
                        'type="button" ' +
                        'id="xlx-font-reset" ' +
                        'aria-label="Restaurar texto para 100 por cento">' +

                        '<span id="xlx-font-value">' +
                            '100%' +
                        '</span>' +

                    '</button>' +

                    '<button ' +
                        'type="button" ' +
                        'id="xlx-font-up" ' +
                        'aria-label="Aumentar tamanho do texto">' +
                        'A+' +
                    '</button>' +

                '</div>' +

                optionHTML(
                    'contrast',
                    'Alto contraste'
                ) +

                optionHTML(
                    'motion',
                    'Reduzir animações da interface'
                ) +

                optionHTML(
                    'links',
                    'Destacar links'
                ) +

                optionHTML(
                    'controls',
                    'Controles maiores'
                ) +

                optionHTML(
                    'readable',
                    'Leitura facilitada'
                ) +

                '<div class="xlx-a11y-actions">' +

                    '<button ' +
                        'type="button" ' +
                        'id="xlx-a11y-test">' +
                        'Testar recursos' +
                    '</button>' +

                    '<button ' +
                        'type="button" ' +
                        'id="xlx-a11y-reset">' +
                        'Restaurar padrão' +
                    '</button>' +

                '</div>' +

                '<div ' +
                    'id="xlx-a11y-diagnostic" ' +
                    'aria-live="polite">' +
                '</div>' +

                '<p class="xlx-a11y-description" ' +
                    'style="font-size:12px;margin-top:13px">' +

                    'Atalho: Alt + A. ' +
                    'O × ao lado do botão apenas o oculta desta página; ' +
                    'ao recarregar ele aparece novamente.' +

                '</p>' +

            '</div>';

        status =
            document.createElement('div');

        status.id =
            'xlx-a11y-status';

        status.className =
            'xlx-a11y-sr';

        status.setAttribute(
            'role',
            'status'
        );

        status.setAttribute(
            'aria-live',
            'polite'
        );

        status.setAttribute(
            'aria-atomic',
            'true'
        );

        document.body.appendChild(
            launcher
        );

        document.body.appendChild(
            panel
        );

        document.body.appendChild(
            status
        );

        bindInterface(
            launcher,
            trigger,
            hide,
            panel
        );

        setTimeout(
            putLauncherInMenu,
            100
        );

        setTimeout(
            putLauncherInMenu,
            500
        );

        setTimeout(
            putLauncherInMenu,
            1500
        );
    }

    /* ==============================================================
       ABRIR / FECHAR
    ============================================================== */

    function showLauncher(launcher) {
        var holder =
            launcher.parentNode;

        launcher.style.display = '';

        if (
            holder &&
            String(
                holder.tagName || ''
            ).toUpperCase() === 'LI' &&
            holder.className.indexOf(
                'xlx-a11y-menu-holder'
            ) !== -1
        ) {
            holder.style.display = '';
        }
    }

    function hideLauncher(
        launcher,
        panel
    ) {
        var holder =
            launcher.parentNode;

        panel.hidden = true;

        launcher.style.display =
            'none';

        if (
            holder &&
            String(
                holder.tagName || ''
            ).toUpperCase() === 'LI' &&
            holder.className.indexOf(
                'xlx-a11y-menu-holder'
            ) !== -1
        ) {
            holder.style.display =
                'none';
        }
    }

    function openPanel(
        launcher,
        trigger,
        panel
    ) {
        showLauncher(
            launcher
        );

        panel.hidden =
            false;

        trigger.setAttribute(
            'aria-expanded',
            'true'
        );

        try {
            document
                .getElementById(
                    'xlx-a11y-close'
                )
                .focus();
        } catch (e) {}
    }

    function closePanel(
        trigger,
        panel
    ) {
        panel.hidden =
            true;

        trigger.setAttribute(
            'aria-expanded',
            'false'
        );

        try {
            trigger.focus();
        } catch (e) {}
    }

    /* ==============================================================
       FONT CONTROLS
    ============================================================== */

    function fontIndex() {
        var i;

        for (
            i = 0;
            i < FONT_VALUES.length;
            i++
        ) {
            if (
                FONT_VALUES[i] ===
                state.font
            ) {
                return i;
            }
        }

        return 1;
    }

    /* ==============================================================
       DIAGNÓSTICO INTERNO
    ============================================================== */

    function storageAvailable() {
        var test =
            '__xlx_a11y_test__';

        try {
            localStorage.setItem(
                test,
                '1'
            );

            localStorage.removeItem(
                test
            );

            return true;
        } catch (e) {
            return false;
        }
    }

    function stylesheetLoaded() {
        var sheets =
            document.styleSheets;

        var i;
        var href;

        for (
            i = 0;
            i < sheets.length;
            i++
        ) {
            href =
                String(
                    sheets[i].href || ''
                );

            if (
                href.indexOf(
                    'xlx026-accessibility.css'
                ) !== -1
            ) {
                return true;
            }
        }

        return false;
    }

    function runDiagnostic() {
        var result =
            document.getElementById(
                'xlx-a11y-diagnostic'
            );

        var checks = [];
        var passed = 0;
        var i;
        var html;

        checks.push({
            label:
                'CSS de acessibilidade carregado',
            ok:
                stylesheetLoaded()
        });

        checks.push({
            label:
                'Conteúdo principal detectado',
            ok:
                !!findMainContent()
        });

        checks.push({
            label:
                'Menu principal detectado',
            ok:
                !!findMenu()
        });

        checks.push({
            label:
                'Preferências locais disponíveis',
            ok:
                storageAvailable()
        });

        checks.push({
            label:
                'Atualização dinâmica suportada',
            ok:
                !!window.MutationObserver
        });

        checks.push({
            label:
                'Status para leitor de tela ativo',
            ok:
                !!document.getElementById(
                    'xlx-a11y-status'
                )
        });

        html =
            '<strong>Teste interno</strong>';

        for (
            i = 0;
            i < checks.length;
            i++
        ) {
            if (checks[i].ok) {
                passed++;
            }

            html +=
                '<div>' +
                    (
                        checks[i].ok
                            ? '✓ '
                            : '⚠ '
                    ) +
                    checks[i].label +
                '</div>';
        }

        html +=
            '<div style="margin-top:6px;font-weight:bold">' +
                passed +
                '/' +
                checks.length +
                ' verificações disponíveis' +
            '</div>';

        result.innerHTML =
            html;

        result.className =
            'xlx-show';

        announce(
            'Teste interno de acessibilidade concluído.'
        );
    }

    /* ==============================================================
       EVENTOS
    ============================================================== */

    function bindInterface(
        launcher,
        trigger,
        hide,
        panel
    ) {
        var close =
            document.getElementById(
                'xlx-a11y-close'
            );

        var down =
            document.getElementById(
                'xlx-font-down'
            );

        var up =
            document.getElementById(
                'xlx-font-up'
            );

        var fontReset =
            document.getElementById(
                'xlx-font-reset'
            );

        var reset =
            document.getElementById(
                'xlx-a11y-reset'
            );

        var test =
            document.getElementById(
                'xlx-a11y-test'
            );

        trigger.onclick =
            function () {
                if (panel.hidden) {
                    openPanel(
                        launcher,
                        trigger,
                        panel
                    );
                } else {
                    closePanel(
                        trigger,
                        panel
                    );
                }
            };

        hide.onclick =
            function (event) {
                if (event) {
                    if (
                        event.preventDefault
                    ) {
                        event.preventDefault();
                    }

                    if (
                        event.stopPropagation
                    ) {
                        event.stopPropagation();
                    }
                }

                hideLauncher(
                    launcher,
                    panel
                );
            };

        close.onclick =
            function () {
                closePanel(
                    trigger,
                    panel
                );
            };

        down.onclick =
            function () {
                var index =
                    fontIndex();

                if (index > 0) {
                    state.font =
                        FONT_VALUES[
                            index - 1
                        ];
                }

                applyState(true);
            };

        up.onclick =
            function () {
                var index =
                    fontIndex();

                if (
                    index <
                    FONT_VALUES.length - 1
                ) {
                    state.font =
                        FONT_VALUES[
                            index + 1
                        ];
                }

                applyState(true);
            };

        fontReset.onclick =
            function () {
                state.font = 100;

                applyState(true);
            };

        function bindOption(name) {
            var el =
                document.getElementById(
                    'xlx-opt-' + name
                );

            el.onclick =
                function () {
                    state[name] =
                        !state[name];

                    applyState(true);
                };
        }

        bindOption('contrast');
        bindOption('motion');
        bindOption('links');
        bindOption('controls');
        bindOption('readable');

        reset.onclick =
            function () {
                state.font = 100;
                state.contrast = false;
                state.motion = false;
                state.links = false;
                state.controls = false;
                state.readable = false;

                applyState(false);

                announce(
                    'Configurações restauradas para o padrão.'
                );
            };

        test.onclick =
            runDiagnostic;

        document.addEventListener(
            'keydown',
            function (event) {
                var key =
                    event.key ||
                    String.fromCharCode(
                        event.keyCode || 0
                    );

                if (
                    event.altKey &&
                    String(key)
                        .toLowerCase() ===
                        'a'
                ) {
                    if (
                        event.preventDefault
                    ) {
                        event.preventDefault();
                    }

                    if (panel.hidden) {
                        openPanel(
                            launcher,
                            trigger,
                            panel
                        );
                    } else {
                        closePanel(
                            trigger,
                            panel
                        );
                    }

                    return;
                }

                if (
                    (
                        key === 'Escape' ||
                        event.keyCode === 27
                    ) &&
                    !panel.hidden
                ) {
                    closePanel(
                        trigger,
                        panel
                    );
                }
            },
            false
        );
    }

    /* ==============================================================
       INICIALIZAÇÃO
    ============================================================== */

    function init() {
        if (
            !document.documentElement.lang
        ) {
            document.documentElement.lang =
                'pt-BR';
        }

        loadState();

        createSkipLink();

        createInterface();

        applyState(false);

        watchDynamicContent();
    }

    if (
        document.readyState ===
        'loading'
    ) {
        document.addEventListener(
            'DOMContentLoaded',
            init,
            false
        );
    } else {
        init();
    }

})();
