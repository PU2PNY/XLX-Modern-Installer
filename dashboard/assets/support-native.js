document.addEventListener('DOMContentLoaded',()=>{
const supportRoot=document.querySelector('.support-native'); if(!supportRoot) return;

    const typebotInitScript = document.createElement("script");
    typebotInitScript.type = "module";
    typebotInitScript.innerHTML = `import Typebot from 'https://cdn.jsdelivr.net/npm/@typebot.io/js@0/dist/web.js'
  
Typebot.initStandard({ typebot: "d-starbrasil-{{REFLECTOR_NAME}}" });
`;
    document.body.append(typebotInitScript);
  


    const tutorials = [
      {
        id: "q8qnJkGIwtQ",
        title: "Atualizar a lista de servidores no Pi-Star e WPSD",
        description: "Mostra como atualizar as listas de servidores D-STAR, DMR e YSF/C4FM no Pi-Star ou WPSD.",
        category: "apoio",
        label: "Hotspot"
      },
      {
        id: "jIUHAfXIXuM",
        title: "Aplicativo Android para conectar ao DMR",
        description: "Tutorial de instalação e configuração do aplicativo Z3 DMR para acessar servidores DMR pelo celular.",
        category: "{{REFLECTOR_NAME}}",
        label: "DMR"
      },
      {
        id: "O6pF45RkjlU",
        title: "Como trocar rapidamente de refletor D-STAR",
        description: "Explica como mudar de refletor D-STAR pelo Pi-Star e pelo aplicativo ircDDB Remote.",
        category: "{{REFLECTOR_NAME}}",
        label: "D-STAR"
      },
      {
        id: "RRttQ28x-Hg",
        title: "Ativar o D-STAR no Pi-Star e conectar ao {{REFLECTOR_NAME}}",
        description: "Passo a passo para habilitar o D-STAR no Pi-Star e conectar o hotspot ao refletor {{REFLECTOR_NAME}}.",
        category: "{{REFLECTOR_NAME}}",
        label: "D-STAR"
      },
      {
        id: "0_-3tE-aVvg",
        title: "Como conectar ao DMR usando o aplicativo VOXDMR",
        description: "Passo a passo para configurar o VOXDMR, conectar ao DMR e utilizar o {{REFLECTOR_NAME}} pelo aplicativo.",
        category: "{{REFLECTOR_NAME}}",
        label: "VOXDMR"
      },

      {
        id: "2MZUdodGGEE",
        title: "Como agendar a promoção de classe C para B",
        description: "Passo a passo para acessar o sistema da ANATEL e agendar a promoção da licença de radioamador da classe C para a classe B.",
        category: "classe",
        label: "Classe"
      },
      {
        id: "Qv821YJAJoY",
        title: "Módulo MMAR da ANATEL: licenciamento e migração",
        description: "Apresentação do módulo MMAR dentro do sistema Mosaico, com orientações sobre licenciamento, migração e procedimentos para radioamadores.",
        category: "anatel",
        label: "ANATEL"
      },
      {
        id: "D3yV9iRYBtQ",
        title: "Como identificar a fabricação e o firmware da MMDVM",
        description: "Mostra como consultar pelo terminal SSH do Pi-Star a data de fabricação e a versão do firmware da placa MMDVM.",
        category: "apoio",
        label: "MMDVM"
      },
      {
        id: "AJJmlH9qZ1Y",
        title: "Como instalar o DroidStar sem erro de áudio",
        description: "Guia para baixar e instalar no Android uma versão do DroidStar com suporte de áudio, evitando problemas relacionados ao vocoder.",
        category: "{{REFLECTOR_NAME}}",
        label: "DroidStar"
      },
      {
        id: "uDBUACMhOG0",
        title: "WPSD: conectar C4FM ao YSF72426 do {{REFLECTOR_NAME}}",
        description: "Configuração prática do hotspot com WPSD para operar em C4FM/System Fusion conectado ao refletor YSF72426 do {{REFLECTOR_NAME}}.",
        category: "{{REFLECTOR_NAME}}",
        label: "C4FM / WPSD"
      },
      {
        id: "_ilJWy92-VU",
        title: "Como configurar o WPSD para D-STAR no {{REFLECTOR_NAME}}",
        description: "Tutorial de configuração inicial do WPSD para conectar o hotspot ao refletor D-STAR {{REFLECTOR_NAME}} e selecionar o módulo correto.",
        category: "{{REFLECTOR_NAME}}",
        label: "D-STAR / WPSD"
      },
      {
        id: "veace9-23cE",
        title: "Instalação do WPSD do zero no cartão de memória",
        description: "Passo a passo para baixar a imagem do WPSD, gravar no cartão e preparar o hotspot MMDVM para os modos digitais.",
        category: "apoio",
        label: "Instalação WPSD"
      },
      {
        id: "6dARFsYumOs",
        title: "Configuração complementar de hotspot e modos digitais",
        description: "Tutorial complementar da biblioteca para revisar ajustes de hotspot, Pi-Star ou WPSD e a operação nos modos digitais.",
        category: "apoio",
        label: "Apoio"
      },
      {
        id: "hNJnxTn36UY",
        title: "Configuração DMR no {{REFLECTOR_NAME}} pelo Pi-Star",
        description: "Explica como configurar o hotspot Pi-Star para conectar um rádio DMR diretamente ao servidor {{REFLECTOR_NAME}}.",
        category: "{{REFLECTOR_NAME}}",
        label: "DMR / Pi-Star"
      },
      {
        id: "gLjF8gl28GA",
        title: "Como configurar Pi-Star para C4FM/YSF no {{REFLECTOR_NAME}}",
        description: "Configuração do Pi-Star para operar em C4FM/YSF, conectar ao servidor {{REFLECTOR_NAME}} e acessar o refletor correspondente.",
        category: "{{REFLECTOR_NAME}}",
        label: "C4FM / Pi-Star"
      },
      {
        id: "Ig3eBxtUcY4",
        title: "DroidStar: configurar DMR no {{REFLECTOR_NAME}} passo a passo",
        description: "Guia completo para configurar o DroidStar no Android e operar em DMR, com referência também aos modos D-STAR e C4FM.",
        category: "{{REFLECTOR_NAME}}",
        label: "DMR / DroidStar"
      },
      {
        id: "_EMeDCZWlMU",
        title: "DroidStar YSF/C4FM: conectar ao YSF72426",
        description: "Configuração do DroidStar para conectar e comunicar no refletor YSF72426, integrado ao ambiente C4FM do {{REFLECTOR_NAME}}.",
        category: "{{REFLECTOR_NAME}}",
        label: "YSF / DroidStar"
      },
      {
        id: "cGypXpI1kQo",
        title: "Conectar ao C4FM YSF72426 usando rádio DMR",
        description: "Demonstra como configurar o hotspot Pi-Star em crossmode para acessar o C4FM/YSF72426 com um rádio DMR.",
        category: "{{REFLECTOR_NAME}}",
        label: "Crossmode"
      }
    ];

    const videosGrid = document.getElementById("videosGrid");
    const emptyVideos = document.getElementById("emptyVideos");
    const videoSearch = document.getElementById("videoSearch");
    const filterButtons = document.querySelectorAll(".support-native .filter-btn");
    const videoModal = document.getElementById("videoModal");
    const videoFrame = document.getElementById("videoFrame");
    const closeVideoModal = document.getElementById("closeVideoModal");
    const modalVideoTitle = document.getElementById("modalVideoTitle");
    const backTop = document.querySelector(".support-native .back-top");

    let activeFilter = "all";

    function youtubeWatchUrl(id) {
      return `https://www.youtube.com/watch?v=${id}`;
    }

    function youtubeEmbedUrl(id) {
      return `https://www.youtube.com/embed/${id}?autoplay=1&rel=0`;
    }

    function youtubeThumbUrl(id) {
      return `https://img.youtube.com/vi/${id}/hqdefault.jpg`;
    }

    function escapeHtml(value) {
      return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }

    function renderVideos() {
      const searchTerm = videoSearch.value.trim().toLowerCase();
      const filtered = tutorials.filter((video) => {
        const matchesFilter = activeFilter === "all" || video.category === activeFilter;
        const haystack = `${video.title} ${video.description} ${video.label}`.toLowerCase();
        const matchesSearch = !searchTerm || haystack.includes(searchTerm);
        return matchesFilter && matchesSearch;
      });

      videosGrid.innerHTML = filtered.map((video) => `
        <article class="video-card" tabindex="0" role="button" aria-label="Assistir ${escapeHtml(video.title)}" data-video-id="${escapeHtml(video.id)}" data-title="${escapeHtml(video.title)}">
          <div class="video-thumb">
            <img src="${youtubeThumbUrl(video.id)}" alt="Miniatura do vídeo ${escapeHtml(video.title)}" loading="lazy">
            <span class="video-label">${escapeHtml(video.label)}</span>
            <span class="play-button" aria-hidden="true">▶</span>
          </div>
          <div class="video-info">
            <h3>${escapeHtml(video.title)}</h3>
            <p>${escapeHtml(video.description)}</p>
            <div class="video-meta">
              <span>Vídeo tutorial</span>
              <a href="${youtubeWatchUrl(video.id)}" target="_blank" rel="noopener" onclick="event.stopPropagation()">Abrir no YouTube</a>
            </div>
          </div>
        </article>
      `).join("");

      emptyVideos.style.display = filtered.length ? "none" : "block";
    }

    function openVideo(id, title) {
      modalVideoTitle.textContent = title || "Vídeo tutorial";
      videoFrame.src = youtubeEmbedUrl(id);
      videoModal.classList.add("active");
      videoModal.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
    }

    function closeVideo() {
      videoModal.classList.remove("active");
      videoModal.setAttribute("aria-hidden", "true");
      videoFrame.src = "";
      document.body.style.overflow = "";
    }

    videosGrid.addEventListener("click", (event) => {
      const card = event.target.closest(".video-card");
      if (!card) return;
      openVideo(card.dataset.videoId, card.dataset.title);
    });

    videosGrid.addEventListener("keydown", (event) => {
      const card = event.target.closest(".video-card");
      if (!card) return;
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openVideo(card.dataset.videoId, card.dataset.title);
      }
    });

    filterButtons.forEach((button) => {
      button.addEventListener("click", () => {
        filterButtons.forEach((item) => item.classList.remove("active"));
        button.classList.add("active");
        activeFilter = button.dataset.filter;
        renderVideos();
      });
    });

    videoSearch.addEventListener("input", renderVideos);
    closeVideoModal.addEventListener("click", closeVideo);

    videoModal.addEventListener("click", (event) => {
      if (event.target === videoModal) closeVideo();
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && videoModal.classList.contains("active")) {
        closeVideo();
      }
    });

    window.addEventListener("scroll", () => {
      if (window.scrollY > 420) {
        backTop.classList.add("visible");
      } else {
        backTop.classList.remove("visible");
      }
    });

    renderVideos();
  
});
