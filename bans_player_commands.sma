#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <bans>

new Handle:g_pSqlTuple;
new g_iServerId;
new g_dBanInfo[33][ENUM_BAN_INFO];

public plugin_init() {
  register_plugin("[BANS] - Player Commands", BANS_VERSION, BANS_AUTHOR);

  register_concmd("amx_banip", "cmdBan", ADMIN_BAN, "<time in mins> <steamID or nickname or #authid or IP> <reason>");
  register_srvcmd("amx_banip", "cmdBan", -1, "<time in mins> <steamID or nickname or #authid or IP> <reason>");
}

public plugin_end() {
  if(g_pSqlTuple) {
    SQL_FreeHandle(g_pSqlTuple);
  }
}

public plugin_cfg() {
  set_task(0.1, "plugin_cfg_post");
}

public plugin_cfg_post() {
  g_iServerId = get_cvar_num("bans_server_id");
  if(!g_iServerId) {
    set_fail_state("%s Unset 'bans_server_id' cvar, exiting...", DEFAULT_TAG);
  }
  MySQL_Init();
}

// public client_authorized(id) {
//   MySQL_LoadBans(id);
// }

// MySQL
public MySQL_Init() {
  new host[64], user[32], pass[32], db[32];
  get_cvar_string("amx_sql_host", host, charsmax(host));
  get_cvar_string("amx_sql_user", user, charsmax(user));
  get_cvar_string("amx_sql_pass", pass, charsmax(pass));
  get_cvar_string("amx_sql_db", db, charsmax(db));
  g_pSqlTuple = SQL_MakeDbTuple(host, user, pass, db);
}

public cmdBan(id, level, cid) {
  if(!cmd_access(id, level, cid, 3))
    return PLUGIN_HANDLED;

  static command[228];
  read_args(command, charsmax(command));

  static length[50], identifier[50], reason[LENGTH_BAN];
  parse(command, length, charsmax(length), identifier, charsmax(identifier), reason, charsmax(reason));

  trim(length);
  trim(identifier);
  trim(reason);
  remove_quotes(reason);

  if(!is_str_num(length) || read_argc() < 3) {
    client_print(id, print_console, "%s %L", DEFAULT_TAG, LANG_PLAYER, "AMX_BAN_SYNTAX");
    return PLUGIN_HANDLED;
  }

  new target = locate_player(id, identifier);
  if(!target || g_dBanInfo[target][BAN_INFO_INBAN])
    return PLUGIN_HANDLED;

  g_dBanInfo[target][BAN_INFO_LENGTH] = str_to_num(length);
  // TODO cleanup
  g_dBanInfo[target][BAN_INFO_INBAN] = true;
  g_dBanInfo[target][BAN_INFO_REASON] = reason;

  new query[192], name[LENGTH_NAME_SAFE];
  mysql_get_username_safe(id, name, charsmax(name));
  // TODO correct admin query
  formatex(query, charsmax(query), "SELECT `aa`.* FROM `%s` as aa WHERE `aa`.`deleted_at` IS NULL AND `aa`.`username` = '%s' AND `aa`.`server_id` = %d", DB_ADMIN, name, g_iServerId);

  new data[2];
  data[0] = id;
  data[1] = target;
  SQL_ThreadQuery(g_pSqlTuple, "cmd_ban_", query, data, sizeof(data));

  return PLUGIN_HANDLED;
}

public cmd_ban_(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate == TQUERY_CONNECT_FAILED) {
    log_amx("%s Could not connect to SQL database. [%d] %s", DEFAULT_TAG, code, error);
  }
  else if(failstate == TQUERY_QUERY_FAILED) {
    log_amx("%s Load query failed. [%d] %s", DEFAULT_TAG, code, error);
  }

  new id = data[0];
  new target = data[1];

  if(!is_user_connected(target) || !SQL_NumResults(query)) {
    return PLUGIN_HANDLED;
  }

  static username[LENGTH_NAME_SAFE];
  mysql_get_username_safe(target, username, charsmax(username));

  new col_id = SQL_FieldNameToNum(query, "id");
  new admin_id = SQL_ReadResult(query, col_id);

  static steam_id[LENGTH_ID], ip[LENGTH_IP];
  get_user_ip(target, ip, charsmax(ip), 1);
  get_user_authid(target, steam_id, charsmax(steam_id));
  if(contain(steam_id, "VALVE") != -1) {
    steam_id[0] = EOS;
  }
  else {
    ip[0] = EOS;
  }

  new query[512];
  formatex(query, charsmax(query), "INSERT INTO `%s` (`admin_id`, `server_id`, `username`, `ip_address`, `steam_id`, `reason`, `length`, `created_at`, `updated_at`) \
    VALUES (%d, %d, '%s', '%s', '%s', '%s', %d, NOW(), NOW())", DB_BAN, admin_id, g_iServerId, username, ip, steam_id, g_dBanInfo[target][BAN_INFO_REASON], g_dBanInfo[target][BAN_INFO_LENGTH]);

  new data[1];
  data[0] = id;
  SQL_ThreadQuery(g_pSqlTuple, "insert_bandetails", query, data, sizeof(data));
  return PLUGIN_HANDLED;
}

public insert_bandetails(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate == TQUERY_CONNECT_FAILED) {
    log_amx("%s Could not connect to SQL database. [%d] %s", DEFAULT_TAG, code, error);
  }
  else if(failstate == TQUERY_QUERY_FAILED) {
    log_amx("%s Load query failed. [%d] %s", DEFAULT_TAG, code, error);
  }

  kick_player(data[0]);
  // new id = data[0];
  // TODO add motd before kick
  // select_amxbans_motd(id,g_choicePlayerId[id],bid)
  return PLUGIN_HANDLED;
}

public locate_player(id, identifier[]) {
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

    if(strlen(message)) {
      id ? console_print(id, message) : server_print(message);
      return 0;
    }
  }
  else {
    if(id) {
      server_print("%s %L", DEFAULT_TAG, LANG_PLAYER, "PLAYER_NOT_FOUND", identifier);
    }
    else {
      console_print(id, "%s %L", DEFAULT_TAG, LANG_PLAYER, "PLAYER_NOT_FOUND", identifier);
    }
    return 0;
  }

  return player;
}

public kick_player(id) {
  static message[128];
  format(message, charsmax(message), "%L", id, "KICK_MESSAGE");
  server_cmd("kick #%d %s", get_user_userid(id), message);
  return PLUGIN_CONTINUE;
}
