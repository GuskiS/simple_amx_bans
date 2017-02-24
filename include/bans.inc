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
