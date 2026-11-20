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
        certificate: null
    };

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

    function certificateMessage(campaign) {
        if (campaign?.theme === 'profissao') {
            return ['Uma homenagem do {{REFLECTOR_NAME}} aos profissionais que fazem a diferença.'];
        }

        const map = {
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
    function certificateVerificationUrl(cert) {
        const raw = String(cert?.verification_url || '').trim();
        if (!raw) return '';
        try {
            return new URL(raw, window.location.origin).toString();
        } catch (_) {
            return raw;
        }
    }

    const certificateCenter = LOGICAL_WIDTH / 2;
    const certificateInk = '#122944';
    const certificateMuted = '#455973';
    const certificateSerif = 'Georgia, serif';

    function certificateText(text, x, y, width, size, options = {}) {
        const { color = certificateInk, weight = '400', family = certificateSerif, style = '' } = options;
        ctx.save();
        ctx.fillStyle = color;
        ctx.font = `${style} ${weight} ${size}px ${family}`.trim();
        ctx.textAlign = 'center';
        ctx.textBaseline = 'alphabetic';
        const measured = ctx.measureText(text).width;
        if (measured > width) {
            const fittedSize = Math.max(15, Math.floor(size * width / measured));
            ctx.font = `${style} ${weight} ${fittedSize}px ${family}`.trim();
        }
        ctx.fillText(text, x, y, width);
        ctx.restore();
    }

    function drawCertificateCorner(x, y, horizontal, vertical, gold) {
        ctx.save();
        ctx.translate(x, y);
        ctx.scale(horizontal, vertical);
        ctx.lineCap = 'round';
        ctx.strokeStyle = gold;
        ctx.lineWidth = 2.5;

        ctx.beginPath();
        ctx.moveTo(12, 156);
        ctx.bezierCurveTo(12, 62, 62, 12, 156, 12);
        ctx.bezierCurveTo(120, 13, 109, 50, 138, 56);
        ctx.bezierCurveTo(159, 61, 164, 37, 148, 34);
        ctx.moveTo(13, 156);
        ctx.bezierCurveTo(15, 121, 52, 109, 58, 138);
        ctx.bezierCurveTo(63, 159, 38, 164, 35, 148);
        ctx.moveTo(22, 23);
        ctx.bezierCurveTo(46, 35, 40, 54, 62, 62);
        ctx.bezierCurveTo(82, 69, 89, 50, 75, 45);
        ctx.moveTo(22, 23);
        ctx.bezierCurveTo(35, 46, 55, 40, 62, 62);
        ctx.bezierCurveTo(69, 82, 50, 89, 45, 75);
        ctx.stroke();

        ctx.fillStyle = gold;
        for (const [leafX, leafY, angle] of [[91, 25, -.42], [62, 44, -.72], [43, 65, -.91], [23, 94, -1.16]]) {
            ctx.beginPath();
            ctx.ellipse(leafX, leafY, 12, 3.4, angle, 0, Math.PI * 2);
            ctx.fill();
        }
        ctx.restore();
    }

    function drawCertificateFrame(visual) {
        const frame = ctx.createLinearGradient(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
        frame.addColorStop(0, '#050e24');
        frame.addColorStop(.47, '#163d68');
        frame.addColorStop(1, '#050f26');
        ctx.fillStyle = frame;
        ctx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);

        const gold = ctx.createLinearGradient(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
        gold.addColorStop(0, '#f5e4af');
        gold.addColorStop(.33, '#8f622b');
        gold.addColorStop(.62, '#f0d895');
        gold.addColorStop(1, '#a77537');

        const paper = ctx.createRadialGradient(certificateCenter, 550, 225, certificateCenter, 575, 960);
        paper.addColorStop(0, '#ffffff');
        paper.addColorStop(.71, '#fcfbf6');
        paper.addColorStop(1, '#e8e0ce');
        ctx.fillStyle = paper;
        ctx.fillRect(106, 106, LOGICAL_WIDTH - 212, LOGICAL_HEIGHT - 212);

        ctx.strokeStyle = gold;
        for (const [inset, width] of [[20, 2], [41, 8], [52, 2], [99, 7], [110, 2]]) {
            ctx.lineWidth = width;
            ctx.strokeRect(inset, inset, LOGICAL_WIDTH - 2 * inset, LOGICAL_HEIGHT - 2 * inset);
        }

        const inset = 130;
        const right = LOGICAL_WIDTH - inset;
        const bottom = LOGICAL_HEIGHT - inset;
        const corner = 85;
        ctx.beginPath();
        ctx.moveTo(inset + corner, inset);
        ctx.lineTo(right - corner, inset);
        ctx.quadraticCurveTo(right - corner + 10, inset + corner - 10, right, inset + corner);
        ctx.lineTo(right, bottom - corner);
        ctx.quadraticCurveTo(right - corner + 10, bottom - corner + 10, right - corner, bottom);
        ctx.lineTo(inset + corner, bottom);
        ctx.quadraticCurveTo(inset + corner - 10, bottom - corner + 10, inset, bottom - corner);
        ctx.lineTo(inset, inset + corner);
        ctx.quadraticCurveTo(inset + corner - 10, inset + corner - 10, inset + corner, inset);
        ctx.closePath();
        ctx.strokeStyle = '#183c61';
        ctx.lineWidth = 4;
        ctx.stroke();

        drawCertificateCorner(62, 62, 1, 1, gold);
        drawCertificateCorner(LOGICAL_WIDTH - 62, 62, -1, 1, gold);
        drawCertificateCorner(62, LOGICAL_HEIGHT - 62, 1, -1, gold);
        drawCertificateCorner(LOGICAL_WIDTH - 62, LOGICAL_HEIGHT - 62, -1, -1, gold);

        ctx.fillStyle = visual.dark;
        ctx.beginPath();
        ctx.arc(certificateCenter, 125, 30, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = gold;
        ctx.lineWidth = 3;
        ctx.stroke();
        certificateText(visual.symbol, certificateCenter, 134, 40, 24, { color: '#f6e3ab' });
    }

    function drawCertificateRule(x, y, width) {
        ctx.fillStyle = '#a78141';
        ctx.fillRect(x - width / 2, y, width, 2);
    }

    function drawCertificateFooter(cert, qr) {
        const left = 496;
        const right = LOGICAL_WIDTH - left;
        drawCertificateRule(left, 952, 400);
        drawCertificateRule(right, 952, 400);
        const heading = { weight: '700', family: 'Arial, sans-serif' };
        certificateText('DATA DE EMISSÃO', left, 983, 400, 17, heading);
        certificateText(cert ? `${issueDate(cert.issued_at_iso)} (BRT)` : '—', left, 1017, 400, 22);
        certificateText('Equipe {{REFLECTOR_NAME}}', right, 983, 400, 22, { weight: '700' });
        certificateText('Gestão e Operação do Refletor', right, 1017, 400, 18);
        if (!cert || !qr) return;

        certificateText(cert.id, left, 1052, 400, 18, { ...heading, color: certificateMuted });
        const size = 152;
        const x = certificateCenter - size / 2;
        const y = 880;
        ctx.fillStyle = '#fff';
        ctx.fillRect(x - 16, y - 16, size + 32, size + 32);
        ctx.strokeStyle = '#a78141';
        ctx.lineWidth = 2;
        ctx.strokeRect(x - 16, y - 16, size + 32, size + 32);
        ctx.save();
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(qr, x, y, size, size);
        ctx.restore();
        certificateText('VALIDAÇÃO DIGITAL', certificateCenter, 1074, 220, 15, heading);
    }

    function drawCertificateLayout(campaign, cert, qr) {
        const x = certificateCenter;
        const sans = { family: 'Arial, sans-serif' };
        const bold = { ...sans, weight: '700' };
        const visual = certificateVisual(campaign);
        drawCertificateFrame(visual);

        certificateText('{{REFLECTOR_NAME}}', x, 211, 1100, 29, bold);
        certificateText('CERTIFICADO', x, 308, 1200, 96, { weight: '700' });
        certificateText('DE PARTICIPAÇÃO', x, 358, 1100, 30, bold);
        drawCertificateRule(x, 388, 326);
        certificateText('Certificamos a participação de', x, 442, 1100, 29);

        const callsign = cert?.callsign || 'SEU INDICATIVO';
        const hasName = cert?.name && cert.name !== 'Não informado';
        certificateText(hasName ? cert.name : callsign, x, 551, 1280, 92, { style: 'italic' });
        drawCertificateRule(x, 576, 730);

        const location = cert?.location === 'Não informada' ? '' : cert?.location;
        const identity = [hasName ? callsign : '', location].filter(Boolean).join('  •  ');
        certificateText(identity, x, 620, 1060, 23, { ...bold, color: certificateMuted });
        certificateText(campaign?.title || 'Participação {{REFLECTOR_NAME}}', x, 677, 1170, 34, {
            weight: '700',
            color: visual.dark
        });
        certificateText(campaign?.period_label || '', x, 716, 1170, 23, { color: certificateMuted });

        const message = campaign?.special
            ? certificateMessage(campaign)
            : [cert
                ? 'Participação registrada na comunidade de radioamadorismo digital.'
                : 'Digite seu indicativo para verificar a participação registrada.'];
        message.forEach((line, index) => {
            certificateText(line, x, 758 + 24 * index, 1170, 22, { color: certificateMuted });
        });

        if (cert) {
            const stats = cert.stats || {};
            const protocols = (stats.protocols || []).map(protocol => String(protocol).replace('/DCS', ''));
            const metrics = [
                `${'TRANSMISSÕES'} ${stats.transmissions || 0}`,
                `${'TEMPO TX'} ${formatSeconds(stats.duration_total)}`,
                `${'PROTOCOLOS'} ${protocols.join(' / ') || '—'}`,
                `${'MÓDULOS'} ${(stats.modules || []).join(' / ') || '—'}`
            ];
            certificateText(metrics.join('   •   '), x, 848, 1260, 22, bold);
        }

        drawCertificateFooter(cert, qr);
    }

    function drawBlankCertificate(campaign) {
        drawCertificateLayout(campaign, null, null);
    }

    async function drawCertificate(cert) {
        const qr = await makeQrCanvas(certificateVerificationUrl(cert));
        drawCertificateLayout(cert.campaign || {}, cert, qr);
        previewState.textContent = cert.id;
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
        actions.hidden = true;
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
