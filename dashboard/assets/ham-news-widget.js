(() => {
    "use strict";

    if (
        !document.body ||
        document.body.dataset.page !== "noticias"
    ) {
        return;
    }

    const widget = document.getElementById("hamNewsWidget");

    if (!widget) {
        return;
    }

    const anatel = document.getElementById("hamNewsAnatel");
    const labre = document.getElementById("hamNewsLabre");
    const updated = document.getElementById("hamNewsUpdated");
    const refresh = document.getElementById("hamNewsRefresh");

    let loading = false;

    function loadingMarkup(container){
        container.innerHTML = `
            <div class="ham-news-loading" aria-label="Atualizando notícias">
                <span></span>
                <span></span>
                <span></span>
            </div>
        `;
    }

    function formatDate(value){
        if (!value) {
            return "Publicação oficial";
        }

        const d = new Date(value);

        if (Number.isNaN(d.getTime())) {
            return "Publicação oficial";
        }

        return new Intl.DateTimeFormat(
            "pt-BR",
            {
                day:"2-digit",
                month:"2-digit",
                year:"numeric",
                hour:"2-digit",
                minute:"2-digit"
            }
        ).format(d);
    }

    function render(container, items, source){

        container.replaceChildren();

        if (!Array.isArray(items) || items.length === 0) {

            const empty = document.createElement("div");

            empty.className = "ham-news-empty";
            empty.textContent =
                `Não foi possível atualizar ${source} neste momento.`;

            container.appendChild(empty);

            return;
        }

        items.forEach(item => {

            const a = document.createElement("a");

            a.className = "ham-news-item";
            a.href = String(item.url || "#");
            a.target = "_blank";
            a.rel = "noopener noreferrer";

            const title = document.createElement("span");

            title.className = "ham-news-item-title";
            title.textContent = String(
                item.title || "Notícia"
            );

            const meta = document.createElement("span");
            meta.className = "ham-news-meta";

            const date = document.createElement("span");
            date.textContent = formatDate(item.published);

            const open = document.createElement("span");
            open.className = "ham-news-open";
            open.textContent = "Abrir ↗";

            meta.append(date, open);
            a.append(title, meta);

            container.appendChild(a);
        });
    }

    async function loadNews(manual = false){

        if (loading) {
            return;
        }

        loading = true;

        if (manual) {
            refresh.disabled = true;
            refresh.textContent = "Atualizando...";
        }

        const controller = new AbortController();
        const timer = setTimeout(
            () => controller.abort(),
            12000
        );

        try {

            const res = await fetch(
                "/api/ham-news.php?v=1",
                {
                    cache:"no-store",
                    signal:controller.signal
                }
            );

            if (!res.ok) {
                throw new Error(`HTTP ${res.status}`);
            }

            const data = await res.json();

            if (!data || data.ok !== true) {
                throw new Error("Resposta inválida");
            }

            render(anatel, data.anatel, "a ANATEL");
            render(labre, data.labre, "a LABRE");

            const generated = new Date(data.generated_at);

            if (!Number.isNaN(generated.getTime())) {

                updated.textContent =
                    "Atualizado " +
                    generated.toLocaleTimeString(
                        "pt-BR",
                        {
                            hour:"2-digit",
                            minute:"2-digit"
                        }
                    );
            }

        } catch (error) {

            console.warn(
                "XLX026 notícias:",
                error
            );

            if (!anatel.children.length) {
                render(anatel, [], "a ANATEL");
            }

            if (!labre.children.length) {
                render(labre, [], "a LABRE");
            }

            updated.textContent =
                "Atualização indisponível";

        } finally {

            clearTimeout(timer);

            loading = false;

            refresh.disabled = false;
            refresh.textContent = "Atualizar";
        }
    }

    refresh?.addEventListener(
        "click",
        () => loadNews(true)
    );

    loadingMarkup(anatel);
    loadingMarkup(labre);

    loadNews();

    /*
     * 15 minutos.
     * O backend também possui cache próprio.
     */
    setInterval(
        () => {
            if (!document.hidden) {
                loadNews();
            }
        },
        15 * 60 * 1000
    );

})();
