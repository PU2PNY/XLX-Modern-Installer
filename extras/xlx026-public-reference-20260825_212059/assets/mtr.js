'use strict';

(() => {
    const INTERVAL = 3000;
    const MAX_WIDGETS = 3;

    let updateTimer = null;
    let widgets = [];

    const escapeHtml = value =>
        String(value ?? '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#039;');

    function txKey(module) {
        const tx =
            module.transmission || {};

        return String(
            tx.key
            || `${module.module}:${tx.stream_id || ''}`
        );
    }

    function sparklinePoints(history) {
        const values = (
            Array.isArray(history)
                ? history
                : []
        )
            .filter(value =>
                value !== null
                && value !== ''
                && Number.isFinite(
                    Number(value)
                )
            )
            .map(Number);

        if (values.length === 0) {
            return '';
        }

        if (values.length === 1) {
            return '0,10 100,10';
        }

        const minimum =
            Math.min(...values);

        const maximum =
            Math.max(...values);

        const range =
            Math.max(
                maximum - minimum,
                1
            );

        return values
            .map((value, index) => {
                const x =
                    (
                        index
                        / (values.length - 1)
                    )
                    * 100;

                const y =
                    18
                    - (
                        (
                            value - minimum
                        )
                        / range
                    )
                    * 16;

                return (
                    `${x.toFixed(1)},`
                    + `${y.toFixed(1)}`
                );
            })
            .join(' ');
    }

    function widgetHtml(module) {
        const tx =
            module.transmission || {};

        const gateway =
            tx.gateway
            || [
                tx.callsign,
                tx.suffix,
            ]
                .filter(Boolean)
                .join(' ')
            || tx.callsign
            || 'Gateway';

        return `
            <div class="mtr-mini mtr-unknown">
                <div class="mtr-head">
                    <span class="mtr-label">
                        MTR
                    </span>

                    <strong class="mtr-gateway">
                        ${escapeHtml(gateway)}
                    </strong>

                    <span class="mtr-update">
                        atualizando
                    </span>

                    <span class="mtr-info-wrap">
                        <button
                            type="button"
                            class="mtr-info"
                            aria-label="Entenda as informações do MTR"
                        >
                            i
                        </button>

                        <span
                            class="mtr-tooltip"
                            role="tooltip"
                        >
                            <strong>Como interpretar</strong>

                            <b>LAT</b>: tempo de resposta.
                            Quanto menor, melhor.

                            <b>PER</b>: perda de pacotes.
                            O ideal é 0%.

                            <b>JIT</b>: variação do tempo
                            de resposta. Quanto menor,
                            mais estável.

                            <b>Rota parcial</b>: o equipamento
                            final bloqueou o teste. Os números
                            foram obtidos até o último ponto da
                            internet que respondeu.

                            Verde é normal, amarelo exige
                            atenção e vermelho indica problema.
                        </span>
                    </span>
                </div>

                <div class="mtr-metrics">
                    <span class="mtr-metric mtr-latency">
                        <small>LAT</small>
                        <b>— ms</b>
                    </span>

                    <span class="mtr-metric mtr-loss">
                        <small>PER</small>
                        <b>—%</b>
                    </span>

                    <span class="mtr-metric mtr-jitter">
                        <small>JIT</small>
                        <b>— ms</b>
                    </span>
                </div>

                <div class="mtr-graph-row">
                    <span class="mtr-chart">
                        <svg
                            class="mtr-sparkline"
                            viewBox="0 0 100 24"
                            preserveAspectRatio="none"
                            aria-label="Histórico recente da latência"
                        >
                            <polyline
                                class="mtr-line"
                                points=""
                                fill="none"
                            ></polyline>

                            <circle
                                class="mtr-dot"
                                cx="0"
                                cy="12"
                                r="2.5"
                                hidden
                            ></circle>
                        </svg>
                    </span>

                    <span class="mtr-state-group">
                        <span class="mtr-quality">
                            <i></i>
                            <b>Medindo</b>
                        </span>

                        <span class="mtr-reason">
                            aguardando dados
                        </span>

                        <span class="mtr-trend">
                            → iniciando
                        </span>

                        <span
                            class="mtr-route"
                            hidden
                        >
                            ↝ rota parcial
                        </span>
                    </span>
                </div>

                <span
                    class="mtr-scale"
                    aria-label="Escala de qualidade: verde, amarelo e vermelho"
                >
                    <i class="mtr-scale-marker"></i>
                </span>
            </div>
        `;
    }

    function metricSeverity(
        value,
        greenMaximum,
        yellowMaximum
    ) {
        /*
         * null, undefined e string vazia significam:
         * nenhuma medicao disponivel.
         *
         * Number(null) === 0 em JavaScript; portanto
         * precisam ser barrados antes da conversao.
         */
        if (
            value === null
            || value === undefined
            || value === ''
        ) {
            return null;
        }

        const number = Number(value);

        if (!Number.isFinite(number)) {
            return null;
        }

        if (number <= greenMaximum) {
            return Math.max(
                0,
                Math.min(
                    50,
                    (
                        number
                        / Math.max(
                            greenMaximum,
                            0.01
                        )
                    ) * 50
                )
            );
        }

        if (number <= yellowMaximum) {
            return 50 + (
                (
                    number - greenMaximum
                )
                / Math.max(
                    yellowMaximum - greenMaximum,
                    0.01
                )
            ) * 25;
        }

        return Math.min(
            100,
            75 + (
                (
                    number - yellowMaximum
                )
                / Math.max(
                    yellowMaximum,
                    0.01
                )
            ) * 25
        );
    }

    function visualQuality(data) {
        const metrics = [
            {
                name: 'latência elevada',
                score: metricSeverity(
                    data.avg_ms,
                    120,
                    200
                ),
            },
            {
                name: 'perda de pacotes',
                score: metricSeverity(
                    data.loss_pct,
                    1,
                    5
                ),
            },
            {
                name: 'jitter elevado',
                score: metricSeverity(
                    data.jitter_ms,
                    30,
                    60
                ),
            },
        ].filter(
            item => item.score !== null
        );

        if (metrics.length === 0) {
            return {
                status: 'unknown',
                label: 'Sem dados',
                reason: 'aguardando medição',
                score: 0,
            };
        }

        metrics.sort(
            (first, second) =>
                second.score - first.score
        );

        const worst = metrics[0];

        if (worst.score <= 50) {
            return {
                status: 'good',
                label: 'Normal',
                reason: 'rota estável',
                score: worst.score,
            };
        }

        if (worst.score <= 75) {
            return {
                status: 'warning',
                label: 'Atenção',
                reason: worst.name,
                score: worst.score,
            };
        }

        return {
            status: 'bad',
            label: 'Ruim',
            reason: worst.name,
            score: worst.score,
        };
    }

    function trendInformation(history) {
        const values = (
            Array.isArray(history)
                ? history
                : []
        )
            .filter(value =>
                value !== null
                && value !== ''
                && Number.isFinite(
                    Number(value)
                )
            )
            .map(Number)
            .slice(-6);

        if (values.length < 4) {
            return {
                symbol: '→',
                label: 'iniciando',
            };
        }

        const middle =
            Math.floor(
                values.length / 2
            );

        const first =
            values.slice(0, middle);

        const second =
            values.slice(middle);

        const average = items =>
            items.reduce(
                (total, value) =>
                    total + value,
                0
            ) / items.length;

        const beginning =
            average(first);

        const ending =
            average(second);

        const difference =
            (
                ending - beginning
            )
            / Math.max(
                beginning,
                1
            );

        if (difference <= -0.12) {
            return {
                symbol: '↘',
                label: 'melhorando',
            };
        }

        if (difference >= 0.12) {
            return {
                symbol: '↗',
                label: 'piorando',
            };
        }

        return {
            symbol: '→',
            label: 'estável',
        };
    }

    function updateAge(updatedAt) {
        const timestamp =
            Number(updatedAt);

        if (!Number.isFinite(timestamp)) {
            return 'atualizando';
        }

        const age =
            Math.max(
                0,
                Math.floor(
                    Date.now() / 1000
                    - timestamp
                )
            );

        if (age <= 1) {
            return 'agora';
        }

        return `há ${age}s`;
    }

    function renderResult(
        widget,
        data
    ) {
        if (
            !widget
            || !widget.isConnected
        ) {
            return;
        }

        const quality =
            visualQuality(data);

        const trend =
            trendInformation(
                data.history
            );

        widget.classList.remove(
            'mtr-good',
            'mtr-warning',
            'mtr-bad',
            'mtr-unknown'
        );

        widget.classList.add(
            `mtr-${quality.status}`
        );

        widget.style.setProperty(
            '--mtr-score',
            `${
                Math.max(
                    0,
                    Math.min(
                        100,
                        quality.score
                    )
                )
            }%`
        );

        const gateway =
            widget.querySelector(
                '.mtr-gateway'
            );

        const latency =
            widget.querySelector(
                '.mtr-latency b'
            );

        const loss =
            widget.querySelector(
                '.mtr-loss b'
            );

        const jitter =
            widget.querySelector(
                '.mtr-jitter b'
            );

        const qualityText =
            widget.querySelector(
                '.mtr-quality b'
            );

        const reason =
            widget.querySelector(
                '.mtr-reason'
            );

        const trendText =
            widget.querySelector(
                '.mtr-trend'
            );

        const route =
            widget.querySelector(
                '.mtr-route'
            );

        const updated =
            widget.querySelector(
                '.mtr-update'
            );

        const line =
            widget.querySelector(
                '.mtr-line'
            );

        const dot =
            widget.querySelector(
                '.mtr-dot'
            );

        if (
            gateway
            && data.gateway
        ) {
            gateway.textContent =
                data.gateway;
        }

        const validLatency =
            data.avg_ms !== null
            && data.avg_ms !== undefined
            && Number.isFinite(
                Number(data.avg_ms)
            );

        const validLoss =
            data.loss_pct !== null
            && data.loss_pct !== undefined
            && Number.isFinite(
                Number(data.loss_pct)
            );

        const validJitter =
            data.jitter_ms !== null
            && data.jitter_ms !== undefined
            && Number.isFinite(
                Number(data.jitter_ms)
            );

        if (latency) {
            latency.textContent =
                validLatency
                    ? `${
                        Number(
                            data.avg_ms
                        ).toFixed(1)
                    } ms`
                    : '— ms';
        }

        if (loss) {
            loss.textContent =
                validLoss
                    ? `${
                        Number(
                            data.loss_pct
                        ).toFixed(1)
                    }%`
                    : '—%';
        }

        if (jitter) {
            jitter.textContent =
                validJitter
                    ? `${
                        Number(
                            data.jitter_ms
                        ).toFixed(1)
                    } ms`
                    : '— ms';
        }

        if (qualityText) {
            qualityText.textContent =
                quality.label;
        }

        if (reason) {
            reason.textContent =
                quality.reason;
        }

        if (trendText) {
            trendText.textContent =
                `${trend.symbol} ${trend.label}`;
        }

        if (route) {
            route.hidden =
                !data.route_partial;
        }

        if (updated) {
            updated.textContent =
                updateAge(
                    data.updated_at
                );
        }

        const points =
            sparklinePoints(
                data.history
            );

        if (line) {
            line.setAttribute(
                'points',
                points
            );
        }

        if (dot) {
            const lastPoint =
                points
                    .trim()
                    .split(/\s+/)
                    .filter(Boolean)
                    .pop();

            if (
                lastPoint
                && lastPoint.includes(',')
            ) {
                const [
                    x,
                    y,
                ] = lastPoint.split(',');

                dot.setAttribute(
                    'cx',
                    x
                );

                dot.setAttribute(
                    'cy',
                    y
                );

                dot.hidden = false;
            } else {
                dot.hidden = true;
            }
        }

        const scope =
            data.route_partial
                ? 'rota parcial'
                : 'destino final';

        widget.title =
            `LAT: ${
                validLatency
                    ? data.avg_ms + ' ms'
                    : 'indisponível'
            } | PER: ${
                validLoss
                    ? data.loss_pct + '%'
                    : 'indisponível'
            } | JIT: ${
                validJitter
                    ? data.jitter_ms + ' ms'
                    : 'indisponível'
            } | Qualidade: ${
                quality.label
            } | Medição: ${scope}`;
    }

    async function updateWidget(item) {
        const widget = item.widget;

        if (
            !widget
            || !widget.isConnected
            || widget.dataset.loading === '1'
        ) {
            return;
        }

        widget.dataset.loading = '1';

        const tx =
            item.module.transmission || {};

        const parameters =
            new URLSearchParams({
                key:
                    txKey(item.module),
                module:
                    item.module.module
                    || '',
                callsign:
                    tx.callsign
                    || '',
                suffix:
                    tx.suffix
                    || '',
            });

        const controller =
            new AbortController();

        const timeout =
            setTimeout(
                () => controller.abort(),
                9500
            );

        try {
            const response =
                await fetch(
                    `/api/mtr.php?${parameters.toString()}&ts=${Date.now()}`,
                    {
                        cache: 'no-store',
                        signal:
                            controller.signal,
                    }
                );

            const data =
                await response.json();

            if (!widget.isConnected) {
                return;
            }

            if (!data.ok) {
                renderResult(
                    widget,
                    {
                        gateway:
                            widget
                                .querySelector(
                                    '.mtr-gateway'
                                )
                                ?.textContent,
                        status: 'unknown',
                        status_label:
                            data.state
                            === 'inactive'
                                ? 'Finalizando'
                                : 'Indisponível',
                        avg_ms: null,
                        loss_pct: null,
                        jitter_ms: null,
                        history: [],
                    }
                );

                return;
            }

            renderResult(
                widget,
                data
            );
        } catch (error) {
            if (widget.isConnected) {
                renderResult(
                    widget,
                    {
                        gateway:
                            widget
                                .querySelector(
                                    '.mtr-gateway'
                                )
                                ?.textContent,
                        status: 'unknown',
                        status_label:
                            'Sem resposta',
                        avg_ms: null,
                        loss_pct: null,
                        jitter_ms: null,
                        history: [],
                    }
                );
            }
        } finally {
            clearTimeout(timeout);

            if (widget.isConnected) {
                widget.dataset.loading =
                    '0';
            }
        }
    }

    function refreshAll() {
        if (document.hidden) {
            return;
        }

        widgets.forEach(
            updateWidget
        );
    }

    function stop() {
        if (updateTimer !== null) {
            clearInterval(
                updateTimer
            );

            updateTimer = null;
        }

        widgets = [];
    }

    function sync(activeModules) {
        stop();

        const grid =
            document.getElementById(
                'moduleGrid'
            );

        if (!grid) {
            return;
        }

        const modules = (
            Array.isArray(activeModules)
                ? activeModules
                : []
        )
            .filter(module =>
                module
                && module.transmission
            )
            .slice(
                0,
                MAX_WIDGETS
            );

        if (modules.length === 0) {
            return;
        }

        const cards = [
            ...grid.children,
        ].filter(element =>
            element.matches(
                'article.tx-card'
            )
        );

        modules.forEach(
            (module, index) => {
                const card =
                    cards[index];

                if (!card) {
                    return;
                }

                const stack =
                    document.createElement(
                        'div'
                    );

                stack.className =
                    'tx-mtr-stack';

                stack.dataset.mtrKey =
                    txKey(module);

                stack.innerHTML =
                    widgetHtml(module);

                const widget =
                    stack.querySelector(
                        '.mtr-mini'
                    );

                grid.insertBefore(
                    stack,
                    card
                );

                stack.appendChild(
                    card
                );

                if (widget) {
                    widgets.push({
                        module,
                        widget,
                    });
                }
            }
        );

        refreshAll();

        updateTimer =
            setInterval(
                refreshAll,
                INTERVAL
            );
    }

    document.addEventListener(
        'visibilitychange',
        () => {
            if (!document.hidden) {
                refreshAll();
            }
        }
    );

    window.XLX026MTR =
        Object.freeze({
            sync,
        });
})();
