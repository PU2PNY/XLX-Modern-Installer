<?php
declare(strict_types=1);
return [
 'reflector'=>[
  'name'=>'XLX000','title'=>'XLX000 Reflector',
  'description'=>'Multiprotocol amateur radio reflector',
  'sysop_callsign'=>'N0CALL','location'=>'City / State',
  'country'=>'Country','domain'=>'xlx.example.org',
  'contact_email'=>'sysop@example.org',
 ],
 'branding'=>[
  'header_title'=>'XLX000 Reflector',
  'header_subtitle'=>'Multiprotocol amateur radio reflector',
  'footer_text'=>'',
 ],
 'features'=>[
  'show_contact_email'=>true,
  'show_location'=>true,
  'show_sysop_callsign'=>true,
 ],
 'radio'=>[
  'reflector_number'=>'000',
  'reflector_short_number'=>'0',
  'ysf_id'=>'00000',
  'dmr_tg'=>'4000',
  // Rotulos EXIBIDOS dos modulos (apenas visual). A letra continua sendo a
  // chave interna. Remova ou deixe vazio para usar o padrao "DV <letra>".
  // Display-only module labels; the letter stays the internal key.
  'module_labels'=>[
   'A'=>'DV A', 'B'=>'DV B', 'C'=>'DV C', 'D'=>'DV D', 'E'=>'DV E', 'F'=>'DV F', 'G'=>'DV G',
   'H'=>'DV H', 'I'=>'DV I', 'J'=>'DV J', 'K'=>'DV K', 'L'=>'DV L', 'M'=>'DV M', 'N'=>'DV N',
   'O'=>'DV O', 'P'=>'DV P', 'Q'=>'DV Q', 'R'=>'DV R', 'S'=>'DV S', 'T'=>'DV T', 'U'=>'DV U',
   'V'=>'DV V', 'W'=>'DV W', 'X'=>'DV X', 'Y'=>'DV Y', 'Z'=>'DV Z',
  ],
  // Rotulos EXIBIDOS dos protocolos (apenas visual). A chave e o valor
  // canonico interno e NAO deve ser alterada; so o texto a direita muda.
  // Display-only protocol labels; keys are the canonical internal values.
  'protocol_labels'=>[
   'DMR'=>'DMR',
   'D-STAR'=>'D-STAR',
   'C4FM/YSF'=>'C4FM/YSF',
   'D-STAR/DCS'=>'D-STAR/DCS',
   'D-STAR/DExtra'=>'D-STAR/DExtra',
   'D-STAR/DPlus'=>'D-STAR/DPlus',
   'XLX Interlink'=>'XLX Interlink',
  ],
 ],
 'locale'=>[
  'default'=>'en',
 ],
 'timezone'=>'UTC',
 'certificates'=>[
  'enabled'=>true,
  // Optional reflector anniversary in MM-DD format, for example 07-22.
  'anniversary'=>'',
 ],
];
