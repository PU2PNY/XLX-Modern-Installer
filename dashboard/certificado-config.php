<?php
declare(strict_types=1);

const CERT_ANNIVERSARY = '';
const CERT_CAMPAIGN_PACK = 'pt-BR';

/*
 * {{REFLECTOR_NAME}} — Motor de campanhas de certificados
 *
 * Nenhuma data especial é decidida no JavaScript.
 * O servidor escolhe automaticamente o modelo válido pela data local.
 */

function cert_timezone(): DateTimeZone
{
    static $tz = null;
    return $tz ??= new DateTimeZone('America/Sao_Paulo');
}

function cert_nth_weekday(
    int $year,
    int $month,
    int $isoWeekday,
    int $nth
): DateTimeImmutable
{
    if (
        $month < 1 ||
        $month > 12 ||
        $isoWeekday < 1 ||
        $isoWeekday > 7 ||
        $nth < 1 ||
        $nth > 5
    ) {
        throw new InvalidArgumentException(
            'Regra de calendário inválida.'
        );
    }

    $tz = cert_timezone();

    $first = new DateTimeImmutable(
        sprintf(
            '%04d-%02d-01 00:00:00',
            $year,
            $month
        ),
        $tz
    );

    $firstWeekday =
        (int)$first->format('N');

    $delta =
        ($isoWeekday - $firstWeekday + 7) % 7;

    $date = $first
        ->modify('+' . $delta . ' days')
        ->modify('+' . (($nth - 1) * 7) . ' days');

    if ((int)$date->format('n') !== $month) {
        throw new RuntimeException(
            'Ocorrência inexistente neste mês.'
        );
    }

    return $date;
}

function cert_last_weekday(
    int $year,
    int $month,
    int $isoWeekday
): DateTimeImmutable
{
    if (
        $month < 1 ||
        $month > 12 ||
        $isoWeekday < 1 ||
        $isoWeekday > 7
    ) {
        throw new InvalidArgumentException(
            'Regra de calendário inválida.'
        );
    }

    $tz = cert_timezone();

    $last = (
        new DateTimeImmutable(
            sprintf(
                '%04d-%02d-01 00:00:00',
                $year,
                $month
            ),
            $tz
        )
    )->modify('last day of this month');

    $current =
        (int)$last->format('N');

    $back =
        ($current - $isoWeekday + 7) % 7;

    return $last->modify(
        '-' . $back . ' days'
    );
}

function cert_nth_sunday(
    int $year,
    int $month,
    int $nth
): DateTimeImmutable
{
    return cert_nth_weekday(
        $year,
        $month,
        7,
        $nth
    );
}

function cert_make_campaign(
    string $slug,
    string $title,
    string $subtitle,
    DateTimeImmutable $start,
    DateTimeImmutable $end,
    string $theme,
    int $priority,
    bool $special = true
): array {
    return [
        'slug' => $slug,
        'title' => $title,
        'subtitle' => $subtitle,
        'start' => $start,
        'end' => $end,
        'theme' => $theme,
        'priority' => $priority,
        'special' => $special,
    ];
}

function cert_easter_sunday(int $year): DateTimeImmutable
{
    /*
     * Algoritmo gregoriano de Meeus/Jones/Butcher.
     * Evita dependência da extensão calendar do PHP.
     */
    $a = $year % 19;
    $b = intdiv($year, 100);
    $c = $year % 100;
    $d = intdiv($b, 4);
    $e = $b % 4;
    $f = intdiv($b + 8, 25);
    $g = intdiv($b - $f + 1, 3);

    $h = (
        19 * $a
        + $b
        - $d
        - $g
        + 15
    ) % 30;

    $i = intdiv($c, 4);
    $k = $c % 4;

    $l = (
        32
        + 2 * $e
        + 2 * $i
        - $h
        - $k
    ) % 7;

    $m = intdiv(
        $a
        + 11 * $h
        + 22 * $l,
        451
    );

    $month = intdiv(
        $h
        + $l
        - 7 * $m
        + 114,
        31
    );

    $day = (
        (
            $h
            + $l
            - 7 * $m
            + 114
        ) % 31
    ) + 1;

    return new DateTimeImmutable(
        sprintf(
            '%04d-%02d-%02d 00:00:00',
            $year,
            $month,
            $day
        ),
        cert_timezone()
    );
}

function cert_campaigns(DateTimeImmutable $now): array
{
    $tz = cert_timezone();
    $year = (int)$now->format('Y');

    $campaigns = [];

    /*
     * 01/01 — ANO NOVO
     */
    $d = new DateTimeImmutable(
        "$year-01-01 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "ano-novo-xlx-modern-$year",
        "Ano Novo {{REFLECTOR_NAME}} $year",
        'Confraternização Universal',
        $d,
        $d->setTime(23, 59, 59),
        'ano-novo',
        145
    );

    /*
     * DATAS MÓVEIS BASEADAS NA PÁSCOA
     */
    $easter = cert_easter_sunday($year);

    $carnival = $easter->modify('-47 days');

    $campaigns[] = cert_make_campaign(
        "carnaval-$year",
        "Carnaval $year",
        'Edição comemorativa {{REFLECTOR_NAME}}',
        $carnival,
        $carnival->setTime(23, 59, 59),
        'carnaval',
        125
    );

    /*
     * 08/03 — DIA INTERNACIONAL DA MULHER
     */
    $d = new DateTimeImmutable(
        "$year-03-08 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-internacional-mulher-$year",
        "Dia Internacional da Mulher $year",
        'Uma homenagem do {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'mulher',
        145
    );

    /*
     * SEXTA-FEIRA SANTA
     */
    $goodFriday = $easter->modify('-2 days');

    $campaigns[] = cert_make_campaign(
        "sexta-feira-santa-$year",
        "Paixão de Cristo $year",
        'Sexta-feira Santa',
        $goodFriday,
        $goodFriday->setTime(23, 59, 59),
        'sexta-santa',
        130
    );

    /*
     * PÁSCOA
     */
    $campaigns[] = cert_make_campaign(
        "pascoa-$year",
        "Páscoa $year",
        'Edição especial {{REFLECTOR_NAME}}',
        $easter,
        $easter->setTime(23, 59, 59),
        'pascoa',
        145
    );

    /*
     * 18/04 — DIA MUNDIAL DO RADIOAMADOR
     */
    $d = new DateTimeImmutable(
        "$year-04-18 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-mundial-radioamador-$year",
        "Dia Mundial do Radioamador $year",
        'Edição especial {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'radio',
        170
    );

    /*
     * 21/04 — TIRADENTES
     */
    $d = new DateTimeImmutable(
        "$year-04-21 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "tiradentes-$year",
        "Tiradentes $year",
        'Edição comemorativa {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'tiradentes',
        125
    );

    /*
     * 01/05 — DIA DO TRABALHADOR
     */
    $d = new DateTimeImmutable(
        "$year-05-01 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-trabalhador-$year",
        "Dia do Trabalhador $year",
        'Uma homenagem do {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'trabalhador',
        135
    );

    /*
     * SEGUNDO DOMINGO DE MAIO — DIA DAS MÃES
     */
    $d = cert_nth_sunday(
        $year,
        5,
        2
    );

    $campaigns[] = cert_make_campaign(
        "dia-das-maes-$year",
        "Dia das Mães $year",
        'Uma homenagem do {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'maes',
        150
    );

    /*
     * CORPUS CHRISTI — 60 DIAS APÓS A PÁSCOA
     */
    $corpus = $easter->modify('+60 days');

    $campaigns[] = cert_make_campaign(
        "corpus-christi-$year",
        "Corpus Christi $year",
        'Edição especial {{REFLECTOR_NAME}}',
        $corpus,
        $corpus->setTime(23, 59, 59),
        'corpus-christi',
        130
    );

    /*
     * 12/06 — DIA DOS NAMORADOS
     */
    $d = new DateTimeImmutable(
        "$year-06-12 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-namorados-$year",
        "Dia dos Namorados $year",
        'Celebrando conexões especiais',
        $d,
        $d->setTime(23, 59, 59),
        'namorados',
        145
    );

    /*
     * ANIVERSÁRIO DO REFLETOR — opcional, configurado em MM-DD.
     * A campanha cobre dois dias antes e dois dias depois.
     */
    if (preg_match('/^(\d{2})-(\d{2})$/', CERT_ANNIVERSARY, $ann)) {
        $month = (int)$ann[1];
        $day = (int)$ann[2];

        if (checkdate($month, $day, $year)) {
            $official = new DateTimeImmutable(
                sprintf('%04d-%02d-%02d 00:00:00', $year, $month, $day),
                $tz
            );
            $start = $official->modify('-2 days');
            $end = $official->modify('+2 days')->setTime(23, 59, 59);

            $campaigns[] = cert_make_campaign(
                'aniversario-xlx-modern-' . $year,
                'Semana de Aniversário {{REFLECTOR_NAME}} ' . $year,
                'Aniversário oficial em ' . $official->format('d/m'),
                $start,
                $end,
                'aniversario',
                180
            );
        }
    }

    /*
     * SEGUNDO DOMINGO DE AGOSTO — DIA DOS PAIS
     */
    $d = cert_nth_sunday(
        $year,
        8,
        2
    );

    $campaigns[] = cert_make_campaign(
        "dia-dos-pais-$year",
        "Dia dos Pais $year",
        'Uma homenagem do {{REFLECTOR_NAME}} aos pais radioamadores',
        $d,
        $d->setTime(23, 59, 59),
        'pais',
        150
    );

    /*
     * 07/09 — INDEPENDÊNCIA DO BRASIL
     */
    $d = new DateTimeImmutable(
        "$year-09-07 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "independencia-brasil-$year",
        "Independência do Brasil $year",
        'Edição comemorativa {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'brasil',
        135
    );

    /*
     * 12/10 — NOSSA SENHORA APARECIDA / DIA DAS CRIANÇAS
     */
    $d = new DateTimeImmutable(
        "$year-10-12 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "nossa-sra-aparecida-criancas-$year",
        "Nossa Senhora Aparecida / Dia das Crianças $year",
        'Edição comemorativa {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'aparecida-criancas',
        135
    );

    /*
     * 15/10 — DIA DO PROFESSOR
     */
    $d = new DateTimeImmutable(
        "$year-10-15 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-professor-$year",
        "Dia do Professor $year",
        'Uma homenagem do {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'professor',
        140
    );

    /*
     * 18/10 — DIA DO MÉDICO
     */
    $d = new DateTimeImmutable(
        "$year-10-18 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-medico-$year",
        "Dia do Médico $year",
        'Uma homenagem do {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'medico',
        140
    );

    /*
     * 02/11 — FINADOS
     */
    $d = new DateTimeImmutable(
        "$year-11-02 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "finados-$year",
        "Finados $year",
        'Memória e respeito',
        $d,
        $d->setTime(23, 59, 59),
        'finados',
        125
    );

    /*
     * 05/11 — DIA DO RADIOAMADOR BRASILEIRO
     */
    $d = new DateTimeImmutable(
        "$year-11-05 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-radioamador-brasileiro-$year",
        "Dia do Radioamador Brasileiro $year",
        'Edição especial {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'radio-br',
        170
    );

    /*
     * 15/11 — PROCLAMAÇÃO DA REPÚBLICA
     */
    $d = new DateTimeImmutable(
        "$year-11-15 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "proclamacao-republica-$year",
        "Proclamação da República $year",
        'Edição comemorativa {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'republica',
        130
    );

    /*
     * 20/11 — CONSCIÊNCIA NEGRA
     */
    $d = new DateTimeImmutable(
        "$year-11-20 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "consciencia-negra-$year",
        "Dia Nacional de Zumbi e da Consciência Negra $year",
        'Memória, respeito e igualdade',
        $d,
        $d->setTime(23, 59, 59),
        'consciencia-negra',
        140
    );

    /*
     * 25/12 — NATAL
     */
    $d = new DateTimeImmutable(
        "$year-12-25 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "natal-xlx-modern-$year",
        "Natal {{REFLECTOR_NAME}} $year",
        'Boas festas da família {{REFLECTOR_NAME}}',
        $d,
        $d->setTime(23, 59, 59),
        'natal',
        145
    );


    /*
     * ========================================================
     * DATAS PROFISSIONAIS — {{REFLECTOR_NAME}}
     *
     * Datas fixas são recriadas automaticamente a cada ano.
     *
     * Prioridade: 110
     * Campanhas {{REFLECTOR_NAME}}, radioamadorismo e eventos especiais
     * com prioridade maior continuam prevalecendo.
     * ========================================================
     */
    $professionalDates = [
        [
            'dia-farmaceutico',
            'Dia Nacional do Farmacêutico',
            1,
            20
        ],
        [
            'dia-enfermeiro',
            'Dia do Enfermeiro',
            5,
            12
        ],
        [
            'dia-assistente-social',
            'Dia da Assistente e do Assistente Social',
            5,
            15
        ],
        [
            'dia-advocacia',
            'Dia da Advocacia',
            8,
            11
        ],
        [
            'dia-psicologia',
            'Dia da Psicóloga e do Psicólogo',
            8,
            27
        ],
        [
            'dia-nutricionista',
            'Dia do Nutricionista',
            8,
            31
        ],
        [
            'dia-medico-veterinario',
            'Dia do Médico-Veterinário',
            9,
            9
        ],
        [
            'dia-contador',
            'Dia do Contador',
            9,
            22
        ],
        [
            'dia-fisioterapeuta-terapeuta-ocupacional',
            'Dia do Fisioterapeuta e do Terapeuta Ocupacional',
            10,
            13
        ],
        [
            'dia-cirurgiao-dentista',
            'Dia do Cirurgião-Dentista',
            10,
            25
        ],
        [
            'dia-servidor-publico',
            'Dia do Servidor Público',
            10,
            28
        ],
        [
            'dia-engenheiro',
            'Dia do Engenheiro',
            12,
            11
        ],
        [
            'dia-arquiteto-urbanista',
            'Dia Nacional do Arquiteto e Urbanista',
            12,
            15
        ],
    ];

    foreach (
        $professionalDates
        as [
            $professionalSlug,
            $professionalTitle,
            $professionalMonth,
            $professionalDay
        ]
    ) {
        $d = new DateTimeImmutable(
            sprintf(
                '%04d-%02d-%02d 00:00:00',
                $year,
                $professionalMonth,
                $professionalDay
            ),
            $tz
        );

        $campaigns[] = cert_make_campaign(
            $professionalSlug . '-' . $year,
            $professionalTitle . ' ' . $year,
            'Uma homenagem do {{REFLECTOR_NAME}} aos profissionais que fazem a diferença',
            $d,
            $d->setTime(23, 59, 59),
            'profissao',
            110
        );
    }

    if (CERT_CAMPAIGN_PACK !== 'pt-BR') {
        $portableThemes = ['ano-novo', 'radio', 'aniversario'];
        $campaigns = array_values(array_filter(
            $campaigns,
            static fn(array $campaign): bool =>
                in_array((string)($campaign['theme'] ?? ''), $portableThemes, true)
        ));
    }


    /*
     * ==========================================================
     * {{REFLECTOR_NAME}}_DATAS_COMUNICACAO_V2
     * ==========================================================
     */

    /*
     * 13/02 — Dia Mundial do Rádio
     */
    $d = new DateTimeImmutable(
        "$year-02-13 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-mundial-radio-$year",
        "Dia Mundial do Rádio $year",
        'Uma celebração do rádio, da comunicação e das conexões que aproximam pessoas',
        $d,
        $d->setTime(23, 59, 59),
        'comunicacao',
        155,
        true
    );

    /*
     * 17/05 — Dia Mundial das Telecomunicações
     * e da Sociedade da Informação
     */
    $d = new DateTimeImmutable(
        "$year-05-17 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-mundial-telecom-sociedade-informacao-$year",
        "Dia Mundial das Telecomunicações e da Sociedade da Informação $year",
        'Uma celebração da conectividade, da tecnologia e da comunicação digital',
        $d,
        $d->setTime(23, 59, 59),
        'comunicacao',
        155,
        true
    );

    /*
     * 25/09 — Dia Nacional do Rádio
     */
    $d = new DateTimeImmutable(
        "$year-09-25 00:00:00",
        $tz
    );

    $campaigns[] = cert_make_campaign(
        "dia-nacional-radio-$year",
        "Dia Nacional do Rádio $year",
        'Uma homenagem do {{REFLECTOR_NAME}} à história e à importância do rádio no Brasil',
        $d,
        $d->setTime(23, 59, 59),
        'comunicacao',
        155,
        true
    );

    /* /{{REFLECTOR_NAME}}_DATAS_COMUNICACAO_V2 */

    return $campaigns;
}

function cert_default_campaign(DateTimeImmutable $now): array
{
    $start = $now->setTime(0, 0, 0);
    $end = $now->setTime(23, 59, 59);

    return cert_make_campaign(
        'participacao-' . $now->format('Y-m-d'),
        'Certificado de Participação',
        '{{REFLECTOR_NAME}} — Refletor Digital Multiprotocolo',
        $start,
        $end,
        'padrao',
        0,
        false
    );
}

function cert_current_campaign(?DateTimeImmutable $now = null): array
{
    $now ??= new DateTimeImmutable('now', cert_timezone());

    $active = [];

    foreach (cert_campaigns($now) as $campaign) {
        if (
            $now->getTimestamp() >= $campaign['start']->getTimestamp()
            && $now->getTimestamp() <= $campaign['end']->getTimestamp()
        ) {
            $active[] = $campaign;
        }
    }

    if (!$active) {
        return cert_default_campaign($now);
    }

    usort(
        $active,
        static fn(array $a, array $b): int =>
            $b['priority'] <=> $a['priority']
    );

    return $active[0];
}

function cert_public_campaign(array $campaign): array
{
    return [
        'id' => $campaign['slug'],
        'title' => $campaign['title'],
        'subtitle' => $campaign['subtitle'],
        'theme' => $campaign['theme'],
        'special' => $campaign['special'],
        'start' => $campaign['start']->format(DateTimeInterface::ATOM),
        'end' => $campaign['end']->format(DateTimeInterface::ATOM),
        'period_label' =>
            $campaign['start']->format('d/m/Y') === $campaign['end']->format('d/m/Y')
                ? $campaign['start']->format('d/m/Y')
                : $campaign['start']->format('d/m/Y') . ' a ' . $campaign['end']->format('d/m/Y'),
    ];
}
