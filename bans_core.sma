#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <bans>

new g_iServerId;
new g_pServerId;
new g_szPassword[33][LENGTH_NAME];
new Handle:g_pSqlTuple;

public plugin_init() {
  register_plugin("[BANS] - Core", BANS_VERSION, BANS_AUTHOR);

  register_dictionary("admin.txt");
  register_dictionary("amxbans.txt");
  register_dictionary("common.txt");

  register_cvar("amx_vote_ratio",     "0.02");
  register_cvar("amx_vote_time",        "10");
  register_cvar("amx_vote_answers",      "1");
  register_cvar("amx_vote_delay",       "60");
  register_cvar("amx_last_voting",       "0");
  register_cvar("amx_show_activity",     "2");
  register_cvar("amx_votekick_ratio", "0.40");
  register_cvar("amx_voteban_ratio",  "0.40");
  register_cvar("amx_votemap_ratio",  "0.40");

  set_cvar_float("amx_last_voting", 0.0);

  register_cvar("amx_sql_host", "127.0.0.1");
  register_cvar("amx_sql_user",      "root");
  register_cvar("amx_sql_pass",          "");
  register_cvar("amx_sql_db",         "amx");
  register_cvar("amx_sql_type",     "mysql");

  g_pServerId = register_cvar("bans_server_id", "0");
  register_concmd("amx_reloadadmins", "cmd_reloadadmins", ADMIN_CFG);
  register_concmd("amx_ra", "cmd_reloadadmins", ADMIN_CFG);

  remove_user_flags(0, read_flags("z"));

  new dir[64];
  get_configsdir(dir, charsmax(dir));
  server_cmd("exec %s/amxx.cfg", dir);
  server_cmd("exec %s/sql.cfg", dir);
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
  g_iServerId = get_pcvar_num(g_pServerId);

  if(find_plugin_byfile("admin.amxx") != INVALID_PLUGIN_ID) {
    log_amx("%s WARNING: admin.amxx plugin running! stopped.", DEFAULT_TAG);
    pause("acd", "admin.amxx");
  }

  if(find_plugin_byfile("admin_sql.amxx") != INVALID_PLUGIN_ID) {
    log_amx("%s WARNING: admin_sql.amxx plugin running! stopped.", DEFAULT_TAG);
    pause("acd", "admin_sql.amxx");
  }

  if(!g_iServerId) {
    set_fail_state("%s Unset 'bans_server_id' cvar, exiting...", DEFAULT_TAG);
  }

  MySQL_Init();
  MySQL_LoadAdmins();
  server_exec();
}

public client_authorized(id) {
  set_user_access(id);
  if(is_user_admin(id)) {
    MySQL_LoadAdmin(id);
  }
}

public client_infochanged(id) {
  if(!is_user_connected(id)) {
    return PLUGIN_CONTINUE;
  }

  new newname[LENGTH_NAME], oldname[LENGTH_NAME], password[LENGTH_NAME];
  get_user_name(id, oldname, charsmax(oldname));
  get_user_info(id, "name", newname, charsmax(newname));
  get_user_info(id, DEFAULT_FIELD, password, charsmax(password));

  if(!equali(newname, oldname) || !equali(password, g_szPassword[id])) {
    set_user_access(id, newname);
  }

  return PLUGIN_CONTINUE;
}

public cmd_reloadadmins(id, level, cid) {
  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED;
  }

  remove_user_flags(0, read_flags("z"));
  MySQL_LoadAdmins();
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

public MySQL_LoadAdmins() {
  new query[192];

  admins_flush();
  load_admins_query(query, charsmax(query), g_iServerId);
  SQL_ThreadQuery(g_pSqlTuple, "MySQL_RecieveAdmins", query);
}

public MySQL_RecieveAdmins(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate) return mysql_errors_print(failstate, code, error);

  new count = 0;
  if(SQL_NumResults(query)) {
    new col_flags    = SQL_FieldNameToNum(query, "flags");
    new col_access   = SQL_FieldNameToNum(query, "access");
    new col_username = SQL_FieldNameToNum(query, "username");
    new col_password = SQL_FieldNameToNum(query, "password");

    new access[32], flags[5], username[LENGTH_NAME], password[LENGTH_NAME];

    while(SQL_MoreResults(query)) {
      SQL_ReadResult(query, col_access, access, charsmax(access));
      SQL_ReadResult(query, col_flags, flags, charsmax(flags));
      SQL_ReadResult(query, col_username, username, charsmax(username));
      SQL_ReadResult(query, col_password, password, charsmax(password));

      admins_push(username, password, read_flags(access), read_flags(flags));

      count++;
      SQL_NextRow(query);
    }
  }

  if(count == 1) {
    server_print("%s %L", DEFAULT_TAG, LANG_SERVER, "LOADED_ADMIN");
  }
  else {
    server_print("%s %L", DEFAULT_TAG, LANG_SERVER, "LOADED_ADMINS", count);
  }

  users_access();
  SQL_FreeHandle(query);
  return PLUGIN_HANDLED;
}

public MySQL_LoadAdmin(id) {
  new query[192];

  new name[LENGTH_NAME_SAFE], data[1];
  data[0] = id;
  mysql_get_username_safe(id, name, charsmax(name));
  load_admin_query(query, charsmax(query), name, g_iServerId);
  SQL_ThreadQuery(g_pSqlTuple, "MySQL_RecieveAdmin", query, data, sizeof(data));
}

public MySQL_RecieveAdmin(failstate, Handle:query, error[], code, data[], datasize) {
  if(failstate) return mysql_errors_print(failstate, code, error);

  new id = data[0];
  if(!SQL_NumResults(query)) {
    remove_user_flags(id);
    return PLUGIN_HANDLED;
  }

  new col_flags    = SQL_FieldNameToNum(query, "flags");
  new col_access   = SQL_FieldNameToNum(query, "access");
  new col_username = SQL_FieldNameToNum(query, "username");
  new col_password = SQL_FieldNameToNum(query, "password");

  new access[32], flags[5], username[LENGTH_NAME], password[LENGTH_NAME];

  SQL_ReadResult(query, col_access, access, charsmax(access));
  SQL_ReadResult(query, col_flags, flags, charsmax(flags));
  SQL_ReadResult(query, col_username, username, charsmax(username));
  SQL_ReadResult(query, col_password, password, charsmax(password));

  admins_push(username, password, read_flags(access), read_flags(flags));
  set_user_access(id);

  return PLUGIN_CONTINUE;
}

// Helpers
stock users_access() {
  new num;
  static players[32];
  get_players(players, num);
  for(--num; num >= 0; num--) {
    set_user_access(players[num]);
  }
}

stock lookup_access(id, username[], password[]) {
  new index = -1, result = 0;
  new i, adminname[LENGTH_NAME], adminpassword[LENGTH_NAME], count = admins_num()-1;

  for(i = count; i >= 0; i--) {
    admins_lookup(i, AdminProp_Auth, adminname, charsmax(adminname));
    if(equali(username, adminname)) {
      index = i;
      break;
    }
  }

  if(index != -1) {
    new access = admins_lookup(index, AdminProp_Access), ip[LENGTH_IP], steamid[LENGTH_ID];
    admins_lookup(index, AdminProp_Password, adminpassword, charsmax(adminpassword));
    get_user_ip(id, ip, charsmax(ip), 1);
    get_user_authid(id, steamid, charsmax(steamid));

    if(equal(password, adminpassword)) {
      result |= 12;
      set_user_flags(id, access);

      new sflags[32];
      get_flags(access, sflags, charsmax(sflags));

      log_amx("%s Login: ^"%s<%d><%s><>^" became an admin (access ^"%s^") (address ^"%s^")", DEFAULT_TAG, username, get_user_userid(id), steamid, sflags, ip);
    }
    else {
      result |= 1;

      if(admins_lookup(index, AdminProp_Flags) & FLAG_KICK) {
        result |= 2;
        log_amx("%s Login: ^"%s<%d><%s><>^" kicked due to invalid password (address ^"%s^")", DEFAULT_TAG, username, get_user_userid(id), steamid, ip);
      }
    }
  }
  else {
    new access = read_flags(DEFAULT_ACCESS);

    if(access) {
      result |= 8;
      set_user_flags(id, access);
    }
  }

  return result;
}

stock set_user_access(id, name[] = "") {
  new username[LENGTH_NAME];

  remove_user_flags(id);
  get_user_info(id, DEFAULT_FIELD, g_szPassword[id], charsmax(g_szPassword[]));
  if(name[0]) {
    copy(username, charsmax(username), name);
  }
  else {
    get_user_name(id, username, charsmax(username));
  }

  new result = lookup_access(id, username, g_szPassword[id]);
  if(result & 1) {
    client_cmd(id, "echo ^"* %L^"", id, "INV_PAS");
  }

  if(result & 2) {
    server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "NO_ENTRY");
    return PLUGIN_HANDLED;
  }

  if(result & 4) {
    client_cmd(id, "echo ^"* %L^"", id, "PAS_ACC");
  }

  if(result & 8) {
    client_cmd(id, "echo ^"* %L^"", id, "PRIV_SET");
  }

  return PLUGIN_CONTINUE;
}
