--[[
    BlackLight Scavenging — user-facing text
    ----------------------------------------
    Every string players read lives here. Key names are the resource's internal API and
    are referenced from client/server code as Config.Lang.<key>, so they are stable —
    only the wording has been rewritten.

    Format specifiers (%s / %d / %%) are positional and MUST be preserved exactly as they
    appear, in the same order: they are filled by string.format() at the call site.
]]

Config.Lang = {
    -- ---------------------------------------------------------------
    --  Rummaging: outcomes, mishaps and prop labels
    -- ---------------------------------------------------------------
    ['needles']              = '¡Una aguja usada se te ha clavado en la mano!',
    ['rat']                  = 'Una rata sale disparada y te muerde.',
    ['fail']                 = 'Rebuscas a ciegas y acabas haciéndote daño.',
    ['success']              = 'Algo aprovechable entre los desperdicios.',
    ['garbagebag']           = 'La bolsa está bien cargada... ¿la abres?',
    ['notrash']              = 'Ya han vaciado esto. No queda nada.',
    ['look']                 = 'Aquí no hay nada. Prueba en otro contenedor.',
    ['cheater']              = 'Movimiento no permitido. Inténtalo por las buenas.',
    -- NEW: shown when a server-side rate limiter rejects a request that arrived too quickly.
    ['too_fast']             = 'Más despacio, que no hay prisa.',
    ['look_somewhere_else']  = 'Este rincón está agotado. Cambia de sitio.',
    ['no_items']             = 'Solo basura de la que no sirve.',
    ['inspect']              = 'Revisar bolsa',
    ['open_garbage']         = 'Abrir papelera',
    ['open_dumpster']        = 'Abrir contenedor',
    ['search_dumpster']      = 'Rebuscar en el contenedor',
    ['search_garbage']       = 'Rebuscar en la papelera',
    ['search']               = 'Rebuscar',
    ['open']                 = 'Abrir',
    ['hide_in_dumpster']     = 'Meterse dentro',
    ['dumpster_busy']        = 'Ocupado: ya hay alguien agazapado ahí dentro.',
    ['get_out_dumpster']     = '[X] - Salir del contenedor',
    ['snitch']               = 'Aviso vecinal: alguien está hurgando en la basura.',
    ['snitchBlip']           = 'Aviso por saqueo',

    ['progress_searching']   = 'Rebuscando...',
    ['leaving_dumpster']     = 'Saliendo...',
    ['rat_treats']           = 'Sueltas unas golosinas y la rata te deja en paz.',
    ['dirty_needles_stopped'] = 'Tus guantes han aguantado el pinchazo. Bien invertidos.',
    ['racoon']               = '¡Un mapache furioso se te echa encima!',
    ['raccoon_search']       = 'Mandar al mapache',

    -- ---------------------------------------------------------------
    --  Panhandling
    -- ---------------------------------------------------------------
    ['ped_refuse_help']      = 'Te contestan de malas maneras y siguen su camino.',
    ['begging_received_money'] = 'Te sueltan $%s sin mirarte a la cara.',
    ['begging_cooldown']     = 'Acabas de pedir por aquí. Deja pasar un rato.',
    ['begging_progressbar']  = 'Pidiendo unas monedas...',
    ['begging_cancelled']    = 'Lo dejas estar.',
    ['stop_begging']         = 'Dejar de pedir',
    -- BUGFIX: client/panhandle.lua referenced Config.Lang.begging_already_begging but the
    -- original lang table never defined it, so the "already begging" notification was
    -- called with a nil message. Key added with the wording the code clearly intended.
    ['begging_already_begging'] = 'Ya estás pidiendo.',

    -- ---------------------------------------------------------------
    --  Trolley derby
    -- ---------------------------------------------------------------
    ['cart_derby_blip']      = 'Derbi de carritos',
    ['check_map_derby']      = 'Tienes las bajadas marcadas en el mapa.',
    ['thrill_ride_distance'] = 'Bajada libre: %s/%s metros',
    ['find_cart_ride']       = 'Hazte con un carrito y suma %s metros cuesta abajo. Las bajadas están en tu mapa.',
    ['abandoned_passenger']  = 'Has dejado tirado al pasajero. Encargo perdido.',
    ['cart_tipped']          = 'El carrito ha volcado. Se acabó la bajada.',
    ['cart_controls']        = '[E] - Subirse al carrito \n [X] - Soltar el carrito',
    ['traveled_distance_cart'] = 'Has aguantado %s metros subido al carrito.',
    ['placed_leaderboard']   = 'Entras en el puesto %s de la tabla mundial.',
    ['nice_try']             = 'Casi. Otra vez será.',
    ['traveled_distance']    = '%s metros recorridos.',
    ['first_place_distance'] = 'Primer puesto con %s metros. Nadie ha llegado más lejos.',
    ['new_best_distance']    = 'Marca personal batida: %s metros.',
    ['derby_starting_soon']  = 'El derbi arranca en %s minutos.',
    ['too_far_from_start']   = 'Estás lejos de la salida. La próxima vez colócate a tiempo.',
    ['derby_started']        = 'El derbi de %s acaba de empezar. Suerte ahí abajo.',
    ['won_tournament']       = 'Torneo ganado. La calle es tuya.',
    ['tournament_ended']     = 'Torneo cerrado. Gana %s con %s metros.',
    ['tournament_will_start'] = 'El torneo empieza en %s minutos.',
    ['joined_tournament']    = 'Estás dentro del torneo.',
    ['failed_join_tournament'] = 'No has podido entrar: %s',
    ['got_new_cart']         = 'Carrito nuevo conseguido.',
    ['take_cart_far']        = 'Llévate este y a ver hasta dónde aguantas.',
    ['check_leaderboard']    = 'Échale un ojo a la tabla.',
    ['help_fellow_hobo']     = 'Entre los de la calle nos echamos una mano.',
    ['tournament_active']    = 'Hay un torneo en marcha ahora mismo.',
    ['derby_goal']           = 'La idea es sencilla: cuanto más lejos, mejor.',
    ['derby_greeting']       = '¿Te apetece una bajada de las buenas?',
    ['derby_goodbye']        = 'Tranquilo, aquí estaré.',
    ['push_cart']            = 'Empujar carrito',
    ['sit_in_cart']          = 'Subirse al carrito',
    ['push_cart_e']          = '[E] - Empujar carrito',
    ['sit_in_cart_e']        = '[E] - Subirse al carrito',
    ['tournament_signup']    = 'Las inscripciones están abiertas. ¿Te apuntas?',
    ['tournament_buyin']     = 'La inscripción son %s chapas.',
    ['lost_cart']            = 'El torneo ya ha arrancado. Si te has quedado sin carrito, te consigo otro por %s chapas.',

    -- ---------------------------------------------------------------
    --  Alley bowling
    -- ---------------------------------------------------------------
    ['no_games_available']   = 'Ahora mismo no hay ninguna partida abierta.',
    ['game_at_location']     = 'Partida en %s (%d/%d jugadores)',
    ['join_bowling']         = 'Entrar en una partida',
    ['host_bowling']         = 'Montar una partida',
    ['select_game']          = 'Elegir partida',
    ['number_of_players']    = 'Número de jugadores',
    ['enter_1_4_players']    = 'Indica entre 1 y 4 jugadores',
    ['private_game']         = 'Partida cerrada',
    ['only_invited_players'] = 'Solo entra quien tú invites',
    ['player_id_error']      = 'No se ha podido leer tu identificador.',
    ['foul_warning']         = 'Nulo. Tienes que lanzar desde dentro de la línea.',
    ['bowling_host_title']   = 'Organizador de la bolera',
    ['bowling_welcome']      = 'Bienvenido a %s. ¿Listo para tirar unos cuantos?',
    ['host_game']            = 'Montar partida',
    ['join_game']            = 'Entrar en partida',
    ['nevermind']            = 'Déjalo',
    ['host_game_speech']     = 'Te la monto en un momento.',
    ['find_game_speech']     = 'Voy a buscarte hueco.',
    ['come_back_soon']       = 'Pásate cuando quieras.',
    ['current_scores']       = 'Marcador:',
    ['your_turn']            = 'Te toca. Colócate.',
    ['bowling_host_welcome'] = 'Bienvenido a %s. ¿Jugamos una?',
    ['bowling_host_setup']   = 'Te preparo la pista.',
    ['bowling_host_find']    = 'Deja que te busque partida.',
    ['bowling_host_goodbye'] = 'Cuando quieras la revancha, ya sabes.',
    ['bowl_cart']            = 'Tu turno. ¡Suelta el carrito!',
    ['turn_complete']        = 'Turno cerrado: %d derribados.',
    ['you_lead']             = 'Vas primero con %d puntos.',
    ['player_leads']         = '%s lidera con %d puntos — tú llevas %d.',
    ['another_player']       = 'Otro jugador',
    ['game_started']         = 'Partida en marcha. Prepárate.',
    ['turn_coming_up']       = 'Tu turno está al caer.',
    ['waiting_players']      = 'Esperando al resto...',
    ['you_won']              = 'Partida ganada.',
    ['game_finished']        = 'Partida terminada.',

    -- ---------------------------------------------------------------
    --  Street warden: gauntlet
    -- ---------------------------------------------------------------
    ['hobo_king_challenge']  = 'Duelo por la corona',
    ['challenge_begin']      = 'Empieza el duelo. Aguanta diez minutos o cae peleando.',
    ['kills_count']          = 'Rivales tumbados: %s',
    ['challenge_complete']   = 'Has aguantado los diez minutos y tumbado a %s rivales.',
    ['challenge_failed']     = 'Te han tumbado tras %s minutos y %s segundos, con %s rivales abatidos.',
    ['no_completions']       = 'Nadie ha superado el duelo todavía.',
    ['king_leaderboard_title'] = 'Clasificación del duelo',
    ['king_leaderboard_header'] = '# Clasificación del duelo #',
    ['new_king']             = '%s se ha coronado en la calle.',

    -- ---------------------------------------------------------------
    --  Street warden: hub menu
    -- ---------------------------------------------------------------
    ['hobo_king_title']      = 'Patrón de la calle',
    ['hobo_king_welcome']    = 'Bienvenido a mi esquina. ¿Qué se te ofrece?',
    ['check_progress']       = 'Ver mi progreso',
    ['current_mission']      = 'Encargo actual',
    ['hobo_tasks']           = 'Trabajos sueltos',
    ['donate_drugs']         = 'Entregar mercancía',
    ['donate_caps']          = 'Entregar chapas',
    ['hobo_shop']            = 'Mercadillo',
    ['active_task_error']    = 'Ya tienes un trabajo entre manos.',
    ['choose_task']          = 'Elige el trabajo que quieras sacarte:',
    ['hobo_taxi_started']    = 'Encargo de transporte aceptado.',
    ['id_error']             = 'No me suenas de nada. Algo no cuadra.',
    ['hobo_progression']     = 'Tu recorrido en la calle',
    ['what_you_doing']       = 'Bueno, ¿a qué has venido?',
    ['level_up']             = 'Subir de rango',
    ['challenge_king']       = 'Retar al patrón',
    ['buy_freedom']          = 'Comprar tu salida',
    ['freedom_cost_msg']     = 'Conque quieres dejarlo... eso tiene su precio.',
    ['freedom_title']        = '**Comprar tu salida**',
    ['freedom_description']  = '¿Seguro? Perderás todo tu recorrido y volverás a ser uno más. Cuesta %s chapas.',
    ['not_enough_xp']        = 'Aún no tienes experiencia para dar el salto.',
    ['need_complete_mission'] = 'Antes tienes que cerrar el encargo "%s".',
    ['hobo_warning_title']   = '**¿SEGURO QUE QUIERES ESTO?**',
    ['hobo_warning_content'] = '[⚠️ AVISO ⚠️]\nLa calle no se toma a broma.\nHas llegado lejos, pero para seguir subiendo tienes que comprometerte del todo.\nSerá PARA SIEMPRE y NO PODRÁS ACEPTAR NINGÚN OTRO EMPLEO.\n¿Sigues adelante?',
    ['not_ready_hobo']       = 'Todavía no estás hecho para esto.',
    ['level_progress_msg']   = 'Vas por el rango %s con %s de experiencia.',
    ['hobo_king_msg']        = ' Ahora mismo la corona es tuya. Que dure.',
    ['max_level_msg']        = ' Has tocado techo. Reta por la corona cuando lo veas claro.',
    ['next_level_msg']       = ' Sigue sumando para alcanzar el rango %s.',
    ['level_up_notification'] = 'Rango %s alcanzado.',
    ['unlocked_items']       = 'Se te ha abierto: %s',
    ['challenge_king_notification'] = 'Ya puedes retar por la corona.',
    ['no_mission']           = 'Sigue rodándote. El próximo encargo llegará.',
    ['already_completed']    = 'Ese encargo ya lo cerraste.',
    ['mission_started']      = 'Encargo aceptado: %s',
    ['visit_zones']          = 'Pásate por cada zona marcada y rebusca en sus contenedores.',
    ['rat_infestation_cleared'] = 'Zona %s despejada de ratas.',
    ['professional_beggar_hint'] = 'Usa /beg donde haya gente para sacar algo.',
    ['supply_chain_hint']    = 'Reúne 100 piezas de chatarra rebuscando por ahí.',
    ['thief_name']           = 'Samuel "el Rata"',
    ['thief_fleeing']        = 'El muy rata se escapa. ¡No lo pierdas!',
    ['thief_defeated']       = 'Asunto resuelto. Vuelve con el patrón y cuéntaselo.',
    ['taming_raccoon']       = 'Ganándote al mapache...',
    ['raccoon_left']         = 'Tu mapache se ha largado.',
    ['must_be_level_ten']    = 'Necesitas el rango 10 para retar al patrón.',
    ['donate_drugs_speech']  = 'Siempre me hace falta material. Trae algo y te lo pago en experiencia, UNA VEZ AL DÍA.',
    ['donate_amount']        = 'Elige cuánto entregas:',
    ['donate_caps_xp']       = 'Chapas a cambio de experiencia:',
    ['hobo_shop_title']      = 'Mercadillo',
    ['purchase_quantity']    = 'Comprar %s',
    ['welcome_back']         = 'Otra vez por aquí, rango %s.',
    ['bodyguard_recruited']  = 'Uno más en tu escolta. (%s/%s)',
    ['bodyguard_dismissed']  = 'Escolta despedida.',
    ['recruit_bodyguard']    = 'Sumar a tu escolta',
    ['dismiss_bodyguard']    = 'Despedir escolta',
    ['yes_ready']            = 'Adelante',
    ['hell_no']              = 'Ni hablar',
    ['yes_sure']             = 'Claro',
    ['no']                   = 'No',
    ['not_yet']              = 'Ahora no',
    ['back']                 = 'Volver',

    -- ---------------------------------------------------------------
    --  Reclaim units
    -- ---------------------------------------------------------------
    ['recycler_in_use']      = 'La máquina está ocupada.',
    ['recycling_started']    = 'Máquina en marcha.',
    ['recycler_level_error'] = 'Te falta rodaje para manejar esto.',
    ['open_recycler']        = 'Abrir máquina',
    ['use_recycler']         = 'Poner en marcha',
    ['open_recycler_e']      = '[E] - Abrir máquina',
    ['use_recycler_e']       = '[E] - Poner en marcha',

    -- ---------------------------------------------------------------
    --  Cart fare runs
    -- ---------------------------------------------------------------
    ['taxi_already_active']  = 'Ya tienes un encargo de transporte abierto.',
    ['taxi_find_customer_failed'] = 'No hay nadie esperando. Prueba más tarde.',
    ['taxi_pickup_blip']     = 'Recogida',
    ['taxi_goto_pickup']     = 'Busca un carrito y acércate al punto marcado.',
    ['taxi_time_up']         = 'Se te ha echado el tiempo encima. Encargo perdido.',
    ['taxi_passenger_fell']  = 'Tu pasajero ha acabado en el suelo. Encargo perdido.',
    ['taxi_cart_abandoned']  = 'Has soltado el carrito. Encargo perdido.',
    ['taxi_no_payment']      = 'Se ha largado sin soltar un duro.',

    -- ---------------------------------------------------------------
    --  Deployable gear
    -- ---------------------------------------------------------------
    ['sleep']                = 'Descansar',
    ['pick_up']              = 'Recoger',
    ['get_up']               = '[X] Levantarse',
    ['sleep_e']              = '[E] - Descansar',
    ['pick_up_e']            = '[E] - Recoger',
    ['open_stash']           = 'Abrir escondite',
    ['open_stash_e']         = '[E] - Abrir escondite',
    ['ration_opened']        = 'Abres el paquete de emergencia.',

    -- ---------------------------------------------------------------
    --  Toxin weapons
    -- ---------------------------------------------------------------
    ['poisoned_status']      = 'Notas que algo te corre por dentro.',
    ['poison_worn_off']      = 'Ya vuelves a respirar tranquilo.',
    ['antidote_taken']       = 'Te tomas el antídoto. Dale un momento.',
    ['antidote_working']     = 'El antídoto está haciendo su trabajo.',
    ['antidote_ineffective'] = 'Ese antídoto no ha servido de nada.',

    -- ---------------------------------------------------------------
    --  Side hustles
    -- ---------------------------------------------------------------
    ['task_bottle_collection'] = 'Reúne %d chapas rebuscando por la ciudad',
    ['task_cart_derby_tournament'] = 'Organiza un derbi con %d participantes como mínimo',
    ['task_begging_challenge'] = 'Saca $%d pidiendo por la calle',
    ['task_hobo_bowling']    = 'Monta una partida de bolos con %d jugadores como mínimo',
    ['task_progress_bottle'] = 'Chapas: %d/%d (%d%%)',
    ['task_progress_derby']  = 'Derbi: %d/%d participantes',
    ['task_progress_begging'] = 'Recaudado: $%d/$%d (%d%%)',
    ['task_progress_bowling'] = 'Bolos: %d/%d participantes',
    ['task_completed']       = 'Trabajo cerrado. Te llevas %d chapas.',
    ['street_hustler_level_requirement'] = 'Necesitas el rango 9 para los trabajos sueltos.',
    ['already_working_task'] = 'Ya estás con ese trabajo.',
    ['task_not_found']       = 'Ese trabajo no existe.',
    ['task_started']         = 'Trabajo aceptado: %s',
    ['task_canceled']        = 'Trabajo abandonado.',

    -- ---------------------------------------------------------------
    --  Derby tournaments (server responses)
    -- ---------------------------------------------------------------
    ['invalid_player']       = 'Jugador no válido.',
    ['no_tournament_found']  = 'No hay ningún torneo abierto.',
    ['not_enough_caps_new_cart'] = 'No te llegan las chapas. Busca tu carrito o quítale uno a otro.',
    ['tournament_already_started'] = 'El torneo ya está en marcha.',
    ['already_in_tournament'] = 'Ya estás inscrito.',
    ['not_enough_caps_buyin'] = 'No te llegan las chapas para la inscripción.',
    ['tournament_already_exists'] = 'Ya hay un torneo montado.',
    ['tournament_won']       = 'Torneo ganado.',

    -- ---------------------------------------------------------------
    --  Alley bowling (server responses)
    -- ---------------------------------------------------------------
    ['player_data_not_found'] = 'No se han encontrado tus datos.',
    ['invalid_game_data']    = 'Los datos de la partida no son válidos.',
    ['bowling_lane_in_use']  = 'Esa pista está ocupada.',
    ['game_created_waiting'] = 'Partida creada. Esperando gente...',
    ['game_timed_out']       = 'La partida ha caducado.',
    ['game_not_found']       = 'No se encuentra la partida.',
    ['game_is_full']         = 'La partida está completa.',
    ['joined_game']          = 'Estás dentro.',
    ['you_won_xp']           = 'Victoria. +%s de experiencia',
    ['game_finished_winner'] = 'Partida cerrada. Gana %s.',
    ['server_player_not_found'] = 'No se han encontrado tus datos.',
    ['server_location_in_use'] = 'Ese sitio está ocupado.',
    ['server_game_created']  = 'Partida creada. Esperando gente...',
    ['server_invalid_game']  = 'Partida o jugador no válidos.',
    ['server_game_full']     = 'La partida está completa.',
    ['server_already_in_game'] = 'Ya estás en esta partida.',
    ['server_joined_game']   = 'Estás dentro.',
    ['found_bottle_caps']    = 'Rescatas %s chapa%s.',
    ['bottle_caps']          = 'chapa%s',

    -- ---------------------------------------------------------------
    --  Vehicle washing
    -- ---------------------------------------------------------------
    ['car_already_cleaning'] = 'Ese coche ya está reluciente.',
    ['clean_car_success']    = 'Dejas el coche limpio y te dan %s.',
    ['clean_car_label']      = 'Limpiar el coche',

    -- ---------------------------------------------------------------
    --  Gear feedback
    -- ---------------------------------------------------------------
    ['welcome_new_home']     = 'Ya tienes dónde caerte muerto.',
    ['remaining_uses']       = 'Te quedan %s usos.',
    ['bottle_empty']         = 'La botella está seca. Busca un grifo.',
    ['bottle_refilled']      = 'Botella llena.',
    ['feel_sick']            = 'El estómago se te revuelve...',
    ['feel_refreshed']       = 'Eso entra bien.',
    ['take_medical_package'] = 'Lleva este paquete médico al patrón de la calle.',
    ['valuable_medical_supplies'] = 'Material sanitario. Esto vale lo suyo.',
    ['rat_treats_used']      = 'Las golosinas te han librado del mordisco.',
    ['not_hobo']             = 'Esto no es para ti.',

    -- ---------------------------------------------------------------
    --  Contracts
    -- ---------------------------------------------------------------
    ['must_be_level_10_freedom'] = 'Necesitas el rango 10 para comprar tu salida.',
    ['not_enough_caps_freedom'] = 'No te llegan las chapas para salir.',
    ['freedom_bought']       = 'Trato hecho. Eres libre.',
    ['player_not_found']     = 'Jugador no encontrado.',
    ['not_enough_caps']      = 'No te llegan las chapas.',
    ['item_purchased']       = 'Te llevas %s por %s chapas.',
    ['supply_chain_progress'] = 'Chatarra reunida: %s/%s',
    ['junk_items_collected'] = 'Ya tienes bastante chatarra. Encargo cerrado.',
    ['raccoon_treats_received'] = 'Tienes golosinas para mapaches. Busca uno.',
    ['find_raccoon_to_tame'] = 'Ve a buscar un mapache.',
    ['not_ready_for_mission'] = 'Todavía no te toca este encargo.',
    ['need_raccoon_treats']  = 'Sin golosinas no hay mapache que valga.',
    ['failed_tame_raccoon']  = 'El mapache no se ha fiado de ti.',
    ['raccoon_tamed_well_done'] = 'Te has ganado a un mapache. Nada mal.',
    ['raccoon_tamed']        = 'El mapache ya va contigo.',
    ['must_be_level_10_challenge'] = 'Necesitas el rango 10 para retar al patrón.',
    ['no_current_king']      = 'No había nadie al mando. La corona es tuya.',
    ['inactive_king']        = 'El anterior patrón llevaba tiempo desaparecido. Tomas su sitio.',
    ['challenge_begun']      = 'Empieza el duelo. Con él y con los suyos.',
    ['congrats_new_king']    = 'Se acabó: mandas tú.',
    ['thrill_ride_complete'] = 'Bajada dominada. Ya nadie te discute el carrito.',
    ['taxi_level_requirement'] = 'Necesitas el rango 9 o más para los encargos de transporte.',
    ['taxi_mission_completed'] = 'Encargo entregado: %d de experiencia y %d chapas. Propina: %d%%',
    ['zone_visited']         = 'Zona %s cubierta.',
    ['mission_progress_zones'] = 'Progreso: %s/5 zonas',
    ['mission_complete_return'] = 'Encargo cerrado. Vuelve con el patrón para subir de rango.',
    ['found_medical_package'] = 'Has dado con un paquete médico. Llévaselo al patrón.',
    ['new_king_with_kills']  = 'Nuevo patrón con %s rivales tumbados.',
    ['challenge_complete_record'] = 'Duelo superado con %s rivales. El récord está en %s.',
    ['challenge_complete_best'] = 'Duelo superado con %s rivales. Tu mejor marca es %s.',
    ['challenge_complete_no_qualify'] = 'Duelo superado con %s rivales. No entra en el top 10.',

    -- ---------------------------------------------------------------
    --  Market
    -- ---------------------------------------------------------------
    ['level_too_low']        = 'Tu rango no da para este artículo.',
    ['failed_remove_caps']   = 'No se han podido descontar las chapas.',
    ['failed_add_item']      = 'No te cabe en el inventario.',
    ['purchased_quantity']   = 'Te llevas %sx %s por %s chapas.',
    ['begging_progress']     = 'Recaudado: $%s/$%s',
    ['collected_enough_money'] = 'Ya tienes bastante. Encargo cerrado.',
    ['no_medical_package']   = 'No llevas ningún paquete médico.',
    ['package_delivered_complete'] = 'Paquete entregado. Encargo cerrado.',
    ['package_delivered']    = 'Paquete entregado.',

    -- ---------------------------------------------------------------
    --  Progression
    -- ---------------------------------------------------------------
    ['already_donated_drugs'] = 'Ya has entregado material hoy.',
    ['invalid_drug_type']    = 'Eso no me sirve.',
    ['donation_thank_you']   = 'Buen material. Te llevas %s de experiencia.',
    ['bottle_caps_spent']    = 'Sueltas %s chapas y ganas %s de experiencia.',
    ['active_king_exists']   = 'Ya hay alguien al mando.',
    ['now_hobo_king']        = 'A partir de ahora, mandas tú.',
    ['not_enough_drug']      = 'No llevas suficiente %s.',
    ['hobo_for_life_reminder'] = 'Recuerda el trato: esto es de por vida.',
    ['specify_valid_level']  = 'Indica un rango entre 1 y 10.',
    ['hobo_level_set']       = 'Rango ajustado a %s.',

    -- ---------------------------------------------------------------
    --  Shared UI labels
    -- ---------------------------------------------------------------
    ['dumpster_zone']        = 'Zona de rebusca ',
    ['completed']            = 'Cerrado ✔',
    ['start_mission']        = 'Aceptar encargo',
    ['deliver_package']      = 'Entregar paquete',
    ['price']                = 'Precio',
    ['unlocked_at_level']    = 'Disponible en el rango',
    ['donate']               = 'Entregar',
    ['cancel']               = 'Cancelar',
    ['let_go']               = '¡Allá vamos!',
    ['leaderboard']          = 'Clasificación',
    ['hobo_cart_derby']      = 'Derbi de carritos',
    ['cart_derby_host']      = 'Organizador del derbi',
    ['top_racers']           = '%s - Mejores marcas',
    ['lost_cart_title']      = '¿Te has quedado sin carrito?',
    ['no_thanks']            = 'Paso',
    ['yes_please']           = 'Venga, sí',
    ['tournament']           = 'Torneo',
    ['host_tournament']      = 'Montar torneo',
    ['position']             = 'Puesto',
    ['player']               = 'Jugador',
    ['distance']             = 'Distancia',
    ['leaderboard_title']    = 'Clasificación de %s',
    ['starts_in']            = 'Empieza en (minutos)',
    ['duration']             = 'Duración (minutos)',
    ['buy_in']               = 'Inscripción (chapas)',
    ['ride_cart']            = 'Subirse al carrito',
    ['leave_cart']           = 'Soltar el carrito',
}
