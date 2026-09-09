<section class="page-heading cert-page-heading">
    <p class="eyebrow">REGISTRO OFICIAL DE PARTICIPAÇÃO</p>
    <h1>Certificado {{REFLECTOR_NAME}}</h1>
    <p id="certCampaignLead">Verificando a edição disponível para hoje...</p>
</section>

<section class="cert-layout">

    <section class="panel cert-generator">
        <div id="certSpecialBanner" class="cert-special-banner" hidden>
            <span>EDIÇÃO ESPECIAL</span>
            <strong id="certSpecialTitle"></strong>
            <small id="certSpecialSubtitle"></small>
        </div>

        <div class="cert-intro">
            <h2>Gerar meu certificado</h2>
            <p>
                Digite seu indicativo. O {{REFLECTOR_NAME}} verificará automaticamente
                se existe participação registrada no período válido.
            </p>
        </div>

        <form id="certForm" class="cert-form" autocomplete="off">
            <label for="certCallsign">Indicativo</label>

            <div class="cert-input-row">
                <input
                    id="certCallsign"
                    name="callsign"
                    type="text"
                    maxlength="10"
                    placeholder="Ex.: N0CALL"
                    autocomplete="off"
                    autocapitalize="characters"
                    spellcheck="false"
                    required
                >
                <button type="submit" class="cert-primary-btn">
                    Verificar e gerar
                </button>
            </div>
        </form>

        <div
            id="certMessage"
            class="cert-message"
            role="status"
            aria-live="polite"
            hidden
        ></div>

        <div class="cert-rules">
            <div>
                <strong>Participação real</strong>
                <span>O certificado só é liberado quando existe transmissão registrada no {{REFLECTOR_NAME}}.</span>
            </div>
            <div>
                <strong>Uma emissão</strong>
                <span>Na mesma campanha, o sistema reutiliza o certificado já emitido.</span>
            </div>
            <div>
                <strong>QR verificável</strong>
                <span>Cada certificado possui código individual de autenticidade.</span>
            </div>
        </div>
    </section>

    <section class="panel cert-preview-panel">
        <div class="cert-preview-top">
            <div>
                <p class="eyebrow">PRÉVIA</p>
                <h2>Seu certificado</h2>
            </div>
            <span id="certPreviewState">Aguardando indicativo</span>
        </div>

        <div class="cert-canvas-wrap">
            <canvas
                id="certCanvas"
                width="3508"
                height="2480"
                aria-label="Prévia do certificado {{REFLECTOR_NAME}}"
            ></canvas>
        </div>

        <div id="certActions" class="cert-actions" hidden>
            <button id="certDownloadPdf" type="button" class="cert-primary-btn">
                Baixar PDF
            </button>
            <button id="certDownloadPng" type="button" class="cert-secondary-btn">
                Baixar imagem
            </button>
        </div>
    </section>

</section>

<section id="certVerification" class="panel cert-verification" hidden>
    <p class="eyebrow">VALIDAÇÃO PÚBLICA</p>
    <h2 id="certVerificationTitle">Verificando certificado...</h2>
    <div id="certVerificationBody"></div>
</section>

<div
    id="certQrStage"
    class="cert-qr-stage"
    aria-hidden="true"
></div>
