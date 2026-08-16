--[[ ==========================================================================
     BlackLight Dumpsters — Locale Strings
     Every player-facing line lives here. Translate freely.
========================================================================== ]]

Settings.Text = {
    -- ----------------------------------------------------------------------
    --  CORE SCAVENGING
    -- ----------------------------------------------------------------------
    ['sharps_hit']          = '¡Una aguja desechada se te ha clavado en la mano!',
    ['vermin_bite']         = '¡Un roedor te ha hincado los dientes!',
    ['mishap_generic']      = '¡Te has lastimado hurgando ahí dentro!',
    ['loot_found']          = '¡Algo has rescatado de la basura!',
    ['sack_prompt']         = 'Puede que ahí dentro haya algo aprovechable... ¿Le echas un vistazo?',
    ['container_empty']     = '¡Aquí ya no queda nada!',
    ['try_elsewhere']       = '¡Prueba fortuna en otro rincón!',
    ['exploit_detected']    = '¡Deja de hacer trampas, sinvergüenza!',
    ['search_elsewhere']    = '¡Rebusca en otra parte!',
    ['nothing_recovered']   = '¡No has sacado absolutamente nada!',
    ['sack_option']         = 'Examinar Bolsa de Basura',
    ['wastebin_open']       = 'Abrir Cubo de Basura',
    ['skip_open']           = 'Abrir Contenedor',
    ['skip_search']         = 'Rebuscar en el Contenedor',
    ['wastebin_search']     = 'Rebuscar en la Basura',
    ['generic_search']      = 'Rebuscar',
    ['generic_open']        = 'Abrir',
    ['skip_conceal']        = 'Meterse en el Contenedor',
    ['skip_taken']          = '¡Parece que alguien ya se ha metido ahí dentro!',
    ['skip_exit_prompt']    = '[X] - Salir del Contenedor',
    ['informant_alert']     = '¡Alguien ha dado el aviso: hay gente hurgando en la basura!',
    ['informant_blip']      = 'Saqueador de Basuras',

    -- ----------------------------------------------------------------------
    --  SEARCH FEEDBACK
    -- ----------------------------------------------------------------------
    ['rummaging']           = 'Rebuscando...',
    ['climbing_out']        = 'Saliendo del Contenedor...',
    ['treats_saved_you']    = '¡Le has echado unas golosinas al roedor y te has librado del mordisco!',
    ['gloves_saved_you']    = '¡Tus fieles guantes han impedido que la aguja te atravesara la piel!',
    ['bandit_mauling']      = '¡Un mapache furioso se te ha echado encima!',
    ['companion_search']    = 'Enviar a Rebuscar',

    -- ----------------------------------------------------------------------
    --  PANHANDLING
    -- ----------------------------------------------------------------------
    ['pedestrian_snub']     = '¡El transeúnte te ha mandado a paseo de malas maneras!',
    ['panhandle_payout']    = '¡Has sacado $%s pidiendo por la calle!',
    ['panhandle_cooldown']  = "Ahora mismo no puedes seguir pidiendo. Deja pasar un rato.",
    ['panhandle_progress']  = 'Pidiendo unas monedas...',
    ['panhandle_stopped']   = 'Has dejado de pedir',
    ['panhandle_stop_key']  = 'Dejar de pedir',
    ['panhandle_busy']      = '¡Ya estás pidiendo!',

    -- ----------------------------------------------------------------------
    --  TROLLEY DERBY
    -- ----------------------------------------------------------------------
    ['derby_blip']            = 'Derbi de Carritos',
    ['derby_check_map']       = '¡Mira el mapa para localizar las pistas del Derbi de Carritos!',
    ['rush_progress']         = 'Distancia acumulada en el Descenso: %s/%s metros',
    ['rush_briefing']         = '¡Hazte con un carrito y acumula %s metros de recorrido! Las pistas del derbi están marcadas en tu mapa.',
    ['fare_abandoned']        = '¡Has dejado tirado a tu pasajero! Contrato fallido.',
    ['trolley_flipped']       = '¡El carrito ha volcado! Contrato fallido.',
    ['trolley_controls']      = '[E] - Montarte en el Carrito \n [X] - Soltar el Carrito',
    ['trolley_distance']      = '¡Has recorrido %s metros subido al carrito!',
    ['ranked_on_board']       = '¡Has entrado en el puesto %s del Ranking Mundial!',
    ['good_attempt']          = '¡No ha estado mal!',
    ['distance_covered']      = '¡Has recorrido %s metros!',
    ['leading_distance']      = '¡Vas primero con una marca de %s metros!',
    ['personal_best']         = '¡Nueva marca personal: %s metros!',
    ['cup_countdown']         = '¡Arranca una Copa de Carritos en %s minutos!',
    ['outside_launch_zone']   = '¡Estás demasiado lejos de la salida! La próxima vez colócate ahí a tiempo.',
    ['cup_underway']          = '¡La Copa de Carritos de %s ha arrancado! ¡Mucha suerte!',
    ['cup_victory']           = '¡Enhorabuena! ¡Te has llevado la copa!',
    ['cup_results']           = '¡Copa finalizada! Ha ganado %s con una marca de %s metros!',
    ['cup_scheduled']         = '¡La copa arrancará en %s minutos!',
    ['cup_entered']           = '¡Te has inscrito en la copa!',
    ['cup_entry_failed']      = 'No has podido inscribirte. %s',
    ['replacement_trolley']   = '¡Ya tienes carrito nuevo!',
    ['ride_it_far']           = '¡Agarra este carrito y llega lo más lejos que puedas!',
    ['peek_at_board']         = '¡Échale un ojo al ranking!',
    ['glad_to_help']          = '¡Siempre da gusto ayudar a los de la calle!',
    ['cup_in_progress']       = '¡Justo ahora hay una copa en marcha!',
    ['derby_objective']       = '¡Se trata de llegar lo más lejos posible subido al carrito!',
    ['derby_hello']           = '¿Preparado para el viaje de tu vida?',
    ['derby_farewell']        = 'Sin problema, ¡pásate cuando quieras!',
    ['trolley_push']          = 'Empujar Carrito',
    ['trolley_mount']         = 'Montarse en el Carrito',
    ['trolley_push_key']      = '[E] - Empujar Carrito',
    ['trolley_mount_key']     = '[E] - Montarse en el Carrito',
    ['cup_signup_prompt']     = '¡Las inscripciones para la copa están abiertas! ¿Te apuntas?',
    ['cup_entry_fee']         = 'La inscripción cuesta %s chapas.',
    ['trolley_lost']          = '¿Y tú qué haces aquí? ¡La copa ya arrancó! Si has perdido el carrito, puedo darte otro por %s chapas.',

    -- ----------------------------------------------------------------------
    --  ALLEY BOWLING
    -- ----------------------------------------------------------------------
    ['no_open_matches']      = '¡No hay ninguna partida abierta a la que unirse!',
    ['match_listing']        = 'Partida en %s (%d/%d jugadores)',
    ['bowling_join']         = 'Unirse a los Bolos del Callejón',
    ['bowling_host']         = 'Montar Bolos del Callejón',
    ['pick_match']           = 'Elegir Partida',
    ['entrant_count']        = 'Número de Jugadores',
    ['entrant_hint']         = 'Introduce entre 1 y 4 jugadores',
    ['private_match']        = 'Partida Privada',
    ['invite_only']          = 'Solo pueden entrar los jugadores invitados',
    ['identity_error']       = 'Error: ¡no se ha podido leer el identificador del jugador!',
    ['foul_called']          = '¡Falta! Tienes que lanzar desde dentro de la zona.',
    ['compere_title']        = 'Organizador de Bolos',
    ['compere_greeting']     = '¡Bienvenido a %s! ¿Listo para derribar unos cuantos?',
    ['host_match']           = 'Montar Partida',
    ['join_match']           = 'Unirse a Partida',
    ['never_mind']           = 'Nada, olvídalo',
    ['compere_host_line']    = '¡Puedo montarte una partida!',
    ['compere_find_line']    = '¡Vamos a buscarte una partida!',
    ['drop_by_again']        = '¡Vuelve cuando quieras!',
    ['scoreboard_header']    = 'Marcador actual:',
    ['its_your_go']          = '¡Te toca! Prepárate para lanzar.',
    ['compere_welcome']      = '¡Bienvenido a %s! ¿Te apetece una partida de bolos callejeros?',
    ['compere_setup']        = '¡Puedo prepararte una partida!',
    ['compere_search']       = '¡Deja que te busque una partida!',
    ['compere_goodbye']      = '¡Pásate cuando quieras!',
    ['throw_the_trolley']    = '¡Tu turno! ¡Lanza el carrito!',
    ['turn_summary']         = '¡Turno completado! Has derribado %d bolos',
    ['you_are_leading']      = '¡Vas en cabeza con %d puntos!',
    ['rival_is_leading']     = '%s va en cabeza con %d puntos - Tú llevas %d puntos',
    ['unnamed_rival']        = 'Otro Jugador',
    ['match_underway']       = '¡Partida en marcha! Prepárate...',
    ['your_go_soon']         = '¡Tu turno está al caer!',
    ['awaiting_entrants']    = 'Esperando al resto de jugadores...',
    ['match_won']            = '¡Has ganado la partida!',
    ['match_over']           = '¡Partida terminada!',

    -- ----------------------------------------------------------------------
    --  THE GAUNTLET
    -- ----------------------------------------------------------------------
    ['gauntlet_title']         = 'Duelo por el Trono Callejero',
    ['gauntlet_start']         = '¡Comienza el Duelo por el Trono! ¡Aguanta 10 minutos o hasta que caigas!',
    ['takedown_tally']         = 'Derribos: %s',
    ['gauntlet_survived']      = '¡Duelo superado! Has aguantado 10 minutos y derribado a %s asaltantes.',
    ['gauntlet_lost']          = 'Te han tumbado. Has aguantado %s minutos y %s segundos, derribando a %s asaltantes.',
    ['board_empty']            = '¡Todavía nadie ha superado el Duelo por el Trono!',
    ['gauntlet_board_title']   = 'Ranking del Trono Callejero',
    ['gauntlet_board_header']  = '# Ranking del Trono Callejero #',
    ['throne_claimed']         = '¡%s ocupa ahora el Trono Callejero!',

    -- ----------------------------------------------------------------------
    --  OVERSEER MENU
    -- ----------------------------------------------------------------------
    ['overseer_title']       = 'Capataz de la Calle',
    ['overseer_greeting']    = '¡Bienvenido a mi reino de desperdicios! ¿Qué te trae a mi humilde rincón?',
    ['view_standing']        = 'Consultar tu Reputación',
    ['active_chapter']       = 'Capítulo Actual',
    ['contract_board']       = 'Contratos Callejeros',
    ['tithe_contraband']     = 'Entregar Contrabando',
    ['tithe_currency']       = 'Entregar Chapas',
    ['street_market']        = 'Mercado Callejero',
    ['contract_in_progress'] = '¡Ya tienes un contrato en marcha!',
    ['pick_a_contract']      = 'Escoge el contrato que quieras cumplir:',
    ['cab_run_started']      = '¡Has aceptado un contrato de Carrito-Taxi!',
    ['identity_unknown']     = 'No te reconozco. Aquí algo no cuadra.',
    ['reputation_screen']    = 'Reputación Callejera',
    ['what_do_you_want']     = 'Bueno, ¿qué es lo que buscas exactamente?',
    ['advance_rank']         = 'Subir de Rango',
    ['contest_throne']       = 'Disputar el Trono',
    ['purchase_exit']        = 'Comprar tu Salida',
    ['exit_price_intro']     = 'Ah, que quieres largarte de esta vida, ¿eh? Pues eso tiene su precio...',
    ['exit_dialog_title']    = '**Comprar tu Salida**',
    ['exit_dialog_body']     = '¿Seguro que quieres pagar tu salida? Perderás absolutamente todo tu progreso y volverás a ser un ciudadano cualquiera. Coste: %s chapas.',
    ['xp_insufficient']      = '¡No tienes suficiente XP para subir de rango!',
    ['chapter_pending']      = '¡Antes de subir de rango tienes que cerrar el capítulo "%s"!',
    ['commitment_title']     = '**¿PREPARADO PARA LA VIDA CALLEJERA?**',
    ['commitment_body']      = '[⚠️ AVISO ⚠️]\n¡Vivir en la calle no es ningún juego!\nHas llegado lejos, pero para seguir avanzando tienes que entregarte del todo.\n¡Serás un callejero PARA SIEMPRE y NO PODRÁS DESEMPEÑAR NINGÚN OTRO OFICIO!\n¿Seguro que quieres continuar?',
    ['not_committed']        = '¡Todavía no estás hecho para la vida callejera!',
    ['standing_summary']     = 'Ahora mismo eres rango %s con %s XP.',
    ['you_hold_throne']      = ' ¡Ocupas el Trono Callejero! Que tu reinado sea largo.',
    ['at_top_rank']          = ' ¡Has alcanzado el rango máximo! Disputa la corona cuando llegue el momento.',
    ['next_rank_hint']       = ' Sigue acumulando XP para alcanzar el rango %s.',
    ['rank_gained']          = '¡Enhorabuena! ¡Has alcanzado el rango %s!',
    ['stock_unlocked']       = 'Has desbloqueado: %s',
    ['throne_now_open']      = '¡Ya puedes disputar el Trono Callejero!',
    ['no_active_chapter']    = '¡Sigue curtiéndote y prepárate para el próximo reto!',
    ['chapter_already_done'] = '¡Este capítulo ya lo cerraste!',
    ['chapter_begun']        = 'Capítulo iniciado: %s',
    ['visit_the_districts']  = 'Recorre cada distrito marcado y rebusca en los contenedores de esas zonas.',
    ['nest_cleared']         = '¡Nido de roedores %s exterminado!',
    ['panhandle_hint']       = 'Usa el comando /beg en zonas concurridas para sacar dinero.',
    ['salvage_hint']         = 'Reúne 100 piezas de chatarra rebuscando en contenedores y cubos.',
    ['rival_name']           = 'Samuel "La Rata"',
    ['rival_bolting']        = '¡Esa rata ladrona intenta escaparse! ¡Que no se te escurra!',
    ['rival_beaten']         = '¡Le has dado su merecido al desterrado! Vuelve con el Capataz y dale la buena noticia.',
    ['taming_attempt']       = 'Intentando ganarte al mapache...',
    ['companion_departed']   = '¡Tu compañero mapache se ha largado!',
    ['rank_ten_required']    = '¡Necesitas ser rango 10 para disputar el Trono Callejero!',
    ['contraband_pitch']     = 'Siempre me hacen falta ciertos "suministros personales". Entrégame algo de mercancía y te recompensaré con XP UNA VEZ AL DÍA.',
    ['choose_quantity']      = 'Selecciona la cantidad a entregar:',
    ['tithe_for_xp']         = 'Entregar Chapas a cambio de XP:',
    ['market_title']         = 'Mercado Callejero',
    ['buy_quantity_of']      = 'Comprar %s',
    ['returning_scavenger']  = '¡Cuánto tiempo, callejero de rango %s!',
    ['escort_hired']         = '¡Callejero reclutado como escolta personal! (%s/%s)',
    ['escort_released']      = 'Escolta despedido.',
    ['hire_escort']          = 'Reclutar Escolta',
    ['release_escort']       = 'Despedir Escolta',
    ['affirm_ready']         = '¡Sí, estoy listo!',
    ['decline_hard']         = '¡Ni de broma!',
    ['affirm_sure']          = '¡Sí, adelante!',
    ['decline']              = 'No',
    ['decline_soft']         = 'Todavía no',
    ['go_back']              = 'Atrás',

    -- ----------------------------------------------------------------------
    --  RECLAIMER
    -- ----------------------------------------------------------------------
    ['reclaimer_busy']        = 'Ahora mismo hay alguien usando la recicladora',
    ['reclaim_cycle_started'] = '¡Ciclo de reciclaje en marcha!',
    ['reclaimer_locked']      = '¡Te falta callo para manejar la recicladora!',
    ['reclaimer_open']        = 'Abrir Recicladora',
    ['reclaimer_run']         = 'Poner en Marcha la Recicladora',
    ['reclaimer_open_key']    = '[E] - Abrir Recicladora',
    ['reclaimer_run_key']     = '[E] - Poner en Marcha la Recicladora',

    -- ----------------------------------------------------------------------
    --  TROLLEY CAB
    -- ----------------------------------------------------------------------
    ['cab_already_running']   = '¡Ya tienes un contrato de taxi en curso!',
    ['cab_no_client']         = 'No se ha encontrado ningún cliente. Inténtalo otra vez.',
    ['cab_pickup_blip']       = 'Recogida de Carrito-Taxi',
    ['cab_head_to_pickup']    = '¡Hazte con un carrito y acude al punto marcado a recoger a tu pasajero!',
    ['cab_out_of_time']       = '¡Se te ha agotado el tiempo! Contrato fallido.',
    ['cab_passenger_thrown']  = '¡Tu pasajero ha salido despedido! Contrato fallido.',
    ['cab_trolley_dropped']   = '¡Has soltado el carrito! Contrato fallido.',
    ['cab_stiffed']           = '¡El cliente ha salido corriendo sin soltar un duro!',

    -- ----------------------------------------------------------------------
    --  SURVIVAL GEAR
    -- ----------------------------------------------------------------------
    ['rest']                  = 'Descansar',
    ['collect']               = 'Recoger',
    ['stand_up_key']          = '[X] Levantarse',
    ['rest_key']              = '[E] - Descansar',
    ['collect_key']           = '[E] - Recoger',
    ['open_container']        = 'Abrir Alijo',
    ['open_container_key']    = '[E] - Abrir Alijo',
    ['ration_unpacked']       = 'Has abierto la ración de emergencia',

    -- ----------------------------------------------------------------------
    --  TAINTED ARMAMENTS
    -- ----------------------------------------------------------------------
    ['toxin_active']          = '¡Estás intoxicado!',
    ['toxin_cleared']         = '¡La intoxicación ha remitido!',
    ['cure_administered']     = 'Te has aplicado un antídoto; debería hacer efecto pronto.',
    ['cure_effective']        = '¡El antídoto está surtiendo efecto!',
    ['cure_useless']          = 'Ese antídoto no ha servido de nada.',

    -- ----------------------------------------------------------------------
    --  CORNER GRINDER CONTRACTS
    -- ----------------------------------------------------------------------
    ['contract_currency_haul']    = 'Recolecta %d chapas de los contenedores',
    ['contract_derby_cup']        = 'Organiza una Copa de Carritos con al menos %d participantes',
    ['contract_panhandle_trial']  = 'Reúne $%d pidiendo por la calle',
    ['contract_alley_bowling']    = 'Organiza una partida de Bolos del Callejón con al menos %d participantes',
    ['tracker_currency_haul']     = 'Recolección de Chapas: %d/%d (%d%%)',
    ['tracker_derby_cup']         = 'Copa de Carritos: %d/%d participantes',
    ['tracker_panhandle_trial']   = 'Prueba de Mendicidad: $%d/$%d (%d%%)',
    ['tracker_alley_bowling']     = 'Bolos del Callejón: %d/%d participantes',
    ['contract_fulfilled']        = '¡Contrato cumplido! Te has embolsado %d chapas.',
    ['grinder_rank_required']     = 'Necesitas ser rango 9 para aceptar contratos de Buscavidas.',
    ['contract_duplicate']        = 'Ya estás trabajando en ese contrato.',
    ['contract_missing']          = 'Contrato no encontrado.',
    ['contract_accepted']         = 'Contrato aceptado: %s',
    ['contract_dropped']          = 'Contrato anulado.',

    -- ----------------------------------------------------------------------
    --  DERBY CUP (SERVER SIDE)
    -- ----------------------------------------------------------------------
    ['player_invalid']            = 'Jugador no válido.',
    ['cup_missing']               = 'No se ha encontrado ninguna copa.',
    ['cant_afford_trolley']       = 'No te llegan las chapas para un carrito nuevo. ¡Ve a buscar el tuyo o quítaselo a alguien!',
    ['cup_already_running']       = 'La copa ya ha arrancado.',
    ['cup_already_entered']       = 'Ya estás inscrito en la copa.',
    ['cant_afford_entry']         = 'No te llegan las chapas para la inscripción.',
    ['cup_already_exists']        = 'Ya existe una copa en esa pista.',
    ['cup_prize_claimed']         = '¡Te has llevado la copa!',

    -- ----------------------------------------------------------------------
    --  ALLEY BOWLING (SERVER SIDE)
    -- ----------------------------------------------------------------------
    ['profile_missing']           = '¡Error: no se han encontrado los datos del jugador!',
    ['match_data_invalid']        = '¡Error: los datos de la partida no son válidos!',
    ['lane_occupied']             = '¡Esa pista ya está ocupada!',
    ['match_opened']              = '¡Partida creada! Esperando jugadores...',
    ['match_expired']             = '¡Se ha agotado el tiempo de espera de la partida!',
    ['match_missing']             = '¡Partida no encontrada!',
    ['match_full']                = '¡La partida está completa!',
    ['match_joined']              = '¡Te has unido a la partida!',
    ['match_won_xp']              = '¡Has ganado! +%s XP',
    ['match_winner_named']        = '¡Partida terminada! Ganador: %s',
    ['srv_profile_missing']       = 'Datos del jugador no encontrados',
    ['srv_lane_occupied']         = 'Esa ubicación ya está ocupada',
    ['srv_match_opened']          = '¡Partida creada! Esperando jugadores...',
    ['srv_match_invalid']         = 'Partida o jugador no válidos',
    ['srv_match_full']            = 'La partida está completa',
    ['srv_already_entered']       = 'Ya estás en esta partida',
    ['srv_match_joined']          = '¡Te has unido a la partida!',
    ['currency_found']            = 'Has encontrado %s chapa%s',
    ['currency_plural']           = 'chapa%s',

    -- ----------------------------------------------------------------------
    --  WINDSCREEN WASHING
    -- ----------------------------------------------------------------------
    ['vehicle_already_clean']     = '¡Este coche ya está reluciente!',
    ['wash_payout']               = 'Has lavado el coche y te han dado %s',
    ['wash_option']               = 'Lavar Coche',

    -- ----------------------------------------------------------------------
    --  GEAR MESSAGES
    -- ----------------------------------------------------------------------
    ['home_sweet_home']           = '¡Bienvenido a tu nuevo hogar!',
    ['charges_left']              = 'Usos restantes: %s',
    ['flask_dry']                 = '¡Tu botella está seca! ¡Busca una fuente de agua!',
    ['flask_topped_up']           = '¡Se te ha rellenado la botella!',
    ['stomach_turns']             = 'Notas el estómago revuelto...',
    ['feeling_restored']          = '¡Te sientes como nuevo!',
    ['deliver_the_parcel']        = 'Lleva este Paquete Médico de Urgencia al Capataz.',
    ['looks_valuable']            = 'Esto parece material médico de valor.',
    ['treats_consumed']           = '¡Has usado golosinas para roedores y has esquivado el ataque!',
    ['not_a_scavenger']           = '¡Tú no eres de la calle!',

    -- ----------------------------------------------------------------------
    --  CHAPTER FLOW
    -- ----------------------------------------------------------------------
    ['exit_needs_rank_ten']       = '¡Necesitas ser rango 10 para comprar tu salida!',
    ['cant_afford_exit']          = '¡No te llegan las chapas para comprar tu salida!',
    ['exit_purchased']            = '¡Has comprado tu libertad!',
    ['profile_not_found']         = 'Jugador no encontrado.',
    ['currency_short']            = 'No tienes suficientes chapas.',
    ['purchase_done']             = 'Has comprado %s por %s chapas.',
    ['salvage_progress']          = 'Progreso de la Recolecta: %s/%s',
    ['salvage_quota_met']         = '¡Has reunido chatarra de sobra! Capítulo cerrado.',
    ['treats_handed_over']        = 'Has recibido Golosinas para Mapaches. ¡Busca uno y gánatelo!',
    ['go_find_a_bandit']          = '¡Sal ahí fuera y localiza un mapache que domesticar!',
    ['chapter_not_ready']         = 'Todavía no estás listo para este capítulo.',
    ['treats_required']           = 'Necesitas Golosinas para Mapaches para ganarte a uno.',
    ['taming_failed']             = 'No has conseguido ganarte al mapache.',
    ['taming_success_bonus']      = '¡Te has ganado a un mapache! ¡Bien hecho!',
    ['taming_success']            = '¡Te has ganado a un mapache!',
    ['throne_needs_rank_ten']     = 'Debes ser rango 10 para disputar el Trono Callejero.',
    ['throne_vacant']             = 'El Trono Callejero estaba vacante. ¡Lo has reclamado!',
    ['throne_holder_dormant']     = 'El anterior ocupante llevaba demasiado tiempo ausente. ¡El trono es tuyo!',
    ['gauntlet_underway']         = '¡Empieza el duelo! ¡Derriba al ocupante del trono y a su guardia!',
    ['throne_congratulations']    = '¡Enhorabuena! ¡Ahora ocupas el Trono Callejero!',
    ['rush_chapter_cleared']      = '¡Capítulo del Descenso superado! ¡Ya eres todo un maestro del carrito!',
    ['cab_needs_rank_nine']       = '¡Necesitas ser rango 9 o superior para aceptar contratos de taxi!',
    ['cab_run_paid']              = '¡Contrato de taxi cerrado! Has cobrado %d XP y %d chapas. Propina: %d%%',
    ['district_logged']           = '¡Distrito %s explorado!',
    ['district_tracker']          = 'Progreso del capítulo: %s/5 distritos',
    ['chapter_report_back']       = '¡Capítulo cerrado! Vuelve con el Capataz para subir de rango.',
    ['parcel_recovered']          = '¡Has dado con un Paquete Médico de Urgencia! Llévaselo al Capataz.',
    ['throne_won_with_kills']     = '¡Ocupas el Trono Callejero con %s derribos!',
    ['gauntlet_vs_record']        = '¡Duelo superado! Has logrado %s derribos. El récord está en %s.',
    ['gauntlet_vs_personal']      = '¡Duelo superado! Has logrado %s derribos. Tu mejor marca es %s.',
    ['gauntlet_unranked']         = '¡Duelo superado! Has logrado %s derribos. No ha bastado para entrar en el top 10.',

    -- ----------------------------------------------------------------------
    --  MARKET
    -- ----------------------------------------------------------------------
    ['rank_too_low']              = 'Tu rango callejero es demasiado bajo para llevarte ese artículo.',
    ['currency_removal_failed']   = 'No se han podido descontar las chapas.',
    ['item_grant_failed']         = 'No se ha podido meter el artículo en tu inventario.',
    ['purchase_bulk_done']        = 'Comprado %sx %s por %s chapas.',
    ['panhandle_tracker']         = 'Progreso de mendicidad: $%s/$%s',
    ['earnings_quota_met']        = '¡Has reunido dinero de sobra! Capítulo cerrado.',
    ['no_parcel_carried']         = 'No llevas ningún Paquete Médico de Urgencia que entregar.',
    ['parcel_delivered_final']    = '¡Paquete Médico de Urgencia entregado! Capítulo cerrado.',
    ['parcel_delivered']          = '¡Paquete Médico de Urgencia entregado!',

    -- ----------------------------------------------------------------------
    --  REPUTATION SYSTEM
    -- ----------------------------------------------------------------------
    ['contraband_daily_limit']    = 'Ya has entregado contrabando hoy.',
    ['contraband_unknown']        = 'Ese tipo de mercancía no me sirve.',
    ['tithe_acknowledged']        = '¡Gracias por la entrega! Te has ganado %s XP.',
    ['currency_converted']        = 'Has soltado %s chapas y ganado %s XP.',
    ['throne_occupied']           = 'El Trono Callejero ya tiene ocupante.',
    ['throne_is_yours']           = '¡Ahora ocupas el Trono Callejero!',
    ['contraband_short']          = 'No tienes suficiente %s.',
    ['commitment_reminder']       = 'No lo olvides: ¡juraste ser CALLEJERO DE POR VIDA!',
    ['rank_range_error']          = 'Indica un rango válido entre 1 y 10',
    ['rank_forced']               = 'Tu rango callejero se ha fijado en %s',

    -- ----------------------------------------------------------------------
    --  MISC LABELS
    -- ----------------------------------------------------------------------
    ['district_label']            = 'Distrito de Contenedores ',
    ['done_marker']               = 'Completado ✔',
    ['begin_chapter']             = 'Iniciar Capítulo',
    ['hand_over_parcel']          = 'Entregar Paquete',
    ['price_label']               = 'Precio',
    ['unlock_rank_label']         = 'Se desbloquea en el Rango',
    ['tithe_action']              = 'Entregar',
    ['abort']                     = 'Cancelar',
    ['lets_roll']                 = '¡Vamos allá!',
    ['scoreboard']                = 'Ranking',
    ['derby_menu_title']          = 'Derbi Callejero de Carritos',
    ['derby_compere']             = 'Organizador del Derbi',
    ['top_riders']                = '%s - Mejores Corredores',
    ['lost_trolley_title']        = '¿Se te ha perdido el Carrito?',
    ['decline_polite']            = 'No, gracias',
    ['accept_polite']             = '¡Sí, por favor!',
    ['cup_label']                 = 'Copa',
    ['host_cup']                  = 'Organizar Copa',
    ['rank_column']               = 'Puesto',
    ['player_column']             = 'Jugador',
    ['distance_column']           = 'Distancia',
    ['board_title']               = 'Ranking de %s',
    ['starts_in_field']           = 'Arranca En (Minutos)',
    ['duration_field']            = 'Duración (Minutos)',
    ['entry_fee_field']           = 'Inscripción (Número de Chapas)',
    ['mount_trolley_key']         = 'Montarse en el Carrito',
    ['dismount_trolley_key']      = 'Soltar el Carrito',
    ['tame_bandit']               = 'Domesticar Mapache',
    ['currency_plural_word']      = 'chapas',
}
