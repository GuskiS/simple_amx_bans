#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <bans>

new Handle:g_pSqlTuple;
new g_iServerId, g_iScreenCount;
new Float:g_fScreenInterval;
new g_dBanInfo[33][ENUM_BAN_INFO];
new g_pScreenCount;

public plugin_init() {
  register_plugin("[BANS] - Player Commands", BANS_VERSION, BANS_AUTHOR);

  g_pScreenCount = register_cvar("bans_screen_count", "5");
  register_concmd("amx_banip", "cmd_ban", ADMIN_BAN, "<time in mins> <steamID or nickname or #authid or IP> <reason>");
  register_srvcmd("amx_banip", "cmd_ban", -1, "<time in mins> <steamID or nickname or #authid or IP> <reason>");
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

  g_fScreenInterval = get_cvar_float("amx_ssinterval");
  if(g_fScreenInterval) g_iScreenCount = get_pcvar_num(g_pScreenCount);

  MySQL_Init();
}

public client_authorized(id) {
  g_dBanInfo[id][BAN_INFO_INBAN] = false;
}

public cmd_ban(id, level, cid) {
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
  g_dBanInfo[target][BAN_INFO_INBAN] = true;
  g_dBanInfo[target][BAN_INFO_REASON] = reason;

  new query[192];
  if(id) {
    new name[LENGTH_NAME_SAFE];
    mysql_get_username_safe(id, name, charsmax(name));
    load_admin_query(query, charsmax(query), name, g_iServerId);
  }
  else {
    // TODO load server admin
  }

  new data[2];
  data[0] = id;
  data[1] = target;
  SQL_ThreadQuery(g_pSqlTuple, "MySQL_RecieveAdmin", query, data, sizeof(data));

  return PLUGIN_HANDLED;
}

// MySQL
public MySQL_Init() {
  new host[64], user[32], pass[32], db[32];
  get_cvar_string("amx_sql_host", host, charsmax(host));
  get_cvar_string("amx_sql_user", user, charsmax(user));
  get_cvar_string("amx_sql_pass", pass, charsmax(pass));
  get_cvar_string("amx_sql_db", db, charsmax(db));
  g_pSqlTuple = SQL_MakeDbTuple(host, user, pass, db);
}

public MySQL_RecieveAdmin(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate) return mysql_errors_print(failstate, code, error);

  new admin = data[0], id = data[1];
  if(!is_user_connected(id)) {
    console_print(admin, "%L", admin, "CL_NOT_FOUND");
    return PLUGIN_HANDLED;
  }

  if(!SQL_NumResults(query)) {
    if(admin) remove_user_flags(admin);
    console_print(admin, "%L", admin, "NO_ACC_COM");
    return PLUGIN_HANDLED;
  }

  static username[LENGTH_NAME_SAFE];
  mysql_get_username_safe(id, username, charsmax(username));

  new col_id = SQL_FieldNameToNum(query, "id");
  new admin_id = SQL_ReadResult(query, col_id);

  static steam_id[LENGTH_ID], ip[LENGTH_IP];
  get_user_ip(id, ip, charsmax(ip), 1);
  get_user_authid(id, steam_id, charsmax(steam_id));
  if(contain(steam_id, "VALVE") != -1) {
    steam_id[0] = EOS;
  }
  else {
    ip[0] = EOS;
  }

  new query[512];
  insert_ban_query(query, charsmax(query), admin_id, g_iServerId, username, ip, steam_id, g_dBanInfo[id][BAN_INFO_REASON], g_dBanInfo[id][BAN_INFO_LENGTH]);

  new data[1];
  data[0] = id;
  SQL_ThreadQuery(g_pSqlTuple, "MySQL_AddBan", query, data, sizeof(data));
  return PLUGIN_HANDLED;
}

public MySQL_AddBan(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate) return mysql_errors_print(failstate, code, error);

  new id = data[0];
  new Float:timer = 2.0;
  if(g_iScreenCount) {
    timer += (g_fScreenInterval * float(g_iScreenCount));
    client_cmd(id, "^"wait^";^"wait^";^"wait^";^"wait^";^"net_graph^" 3");
    server_cmd("amx_screen #%d %d", get_user_userid(id), g_iScreenCount);
  }

  set_task(timer, "kick_player", id);
  return PLUGIN_HANDLED;
}

public kick_player(id) {
  _kick_player(id);
}

stock print_message(id, message[]) {
  id ? console_print(id, message) : server_print(message);
  return 0;
}
