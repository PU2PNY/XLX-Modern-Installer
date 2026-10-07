(function () {
    'use strict';

    /*
     * XLXMODERN — ALERTA CERTIFICADO ESPECIAL
     *
     * - somente campanhas especiais
     * - reaparece até o visitante confirmar que já baixou
     * - controle individual por campanha e por data
     * - nova data especial reaparece para todos
     * - nova campanha aparece imediatamente
     * - nunca aparece dentro de /certificado
     * - botão sempre abre:
     *   https://{{REFLECTOR_DOMAIN}}/certificado
     */

    const API =
        '/api/certificado.php?acao=campanha';

    const TARGET =
        'https://{{REFLECTOR_DOMAIN}}/certificado';


    function isCertificatePage() {
        const path = window.location.pathname.replace(/\/+$/, '');
        const params = new URLSearchParams(window.location.search);
        return (
            path === '/certificado'
            || params.get('page') === 'certificado'
        );
    }

    /* XLXMODERN_CERT_ALERT_CONFIRM_DOWNLOAD_V1 */
    const PREFIX =
        'xlxmodern-cert-special-completed-v2:';

    function editionId(campaign) {
        const parts = [
            campaign.id || 'especial',
            campaign.date || '',
            campaign.start_date || campaign.starts_at || '',
            campaign.end_date || campaign.ends_at || '',
            campaign.period_label || '',
            campaign.title || ''
        ];

        return encodeURIComponent(
            parts.map(String).join('|')
        );
    }

    function keyFor(campaign) {
        return PREFIX + editionId(campaign);
    }

    function alreadyDownloaded(campaign) {
        try {
            return Number(
                localStorage.getItem(keyFor(campaign)) || 0
            ) > 0;
        } catch (_) {
            return false;
        }
    }

    function rememberDownloaded(campaign) {
        try {
            localStorage.setItem(
                keyFor(campaign),
                String(Date.now())
            );
        } catch (_) {
        }
    }

    function cleanupOldKeys() {
        try {
            const limit = Date.now() - (730 * 24 * 60 * 60 * 1000);
            for (let i = localStorage.length - 1; i >= 0; i--) {
                const key = localStorage.key(i);
                if (!key || !key.startsWith(PREFIX)) continue;
                const value = Number(localStorage.getItem(key));
                if (!Number.isFinite(value) || value < limit) {
                    localStorage.removeItem(key);
                }
            }
        } catch (_) {
        }
    }

    function installStyle() {
        if (
            document.getElementById(
                'xlxmodern-cert-alert-style'
            )
        ) {
            return;
        }

        const style =
            document.createElement('style');

        style.id =
            'xlxmodern-cert-alert-style';

        style.textContent = `
            #xlxmodern-cert-alert {
                position: fixed;
                inset: 0;
                z-index: 2147483000;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 18px;
                background: rgba(3,17,37,.62);
                backdrop-filter: blur(5px);
            }

            #xlxmodern-cert-alert .xlx-alert-card {
                position: relative;
                width: min(470px, calc(100vw - 32px));
                padding: 27px 24px 23px;
                border: 2px solid #c99a34;
                border-radius: 22px;
                background:
                    linear-gradient(
                        145deg,
                        #ffffff 0%,
                        #f7f9fc 100%
                    );
                box-shadow:
                    0 25px 75px rgba(0,0,0,.32);
                text-align: center;
                font-family: Arial, sans-serif;
            }

            #xlxmodern-cert-alert .xlx-alert-special {
                display: inline-block;
                margin-bottom: 10px;
                color: #b88519;
                font-size: 11px;
                font-weight: 900;
                letter-spacing: .12em;
            }

            #xlxmodern-cert-alert h2 {
                margin: 0 0 10px;
                color: #071b3b;
                font-size: 24px;
                line-height: 1.18;
            }

            #xlxmodern-cert-alert p {
                margin: 0 auto 10px;
                max-width: 395px;
                color: #566779;
                font-size: 14px;
                line-height: 1.5;
            }

            #xlxmodern-cert-alert .xlx-alert-date {
                display: block;
                margin: 13px 0 19px;
                color: #071b3b;
                font-size: 13px;
                font-weight: 900;
            }

            #xlxmodern-cert-alert .xlx-alert-question {
                margin-top: 14px;
                color: #071b3b;
                font-weight: 800;
            }

            #xlxmodern-cert-alert .xlx-alert-actions {
                display: flex;
                justify-content: center;
                gap: 10px;
                flex-wrap: wrap;
            }

            #xlxmodern-cert-alert .xlx-alert-open {
                display: inline-flex;
                align-items: center;
                justify-content: center;
                min-height: 45px;
                padding: 0 21px;
                border: 2px solid #c99a34;
                border-radius: 999px;
                background: #071b3b;
                color: #ffffff;
                text-decoration: none;
                font-size: 14px;
                font-weight: 900;
            }

            #xlxmodern-cert-alert .xlx-alert-close {
                min-height: 45px;
                padding: 0 19px;
                border: 1px solid #cbd3dc;
                border-radius: 999px;
                background: #ffffff;
                color: #526275;
                font-size: 14px;
                font-weight: 800;
                cursor: pointer;
            }

            @media (max-width: 520px) {
                #xlxmodern-cert-alert {
                    padding: 13px;
                }

                #xlxmodern-cert-alert .xlx-alert-card {
                    padding: 23px 17px 20px;
                }

                #xlxmodern-cert-alert h2 {
                    font-size: 21px;
                }
            }
        `;

        document.head.appendChild(style);
    }

    function closeAlert() {
        const alert =
            document.getElementById(
                'xlxmodern-cert-alert'
            );

        if (alert) {
            alert.remove();
        }
    }

    function showAlert(campaign) {
        if (
            document.getElementById(
                'xlxmodern-cert-alert'
            )
        ) {
            return;
        }

        installStyle();

        const overlay =
            document.createElement('div');

        overlay.id =
            'xlxmodern-cert-alert';

        overlay.setAttribute(
            'role',
            'dialog'
        );

        overlay.setAttribute(
            'aria-modal',
            'true'
        );

        const card =
            document.createElement('div');

        card.className =
            'xlx-alert-card';

        const special =
            document.createElement('div');

        special.className =
            'xlx-alert-special';

        special.textContent =
            'CERTIFICADO • EDIÇÃO ESPECIAL';

        const title =
            document.createElement('h2');

        title.textContent =
            campaign.title
            || 'Certificado especial XLXMODERN';

        const subtitle =
            document.createElement('p');

        subtitle.textContent =
            campaign.subtitle
            || 'Uma edição especial está disponível no {{REFLECTOR_TITLE}}.';

        const date =
            document.createElement('span');

        date.className =
            'xlx-alert-date';

        date.textContent =
            campaign.period_label || '';

        const question = document.createElement('p');
        question.className = 'xlx-alert-question';
        question.textContent = 'Você já baixou seu certificado desta edição especial?';

        const actions = document.createElement('div');
        actions.className = 'xlx-alert-actions';

        const yes = document.createElement('button');
        yes.type = 'button';
        yes.className = 'xlx-alert-open';
        yes.textContent = 'Sim, já baixei';
        yes.addEventListener('click', function () {
            rememberDownloaded(campaign);
            closeAlert();
        });

        const no = document.createElement('a');
        no.className = 'xlx-alert-close';
        no.href = TARGET;
        no.textContent = 'Não, gerar agora';

        actions.appendChild(yes);
        actions.appendChild(no);

        card.appendChild(special);
        card.appendChild(title);
        card.appendChild(subtitle);

        if (date.textContent) {
            card.appendChild(date);
        }

        card.appendChild(question);
        card.appendChild(actions);
        overlay.appendChild(card);

        overlay.addEventListener(
            'click',
            function (event) {
                if (event.target === overlay) {
                    closeAlert();
                }
            }
        );

        document.addEventListener(
            'keydown',
            function esc(event) {
                if (event.key === 'Escape') {
                    closeAlert();

                    document.removeEventListener(
                        'keydown',
                        esc
                    );
                }
            }
        );

        document.body.appendChild(overlay);
    }

    async function start() {
        if (isCertificatePage()) {
            return;
        }

        cleanupOldKeys();

        try {
            const response =
                await fetch(
                    API + '&_=' + Date.now(),
                    {
                        cache: 'no-store',
                        headers: {
                            Accept: 'application/json'
                        }
                    }
                );

            if (!response.ok) {
                return;
            }

            const data =
                await response.json();

            if (
                !data
                ||
                !data.ok
                ||
                !data.campaign
                ||
                !data.campaign.special
            ) {
                return;
            }

            const campaign =
                data.campaign;

            if (
                alreadyDownloaded(campaign)
            ) {
                return;
            }

            showAlert(campaign);

        } catch (_) {
            /*
             * Se API/storage falhar,
             * o painel continua funcionando.
             */
        }
    }

    if (
        document.readyState === 'loading'
    ) {
        document.addEventListener(
            'DOMContentLoaded',
            start,
            { once: true }
        );
    } else {
        start();
    }
}());
