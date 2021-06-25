#include 	<a_samp>

// cambia MAX_PLAYERS a la cantidad de jugadores (slots) que quieras
// Por defecto es 1000 (a partir de la versión 0.3.7)
#undef	  	MAX_PLAYERS
#define	 	MAX_PLAYERS			50

#include 	<a_mysql>

// MySQL configuracion
#define		MYSQL_SERVIDOR 			"127.0.0.1"
#define		MYSQL_USUARIO 			"root"
#define		MYSQL_CLAVE 		""
#define		MYSQL_BASE_DATOS 		"sedaxrp"

// Tiempo en segundos que se le da al jugador para loguear antes de kickearlo
#define		SEGUNDOS_PARA_LOGUEAR 	30

// Punto de aparicion para nuevos jugadores: Las Venturas (The High Roller)
#define 	DEFAULT_POS_X 		1958.3783
#define 	DEFAULT_POS_Y 		1343.1572
#define 	DEFAULT_POS_Z 		15.3746
#define 	DEFAULT_POS_A 		270.1425

// Definicion que nos evita crear forwards para todos los public
#define Funcion:%0(%1) forward%0(%1); public%0(%1)

// Variable MySQL donde se almacenara la conexion a la base de datos
new MySQL: BaseDeDatos;

// Datos del Jugador
enum ENUM_JUGADOR
{
	ID,
	Nombre[MAX_PLAYER_NAME],
	// La salida de la función SHA256_PassHash (que se agregó en la versión 0.3.7 R1)
	// siempre tiene 256 bytes de longitud, o el equivalente a 64 celdas de pawn
	Clave[65],
	Salt[17],
	Asesinatos,
	Muertes,
	Float: X_Pos,
	Float: Y_Pos,
	Float: Z_Pos,
	Float: A_Pos,
	Interior,

	Cache: Cache_ID,
	bool: EstaLogueado,
	IntentosLogin,
	RelojLogin
};
new Jugador[MAX_PLAYERS][ENUM_JUGADOR];

new ConexionesMySQL[MAX_PLAYERS];

// Enum de dialogos
enum
{
	DIALOGO_INFORMACION,
	DIALOGO_LOGIN,
	DIALOGO_REGISTRO
};

main() {}


public OnGameModeInit()
{
	new MySQLOpt: opcion_id = mysql_init_options();

	mysql_set_option(opcion_id, AUTO_RECONNECT, true);

	BaseDeDatos = mysql_connect(MYSQL_SERVIDOR, MYSQL_USUARIO, MYSQL_CLAVE, MYSQL_BASE_DATOS, opcion_id);

	if (BaseDeDatos == MYSQL_INVALID_HANDLE || mysql_errno(BaseDeDatos) != 0)
	{
		print("La conexion a la base de datos ha fallado");
	}else{
		print("La conexion a la base de datos ha sido exitosa");
	}

	creaBaseDeDatos();
	return 1;
}

public OnGameModeExit()
{
	//La función GetPlayerPoolSize se agregó en la versión 0.3.7 y obtiene el ID de jugador más alto actualmente en uso en el servidor
	for (new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
	{
		if (IsPlayerConnected(i))
		{
			//El motivo se establece en 1 para 'Salir' normal
			OnPlayerDisconnect(i, 1);
		}
	}

	mysql_close(BaseDeDatos);
	return 1;
}

public OnPlayerConnect(playerid)
{
	ConexionesMySQL[playerid]++;

	// Reseteamos los datos del Enum Jugador
	static const empty_player[ENUM_JUGADOR];
	Jugador[playerid] = empty_player;

	GetPlayerName(playerid, Jugador[playerid][Nombre], MAX_PLAYER_NAME);

	// Envía una consulta para recibir todos los datos del jugador almacenados en la DB
	new query[103];
	mysql_format(BaseDeDatos, query, sizeof query, "SELECT * FROM `players` WHERE `username` = '%e' LIMIT 1", Jugador[playerid][Nombre]);
	mysql_tquery(BaseDeDatos, query, "CargarDatosDelJugador", "dd", playerid, ConexionesMySQL[playerid]);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	ConexionesMySQL[playerid]++;

	GuardarDatosJugador(playerid, reason);

	// Si el jugador fue expulsado (ya sea por una contraseña incorrecta o por haber tardando demasiado)
	// durante la parte de inicio de sesión, eliminamos los datos de la memoria de pawn
	if (cache_is_valid(Jugador[playerid][Cache_ID]))
	{
		cache_delete(Jugador[playerid][Cache_ID]);
		Jugador[playerid][Cache_ID] = MYSQL_INVALID_CACHE;
	}

	// Si el jugador fue expulsado antes de que expire el tiempo (30 segundos), matamos el temporizador
	if (Jugador[playerid][RelojLogin])
	{
		KillTimer(Jugador[playerid][RelojLogin]);
		Jugador[playerid][RelojLogin] = 0;
	}

	// Establece "EstaLogueado" en falso cuando el jugador se desconecta, evita que se guarden los datos del
	// jugador dos veces cuando se usa "gmx"
	Jugador[playerid][EstaLogueado] = false;
	return 1;
}

public OnPlayerSpawn(playerid)
{
	// Spawnea al jugador en su última posición guardada
	SetPlayerInterior(playerid, Jugador[playerid][Interior]);
	SetPlayerPos(playerid, Jugador[playerid][X_Pos], Jugador[playerid][Y_Pos], Jugador[playerid][Z_Pos]);
	SetPlayerFacingAngle(playerid, Jugador[playerid][A_Pos]);
	SetCameraBehindPlayer(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	ActualizaMuertesJugador(playerid);
	ActualizaAsesinatosJugador(killerid);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch (dialogid)
	{
		// Útil para diálogos que contienen solo información y no hacemos nada dependiendo de si respondieron o no
		case DIALOGO_INFORMACION: return 1;

		case DIALOGO_LOGIN:
		{
			if (!response) return Kick(playerid);

			new hashed_pass[65];
			SHA256_PassHash(inputtext, Jugador[playerid][Salt], hashed_pass, 65);

			if (strcmp(hashed_pass, Jugador[playerid][Clave]) == 0)
			{
				// El jugador se logueo correctamente
				ShowPlayerDialog(playerid, DIALOGO_INFORMACION, DIALOG_STYLE_MSGBOX, "Login", "Te has logueado con exito, disfruta tu tiempo de juego.", "Vale", "");

				// Establece el caché especificado como el caché activo para que podamos recuperar el resto de los
				// datos del jugador
				cache_set_active(Jugador[playerid][Cache_ID]);

				DatosJugadorBD(playerid);

				// Elimina el caché activo de la memoria y también desarma el caché activo
				cache_delete(Jugador[playerid][Cache_ID]);
				Jugador[playerid][Cache_ID] = MYSQL_INVALID_CACHE;

				KillTimer(Jugador[playerid][RelojLogin]);
				Jugador[playerid][RelojLogin] = 0;
				Jugador[playerid][EstaLogueado] = true;

				// Spawnea al jugador en su ultima posicion
				SetSpawnInfo(playerid, NO_TEAM, 0, Jugador[playerid][X_Pos], Jugador[playerid][Y_Pos], Jugador[playerid][Z_Pos], Jugador[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
				SpawnPlayer(playerid);
			}
			else
			{
				Jugador[playerid][IntentosLogin]++;

				if (Jugador[playerid][IntentosLogin] >= 3)
				{
					ShowPlayerDialog(playerid, DIALOGO_INFORMACION, DIALOG_STYLE_MSGBOX, "Login", "Ha escrito mal su contraseña mas de 3 veces.", "Vale", "");
					KickearTiempo(playerid);
				}
				else ShowPlayerDialog(playerid, DIALOGO_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Contraseña incorrecta!\nIngrese su contraseña a continuación:", "Login", "Salir");
			}
		}
		case DIALOGO_REGISTRO:
		{
			if (!response) return Kick(playerid);

			if (strlen(inputtext) <= 5) return ShowPlayerDialog(playerid, DIALOGO_REGISTRO, DIALOG_STYLE_PASSWORD, "Registro", "¡Su contraseña debe tener más de 5 caracteres! \n Introduzca su contraseña en siguiente campo:", "Registrar", "Salir");

			// 16 caracteres aleatorios del 33 al 126 (en ASCII) para el salt de la clave
			for (new i = 0; i < 16; i++) Jugador[playerid][Salt][i] = random(94) + 33;
			SHA256_PassHash(inputtext, Jugador[playerid][Salt], Jugador[playerid][Clave], 65);

			new query[221];
			mysql_format(BaseDeDatos, query, sizeof query, "INSERT INTO `players` (`username`, `password`, `salt`) VALUES ('%e', '%s', '%e')", Jugador[playerid][Nombre], Jugador[playerid][Clave], Jugador[playerid][Salt]);
			mysql_tquery(BaseDeDatos, query, "RegistrarJugador", "d", playerid);
		}

		default: return 0; // No se encontró el ID de diálogo, busqueda en otros scripts
	}
	return 1;
}

/***************************************************************/
/*****************|- FUNCIONES CREADAS POR MI -|****************/
/***************************************************************/

Funcion: CargarDatosDelJugador(playerid, recuento_conexiones)
{
	/* verificación de que la conexion pertenesca al jugador
	el jugador A se conecta -> Se activa la consulta SELECT -> esta consulta lleva mucho tiempo
	mientras la consulta aún se está procesando, el jugador A con playerid 2 se desconecta
	el jugador B se une ahora con el id 2 -> nuestra consulta SELECT retrasada finalmente ha finalizado,
	pero para el jugador equivocado que hacemos contra eso?
	Creamos un recuento de conexiones para cada playerid y lo incrementamos cada vez que el playerid se
	conecta o desconecta también pasamos el valor actual del recuento de conexiones a nuestra devolución de
	llamada CargarDatosDelJugador luego verificamos si el recuento de conexiones actual es el mismo que el
	recuento de conexiones que pasamos a la devolución de llamada si es así, todo está bien, si no, solo
	kickeamos al jugador */
	if (recuento_conexiones != ConexionesMySQL[playerid]) return Kick(playerid);
	
	new string[115];
	if(cache_num_rows() > 0)
	{
		// Almacenamos la contraseña y la salt para poder comparar la contraseña que ingresa el jugador
		// y guarde el resto para que no tengamos que ejecutar otra consulta más tarde
		cache_get_value(0, "password", Jugador[playerid][Clave], 65);
		cache_get_value(0, "salt", Jugador[playerid][Salt], 17);

		// Duarda el caché activo en la memoria y devuelve un ID de caché para acceder a él para su uso posterior
		Jugador[playerid][Cache_ID] = cache_save();

		format(string, sizeof string, "Hola %s, esta cuenta esta registrada introduce tu clave", Jugador[playerid][Nombre]);
		ShowPlayerDialog(playerid, DIALOGO_LOGIN, DIALOG_STYLE_PASSWORD, "Login", string, "Login", "Salir");

		// A partir de aqui tienes 30 segundos para loguear
		Jugador[playerid][RelojLogin] = SetTimerEx("TiempoParaLoguear", SEGUNDOS_PARA_LOGUEAR * 1000, false, "d", playerid);
	}
	else
	{
		format(string, sizeof string, "Bienvenido %s esta cuenta no esta registrada introduce una clave", Jugador[playerid][Nombre]);
		ShowPlayerDialog(playerid, DIALOGO_REGISTRO, DIALOG_STYLE_PASSWORD, "Registro", string, "Registrar", "Salir");
	}
	return 1;
}

Funcion: TiempoParaLoguear(playerid)
{
	Jugador[playerid][RelojLogin] = 0;

	ShowPlayerDialog(playerid, DIALOGO_INFORMACION, DIALOG_STYLE_MSGBOX, "Login", "Tardaste demasiado tiempo en introducir tu clave.", "Vale", "Salir");
	KickearTiempo(playerid);
	return 1;
}

Funcion: RegistrarJugador(playerid)
{
	// Recupera el ID generado para una columna AUTO_INCREMENT por la consulta enviada
	Jugador[playerid][ID] = cache_insert_id();

	ShowPlayerDialog(playerid, DIALOGO_INFORMACION, DIALOG_STYLE_MSGBOX, "Registro", "Cuenta registrada correctamente, ha iniciado sesión automáticamente.", "Vale", "Salir");

	Jugador[playerid][EstaLogueado] = true;

	Jugador[playerid][X_Pos] = DEFAULT_POS_X;
	Jugador[playerid][Y_Pos] = DEFAULT_POS_Y;
	Jugador[playerid][Z_Pos] = DEFAULT_POS_Z;
	Jugador[playerid][A_Pos] = DEFAULT_POS_A;

	SetSpawnInfo(playerid, NO_TEAM, 0, Jugador[playerid][X_Pos], Jugador[playerid][Y_Pos], Jugador[playerid][Z_Pos], Jugador[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

Funcion: KickearJugador(playerid)
{
	Kick(playerid);
	return 1;
}

//-----------------------------------------------------

creaBaseDeDatos()
{
	/*
	Crea una base de datos con
	username
	clave
	asesinatos
	muertes
	Posicion x, y, z, angulo e interior
	*/
	mysql_tquery(BaseDeDatos, "CREATE TABLE IF NOT EXISTS `players` (`id` int(11) NOT NULL AUTO_INCREMENT,`username` varchar(24) NOT NULL,`password` char(64) NOT NULL,`salt` char(16) NOT NULL,`kills` mediumint(8) NOT NULL DEFAULT '0',`deaths` mediumint(8) NOT NULL DEFAULT '0',`x` float NOT NULL DEFAULT '0',`y` float NOT NULL DEFAULT '0',`z` float NOT NULL DEFAULT '0',`angle` float NOT NULL DEFAULT '0',`interior` tinyint(3) NOT NULL DEFAULT '0', PRIMARY KEY (`id`), UNIQUE KEY `username` (`username`))");
	return 1;
}

DatosJugadorBD(playerid)
{
	cache_get_value_int(0, "id", Jugador[playerid][ID]);

	cache_get_value_int(0, "kills", Jugador[playerid][Asesinatos]);
	cache_get_value_int(0, "deaths", Jugador[playerid][Muertes]);

	cache_get_value_float(0, "x", Jugador[playerid][X_Pos]);
	cache_get_value_float(0, "y", Jugador[playerid][Y_Pos]);
	cache_get_value_float(0, "z", Jugador[playerid][Z_Pos]);
	cache_get_value_float(0, "angle", Jugador[playerid][A_Pos]);
	cache_get_value_int(0, "interior", Jugador[playerid][Interior]);
	return 1;
}

KickearTiempo(playerid, time = 500)
{
	SetTimerEx("KickearJugador", time, false, "d", playerid);
	return 1;
}

GuardarDatosJugador(playerid, reason)
{
	if (Jugador[playerid][EstaLogueado] == false) return 0;

	// Si el cliente crashea, no es posible obtener la posición del jugador en la devolución de llamada de
	// OnPlayerDisconnect así que usaremos la última posición guardada (en el caso de un jugador que se
	// registró y crasheo o fue kickeado, la posición será el punto de generación predeterminado)
	if (reason == 1)
	{
		GetPlayerPos(playerid, Jugador[playerid][X_Pos], Jugador[playerid][Y_Pos], Jugador[playerid][Z_Pos]);
		GetPlayerFacingAngle(playerid, Jugador[playerid][A_Pos]);
	}

	new query[145];
	mysql_format(BaseDeDatos, query, sizeof query, "UPDATE `players` SET `x` = %f, `y` = %f, `z` = %f, `angle` = %f, `interior` = %d WHERE `id` = %d LIMIT 1", Jugador[playerid][X_Pos], Jugador[playerid][Y_Pos], Jugador[playerid][Z_Pos], Jugador[playerid][A_Pos], GetPlayerInterior(playerid), Jugador[playerid][ID]);
	mysql_tquery(BaseDeDatos, query);
	return 1;
}

ActualizaMuertesJugador(playerid)
{
	if (Jugador[playerid][EstaLogueado] == false) return 0;

	Jugador[playerid][Muertes]++;

	new query[70];
	mysql_format(BaseDeDatos, query, sizeof query, "UPDATE `players` SET `deaths` = %d WHERE `id` = %d LIMIT 1", Jugador[playerid][Muertes], Jugador[playerid][ID]);
	mysql_tquery(BaseDeDatos, query);
	return 1;
}

ActualizaAsesinatosJugador(killerid)
{
	// Debemos verificar antes si el asesino no era un jugador válido (conectado) para evitar errores
	if (killerid == INVALID_PLAYER_ID) return 0;
	if (Jugador[killerid][EstaLogueado] == false) return 0;

	Jugador[killerid][Asesinatos]++;

	new query[70];
	mysql_format(BaseDeDatos, query, sizeof query, "UPDATE `players` SET `kills` = %d WHERE `id` = %d LIMIT 1", Jugador[killerid][Asesinatos], Jugador[killerid][ID]);
	mysql_tquery(BaseDeDatos, query);
	return 1;
}