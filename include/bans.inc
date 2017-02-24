#if defined _bans_included
  #endinput
#endif

#define _bans_included

#pragma semicolon 1

#define DB_BAN         "amx_bans"
#define DB_ADMIN       "amx_admins"
#define DB_SERVER      "amx_servers"
#define DEFAULT_TAG    "[BANS]"
#define DEFAULT_FIELD  "_pw"
#define DEFAULT_ACCESS "z"
#define COMPLAIN_URL   "www.heal.lv"

#define LENGTH_IP         16
#define LENGTH_ID         25
#define LENGTH_NAME       32
#define LENGTH_NAME_SAFE 100
#define LENGTH_BAN       100

#define BANS_VERSION   "1.0.0"
#define BANS_AUTHOR    "GuskiS"

enum _:ENUM_BAN_INFO {
  BAN_INFO_LENGTH,
  BAN_INFO_INBAN,
  BAN_INFO_REASON[LENGTH_BAN]
}

stock mysql_errors_print(failstate, code, error[]) {
  if(failstate == TQUERY_CONNECT_FAILED) {
    log_amx("%s Could not connect to SQL database. [%d] %s", DEFAULT_TAG, code, error);
  }
  else {
    log_amx("%s Load query failed. [%d] %s", DEFAULT_TAG, code, error);
  }

  return PLUGIN_HANDLED;
}

stock mysql_escape_string(const source[], dest[], len) {
  copy(dest, len, source);
  replace_all(dest, len, "\\", "\\\\");
  replace_all(dest, len, "\0", "\\0");
  replace_all(dest, len, "\n", "\\n");
  replace_all(dest, len, "\r", "\\r");
  replace_all(dest, len, "\x1a", "\Z");
  replace_all(dest, len, "'", "\'");
  replace_all(dest, len, "^"", "\^"");
}

stock mysql_get_username_safe(id, dest[], len) {
  new name[LENGTH_NAME];
  get_user_name(id, name, charsmax(name));
  mysql_escape_string(name, dest, len);
}


stock locate_player(id, identifier[]) {
  new player = find_player("c", identifier); // Check based on steam ID
  if(!player) player = find_player("bl", identifier); // Check based on a partial non-case sensitive name
  if(!player) player = find_player("d", identifier);  // Check based on IP address

  if(!player && identifier[0] == '#' && identifier[1]) {
    player = find_player("k", str_to_num(identifier[1])); // Check based on user ID
  }

  if(player) {
    new name[32], message[64];
    get_user_name(player, name, charsmax(name));

    if(get_user_flags(player) & ADMIN_IMMUNITY) {
      formatex(message, charsmax(message), "%s Client ^"%s^" has immunity", DEFAULT_TAG, name);
    }
    else if(is_user_bot(player)) {
      formatex(message, charsmax(message), "%s Client ^"%s^" is a bot", DEFAULT_TAG, name);
    }

    if(strlen(message)) return print_message(id, message);
  }
  else {
    new message[64];
    formatex(message, charsmax(message), "%s %L", DEFAULT_TAG, LANG_PLAYER, "PLAYER_NOT_FOUND", identifier);
    return print_message(id, message);
  }

  return player;
}

stock _kick_player(id) {
  server_cmd("kick #%d %L", get_user_userid(id), id, "KICK_MESSAGE");
}

stock load_admins_query(output[], len, server) {
  formatex(output, len, "SELECT `aa`.* FROM `%s` as aa WHERE `aa`.`deleted_at` IS NULL AND (`aa`.`expires_at` > UNIX_TIMESTAMP(NOW())) AND `aa`.`server_id` = %d", DB_ADMIN, server);
}

stock load_admin_query(output[], len, name[], server) {
  formatex(output, len, "SELECT `aa`.* FROM `%s` as aa WHERE `aa`.`deleted_at` IS NULL AND (`aa`.`expires_at` > UNIX_TIMESTAMP(NOW())) AND `aa`.`username` = '%s' AND `aa`.`server_id` = %d", DB_ADMIN, name, server);
}

stock load_bans_query(output[], len, ip[], steam[]) {
  formatex(output, len, "SELECT `ab`.*, UNIX_TIMESTAMP(`ab`.`created_at`) AS created, `aa`.`username` AS admin FROM `%s` AS ab INNER JOIN `%s` AS aa ON `aa`.`id` = `ab`.`admin_id` WHERE (`ab`.`deleted_at` IS NULL AND (`ab`.`ip_address` = '%s' OR `ab`.`steam_id` = '%s'))", DB_BAN, DB_ADMIN, ip, steam);
}

stock insert_ban_query(output[], len, admin_id, server_id, username[], ip[], steam_id[], reason[], length) {
  formatex(output, len, "INSERT INTO `%s` (`admin_id`, `server_id`, `username`, `ip_address`, `steam_id`, `reason`, `length`, `created_at`, `updated_at`) \
    VALUES (%d, %d, '%s', '%s', '%s', '%s', %d, NOW(), NOW())", DB_BAN, admin_id, server_id, username, ip, steam_id, reason, length);
}

// Amx::Ban(
//   id: integer,
//   admin_id: integer,
//   server_id: integer,
//   username: string,
//   steam_id: string,
//   ip_address: string,
//   reason: string,
//   length: integer,
//   deleted_at: datetime,
//   created_at: datetime,
//   updated_at: datetime
// )

// Amx::Admin(
//   id: integer,
//   user_id: integer,
//   server_id: integer,
//   username: string,
//   password: string,
//   expires_at: datetime,
//   access: string,
//   flags: string,
//   active: boolean,
//   deleted_at: datetime,
//   created_at: datetime,
//   updated_at: datetime
// )
