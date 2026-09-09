(() => {
    'use strict';

    const API = 'api/certificado.php';

    const form = document.getElementById('certForm');
    if (!form) return;

    const callInput = document.getElementById('certCallsign');
    const messageBox = document.getElementById('certMessage');
    const campaignLead = document.getElementById('certCampaignLead');
    const specialBanner = document.getElementById('certSpecialBanner');
    const specialTitle = document.getElementById('certSpecialTitle');
    const specialSubtitle = document.getElementById('certSpecialSubtitle');
    const canvas = document.getElementById('certCanvas');

    /*
     * Matriz lógica original:
     * 1754 x 1240
     *
     * Raster final:
     * 3508 x 2480
     *
     * Equivale às dimensões de A4 horizontal
     * normalmente utilizadas para impressão a 300 DPI,
     * mantendo o mesmo sistema de coordenadas do desenho.
     */
    const LOGICAL_WIDTH = 1754;
    const LOGICAL_HEIGHT = 1240;
    const RENDER_SCALE = 2;

    canvas.width =
        LOGICAL_WIDTH * RENDER_SCALE;

    canvas.height =
        LOGICAL_HEIGHT * RENDER_SCALE;

    const ctx = canvas.getContext('2d');

    ctx.setTransform(
        RENDER_SCALE,
        0,
        0,
        RENDER_SCALE,
        0,
        0
    );
    const actions = document.getElementById('certActions');
    const downloadPdf = document.getElementById('certDownloadPdf');
    const downloadPng = document.getElementById('certDownloadPng');
    const previewState = document.getElementById('certPreviewState');
    const qrStage = document.getElementById('certQrStage');
    const verifyBox = document.getElementById('certVerification');
    const verifyTitle = document.getElementById('certVerificationTitle');
    const verifyBody = document.getElementById('certVerificationBody');

    const state = {
        campaign: null,
        certificate: null,
        logo: null
    };

    const themes = {
        padrao: {
            dark:'#071b33',
            deep:'#0b3158',
            accent:'#d6b15a',
            secondary:'#277fd0',
            paper:'#f8fbff'
        },
        pais: {
            dark:'#071a35',
            deep:'#103d72',
            accent:'#d9b450',
            secondary:'#327ed0',
            paper:'#fbfcff'
        },
        maes: {
            dark:'#32132c',
            deep:'#71345e',
            accent:'#d9aa67',
            secondary:'#b74a83',
            paper:'#fffafd'
        },
        radio: {
            dark:'#062334',
            deep:'#07506c',
            accent:'#d6b15a',
            secondary:'#15a2c2',
            paper:'#f7fcff'
        },
        'radio-br': {
            dark:'#072d24',
            deep:'#075b43',
            accent:'#e0b94d',
            secondary:'#2e85c9',
            paper:'#f9fff9'
        },
        brasil: {
            dark:'#073423',
            deep:'#0b6a40',
            accent:'#edc52f',
            secondary:'#1d77c8',
            paper:'#fbfff8'
        },
        natal: {
            dark:'#173027',
            deep:'#19563d',
            accent:'#d7b45a',
            secondary:'#a7333a',
            paper:'#fffdf8'
        },
        'ano-novo': {
            dark:'#101933',
            deep:'#332766',
            accent:'#e0c36c',
            secondary:'#6756ba',
            paper:'#fcfbff'
        }
    };

    function themeFor(campaign) {
        return themes[campaign?.theme] || themes.padrao;
    }

    function showMessage(text, type = 'info') {
        messageBox.hidden = false;
        messageBox.className = `cert-message ${type}`;
        messageBox.textContent = text;
    }

    function clearMessage() {
        messageBox.hidden = true;
        messageBox.textContent = '';
        messageBox.className = 'cert-message';
    }

    function normalizeCall(value) {
        return String(value || '')
            .toUpperCase()
            .replace(/[^A-Z0-9]/g, '')
            .slice(0, 10);
    }

    function formatSeconds(total) {
        total = Math.max(0, Number(total) || 0);

        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = Math.floor(total % 60);

        if (h > 0) return `${h}h ${m}min ${s}s`;
        if (m > 0) return `${m}min ${s}s`;
        return `${s}s`;
    }

    function localDateTime(timestamp) {
        if (!timestamp) return '—';

        return new Date(timestamp * 1000).toLocaleString(
            'pt-BR',
            {
                timeZone:'America/Sao_Paulo',
                dateStyle:'short',
                timeStyle:'short'
            }
        );
    }

    function issueDate(iso) {
        if (!iso) return '—';

        return new Date(iso).toLocaleString(
            'pt-BR',
            {
                timeZone:'America/Sao_Paulo',
                dateStyle:'short',
                timeStyle:'short'
            }
        );
    }

    async function loadLogo() {
        if (state.logo) return state.logo;

        state.logo = await new Promise(resolve => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = () => resolve(null);
            img.src = 'assets/logo-{{REFLECTOR_NAME}}.svg';
        });

        return state.logo;
    }

    function roundedRect(context, x, y, w, h, r) {
        r = Math.min(r, w / 2, h / 2);

        context.beginPath();
        context.moveTo(x + r, y);
        context.arcTo(x + w, y, x + w, y + h, r);
        context.arcTo(x + w, y + h, x, y + h, r);
        context.arcTo(x, y + h, x, y, r);
        context.arcTo(x, y, x + w, y, r);
        context.closePath();
    }

    function fitText(
        context,
        text,
        maxWidth,
        startSize,
        minSize,
        weight = '700',
        family = 'Georgia, serif'
    ) {
        let size = startSize;

        while (size > minSize) {
            context.font = `${weight} ${size}px ${family}`;

            if (context.measureText(text).width <= maxWidth) {
                break;
            }

            size -= 2;
        }

        return size;
    }

    function centeredText(
        context,
        text,
        x,
        y,
        size,
        color,
        weight = '400',
        family = 'Arial, sans-serif'
    ) {
        context.save();
        context.fillStyle = color;
        context.font = `${weight} ${size}px ${family}`;
        context.textAlign = 'center';
        context.textBaseline = 'alphabetic';
        context.fillText(text, x, y);
        context.restore();
    }

    function leftText(
        context,
        text,
        x,
        y,
        size,
        color,
        weight = '400',
        family = 'Arial, sans-serif'
    ) {
        context.save();
        context.fillStyle = color;
        context.font = `${weight} ${size}px ${family}`;
        context.textAlign = 'left';
        context.fillText(text, x, y);
        context.restore();
    }

    function drawRadioWaves(context, x, y, color) {
        context.save();
        context.strokeStyle = color;
        context.globalAlpha = .14;
        context.lineWidth = 5;

        [75, 125, 175, 225].forEach(r => {
            context.beginPath();
            context.arc(x, y, r, Math.PI * 1.1, Math.PI * 1.9);
            context.stroke();
        });

        context.globalAlpha = .16;
        context.beginPath();
        context.moveTo(x, y);
        context.lineTo(x, y + 250);
        context.stroke();

        context.restore();
    }

    async function makeQrCanvas(text) {
        qrStage.innerHTML = '';

        if (typeof QRCode === 'undefined') {
            throw new Error('Gerador QR não carregado.');
        }

        new QRCode(qrStage, {
            text,
            width:420,
            height:420,
            colorDark:'#000000',
            colorLight:'#ffffff',
            correctLevel:QRCode.CorrectLevel.H
        });

        await new Promise(resolve => setTimeout(resolve, 70));

        const qrCanvas = qrStage.querySelector('canvas');
        if (qrCanvas) return qrCanvas;

        const img = qrStage.querySelector('img');

        if (img) {
            if (!img.complete) {
                await new Promise((resolve, reject) => {
                    img.onload = resolve;
                    img.onerror = reject;
                });
            }

            return img;
        }

        throw new Error('QR Code não pôde ser renderizado.');
    }

    function clearDateParts(label) {
        const m = String(label || '').match(
            /(\d{2})\/(\d{2})\/(\d{4})/
        );

        if (!m) {
            return {
                day: '',
                month: '',
                year: '',
                long: String(label || '')
            };
        }

        const months = [
            '',
            'JANEIRO',
            'FEVEREIRO',
            'MARÇO',
            'ABRIL',
            'MAIO',
            'JUNHO',
            'JULHO',
            'AGOSTO',
            'SETEMBRO',
            'OUTUBRO',
            'NOVEMBRO',
            'DEZEMBRO'
        ];

        return {
            day: m[1],
            month: months[Number(m[2])],
            year: m[3],
            long: `${m[1]} DE ${months[Number(m[2])]}`
        };
    }

    function clearEventName(campaign) {
        return String(
            campaign?.title || 'Participação {{REFLECTOR_NAME}}'
        ).replace(/\s+\d{4}$/, '');
    }

    function certificateMessage(campaign) {
        /*
         * Campanhas profissionais mostram automaticamente
         * o nome verdadeiro da comemoração.
         */
        if (campaign?.theme === 'profissao') {
            const eventName =
                String(
                    campaign?.title
                    || 'Data profissional especial'
                ).trim();

            return [
                `EDIÇÃO ESPECIAL — ${eventName}`,
                'Uma homenagem do {{REFLECTOR_NAME}} aos profissionais que fazem a diferença.'
            ];
        }

        const map = {
            profissao: [
                'O {{REFLECTOR_NAME}} celebra esta data profissional especial,',
                'reconhecendo a importância desses profissionais para a sociedade.'
            ],
            carnaval: [
                'Que a alegria do Carnaval também celebre a amizade,',
                'o respeito e as boas conexões entre radioamadores.'
            ],

            mulher: [
                'Uma homenagem às mulheres que inspiram, comunicam',
                'e fazem história dentro e fora do radioamadorismo.'
            ],

            'sexta-santa': [
                'Uma data de reflexão, respeito e renovação,',
                'marcada pela fé e pela esperança.'
            ],

            pascoa: [
                'Que a Páscoa renove a esperança, a amizade',
                'e os bons sentimentos em cada conexão.'
            ],

            tiradentes: [
                'Uma homenagem à história e aos valores',
                'que ajudaram a construir o Brasil.'
            ],

            trabalhador: [
                'Nosso reconhecimento a quem transforma esforço,',
                'conhecimento e dedicação em progresso.'
            ],

            'corpus-christi': [
                'Uma data de fé, união e reflexão,',
                'celebrada com respeito pelo {{REFLECTOR_NAME}}.'
            ],

            namorados: [
                'Conexões especiais aproximam pessoas',
                'e transformam momentos em boas lembranças.'
            ],

            'aparecida-criancas': [
                'Uma data de fé, proteção e esperança,',
                'com uma homenagem especial às crianças do Brasil.'
            ],

            professor: [
                'Ensinar é compartilhar conhecimento e abrir caminhos.',
                'Nossa homenagem a quem transforma vidas pela educação.'
            ],

            medico: [
                'Nossa homenagem a quem dedica conhecimento e cuidado',
                'à proteção da vida e da saúde.'
            ],

            finados: [
                'Uma data de memória e respeito',
                'por aqueles que permanecem em nossas lembranças.'
            ],

            republica: [
                'Uma homenagem à história republicana do Brasil',
                'e à construção permanente da cidadania.'
            ],

            'consciencia-negra': [
                'Uma data de memória, respeito, igualdade',
                'e valorização da história e da cultura negra.'
            ],

            pais: [
                'Ser pai é construir memórias, inspirar caminhos',
                'e deixar um legado de amor que atravessa gerações.',
                'Parabéns, pai!'
            ],

            maes: [
                'Amor, cuidado e exemplo conectam gerações',
                'e transformam para sempre a vida de uma família.'
            ],

            aniversario: [
                'Celebramos mais um ano do {{REFLECTOR_NAME}},',
                'conectando radioamadores, tecnologia e amizade.',
                'Obrigado por fazer parte desta história.'
            ],

            radio: [
                'Cada transmissão aproxima pessoas, compartilha',
                'conhecimento e mantém viva a essência do radioamadorismo.'
            ],

            'radio-br': [
                'Radioamadorismo é amizade, conhecimento,',
                'serviço e comunicação sem fronteiras.'
            ],

            brasil: [
                'Conectando brasileiros por meio da tecnologia,',
                'da amizade e do radioamadorismo.'
            ],

            natal: [
                'Que cada contato leve amizade, esperança',
                'e bons sentimentos para além das distâncias.'
            ],

            'ano-novo': [
                'Novas conexões, novas amizades',
                'e muitas histórias para transmitir.'
            ]
        };

        return map[campaign?.theme] || [
            'Cada contato constrói uma história.',
            'Cada transmissão aproxima pessoas.'
        ];
    }

    function clearLines(
        lines,
        x,
        y,
        lineHeight,
        size,
        color,
        weight = '400',
        family = 'Arial, sans-serif'
    ) {
        lines.forEach((line, i) => {
            centeredText(
                ctx,
                line,
                x,
                y + (i * lineHeight),
                size,
                color,
                weight,
                family
            );
        });
    }

    function clearBase(campaign = {}) {
        /*
         * Limpeza física completa do backing-store 3508x2480.
         */
        ctx.setTransform(
            1,
            0,
            0,
            1,
            0,
            0
        );

        ctx.clearRect(
            0,
            0,
            canvas.width,
            canvas.height
        );

        /*
         * Volta ao sistema lógico 1754x1240.
         */
        ctx.setTransform(
            RENDER_SCALE,
            0,
            0,
            RENDER_SCALE,
            0,
            0
        );

        const w = LOGICAL_WIDTH;
        const h = LOGICAL_HEIGHT;

        const visual =
            certificateVisual(campaign);

        /*
         * Papel claro premium.
         */
        const bg =
            ctx.createLinearGradient(
                0,
                0,
                w,
                h
            );

        bg.addColorStop(
            0,
            '#fffef9'
        );

        bg.addColorStop(
            .50,
            '#fbfaf6'
        );

        bg.addColorStop(
            1,
            '#f1f4f5'
        );

        ctx.fillStyle = bg;

        ctx.fillRect(
            0,
            0,
            w,
            h
        );

        /*
         * Moldura institucional.
         */
        ctx.strokeStyle =
            '#071b3b';

        ctx.lineWidth = 20;

        ctx.strokeRect(
            22,
            22,
            w - 44,
            h - 44
        );

        ctx.strokeStyle =
            visual.accent;

        ctx.lineWidth = 5;

        ctx.strokeRect(
            49,
            49,
            w - 98,
            h - 98
        );

        ctx.strokeStyle =
            'rgba(7,27,59,.20)';

        ctx.lineWidth = 2;

        ctx.strokeRect(
            64,
            64,
            w - 128,
            h - 128
        );

        /*
         * Ornamento discreto no centro.
         * Não disputa espaço com os dados.
         */
        ctx.save();

        ctx.strokeStyle =
            'rgba(7,27,59,.025)';

        ctx.lineWidth = 3;

        for (
            let r = 170;
            r <= 610;
            r += 110
        ) {
            ctx.beginPath();

            ctx.arc(
                w / 2,
                590,
                r,
                0,
                Math.PI * 2
            );

            ctx.stroke();
        }

        ctx.restore();

        /*
         * Pequenos filetes de campanha.
         */
        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            90,
            83,
            175,
            3
        );

        ctx.fillRect(
            w - 265,
            83,
            175,
            3
        );
    }

    function drawClearBrand() {
        const w =
            LOGICAL_WIDTH;

        centeredText(
            ctx,
            '{{REFLECTOR_NAME}}',
            w / 2,
            118,
            39,
            '#071b3b',
            '900'
        );

        centeredText(
            ctx,
            'BRASIL',
            w / 2,
            153,
            19,
            '#b98628',
            '900'
        );

        centeredText(
            ctx,
            'REFLETOR DIGITAL MULTIPROTOCOLO',
            w / 2,
            181,
            12,
            '#6b7786',
            '800'
        );

        ctx.strokeStyle =
            '#c99a34';

        ctx.lineWidth = 2;

        ctx.beginPath();

        ctx.moveTo(
            w / 2 - 150,
            199
        );

        ctx.lineTo(
            w / 2 + 150,
            199
        );

        ctx.stroke();
    }
    function certificateVisual(campaign) {
        const visuals = {
            padrao: {
                dark: '#071b3b',
                mid: '#173f67',
                accent: '#c99a34',
                symbol: '◆'
            },

            profissao: {
                dark: '#142d49',
                mid: '#315d7e',
                accent: '#c9a24a',
                symbol: '◆'
            },

            pais: {
                dark: '#071b3b',
                mid: '#174b78',
                accent: '#d3aa4a',
                symbol: '♥'
            },

            maes: {
                dark: '#521a35',
                mid: '#8d3458',
                accent: '#d6ad58',
                symbol: '♥'
            },

            aniversario: {
                dark: '#082a55',
                mid: '#0b5eaa',
                accent: '#e2b94f',
                symbol: '★'
            },

            radio: {
                dark: '#073147',
                mid: '#0d6078',
                accent: '#d6ab4c',
                symbol: '⌁'
            },

            brasil: {
                dark: '#0b4935',
                mid: '#13734d',
                accent: '#dfbd42',
                symbol: '◆'
            },

            'radio-br': {
                dark: '#102641',
                mid: '#15506f',
                accent: '#d7ae52',
                symbol: '⌁'
            },

            natal: {
                dark: '#174432',
                mid: '#24694a',
                accent: '#d9b85c',
                symbol: '✦'
            },

            'ano-novo': {
                dark: '#101d40',
                mid: '#29417d',
                accent: '#e1bb55',
                symbol: '✦'
            }
        };

        const aliases = {
            carnaval: 'ano-novo',
            mulher: 'maes',
            'sexta-santa': 'radio-br',
            pascoa: 'natal',
            tiradentes: 'brasil',
            trabalhador: 'profissao',
            'corpus-christi': 'radio-br',
            namorados: 'maes',
            'aparecida-criancas': 'brasil',
            professor: 'profissao',
            medico: 'profissao',
            finados: 'radio-br',
            republica: 'brasil',
            'consciencia-negra': 'brasil'
        };

        const visualKey =
            aliases[campaign?.theme]
            || campaign?.theme
            || 'padrao';

        return (
            visuals[visualKey]
            || visuals.padrao
        );
    }
    function certificateSpecialDate(campaign) {
        const normal = clearDateParts(
            campaign?.period_label
        );

        if (campaign?.theme === 'aniversario') {
            const year =
                String(campaign?.start || '')
                    .slice(0, 4)
                || normal.year;

            return {
                day: '22',
                month: 'JULHO',
                year: year
            };
        }

        if (campaign?.theme === 'ano-novo') {
            const match = String(
                campaign?.title || ''
            ).match(/(\d{4})$/);

            return {
                day: '01',
                month: 'JANEIRO',
                year: match ? match[1] : normal.year
            };
        }

        return normal;
    }

    function drawOtherSpecialRibbon(campaign) {
        const visual = certificateVisual(campaign);
        const date = certificateSpecialDate(campaign);

        const eventLabel =
            clearEventName(campaign)
                .toUpperCase();

        const x = 90;
        const y = 145;
        const bw = 220;
        const bh = 485;

        const gradient = ctx.createLinearGradient(
            x,
            y,
            x + bw,
            y + bh
        );

        gradient.addColorStop(
            0,
            visual.dark
        );

        gradient.addColorStop(
            .55,
            visual.mid
        );

        gradient.addColorStop(
            1,
            visual.dark
        );

        roundedRect(
            ctx,
            x,
            y,
            bw,
            bh,
            20
        );

        ctx.fillStyle = gradient;
        ctx.fill();

        ctx.strokeStyle = visual.accent;
        ctx.lineWidth = 4;
        ctx.stroke();

        centeredText(
            ctx,
            'EDIÇÃO',
            x + bw / 2,
            y + 62,
            18,
            visual.accent,
            '900'
        );

        centeredText(
            ctx,
            'ESPECIAL',
            x + bw / 2,
            y + 94,
            25,
            '#ffffff',
            '900'
        );

        ctx.fillStyle = visual.accent;

        ctx.fillRect(
            x + 42,
            y + 126,
            bw - 84,
            3
        );

        const eventSize = fitText(
            ctx,
            eventLabel,
            bw - 28,
            25,
            11,
            '900'
        );

        centeredText(
            ctx,
            eventLabel,
            x + bw / 2,
            y + 187,
            eventSize,
            '#ffffff',
            '900'
        );

        centeredText(
            ctx,
            date.year,
            x + bw / 2,
            y + 244,
            47,
            visual.accent,
            '900',
            'Georgia, serif'
        );

        ctx.save();

        ctx.fillStyle = visual.accent;
        ctx.font = '900 39px Arial, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        ctx.fillText(
            visual.symbol,
            x + bw / 2,
            y + 305
        );

        ctx.restore();

        clearLines(
            visual.lines,
            x + bw / 2,
            y + 360,
            27,
            12,
            '#ffffff',
            '800'
        );

        const dy = 655;
        const dh = 330;

        roundedRect(
            ctx,
            x,
            dy,
            bw,
            dh,
            20
        );

        ctx.fillStyle = '#ffffff';
        ctx.fill();

        ctx.strokeStyle = visual.accent;
        ctx.lineWidth = 3;
        ctx.stroke();

        centeredText(
            ctx,
            campaign?.theme === 'aniversario'
                ? 'ANIVERSÁRIO OFICIAL'
                : 'DATA ESPECIAL',
            x + bw / 2,
            dy + 48,
            12,
            visual.dark,
            '900'
        );

        ctx.strokeStyle = visual.accent;
        ctx.lineWidth = 2;

        ctx.beginPath();
        ctx.moveTo(
            x + 45,
            dy + 70
        );
        ctx.lineTo(
            x + bw - 45,
            dy + 70
        );
        ctx.stroke();

        centeredText(
            ctx,
            date.day,
            x + bw / 2,
            dy + 142,
            61,
            visual.dark,
            '700',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            `DE ${date.month}`,
            x + bw / 2,
            dy + 185,
            16,
            visual.accent,
            '900'
        );

        centeredText(
            ctx,
            date.year,
            x + bw / 2,
            dy + 238,
            34,
            visual.dark,
            '900'
        );

        const eventSize2 = fitText(
            ctx,
            eventLabel,
            bw - 28,
            13,
            9,
            '900'
        );

        centeredText(
            ctx,
            eventLabel,
            x + bw / 2,
            dy + 286,
            eventSize2,
            '#596a7c',
            '900'
        );
    }

    function drawSpecialRibbon(campaign) {
        if (!campaign?.special) {
            return;
        }

        /*
         * O Dia dos Pais mantém exatamente o
         * modelo clear já aprovado.
         */
        if (campaign?.theme !== 'pais') {
            drawOtherSpecialRibbon(campaign);
            return;
        }

        const date = clearDateParts(
            campaign.period_label
        );

        /*
         * Faixa lateral
         */
        const x = 90;
        const y = 145;
        const bw = 220;
        const bh = 485;

        const gradient = ctx.createLinearGradient(
            x,
            y,
            x + bw,
            y + bh
        );

        gradient.addColorStop(0, '#06172f');
        gradient.addColorStop(.55, '#0a3563');
        gradient.addColorStop(1, '#06172f');

        roundedRect(
            ctx,
            x,
            y,
            bw,
            bh,
            20
        );

        ctx.fillStyle = gradient;
        ctx.fill();

        ctx.strokeStyle = '#d3aa4a';
        ctx.lineWidth = 4;
        ctx.stroke();

        centeredText(
            ctx,
            'EDIÇÃO',
            x + bw / 2,
            y + 65,
            19,
            '#e4c36e',
            '900'
        );

        centeredText(
            ctx,
            'ESPECIAL',
            x + bw / 2,
            y + 96,
            25,
            '#ffffff',
            '900'
        );

        ctx.fillStyle = '#d2a443';
        ctx.fillRect(
            x + 42,
            y + 128,
            bw - 84,
            3
        );

        const eventName = clearEventName(
            campaign
        ).toUpperCase();

        const eventSize = fitText(
            ctx,
            eventName,
            bw - 32,
            28,
            17,
            '900'
        );

        centeredText(
            ctx,
            eventName,
            x + bw / 2,
            y + 190,
            eventSize,
            '#ffffff',
            '900'
        );

        centeredText(
            ctx,
            date.year,
            x + bw / 2,
            y + 246,
            48,
            '#d8b45b',
            '900',
            'Georgia, serif'
        );

        /*
         * Pequeno coração ornamental
         */
        ctx.save();

        ctx.fillStyle = '#d9b75e';
        ctx.font = '900 42px Arial, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        ctx.fillText(
            '♥',
            x + bw / 2,
            y + 310
        );

        ctx.restore();

        clearLines(
            [
                'UMA HOMENAGEM',
                'DO {{REFLECTOR_NAME}}',
                'AOS PAIS',
                'RADIOAMADORES'
            ],
            x + bw / 2,
            y + 360,
            25,
            13,
            '#ffffff',
            '800'
        );

        /*
         * Card da data especial
         */
        const dy = 655;
        const dh = 330;

        roundedRect(
            ctx,
            x,
            dy,
            bw,
            dh,
            20
        );

        ctx.fillStyle = '#ffffff';
        ctx.fill();

        ctx.strokeStyle = '#c99a34';
        ctx.lineWidth = 3;
        ctx.stroke();

        centeredText(
            ctx,
            'DATA ESPECIAL',
            x + bw / 2,
            dy + 48,
            14,
            '#071b3b',
            '900'
        );

        ctx.strokeStyle = '#d4ad55';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(
            x + 45,
            dy + 70
        );
        ctx.lineTo(
            x + bw - 45,
            dy + 70
        );
        ctx.stroke();

        centeredText(
            ctx,
            date.day,
            x + bw / 2,
            dy + 142,
            61,
            '#071b3b',
            '700',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            `DE ${date.month}`,
            x + bw / 2,
            dy + 185,
            16,
            '#b27f23',
            '900'
        );

        centeredText(
            ctx,
            date.year,
            x + bw / 2,
            dy + 238,
            34,
            '#071b3b',
            '900'
        );

        centeredText(
            ctx,
            clearEventName(campaign).toUpperCase(),
            x + bw / 2,
            dy + 286,
            13,
            '#596a7c',
            '900'
        );
    }

    function drawClearTitle(x = 930) {
        centeredText(
            ctx,
            'CERTIFICADO',
            x,
            303,
            68,
            '#071b3b',
            '700',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            'DE PARTICIPAÇÃO',
            x,
            355,
            27,
            '#bd8b2d',
            '900'
        );

        ctx.strokeStyle = '#c99a34';
        ctx.lineWidth = 2;

        ctx.beginPath();
        ctx.moveTo(
            x - 170,
            382
        );
        ctx.lineTo(
            x + 170,
            382
        );
        ctx.stroke();
    }

    function drawOtherQuoteBox(campaign) {
        const visual = certificateVisual(campaign);

        const x = 1245;
        const y = 155;
        const bw = 410;
        const bh = 220;

        roundedRect(
            ctx,
            x,
            y,
            bw,
            bh,
            22
        );

        ctx.fillStyle = 'rgba(255,255,255,.88)';
        ctx.fill();

        ctx.strokeStyle = visual.accent;
        ctx.lineWidth = 2;
        ctx.stroke();

        centeredText(
            ctx,
            'MENSAGEM ESPECIAL',
            x + bw / 2,
            y + 38,
            12,
            visual.dark,
            '900'
        );

        clearLines(
            certificateMessage(campaign),
            x + bw / 2,
            y + 86,
            32,
            17,
            '#34475d',
            '500',
            'Georgia, serif'
        );
    }

    function drawQuoteBox(campaign) {
        /*
         * Dia dos Pais permanece visualmente idêntico.
         */
        if (campaign?.theme !== 'pais') {
            drawOtherQuoteBox(campaign);
            return;
        }

        const x = 1245;
        const y = 155;
        const bw = 410;
        const bh = 220;

        roundedRect(
            ctx,
            x,
            y,
            bw,
            bh,
            22
        );

        ctx.fillStyle = 'rgba(255,255,255,.82)';
        ctx.fill();

        ctx.strokeStyle = 'rgba(201,154,52,.72)';
        ctx.lineWidth = 2;
        ctx.stroke();

        centeredText(
            ctx,
            'MENSAGEM ESPECIAL',
            x + bw / 2,
            y + 38,
            12,
            '#a57420',
            '900'
        );

        clearLines(
            certificateMessage(campaign),
            x + bw / 2,
            y + 86,
            32,
            17,
            '#34475d',
            '500',
            'Georgia, serif'
        );
    }

    function drawParticipationCard(cert) {
        const x = 1275;
        const y = 660;
        const bw = 335;
        const bh = 225;

        roundedRect(
            ctx,
            x,
            y,
            bw,
            bh,
            18
        );

        ctx.fillStyle = '#ffffff';
        ctx.fill();

        ctx.strokeStyle = '#c99a34';
        ctx.lineWidth = 3;
        ctx.stroke();

        centeredText(
            ctx,
            'PARTICIPAÇÃO',
            x + bw / 2,
            y + 46,
            13,
            '#637083',
            '900'
        );

        centeredText(
            ctx,
            'CONFIRMADA',
            x + bw / 2,
            y + 86,
            26,
            '#071b3b',
            '900'
        );

        ctx.strokeStyle = '#d4aa4c';
        ctx.lineWidth = 2;

        ctx.beginPath();
        ctx.moveTo(
            x + 60,
            y + 112
        );
        ctx.lineTo(
            x + bw - 60,
            y + 112
        );
        ctx.stroke();

        centeredText(
            ctx,
            cert.callsign,
            x + bw / 2,
            y + 157,
            29,
            '#bd8b2d',
            '900'
        );

        centeredText(
            ctx,
            'Registro oficial {{REFLECTOR_NAME}}',
            x + bw / 2,
            y + 194,
            12,
            '#5f6d7e',
            '700'
        );
    }

    function premiumEventLabel(campaign) {
        if (!campaign?.special) {
            return 'CERTIFICADO OFICIAL {{REFLECTOR_NAME}}';
        }

        return clearEventName(
            campaign
        ).toUpperCase();
    }

    function drawPremiumEventBadge(campaign) {
        const visual =
            certificateVisual(campaign);

        const x = 352;
        const y = 222;
        const w = 1050;
        const h = 44;

        roundedRect(
            ctx,
            x,
            y,
            w,
            h,
            22
        );

        const gradient =
            ctx.createLinearGradient(
                x,
                y,
                x + w,
                y
            );

        gradient.addColorStop(
            0,
            visual.dark
        );

        gradient.addColorStop(
            .50,
            visual.mid
        );

        gradient.addColorStop(
            1,
            visual.dark
        );

        ctx.fillStyle =
            gradient;

        ctx.fill();

        ctx.strokeStyle =
            visual.accent;

        ctx.lineWidth = 2;

        ctx.stroke();

        const label =
            premiumEventLabel(campaign);

        const size =
            fitText(
                ctx,
                label,
                w - 90,
                17,
                10,
                '900',
                'Arial, sans-serif'
            );

        centeredText(
            ctx,
            label,
            x + w / 2,
            y + 29,
            size,
            '#ffffff',
            '900'
        );
    }

    function drawPremiumTitle() {
        const x =
            LOGICAL_WIDTH / 2;

        centeredText(
            ctx,
            'CERTIFICADO',
            x,
            343,
            61,
            '#071b3b',
            '700',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            'DE PARTICIPAÇÃO',
            x,
            389,
            25,
            '#b88629',
            '900'
        );

        ctx.strokeStyle =
            '#c99a34';

        ctx.lineWidth = 2;

        ctx.beginPath();

        ctx.moveTo(
            x - 175,
            411
        );

        ctx.lineTo(
            x + 175,
            411
        );

        ctx.stroke();
    }

    function drawPremiumEventMessage(campaign) {
        const visual =
            certificateVisual(campaign);

        const x = 250;
        const y = 729;
        const w = 1254;
        const h = 88;

        roundedRect(
            ctx,
            x,
            y,
            w,
            h,
            18
        );

        ctx.fillStyle =
            'rgba(255,255,255,.92)';

        ctx.fill();

        ctx.strokeStyle =
            visual.accent;

        ctx.lineWidth = 2;

        ctx.stroke();

        const lines =
            campaign?.special
                ? certificateMessage(campaign)
                : [
                    'Cada contato constrói uma história.',
                    'Cada transmissão aproxima pessoas.'
                ];

        const shown =
            lines.slice(0, 3);

        const lineHeight =
            shown.length >= 3
                ? 22
                : 27;

        const firstY =
            shown.length >= 3
                ? y + 27
                : y + 32;

        clearLines(
            shown,
            x + w / 2,
            firstY,
            lineHeight,
            15,
            '#34475d',
            '500',
            'Georgia, serif'
        );
    }

    function drawPremiumStats(cert) {
        const stats = [
            [
                'TRANSMISSÕES',
                String(
                    cert.stats?.transmissions
                    || 0
                )
            ],

            [
                'TEMPO TX',
                formatSeconds(
                    cert.stats?.duration_total
                    || 0
                )
            ],

            [
                'PROTOCOLOS',
                (
                    cert.stats?.protocols
                    || []
                )
                    .map(
                        p => String(p)
                            .replace('/DCS', '')
                    )
                    .join(' • ')
                || '—'
            ],

            [
                'MÓDULOS',
                (
                    cert.stats?.modules
                    || []
                ).join(' • ')
                || '—'
            ]
        ];

        const x = 145;
        const y = 840;
        const w = 570;
        const h = 220;

        roundedRect(
            ctx,
            x,
            y,
            w,
            h,
            18
        );

        ctx.fillStyle = '#ffffff';
        ctx.fill();

        ctx.strokeStyle =
            'rgba(201,154,52,.72)';

        ctx.lineWidth = 2;
        ctx.stroke();

        centeredText(
            ctx,
            'PARTICIPAÇÃO REGISTRADA',
            x + w / 2,
            y + 29,
            11,
            '#687688',
            '900'
        );

        const pad = 14;
        const gap = 10;

        const top =
            y + 44;

        const cellW =
            (w - pad * 2 - gap) / 2;

        const cellH = 76;

        stats.forEach(
            ([label, value], index) => {

                const col =
                    index % 2;

                const row =
                    Math.floor(index / 2);

                const bx =
                    x
                    + pad
                    + col * (cellW + gap);

                const by =
                    top
                    + row * (cellH + gap);

                roundedRect(
                    ctx,
                    bx,
                    by,
                    cellW,
                    cellH,
                    11
                );

                ctx.fillStyle =
                    '#fbfaf7';

                ctx.fill();

                ctx.strokeStyle =
                    'rgba(201,154,52,.28)';

                ctx.lineWidth = 1.3;
                ctx.stroke();

                centeredText(
                    ctx,
                    label,
                    bx + cellW / 2,
                    by + 25,
                    9,
                    '#687688',
                    '900'
                );

                const size =
                    fitText(
                        ctx,
                        value,
                        cellW - 18,
                        17,
                        9,
                        '900',
                        'Arial, sans-serif'
                    );

                centeredText(
                    ctx,
                    value,
                    bx + cellW / 2,
                    by + 56,
                    size,
                    '#071b3b',
                    '900'
                );
            }
        );
    }
    function drawPremiumInstitutionalBlock() {
        const x = 170;

        ctx.strokeStyle =
            '#c99a34';

        ctx.lineWidth = 2;

        ctx.beginPath();

        ctx.moveTo(
            x,
            1074
        );

        ctx.lineTo(
            x + 260,
            1074
        );

        ctx.stroke();

        leftText(
            ctx,
            'Equipe {{REFLECTOR_NAME}}',
            x,
            1100,
            16,
            '#071b3b',
            '900'
        );

        leftText(
            ctx,
            'Gestão e Operação do Refletor',
            x,
            1119,
            10,
            '#697788',
            '600'
        );
    }
    function drawPremiumCertificateData(cert) {
        const x = 1039;
        const y = 840;
        const w = 570;
        const h = 220;

        roundedRect(
            ctx,
            x,
            y,
            w,
            h,
            18
        );

        ctx.fillStyle = '#ffffff';
        ctx.fill();

        ctx.strokeStyle =
            'rgba(201,154,52,.72)';

        ctx.lineWidth = 2;
        ctx.stroke();

        centeredText(
            ctx,
            'CERTIFICADO Nº',
            x + w / 2,
            y + 30,
            10,
            '#687688',
            '900'
        );

        const idSize =
            fitText(
                ctx,
                cert.id,
                w - 36,
                17,
                9,
                '900',
                'Arial, sans-serif'
            );

        centeredText(
            ctx,
            cert.id,
            x + w / 2,
            y + 62,
            idSize,
            '#071b3b',
            '900'
        );

        ctx.strokeStyle =
            'rgba(201,154,52,.34)';

        ctx.lineWidth = 1.4;

        ctx.beginPath();

        ctx.moveTo(
            x + 24,
            y + 81
        );

        ctx.lineTo(
            x + w - 24,
            y + 81
        );

        ctx.stroke();

        centeredText(
            ctx,
            'INDICATIVO',
            x + w / 2,
            y + 108,
            10,
            '#687688',
            '900'
        );

        centeredText(
            ctx,
            cert.callsign,
            x + w / 2,
            y + 142,
            23,
            '#071b3b',
            '900'
        );

        centeredText(
            ctx,
            `Emitido em ${issueDate(cert.issued_at_iso)} (BRT)`,
            x + w / 2,
            y + 174,
            10,
            '#687688',
            '600'
        );

        if (
            cert.location
            && cert.location !== 'Não informada'
        ) {
            const locationSize =
                fitText(
                    ctx,
                    cert.location,
                    w - 40,
                    11,
                    8,
                    '700',
                    'Arial, sans-serif'
                );

            centeredText(
                ctx,
                cert.location,
                x + w / 2,
                y + 199,
                locationSize,
                '#687688',
                '700'
            );
        }
    }
    function drawPremiumSideStamp(campaign) {
        if (!campaign?.special) {
            return;
        }

        const visual =
            certificateVisual(campaign);

        const rawTitle =
            String(
                clearEventName(campaign)
                || campaign?.title
                || 'Edição Especial'
            ).trim();

        const eventName =
            rawTitle
                .replace(/\s+20\d{2}\s*$/i, '')
                .trim()
                .toUpperCase();

        const period =
            String(
                campaign?.period_label || ''
            ).trim();

        const date =
            period.match(
                /^(\d{2})\/(\d{2})\/(\d{4})$/
            );

        const months = [
            '',
            'JANEIRO',
            'FEVEREIRO',
            'MARÇO',
            'ABRIL',
            'MAIO',
            'JUNHO',
            'JULHO',
            'AGOSTO',
            'SETEMBRO',
            'OUTUBRO',
            'NOVEMBRO',
            'DEZEMBRO'
        ];

        function wrap(
            text,
            maxWidth,
            size
        ) {
            ctx.font =
                `900 ${size}px Arial, sans-serif`;

            const words =
                String(text)
                    .split(/\s+/)
                    .filter(Boolean);

            const lines = [];
            let line = '';

            words.forEach(word => {
                const candidate =
                    line
                        ? `${line} ${word}`
                        : word;

                if (
                    !line
                    || ctx.measureText(candidate).width
                        <= maxWidth
                ) {
                    line = candidate;
                } else {
                    lines.push(line);
                    line = word;
                }
            });

            if (line) {
                lines.push(line);
            }

            return lines;
        }

        function cardBase(
            x,
            y,
            w,
            h
        ) {
            ctx.save();

            roundedRect(
                ctx,
                x,
                y,
                w,
                h,
                22
            );

            const gradient =
                ctx.createLinearGradient(
                    x,
                    y,
                    x + w,
                    y + h
                );

            gradient.addColorStop(
                0,
                '#061a36'
            );

            gradient.addColorStop(
                .52,
                visual.dark || '#0b3559'
            );

            gradient.addColorStop(
                1,
                '#041329'
            );

            ctx.fillStyle = gradient;
            ctx.fill();

            /*
             * Borda dourada externa.
             */
            ctx.strokeStyle =
                visual.accent;

            ctx.lineWidth = 3;
            ctx.stroke();

            /*
             * Borda interna premium.
             */
            roundedRect(
                ctx,
                x + 7,
                y + 7,
                w - 14,
                h - 14,
                16
            );

            ctx.strokeStyle =
                'rgba(201,154,52,.60)';

            ctx.lineWidth = 1.2;
            ctx.stroke();

            ctx.restore();
        }

        /*
         * ==================================================
         * GEOMETRIA
         *
         * Os dois cartões são espelhados.
         * Mais para dentro do certificado que a V5B.
         * ==================================================
         */

        const w = 205;
        const h = 272;
        const y = 318;

        const leftX = 155;

        const rightX =
            LOGICAL_WIDTH
            - 155
            - w;

        /*
         * ==================================================
         * CARTÃO ESQUERDO
         * EDIÇÃO ESPECIAL
         * ==================================================
         */

        cardBase(
            leftX,
            y,
            w,
            h
        );

        centeredText(
            ctx,
            'EDIÇÃO ESPECIAL',
            leftX + w / 2,
            y + 40,
            12,
            visual.accent,
            '900'
        );

        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            leftX + 50,
            y + 58,
            w - 100,
            2
        );

        /*
         * Pequeno losango central.
         */
        ctx.save();

        ctx.translate(
            leftX + w / 2,
            y + 59
        );

        ctx.rotate(
            Math.PI / 4
        );

        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            -4,
            -4,
            8,
            8
        );

        ctx.restore();

        let eventSize = 13;

        let eventLines =
            wrap(
                eventName,
                w - 32,
                eventSize
            );

        while (
            eventLines.length > 4
            && eventSize > 8
        ) {
            eventSize--;

            eventLines =
                wrap(
                    eventName,
                    w - 32,
                    eventSize
                );
        }

        eventLines =
            eventLines.slice(0, 4);

        const lineHeight =
            eventSize + 6;

        const eventCenter =
            y + 122;

        const firstEventY =
            eventCenter
            - (
                (eventLines.length - 1)
                * lineHeight
                / 2
            );

        eventLines.forEach(
            (line, i) => {
                centeredText(
                    ctx,
                    line,
                    leftX + w / 2,
                    firstEventY
                        + i * lineHeight,
                    eventSize,
                    '#ffffff',
                    '900'
                );
            }
        );

        /*
         * Medalhão central.
         */
        const medX =
            leftX + w / 2;

        const medY =
            y + 190;

        ctx.beginPath();

        ctx.arc(
            medX,
            medY,
            25,
            0,
            Math.PI * 2
        );

        ctx.fillStyle =
            'rgba(201,154,52,.08)';

        ctx.fill();

        ctx.strokeStyle =
            visual.accent;

        ctx.lineWidth = 2.5;
        ctx.stroke();

        /*
         * Símbolo geométrico interno.
         */
        ctx.save();

        ctx.translate(
            medX,
            medY
        );

        ctx.rotate(
            Math.PI / 4
        );

        ctx.strokeStyle =
            visual.accent;

        ctx.lineWidth = 3;

        ctx.strokeRect(
            -7,
            -7,
            14,
            14
        );

        ctx.restore();

        if (date) {
            const shortMonth =
                months[
                    Number(date[2])
                ] || '';

            centeredText(
                ctx,
                `${date[1]} DE ${shortMonth}`,
                leftX + w / 2,
                y + 235,
                fitText(
                    ctx,
                    `${date[1]} DE ${shortMonth}`,
                    w - 30,
                    9,
                    7,
                    '900',
                    'Arial, sans-serif'
                ),
                '#ffffff',
                '900'
            );
        } else {
            centeredText(
                ctx,
                '{{REFLECTOR_NAME}} BRASIL',
                leftX + w / 2,
                y + 235,
                8,
                '#ffffff',
                '900'
            );
        }

        /*
         * ==================================================
         * CARTÃO DIREITO
         * DATA ESPECIAL
         * ==================================================
         */

        cardBase(
            rightX,
            y,
            w,
            h
        );

        centeredText(
            ctx,
            'DATA ESPECIAL',
            rightX + w / 2,
            y + 40,
            12,
            visual.accent,
            '900'
        );

        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            rightX + 50,
            y + 58,
            w - 100,
            2
        );

        ctx.save();

        ctx.translate(
            rightX + w / 2,
            y + 59
        );

        ctx.rotate(
            Math.PI / 4
        );

        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            -4,
            -4,
            8,
            8
        );

        ctx.restore();

        if (date) {
            const day =
                date[1];

            const month =
                months[
                    Number(date[2])
                ] || '';

            const year =
                date[3];

            centeredText(
                ctx,
                day,
                rightX + w / 2,
                y + 125,
                48,
                visual.accent,
                '900',
                'Georgia, serif'
            );

            centeredText(
                ctx,
                month,
                rightX + w / 2,
                y + 164,
                fitText(
                    ctx,
                    month,
                    w - 36,
                    13,
                    9,
                    '900',
                    'Arial, sans-serif'
                ),
                '#ffffff',
                '900'
            );

            centeredText(
                ctx,
                year,
                rightX + w / 2,
                y + 199,
                23,
                visual.accent,
                '900'
            );

        } else {
            const fallback =
                wrap(
                    period || 'EDIÇÃO ESPECIAL',
                    w - 34,
                    12
                ).slice(0, 4);

            const fy =
                y + 133
                - (
                    (fallback.length - 1)
                    * 17 / 2
                );

            fallback.forEach(
                (line, i) => {
                    centeredText(
                        ctx,
                        line,
                        rightX + w / 2,
                        fy + i * 17,
                        12,
                        '#ffffff',
                        '900'
                    );
                }
            );
        }

        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            rightX + 50,
            y + 217,
            w - 100,
            2
        );

        centeredText(
            ctx,
            'CERTIFICADO',
            rightX + w / 2,
            y + 239,
            8,
            '#ffffff',
            '900'
        );

        centeredText(
            ctx,
            'COMEMORATIVO',
            rightX + w / 2,
            y + 254,
            8,
            '#ffffff',
            '900'
        );
    }

    function certificateVerificationUrl(cert) {
        const raw = String(cert?.verification_url || '').trim();
        if (!raw) return '';
        try {
            return new URL(raw, window.location.origin).toString();
        } catch (_) {
            return raw;
        }
    }

    async function drawPremiumValidationCard(
        cert,
        campaign
    ) {
        const visual =
            certificateVisual(campaign);

        /*
         * Canvas lógico = 1754 px.
         * Centro exato = 877 px.
         */
        const w = 260;
        const h = 220;

        const x =
            (LOGICAL_WIDTH - w) / 2;

        const y = 840;

        roundedRect(
            ctx,
            x,
            y,
            w,
            h,
            18
        );

        ctx.fillStyle =
            '#ffffff';

        ctx.fill();

        ctx.strokeStyle =
            visual.accent;

        ctx.lineWidth = 3;
        ctx.stroke();

        centeredText(
            ctx,
            'VALIDAÇÃO DIGITAL',
            x + w / 2,
            y + 27,
            10,
            visual.dark,
            '900'
        );

        ctx.fillStyle =
            visual.accent;

        ctx.fillRect(
            x + 55,
            y + 39,
            w - 110,
            2
        );

        /*
         * Mantém exatamente a URL real
         * recebida da API.
         */
        const qr =
            await makeQrCanvas(
                certificateVerificationUrl(cert)
            );

        const qs = 126;

        const qx =
            x + (w - qs) / 2;

        const qy =
            y + 53;

        /*
         * Quiet zone.
         */
        ctx.fillStyle =
            '#ffffff';

        ctx.fillRect(
            qx - 10,
            qy - 10,
            qs + 20,
            qs + 20
        );

        ctx.drawImage(
            qr,
            qx,
            qy,
            qs,
            qs
        );

        centeredText(
            ctx,
            'AUTENTICIDADE',
            x + w / 2,
            y + 197,
            10,
            visual.dark,
            '900'
        );

        centeredText(
            ctx,
            'Escaneie para validar',
            x + w / 2,
            y + 213,
            8,
            '#687688',
            '700'
        );
    }
    function drawPremiumFooter(campaign) {
        const visual =
            certificateVisual(campaign);

        const x = 140;
        const y = 1134;
        const w = 1474;
        const h = 50;

        roundedRect(
            ctx,
            x,
            y,
            w,
            h,
            25
        );

        const gradient =
            ctx.createLinearGradient(
                x,
                y,
                x + w,
                y
            );

        gradient.addColorStop(
            0,
            '#071b3b'
        );

        gradient.addColorStop(
            .5,
            visual.dark
        );

        gradient.addColorStop(
            1,
            '#071b3b'
        );

        ctx.fillStyle =
            gradient;

        ctx.fill();

        centeredText(
            ctx,
            '{{REFLECTOR_NAME}} • CONECTANDO VOZES, CONECTANDO AMIZADES!',
            x + w / 2,
            y + 31,
            14,
            '#ffffff',
            '900'
        );
    }

    async function drawBlankCertificate(campaign) {
        clearBase(campaign);
        drawClearBrand();
        drawPremiumEventBadge(campaign);
        drawPremiumSideStamp(campaign);
        drawPremiumTitle();

        const x =
            LOGICAL_WIDTH / 2;

        centeredText(
            ctx,
            'Certificamos a participação de',
            x,
            457,
            21,
            '#5c6b7c',
            '400',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            'SEU INDICATIVO',
            x,
            532,
            51,
            '#071b3b',
            '700',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            'Digite seu indicativo para verificar a participação registrada.',
            x,
            586,
            17,
            '#697788',
            '500'
        );

        clearLines(
            [
                'O certificado será gerado com os dados reais',
                'registrados pelo {{REFLECTOR_NAME}}.'
            ],
            x,
            648,
            28,
            16,
            '#34475d',
            '400',
            'Georgia, serif'
        );

        drawPremiumEventMessage(
            campaign
        );

        centeredText(
            ctx,
            'D-STAR  •  DMR  •  C4FM / YSF',
            x,
            914,
            18,
            '#071b3b',
            '900'
        );

        centeredText(
            ctx,
            '{{REFLECTOR_NAME}}',
            x,
            1050,
            17,
            '#071b3b',
            '900'
        );

        drawPremiumFooter(
            campaign
        );
    }

    async function drawCertificate(cert) {
        const campaign =
            cert.campaign || {};

        const visual =
            certificateVisual(campaign);

        const x =
            LOGICAL_WIDTH / 2;

        clearBase(campaign);
        drawClearBrand();
        drawPremiumEventBadge(campaign);
        drawPremiumSideStamp(campaign);
        drawPremiumTitle();

        centeredText(
            ctx,
            'Certificamos que',
            x,
            455,
            21,
            '#5c6b7c',
            '400',
            'Georgia, serif'
        );

        const displayName =
            cert.name
            && cert.name !== 'Não informado'
                ? cert.name.toUpperCase()
                : cert.callsign;

        const nameSize =
            fitText(
                ctx,
                displayName,
                1180,
                48,
                25,
                '700',
                'Georgia, serif'
            );

        centeredText(
            ctx,
            displayName,
            x,
            516,
            nameSize,
            '#071b3b',
            '700',
            'Georgia, serif'
        );

        centeredText(
            ctx,
            cert.callsign,
            x,
            573,
            40,
            visual.accent,
            '900'
        );

        if (
            cert.location
            && cert.location !== 'Não informada'
        ) {
            const locationSize =
                fitText(
                    ctx,
                    cert.location,
                    900,
                    17,
                    11,
                    '700',
                    'Arial, sans-serif'
                );

            centeredText(
                ctx,
                cert.location,
                x,
                607,
                locationSize,
                '#5a6879',
                '700'
            );
        }

        clearLines(
            [
                'teve sua participação registrada no {{REFLECTOR_NAME}},',
                'contribuindo com a integração, a amizade e a atividade',
                'da comunidade do radioamadorismo digital.'
            ],
            x,
            651,
            27,
            17,
            '#304156',
            '400',
            'Georgia, serif'
        );

        /*
         * Removido deste ponto:
         * a confirmação já é exibida em
         * PARTICIPAÇÃO REGISTRADA na faixa inferior.
         */

        drawPremiumEventMessage(
            campaign
        );

        drawPremiumStats(
            cert
        );

        drawPremiumInstitutionalBlock();

        drawPremiumCertificateData(
            cert
        );

        await drawPremiumValidationCard(
            cert,
            campaign
        );

        drawPremiumFooter(
            campaign
        );

        previewState.textContent =
            cert.id;
    }
    async function getCurrentCampaign() {
        try {
            const response = await fetch(
                `${API}?acao=campanha`,
                {
                    cache:'no-store',
                    headers:{'Accept':'application/json'}
                }
            );

            const data = await response.json();

            if (!data.ok) {
                throw new Error(data.message || 'Falha ao carregar campanha.');
            }

            state.campaign = data.campaign;

            campaignLead.textContent = data.campaign.special
                ? `${data.campaign.title} — ${data.campaign.subtitle}`
                : 'Comprove sua participação registrada no {{REFLECTOR_NAME}}.';

            if (data.campaign.special) {
                specialBanner.hidden = false;
                specialTitle.textContent = data.campaign.title;
                specialSubtitle.textContent =
                    `${data.campaign.subtitle} • ${data.campaign.period_label}`;
            } else {
                specialBanner.hidden = true;
            }

            await drawBlankCertificate(data.campaign);

        } catch (error) {
            campaignLead.textContent =
                'Certificados temporariamente indisponíveis.';
            showMessage(
                'Não foi possível carregar o sistema de certificados.',
                'error'
            );

            await drawBlankCertificate({
                theme:'padrao',
                special:false
            });
        }
    }

    async function issueCertificate(callsign) {
        const body = new URLSearchParams();
        body.set('acao', 'emitir');
        body.set('callsign', callsign);

        const response = await fetch(
            API,
            {
                method:'POST',
                headers:{
                    'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8',
                    'Accept':'application/json'
                },
                body:body.toString(),
                cache:'no-store'
            }
        );

        let data;

        try {
            data = await response.json();
        } catch {
            throw new Error('Resposta inválida do servidor.');
        }

        if (!response.ok || !data.ok) {
            throw new Error(
                data.message || 'Não foi possível gerar o certificado.'
            );
        }

        return data;
    }

    form.addEventListener('submit', async event => {
        event.preventDefault();
        clearMessage();

        const callsign = normalizeCall(callInput.value);
        callInput.value = callsign;

        if (callsign.length < 3) {
            showMessage('Digite um indicativo válido.', 'error');
            return;
        }

        const button = form.querySelector('button[type="submit"]');
        button.disabled = true;
        button.textContent = 'Verificando...';
        previewState.textContent = 'Verificando participação';

        try {
            const data = await issueCertificate(callsign);

            state.certificate = data.certificate;

            await drawCertificate(data.certificate);

            actions.hidden = false;

            showMessage(
                data.reused
                    ? 'Seu certificado desta edição já existia. A mesma via foi recuperada para novo download.'
                    : 'Participação confirmada. Seu certificado foi emitido e registrado.',
                'ok'
            );

        } catch (error) {
            actions.hidden = true;
            state.certificate = null;
            previewState.textContent = 'Certificado não liberado';

            showMessage(
                error.message || 'Não foi possível emitir o certificado.',
                'error'
            );

        } finally {
            button.disabled = false;
            button.textContent = 'Verificar e gerar';
        }
    });

    callInput.addEventListener('input', () => {
        callInput.value = normalizeCall(callInput.value);
    });

    function downloadBlob(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');

        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();

        setTimeout(() => URL.revokeObjectURL(url), 1500);
    }

    function canvasJpegBlob() {
        return new Promise((resolve, reject) => {
            canvas.toBlob(
                blob => {
                    if (blob) resolve(blob);
                    else reject(new Error('Falha ao gerar imagem do certificado.'));
                },
                'image/jpeg',
                .96
            );
        });
    }

    function buildPdfFromJpeg(jpegBytes, imageWidth, imageHeight) {
        const enc = new TextEncoder();
        const chunks = [];
        const offsets = new Array(6).fill(0);
        let pos = 0;

        const addBytes = bytes => {
            chunks.push(bytes);
            pos += bytes.length;
        };

        const add = text => addBytes(enc.encode(text));

        const startObject = n => {
            offsets[n] = pos;
            add(`${n} 0 obj\n`);
        };

        add('%PDF-1.3\n');

        startObject(1);
        add('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

        startObject(2);
        add('<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

        startObject(3);
        add(
            '<< /Type /Page /Parent 2 0 R ' +
            '/MediaBox [0 0 841.89 595.28] ' +
            '/Resources << /XObject << /Im0 4 0 R >> >> ' +
            '/Contents 5 0 R >>\nendobj\n'
        );

        startObject(4);
        add(
            `<< /Type /XObject /Subtype /Image ` +
            `/Width ${imageWidth} /Height ${imageHeight} ` +
            `/ColorSpace /DeviceRGB /BitsPerComponent 8 ` +
            `/Filter /DCTDecode /Length ${jpegBytes.length} >>\nstream\n`
        );
        addBytes(jpegBytes);
        add('\nendstream\nendobj\n');

        const content =
            'q\n841.89 0 0 595.28 0 0 cm\n/Im0 Do\nQ\n';
        const contentBytes = enc.encode(content);

        startObject(5);
        add(`<< /Length ${contentBytes.length} >>\nstream\n`);
        addBytes(contentBytes);
        add('endstream\nendobj\n');

        const xrefOffset = pos;

        add('xref\n0 6\n');
        add('0000000000 65535 f \n');

        for (let i = 1; i <= 5; i++) {
            add(
                String(offsets[i]).padStart(10, '0') +
                ' 00000 n \n'
            );
        }

        add(
            'trailer\n' +
            '<< /Size 6 /Root 1 0 R >>\n' +
            'startxref\n' +
            `${xrefOffset}\n` +
            '%%EOF\n'
        );

        return new Blob(
            chunks,
            {type:'application/pdf'}
        );
    }

    downloadPdf.addEventListener('click', async () => {
        if (!state.certificate) return;

        try {
            const jpegBlob = await canvasJpegBlob();
            const jpegBytes = new Uint8Array(
                await jpegBlob.arrayBuffer()
            );

            const pdfBlob = buildPdfFromJpeg(
                jpegBytes,
                canvas.width,
                canvas.height
            );

            downloadBlob(
                pdfBlob,
                `${state.certificate.id}.pdf`
            );
        } catch (error) {
            showMessage(
                'Não foi possível criar o PDF neste navegador.',
                'error'
            );
        }
    });

    downloadPng.addEventListener('click', () => {
        if (!state.certificate) return;

        canvas.toBlob(blob => {
            if (!blob) return;

            downloadBlob(
                blob,
                `${state.certificate.id}.png`
            );
        }, 'image/png');
    });

    async function validateFromUrl() {
        const params = new URLSearchParams(location.search);
        const id = params.get('validar');
        const token = params.get('token');

        if (!id || !token) return;

        verifyBox.hidden = false;
        verifyTitle.textContent = 'Verificando autenticidade...';
        verifyBody.textContent = '';

        try {
            const response = await fetch(
                `${API}?acao=validar&id=${encodeURIComponent(id)}&token=${encodeURIComponent(token)}`,
                {
                    cache:'no-store',
                    headers:{'Accept':'application/json'}
                }
            );

            const data = await response.json();

            if (!response.ok || !data.ok || !data.valid) {
                throw new Error(
                    data.message || 'Certificado inválido.'
                );
            }

            const cert = data.certificate;

            verifyBox.classList.remove('invalid');
            verifyBox.classList.add('valid');
            verifyTitle.textContent =
                '✓ Certificado autêntico — participação confirmada';

            verifyBody.innerHTML = `
                <div class="cert-verify-grid">
                    <div class="cert-verify-item">
                        <span>Indicativo</span>
                        <strong></strong>
                    </div>
                    <div class="cert-verify-item">
                        <span>Operador</span>
                        <strong></strong>
                    </div>
                    <div class="cert-verify-item">
                        <span>Certificado</span>
                        <strong></strong>
                    </div>
                    <div class="cert-verify-item">
                        <span>Edição</span>
                        <strong></strong>
                    </div>
                    <div class="cert-verify-item">
                        <span>Emissão</span>
                        <strong></strong>
                    </div>
                    <div class="cert-verify-item">
                        <span>Status</span>
                        <strong>VÁLIDO</strong>
                    </div>
                </div>
            `;

            const values = [
                cert.callsign,
                cert.name,
                cert.id,
                cert.campaign.title,
                issueDate(cert.issued_at_iso)
            ];

            verifyBody
                .querySelectorAll('.cert-verify-item strong')
                .forEach((node, index) => {
                    if (index < values.length) {
                        node.textContent = values[index];
                    }
                });

            state.certificate = cert;
            state.campaign = cert.campaign;

            await drawCertificate(cert);
            actions.hidden = false;

            verifyBox.scrollIntoView({
                behavior:'smooth',
                block:'start'
            });

        } catch (error) {
            verifyBox.classList.remove('valid');
            verifyBox.classList.add('invalid');
            verifyTitle.textContent = 'Certificado não validado';
            verifyBody.textContent =
                error.message || 'Não foi possível validar este certificado.';
        }
    }

    (async () => {
        await getCurrentCampaign();
        await validateFromUrl();
    })();
})();
