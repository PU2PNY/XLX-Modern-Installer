<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Carregando</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #0f172a;
      font-family: Arial, sans-serif;
      color: #ffffff;
    }

    .loader-container {
      text-align: center;
    }

    .spinner {
      width: 64px;
      height: 64px;
      border: 6px solid rgba(255, 255, 255, 0.15);
      border-top: 6px solid #38bdf8;
      border-radius: 50%;
      animation: girar 1s linear infinite;
      margin: 0 auto 20px auto;
    }

    .mensagem {
      font-size: 20px;
      font-weight: bold;
      letter-spacing: 0.5px;
    }

    .subtexto {
      margin-top: 10px;
      font-size: 14px;
      color: #cbd5e1;
    }

    @keyframes girar {
      0% {
        transform: rotate(0deg);
      }
      100% {
        transform: rotate(360deg);
      }
    }
  </style>
</head>
<body>
  <div class="loader-container">
    <div class="spinner"></div>
    <div class="mensagem" id="mensagem">Carregando...</div>
    <div class="subtexto">Aguarde um instante</div>
  </div>

  <script>
    const mensagens = [
      "Carregando...",
      "Atualizando......",
      "Preparando conteudo...",
      "Quase pronto..."
    ];

    let indice = 0;
    const elMensagem = document.getElementById("mensagem");

    setInterval(() => {
      indice = (indice + 1) % mensagens.length;
      elMensagem.textContent = mensagens[indice];
    }, 2000);
  </script>
</body>
</html>