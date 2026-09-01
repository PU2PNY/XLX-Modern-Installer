(() => {
    'use strict';

    const STORAGE_KEY = 'xlx026_pwa_install_decision_v1';
    const INSTALL_ACCEPTED = 'installed';
    const INSTALL_DECLINED = 'declined';

    let deferredPrompt = null;
    let invitationShown = false;

    const isIOS = () => {
        const ua = navigator.userAgent || '';
        const appleMobile = /iPad|iPhone|iPod/.test(ua);
        const iPadDesktopMode =
            navigator.platform === 'MacIntel'
            && navigator.maxTouchPoints > 1;

        return appleMobile || iPadDesktopMode;
    };

    const isStandalone = () =>
        window.matchMedia('(display-mode: standalone)').matches
        || window.matchMedia('(display-mode: fullscreen)').matches
        || window.navigator.standalone === true;

    const getDecision = () => {
        try {
            return localStorage.getItem(STORAGE_KEY);
        } catch (_) {
            return null;
        }
    };

    const saveDecision = value => {
        try {
            localStorage.setItem(STORAGE_KEY, value);
        } catch (_) {
            // O navegador pode bloquear armazenamento local.
        }
    };

    const overlay = document.getElementById('xlxInstallOverlay');
    const installButton = document.getElementById('xlxInstallAccept');
    const declineButton = document.getElementById('xlxInstallDecline');
    const description = document.getElementById('xlxInstallDescription');
    const iosSteps = document.getElementById('xlxIosSteps');

    if (!overlay || !installButton || !declineButton) {
        return;
    }

    const hideInvitation = () => {
        overlay.classList.remove('is-visible');
        overlay.setAttribute('aria-hidden', 'true');
        document.body.style.overflow = '';
    };

    const showInvitation = () => {
        if (
            invitationShown
            || getDecision()
            || isStandalone()
        ) {
            return;
        }

        invitationShown = true;
        overlay.classList.add('is-visible');
        overlay.setAttribute('aria-hidden', 'false');
        document.body.style.overflow = 'hidden';
        installButton.focus();
    };

    const configureIOS = () => {
        description.textContent =
            'Adicione o {{REFLECTOR_NAME}} à Tela de Início para abrir o painel como um aplicativo.';

        installButton.textContent = 'Ver como instalar';
    };

    window.addEventListener('beforeinstallprompt', event => {
        event.preventDefault();
        deferredPrompt = event;

        window.setTimeout(showInvitation, 900);
    });

    window.addEventListener('appinstalled', () => {
        saveDecision(INSTALL_ACCEPTED);
        deferredPrompt = null;
        hideInvitation();
    });

    declineButton.addEventListener('click', () => {
        saveDecision(INSTALL_DECLINED);
        hideInvitation();
    });

    installButton.addEventListener('click', async () => {
        if (isIOS()) {
            iosSteps.classList.add('is-visible');
            installButton.textContent = 'Entendi';

            if (installButton.dataset.iosInstructions === 'shown') {
                saveDecision(INSTALL_ACCEPTED);
                hideInvitation();
                return;
            }

            installButton.dataset.iosInstructions = 'shown';
            return;
        }

        if (deferredPrompt) {
            const promptEvent = deferredPrompt;
            deferredPrompt = null;

            await promptEvent.prompt();

            try {
                const result = await promptEvent.userChoice;

                saveDecision(
                    result.outcome === 'accepted'
                        ? INSTALL_ACCEPTED
                        : INSTALL_DECLINED
                );
            } catch (_) {
                saveDecision(INSTALL_DECLINED);
            }

            hideInvitation();
            return;
        }

        /*
         * Navegador sem beforeinstallprompt:
         * mostra instrução genérica apenas nesta primeira visita.
         */
        description.textContent =
            'Abra o menu do navegador e escolha “Instalar aplicativo” ou “Adicionar à tela inicial”.';

        iosSteps.textContent =
            'No menu do navegador, procure por “Instalar aplicativo”, “Aplicativos” ou “Adicionar à tela inicial”.';

        iosSteps.classList.add('is-visible');
        installButton.textContent = 'Entendi';

        if (installButton.dataset.genericInstructions === 'shown') {
            saveDecision(INSTALL_ACCEPTED);
            hideInvitation();
            return;
        }

        installButton.dataset.genericInstructions = 'shown';
    });

    document.addEventListener('keydown', event => {
        if (
            event.key === 'Escape'
            && overlay.classList.contains('is-visible')
        ) {
            saveDecision(INSTALL_DECLINED);
            hideInvitation();
        }
    });

    if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
            navigator.serviceWorker.register('/sw.js', {
                scope: '/'
            }).catch(() => {
                // O painel continua funcionando normalmente.
            });
        });
    }

    if (isStandalone()) {
        saveDecision(INSTALL_ACCEPTED);
        return;
    }

    if (getDecision()) {
        return;
    }

    if (isIOS()) {
        configureIOS();
        window.setTimeout(showInvitation, 1400);
        return;
    }

    /*
     * Em navegadores compatíveis, esperamos o evento nativo.
     * Após alguns segundos, exibimos orientação genérica somente
     * quando o navegador não fornecer o evento.
     */
    window.setTimeout(() => {
        if (!deferredPrompt && !getDecision()) {
            showInvitation();
        }
    }, 4500);
})();
