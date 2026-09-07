<?php
declare(strict_types=1);

/*
 * Safe origin rules for XLXD streams.
 * The client recorded by XLXD is always the primary network origin.
 * Connection metadata may enrich a stream only for the same callsign,
 * module and, when both are explicit, suffix.
 */
function xlxmodern_exact_tx_origin(array $connections,string $call,string $suffix,string $module): array {
    $call=norm_call($call);
    $suffix=strtoupper(trim($suffix));
    $module=strtoupper(trim($module));
    $base=[
        'gateway'=>$call,
        'via'=>'',
        'peer'=>'',
        'endpoint_ip'=>'',
        'origin_match'=>'log-client',
    ];

    foreach($connections as $connection){
        if(norm_call((string)($connection['callsign']??''))!==$call) continue;
        if(strtoupper(trim((string)($connection['module']??'')))!==$module) continue;

        $connectionSuffix=strtoupper(trim((string)($connection['suffix']??'')));
        if($suffix!=='' && $connectionSuffix!=='' && $connectionSuffix!==$suffix) continue;

        return [
            'gateway'=>$call,
            'via'=>(string)($connection['via']??''),
            'peer'=>(string)($connection['peer']??''),
            'endpoint_ip'=>mask_ip((string)($connection['ip']??'')),
            'origin_match'=>'exata',
        ];
    }

    return $base;
}

function xlxmodern_enforce_safe_origin(array $tx,array $connections): array {
    $source=trim((string)($tx['identity_source']??''));

    /* STATION/Via node is the only accepted proof of operator != gateway. */
    if(str_starts_with($source,'xlxd-station')) return $tx;

    $origin=xlxmodern_exact_tx_origin(
        $connections,
        (string)($tx['network_callsign']??$tx['callsign']??''),
        (string)($tx['network_suffix']??$tx['suffix']??''),
        (string)($tx['module']??'')
    );

    foreach($origin as $key=>$value) $tx[$key]=$value;
    return $tx;
}

function xlxmodern_history_state(array $tx): string {
    if(!empty($tx['online'])) return 'Online';

    $call=norm_call((string)($tx['callsign']??''));
    $gateway=norm_call((string)($tx['gateway']??''));
    $source=trim((string)($tx['identity_source']??''));

    if(
        $call!=='' &&
        $gateway!=='' &&
        $call!==$gateway &&
        str_starts_with($source,'xlxd-station')
    ) return 'Link';

    return 'Offline';
}
