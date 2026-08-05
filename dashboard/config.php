<?php
return [
  'server_name' => '{{REFLECTOR_NAME}} Brasil',
  'xml_path' => '/var/log/xlxd.xml',
  'log_path' => '/var/log/xlx.log',
  'users_db' => '/xlxd/users_db/users.db',
  'history_limit' => 30,
  'modules' => [
    'A' => ['name'=>'DMR','protocol'=>'DMR','access'=>'TG 4001'],
    'B' => ['name'=>'APRS / D-PRS','protocol'=>'APRS / D-PRS','access'=>'Dados digitais'],
    'C' => ['name'=>'C4FM / YSF / DMR','protocol'=>'C4FM/YSF e DMR','access'=>'YSF 72426 • DMR TG 4003'],
    'D' => ['name'=>'D-STAR','protocol'=>'D-STAR','access'=>'{{REFLECTOR_NAME}}-D / {{REFLECTOR_NAME}}-D'],
    'E' => ['name'=>'Teste / Echo','protocol'=>'D-STAR Echo','access'=>'Teste de áudio'],
  ],
];
