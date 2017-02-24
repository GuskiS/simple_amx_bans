#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <time>
#include <bans>

new Handle:g_pSqlTuple;

public plugin_init() {
  register_plugin("[BANS] - Player Check", BANS_VERSION, BANS_AUTHOR);

  register_dictionary("time.txt");
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
  MySQL_Init();
}

public client_authorized(id) {
  MySQL_LoadBans(id);
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

public MySQL_LoadBans(id) {
  static steam[LENGTH_ID], ip[LENGTH_IP];
  get_user_authid(id, steam, charsmax(steam));
  get_user_ip(id, ip, charsmax(ip), 1);

  static data[1], query[512];
  formatex(query, charsmax(query), "SELECT `ab`.*, UNIX_TIMESTAMP(`ab`.`created_at`) AS created, `aa`.`username` AS admin FROM `%s` AS ab INNER JOIN `%s` AS aa ON `aa`.`id` = `ab`.`admin_id` WHERE (`ab`.`deleted_at` IS NULL AND (`ab`.`ip_address` = '%s' OR `ab`.`steam_id` = '%s'))", DB_BAN, DB_ADMIN, ip, steam);

  data[0] = id;
  SQL_ThreadQuery(g_pSqlTuple, "MySQL_RecieveBans", query, data, sizeof(query));
  return PLUGIN_HANDLED;
}

public MySQL_RecieveBans(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate == TQUERY_CONNECT_FAILED) {
    log_amx("%s Could not connect to SQL database. [%d] %s", DEFAULT_TAG, code, error);
  }
  else if(failstate == TQUERY_QUERY_FAILED) {
    log_amx("%s Load query failed. [%d] %s", DEFAULT_TAG, code, error);
  }

  if(!SQL_NumResults(query)) {
    return PLUGIN_HANDLED;
  }

  new col_admin      = SQL_FieldNameToNum(query,      "admin");
  new col_username   = SQL_FieldNameToNum(query,   "username");
  new col_steam_id   = SQL_FieldNameToNum(query,   "steam_id");
  new col_ip_address = SQL_FieldNameToNum(query, "ip_address");
  new col_reason     = SQL_FieldNameToNum(query,     "reason");
  new col_length     = SQL_FieldNameToNum(query,     "length");
  new col_created    = SQL_FieldNameToNum(query,    "created");

  new length, created, id = data[0];
  static admin[LENGTH_NAME], username[LENGTH_NAME], steam_id[LENGTH_ID], ip_address[LENGTH_IP], reason[40];

  length  = SQL_ReadResult(query, col_length) * 60;
  created = SQL_ReadResult(query, col_created);
  SQL_ReadResult(query, col_admin,      admin,      charsmax(admin));
  SQL_ReadResult(query, col_username,   username,   charsmax(username));
  SQL_ReadResult(query, col_steam_id,   steam_id,   charsmax(steam_id));
  SQL_ReadResult(query, col_ip_address, ip_address, charsmax(ip_address));
  SQL_ReadResult(query, col_reason,     reason,     charsmax(reason));

  new current_time = get_systime(0);

  if(!length || !created || (created + length) > current_time) {
    client_cmd(id, "echo %s ===============================================", DEFAULT_TAG);
    client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_8", admin);

    if(!length) {
      client_cmd(id, "echo %s %L", DEFAULT_TAG, id,"MSG_10");
    }
    else {
      static formated[128];
      new left = (created + length - current_time);
      get_time_length(id, left, timeunit_seconds, formated, charsmax(formated));
      client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_12", formated);
    }

    client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_13", username);
    client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_2", reason);
    client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_7", COMPLAIN_URL);
    if(strlen(steam_id)) {
      client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_4", steam_id);
    }
    if(strlen(ip_address)) {
      client_cmd(id, "echo %s %L", DEFAULT_TAG, id, "MSG_5", ip_address);
    }
    client_cmd(id, "echo %s ===============================================", DEFAULT_TAG);

    set_task(1.0, "kick_player", id);
  }

  return PLUGIN_HANDLED;
}

public kick_player(id) {
  static message[128];
  format(message, charsmax(message), "%L", id, "KICK_MESSAGE");
  server_cmd("kick #%d %s", get_user_userid(id), message);
  return PLUGIN_CONTINUE;
}
