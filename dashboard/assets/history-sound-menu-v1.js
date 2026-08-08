/* ==========================================================
   XLX026_HISTORY_SOUND_MENU_V1

   Não recria a função de áudio.
   Usa o controle de Bip que já existe no painel.

   O botão original permanece no DOM.
   O novo botão no menu apenas aciona o original.
   ========================================================== */

(() => {

    'use strict';


    const normalize = value =>
        String(value || '')
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toLowerCase();


    function descricao(element){

        if (!element) return '';

        return normalize([
            element.textContent,
            element.getAttribute('aria-label'),
            element.getAttribute('title'),
            element.id,
            element.className
        ].join(' '));
    }


    function localizarControle(){

        const widget =
            document.querySelector(
                'body[data-page="ao-vivo"] .live-widget'
            );

        if (!widget) return null;


        const candidates =
            Array.from(
                widget.querySelectorAll(
                    'button, [role="button"]'
                )
            )
            .filter(element =>
                !element.classList.contains(
                    'xlx026-menu-sound-control'
                )
            );


        /*
         * Primeiro tenta identificar por nome/ícone.
         */
        const sound =
            candidates.find(element => {

                const value =
                    descricao(element);

                return (
                    /bip|beep|audio|som|speaker|volume|mute|alto.?falante/.test(value)
                    || /🔊|🔇|🔈/.test(
                        element.textContent || ''
                    )
                );
            });


        if (sound) return sound;


        /*
         * No monitor atual existe um único botão circular
         * de alto-falante. Se for o único button do widget,
         * é seguro utilizá-lo.
         */
        const realButtons =
            candidates.filter(element =>
                element.tagName === 'BUTTON'
            );


        if (realButtons.length === 1){
            return realButtons[0];
        }


        return null;
    }


    let original = null;
    let proxy = null;
    let stateObserver = null;


    function iconFromOriginal(){

        if (!original){
            return '🔊';
        }


        const value =
            descricao(original);


        /*
         * Se o texto do botão é a AÇÃO disponível:
         *
         * "Ligar/ativar" = atualmente desligado.
         * "Desligar/silenciar" = atualmente ligado.
         */
        if (
            /ligar|ativar|habilitar|unmute/.test(value)
            && !/desligar|desativar/.test(value)
        ){
            return '🔇';
        }


        if (
            /desligar|desativar|silenciar|mute/.test(value)
        ){
            return '🔊';
        }


        if (
            String(original.textContent || '')
                .includes('🔇')
        ){
            return '🔇';
        }


        return '🔊';
    }


    function sincronizar(){

        if (!proxy || !original){
            return;
        }


        const icon =
            iconFromOriginal();


        const iconElement =
            proxy.querySelector(
                '.xlx026-sound-icon'
            );


        if (iconElement){
            iconElement.textContent = icon;
        }


        proxy.classList.toggle(
            'is-off',
            icon === '🔇'
        );


        const label =
            original.getAttribute('aria-label')
            || original.getAttribute('title')
            || 'Ligar ou desligar o bip';


        proxy.setAttribute(
            'title',
            label
        );


        const pressed =
            original.getAttribute(
                'aria-pressed'
            );


        if (pressed !== null){

            proxy.setAttribute(
                'aria-pressed',
                pressed
            );

        } else {

            proxy.removeAttribute(
                'aria-pressed'
            );
        }
    }


    function criarProxy(){

        const nav =
            document.querySelector(
                '.universal-header .universal-nav'
            );


        if (!nav || !original){
            return;
        }


        proxy =
            nav.querySelector(
                '.xlx026-menu-sound-control'
            );


        if (!proxy){

            proxy =
                document.createElement(
                    'button'
                );


            proxy.type = 'button';

            proxy.className =
                'xlx026-menu-sound-control';


            proxy.innerHTML =
                '<span class="xlx026-sound-icon" aria-hidden="true">🔊</span>'
                + '<span>Bip</span>';


            proxy.setAttribute(
                'aria-label',
                'Ligar ou desligar o bip'
            );


            nav.appendChild(proxy);


            proxy.addEventListener(
                'click',
                event => {

                    event.preventDefault();
                    event.stopPropagation();


                    /*
                     * Aciona o botão REAL.
                     *
                     * Assim toda a lógica de áudio já existente
                     * continua sendo utilizada.
                     */
                    if (
                        original
                        && original.isConnected
                    ){

                        original.click();


                        window.setTimeout(
                            sincronizar,
                            80
                        );


                        window.setTimeout(
                            sincronizar,
                            300
                        );
                    }
                }
            );
        }


        original.classList.add(
            'xlx026-original-sound-control'
        );


        sincronizar();


        if (stateObserver){
            stateObserver.disconnect();
        }


        stateObserver =
            new MutationObserver(
                sincronizar
            );


        stateObserver.observe(
            original,
            {
                attributes:true,
                childList:true,
                subtree:true,
                characterData:true
            }
        );
    }


    function organizar(){

        /*
         * Se o controle original continua válido,
         * apenas garantimos que permanece escondido
         * e o proxy continua no menu.
         */
        if (
            original
            && original.isConnected
        ){

            original.classList.add(
                'xlx026-original-sound-control'
            );


            if (
                proxy
                && proxy.isConnected
            ){
                sincronizar();
                return;
            }
        }


        original =
            localizarControle();


        if (!original){
            return;
        }


        criarProxy();
    }


    function iniciar(){

        organizar();


        /*
         * O alto-falante pode ser criado depois pelo
         * JavaScript original do painel.
         *
         * Observamos a página até encontrá-lo.
         */
        const observer =
            new MutationObserver(() => {

                window.requestAnimationFrame(
                    organizar
                );
            });


        observer.observe(
            document.body,
            {
                childList:true,
                subtree:true
            }
        );


        /*
         * Verificação leve de segurança.
         */
        window.setInterval(
            organizar,
            2500
        );
    }


    if (
        document.readyState === 'loading'
    ){

        document.addEventListener(
            'DOMContentLoaded',
            iniciar,
            { once:true }
        );

    } else {

        iniciar();
    }

})();

/* FIM XLX026_HISTORY_SOUND_MENU_V1 */
