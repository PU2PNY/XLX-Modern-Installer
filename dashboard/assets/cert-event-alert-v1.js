(() => {
    'use strict';

    const currentPage =
        document.body?.dataset?.page || '';

    if (currentPage === 'certificado') {
        return;
    }

    const endpoint =
        '/api/certificado.php?acao=campanha';

    const prefix =
        'xlx026CertSpecialSeen:';

    function hasSeen(id) {
        try {
            return Boolean(
                localStorage.getItem(
                    prefix + id
                )
            );
        } catch (_) {
            return true;
        }
    }

    function setSeen(id) {
        try {
            localStorage.setItem(
                prefix + id,
                String(Date.now())
            );
        } catch (_) {}
    }

    function element(
        tag,
        className,
        text
    ) {
        const el =
            document.createElement(tag);

        if (className) {
            el.className =
                className;
        }

        if (text !== undefined) {
            el.textContent =
                text;
        }

        return el;
    }

    function installPopupOpen() {
        const overlay =
            document.getElementById(
                'xlxInstallOverlay'
            );

        return Boolean(
            overlay
            && overlay.classList.contains(
                'is-visible'
            )
        );
    }

    function render(campaign) {

        if (
            !campaign
            || campaign.special !== true
            || !campaign.id
            || hasSeen(campaign.id)
        ) {
            return;
        }

        const card =
            element(
                'aside',
                'xlx-cert-special-alert'
            );

        card.setAttribute(
            'role',
            'status'
        );

        card.setAttribute(
            'aria-live',
            'polite'
        );

        const inner =
            element(
                'div',
                'xlx-cert-special-inner'
            );

        const close =
            element(
                'button',
                'xlx-cert-special-close',
                '×'
            );

        close.type = 'button';

        close.setAttribute(
            'aria-label',
            'Fechar aviso'
        );

        const kicker =
            element(
                'span',
                'xlx-cert-special-kicker',
                'CERTIFICADO ESPECIAL DISPONÍVEL'
            );

        const title =
            element(
                'h2',
                '',
                campaign.title
            );

        const description =
            element(
                'p',
                '',
                campaign.subtitle
            );

        const period =
            element(
                'span',
                'xlx-cert-special-period',
                'Período: '
                + campaign.period_label
            );

        const actions =
            element(
                'div',
                'xlx-cert-special-actions'
            );

        const button =
            element(
                'a',
                'xlx-cert-special-button',
                'Gerar meu certificado'
            );

        button.href =
            '/?page=certificado';

        const note =
            element(
                'span',
                'xlx-cert-special-note',
                'Edição comemorativa XLX026 Brasil'
            );

        close.addEventListener(
            'click',
            () => {

                card.classList.remove(
                    'visible'
                );

                setTimeout(
                    () => card.remove(),
                    350
                );
            }
        );

        actions.append(
            button,
            note
        );

        inner.append(
            close,
            kicker,
            title,
            description,
            period,
            actions
        );

        card.append(inner);

        document.body.append(card);

        setSeen(campaign.id);

        requestAnimationFrame(
            () => {
                requestAnimationFrame(
                    () => {
                        card.classList.add(
                            'visible'
                        );
                    }
                );
            }
        );
    }

    function waitForInstall(
        campaign,
        attempt = 0
    ) {

        if (
            installPopupOpen()
            && attempt < 120
        ) {
            setTimeout(
                () => waitForInstall(
                    campaign,
                    attempt + 1
                ),
                500
            );

            return;
        }

        if (!installPopupOpen()) {
            render(campaign);
        }
    }

    async function start() {

        try {

            const response =
                await fetch(
                    endpoint
                    + '&_='
                    + Date.now(),
                    {
                        cache: 'no-store',
                        credentials: 'same-origin'
                    }
                );

            if (!response.ok) {
                return;
            }

            const data =
                await response.json();

            const campaign =
                data?.campaign
                || data?.data?.campaign
                || (
                    data?.id
                        ? data
                        : null
                );

            if (
                !campaign
                || campaign.special !== true
                || !campaign.id
                || hasSeen(campaign.id)
            ) {
                return;
            }

            waitForInstall(
                campaign
            );

        } catch (_) {}
    }

    start();
})();
