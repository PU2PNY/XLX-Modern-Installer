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
