<?php
return [
  'server_name' => '{{REFLECTOR_TITLE}}',
  'xml_path' => '/var/log/xlxd.xml',
  'log_path' => '/var/log/xlx.log',
  'users_db' => '/xlxd/users_db/users.db',
  'users_override_db' => '/var/lib/xlx-user-directory/overrides.db',
  'history_limit' => 30,
  'modules' => [
    'A' => ['name'=>'DMR','protocol'=>'DMR','access'=>'TG 4001'],
    'B' => ['name'=>'APRS / D-PRS','protocol'=>'APRS / D-PRS','access'=>'Dados digitais'],
    'C' => ['name'=>'C4FM / YSF / DMR','protocol'=>'C4FM/YSF e DMR','access'=>'YSF {{YSF_ID}} • DMR TG {{DMR_TG}}'],
    'D' => ['name'=>'D-STAR','protocol'=>'D-STAR','access'=>'{{REFLECTOR_NAME}}-D / XRF{{REFLECTOR_NUMBER}}-D'],
    'E' => ['name'=>'Teste / Echo','protocol'=>'D-STAR Echo','access'=>'Teste de áudio'],
  ],
];
