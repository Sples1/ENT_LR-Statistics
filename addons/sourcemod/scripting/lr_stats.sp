/*
 * SourceMod Entity Projects
 * by: Entity
 *
 *
 * Copyright (C) 2020 Kőrösfalvi "Entity" Martin
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <tomori>
#include <autoexecconfig>
#include <chat-processor>
#include <multicolors>
#include <smlib>
#include <lastrequest>

#pragma semicolon 1
#pragma newdecls required

#define LR_E_NAME						"[ENT-HOSTIES] LR Statistics"
#define LR_E_VERSION					"1.1b"

enum LR_Types
{
	LR_E_KnifeFight = 0,
	LR_E_Shot4Shot,
	LR_E_GunToss,
	LR_E_ChickenFight,
	LR_E_HotPotato,
	LR_E_Dodgeball,
	LR_E_NoScope,
	LR_E_RockPaperScissors,
	LR_E_Rebel,
	LR_E_Mag4Mag,
	LR_E_Race,
	LR_E_RussianRoulette,
	LR_E_JumpContest
};

Database DB = null;

ConVar gH_Cvar_LR_E_Enabled,
	gH_Cvar_LR_E_ChatPrefix;

char gShadow_LR_E_ChatPrefix[MAX_NAME_LENGTH];
char gShadow_LR_E_ClientQuery[2048];
char gShadow_LR_E_ClientID[MAXPLAYERS+1][32];
char gShadow_LR_E_ClientSub[MAXPLAYERS+1][64];

int gH_Cvar_LR_E_ClientOpponent[MAXPLAYERS+1];
int gH_Cvar_LR_E_ClientLR[MAXPLAYERS+1];
int gH_Cvar_LR_E_ClientCameFrom[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = LR_E_NAME, 
	author = "Entity", 
	description = "LR Statistics and Scoreboard for ENT_Hosties.", 
	version = LR_E_VERSION
};

public void OnPluginStart()
{
	LoadTranslations("lr_statistics.phrases");
	
	if(DB == null)
		SQL_DBConnect();
	
	AutoExecConfig_SetFile("LR_Statistics", "sourcemod");
	AutoExecConfig_SetCreateFile(true);
	
	gH_Cvar_LR_E_Enabled = AutoExecConfig_CreateConVar("lr_statistics_enabled", "1", "Enable or disable LR Statistics from Entity:", 0, true, 0.0, true, 1.0);
	gH_Cvar_LR_E_ChatPrefix = AutoExecConfig_CreateConVar("lr_statistics_prefix", "{default}[{lightred}LR-Statistics{default}]", "Edit ChatTag for LR Statistics (Colors can be used).");
	
	HookConVarChange(gH_Cvar_LR_E_ChatPrefix, OnCvarChange);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	RegConsoleCmd("sm_lrsb", Command_ShowScoreboard);
	RegConsoleCmd("sm_lrscoreboard", Command_ShowScoreboard);
	RegConsoleCmd("sm_lrstats", Command_ShowScoreboard);
	
	RegConsoleCmd("sm_lrtop", Command_ShowTopList);
	RegConsoleCmd("sm_lrtop10", Command_ShowTopList);
	
	RegConsoleCmd("sm_lrstat", Command_ShowStatsMe);
	RegConsoleCmd("sm_lrmystats", Command_ShowStatsMe);
	
	for (int idx = 1; idx <= MaxClients; idx++)
	{
		if (IsValidClient(idx))
			GetClientAuthId(idx, AuthId_Steam2, gShadow_LR_E_ClientID[idx], sizeof(gShadow_LR_E_ClientID));
	}
	
	char buffer[128];
	GetConVarString(gH_Cvar_LR_E_ChatPrefix, buffer, sizeof(buffer));
	Format(gShadow_LR_E_ChatPrefix, sizeof(gShadow_LR_E_ChatPrefix), "%s{lightblue} ", buffer);
	
	//Needed against chat-processor bugs
	ReplaceString(gShadow_LR_E_ChatPrefix, sizeof(gShadow_LR_E_ChatPrefix), "{blue}", "\x0C");
	ReplaceString(gShadow_LR_E_ChatPrefix, sizeof(gShadow_LR_E_ChatPrefix), "{red}", "\x02");
}

public void OnConfigsExecuted() 
{
	if(DB == null)
		SQL_DBConnect();
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("hosties"))
		LogError("%t", "Hosties Required");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "hosties"))
		LogError("%t", "Hosties Required");
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client))
		GetClientAuthId(client, AuthId_Steam2, gShadow_LR_E_ClientID[client], sizeof(gShadow_LR_E_ClientID));
}

public void OnStartLR(int PrisonerIndex, int GuardIndex, int Type)
{
	int len;
	if (IsValidClient(PrisonerIndex))
    {
		len = strlen(gShadow_LR_E_ClientID[PrisonerIndex]) * 2 + 1;
		char[] escapedSteamId = new char[len];
		DB.Escape(gShadow_LR_E_ClientID[PrisonerIndex], escapedSteamId, len);
	
		Do_Player_Check(PrisonerIndex, escapedSteamId);
		
		gH_Cvar_LR_E_ClientOpponent[PrisonerIndex] = GuardIndex;
		gH_Cvar_LR_E_ClientLR[PrisonerIndex] = Type;
		
		CreateTimer(0.1, Timer_LR_Analyzer, PrisonerIndex, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
	
	if (IsValidClient(GuardIndex))
	{
		len = strlen(gShadow_LR_E_ClientID[GuardIndex]) * 2 + 1;
		char[] escapedSteamId = new char[len];
		DB.Escape(gShadow_LR_E_ClientID[GuardIndex], escapedSteamId, len);
	
		Do_Player_Check(GuardIndex, escapedSteamId);
		
		gH_Cvar_LR_E_ClientOpponent[GuardIndex] = PrisonerIndex;
		gH_Cvar_LR_E_ClientLR[GuardIndex] = Type;
		
		CreateTimer(0.1, Timer_LR_Analyzer, GuardIndex, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_LR_Analyzer(Handle timer, int client)
{
	if (!IsValidClient(client))
		return Plugin_Stop;

	if (!IsClientInLastRequest(client))
	{
		char edit[32];
		switch (gH_Cvar_LR_E_ClientLR[client])
		{
			case LR_E_KnifeFight:
				Format(edit, sizeof(edit), "lr_kf_");
			case LR_E_Shot4Shot:
				Format(edit, sizeof(edit), "lr_s4s_");
			case LR_E_GunToss:
				Format(edit, sizeof(edit), "lr_gt_");
			case LR_E_ChickenFight:
				Format(edit, sizeof(edit), "lr_cf_");
			case LR_E_HotPotato:
				Format(edit, sizeof(edit), "lr_hp_");
			case LR_E_Dodgeball:
				Format(edit, sizeof(edit), "lr_db_");
			case LR_E_NoScope:
				Format(edit, sizeof(edit), "lr_ns_");
			case LR_E_RockPaperScissors:
				Format(edit, sizeof(edit), "lr_rps_");
			case LR_E_Rebel:
				Format(edit, sizeof(edit), "lr_rebel_");
			case LR_E_Mag4Mag:
				Format(edit, sizeof(edit), "lr_m4m_");
			case LR_E_Race:
				Format(edit, sizeof(edit), "lr_r_");
			case LR_E_RussianRoulette:
				Format(edit, sizeof(edit), "lr_rr_");
			case LR_E_JumpContest:
				Format(edit, sizeof(edit), "lr_jg_");
		}
	
		int len = strlen(gShadow_LR_E_ClientID[client]) * 2 + 1;
		char[] escapedSteamId = new char[len];
		DB.Escape(gShadow_LR_E_ClientID[client], escapedSteamId, len);
	
		if (!IsValidClient(gH_Cvar_LR_E_ClientOpponent[client])) return Plugin_Stop;
	
		char temp_query[128];
		if (IsPlayerAlive(client) && !IsPlayerAlive(gH_Cvar_LR_E_ClientOpponent[client])) 
		{
			DB.Format(temp_query, sizeof(temp_query), ", `lr_won` = (`lr_won` + 1), `%sp` = (`%sp` + 1), `%sw` = (`%sw` + 1)", edit, edit, edit, edit);
			DB.Format(gShadow_LR_E_ClientQuery[client], sizeof(gShadow_LR_E_ClientQuery), "UPDATE `lr_stats` SET `played_lr` = (`played_lr` + 1)%s WHERE `auth` = '%s';", temp_query, escapedSteamId);
			
			DB.Query(Nothing_Callback, gShadow_LR_E_ClientQuery[client], client);
		}
		else if (!IsPlayerAlive(client) && IsPlayerAlive(gH_Cvar_LR_E_ClientOpponent[client]))
		{
			DB.Format(temp_query, sizeof(temp_query), ", `lr_won` = (`lr_won` + 1), `%sp` = (`%sp` + 1)", edit, edit);
			DB.Format(gShadow_LR_E_ClientQuery[client], sizeof(gShadow_LR_E_ClientQuery), "UPDATE `lr_stats` SET `played_lr` = (`played_lr` + 1)%s WHERE `auth` = '%s';", temp_query, escapedSteamId);
			
			DB.Query(Nothing_Callback, gShadow_LR_E_ClientQuery[client], client);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void Do_Player_Check(int id, char[] escapedSteamId)
{
	char userName[MAX_NAME_LENGTH];
	GetClientName(id, userName, sizeof(userName));
	
	int len = strlen(userName) * 2 + 1;
	char[] escapedName = new char[len];
	DB.Escape(userName, escapedName, len);
	
	char query[512];
	DB.Format(query, sizeof(query), "INSERT INTO `lr_stats` (`name`, `auth`) VALUES ('%s', '%s') ON DUPLICATE KEY UPDATE name = '%s';", escapedName, escapedSteamId, escapedName);
	DB.Query(Nothing_Callback, query, id);
}

public Action Command_ShowTopList(int client, int args)
{
	if (!gH_Cvar_LR_E_Enabled.BoolValue || !IsValidClient(client)) return Plugin_Handled;
	
	char buffer[64];
	Menu menu = CreateMenu(TopStats);
	Format(buffer, sizeof(buffer), "---=| %t |=---\n ", "Top Ten");
	menu.SetTitle(buffer);
	
	Format(buffer, sizeof(buffer), "%t", "Summary");
	menu.AddItem("summary", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_KnifeFight");
	menu.AddItem("LR_KnifeFight", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Shot4Shot");
	menu.AddItem("LR_Shot4Shot", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_GunToss");
	menu.AddItem("LR_GunToss", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_ChickenFight");
	menu.AddItem("LR_ChickenFight", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_HotPotato");
	menu.AddItem("LR_HotPotato", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Dodgeball");
	menu.AddItem("LR_Dodgeball", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_NoScope");
	menu.AddItem("LR_NoScope", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_RockPaperScissors");
	menu.AddItem("LR_RockPaperScissors", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Rebel");
	menu.AddItem("LR_Rebel", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Mag4Mag");
	menu.AddItem("LR_Mag4Mag", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Race");
	menu.AddItem("LR_Race", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_RussianRoulette");
	menu.AddItem("LR_RussianRoulette", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_JumpContest");
	menu.AddItem("LR_JumpContest", buffer);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	gH_Cvar_LR_E_ClientCameFrom[client] = 0;
	return Plugin_Handled;
}

public int TopStats(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char query[512];
		switch (itemNum)
		{
			case 0:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_won DESC LIMIT 10");
			case 1:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_kf_w DESC LIMIT 10");
			case 2:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_s4s_w DESC LIMIT 10");
			case 3:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_gt_w DESC LIMIT 10");
			case 4:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_cf_w DESC LIMIT 10");
			case 5:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_hp_w DESC LIMIT 10");
			case 6:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_db_w DESC LIMIT 10");
			case 7:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_ns_w DESC LIMIT 10");
			case 8:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_rps_w DESC LIMIT 10");
			case 9:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_rebel_w DESC LIMIT 10");
			case 10:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_m4m_w DESC LIMIT 10");
			case 11:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_r_w DESC LIMIT 10");
			case 12:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_rr_w DESC LIMIT 10");
			case 13:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_jg_w DESC LIMIT 10");
		}
		
		DB.Query(GetTopStat_Callback, query, client);
	}
}

public void GetTopStat_Callback(Database db, DBResultSet result, char[] error, int client)
{
	if(result == null)
		LogError("%t: %s", "Error", error);
		
	if(result.RowCount > 0)
	{
		char buffer[128];
		Menu menu = CreateMenu(TopChoice);
		Format(buffer, sizeof(buffer), "---=| %t |=---\n ", "Top Ten");
		menu.SetTitle(buffer);
		
		char name[MAX_NAME_LENGTH], steamid[32];
		while(result.FetchRow())
		{
			result.FetchString(0, name, sizeof(name));
			result.FetchString(1, steamid, sizeof(steamid));
			menu.AddItem(steamid, name);
		}
		
		menu.ExitButton = true;
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
		CPrintToChat(client, "%s %t", gShadow_LR_E_ChatPrefix, "No Data");
}

public int TopChoice(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char info[64];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		int len = strlen(info) * 2 + 1;
		char[] escapedSteamId = new char[len];
		DB.Escape(info, escapedSteamId, len);
		
		char query[512];
		DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` WHERE auth = '%s'", escapedSteamId);
		DB.Query(GetUserStat_Callback, query, client);
	}
	else if (action == MenuAction_Cancel)
	{
		Command_ShowTopList(client, 0);
	}
}

public Action Command_ShowScoreboard(int client, int args)
{
	if (!gH_Cvar_LR_E_Enabled.BoolValue || !IsValidClient(client)) return Plugin_Handled;
	
	char buffer[64];
	Menu menu = CreateMenu(SBStats);
	Format(buffer, sizeof(buffer), "---=| %t |=---\n ", "Top Hundred");
	menu.SetTitle(buffer);
	
	Format(buffer, sizeof(buffer), "%t", "Summary");
	menu.AddItem("summary", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_KnifeFight");
	menu.AddItem("LR_KnifeFight", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Shot4Shot");
	menu.AddItem("LR_Shot4Shot", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_GunToss");
	menu.AddItem("LR_GunToss", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_ChickenFight");
	menu.AddItem("LR_ChickenFight", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_HotPotato");
	menu.AddItem("LR_HotPotato", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Dodgeball");
	menu.AddItem("LR_Dodgeball", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_NoScope");
	menu.AddItem("LR_NoScope", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_RockPaperScissors");
	menu.AddItem("LR_RockPaperScissors", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Rebel");
	menu.AddItem("LR_Rebel", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Mag4Mag");
	menu.AddItem("LR_Mag4Mag", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Race");
	menu.AddItem("LR_Race", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_RussianRoulette");
	menu.AddItem("LR_RussianRoulette", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_JumpContest");
	menu.AddItem("LR_JumpContest", buffer);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	gH_Cvar_LR_E_ClientCameFrom[client] = 2;
	return Plugin_Handled;
}

public int SBStats(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char query[512];
		switch (itemNum)
		{
			case 0:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_won DESC LIMIT 100");
			case 1:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_kf_w DESC LIMIT 100");
			case 2:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_s4s_w DESC LIMIT 100");
			case 3:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_gt_w DESC LIMIT 100");
			case 4:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_cf_w DESC LIMIT 100");
			case 5:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_hp_w DESC LIMIT 100");
			case 6:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_db_w DESC LIMIT 100");
			case 7:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_ns_w DESC LIMIT 100");
			case 8:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_rps_w DESC LIMIT 100");
			case 9:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_rebel_w DESC LIMIT 100");
			case 10:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_m4m_w DESC LIMIT 100");
			case 11:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_r_w DESC LIMIT 100");
			case 12:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_rr_w DESC LIMIT 100");
			case 13:
				DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` ORDER BY lr_jg_w DESC LIMIT 100");
		}
		
		DB.Query(GetSBStat_Callback, query, client);
	}
}

public void GetSBStat_Callback(Database db, DBResultSet result, char[] error, int client)
{
	if(result == null)
		LogError("%t: %s", "Error", error);
		
	if(result.RowCount > 0)
	{
		char buffer[128];
		Menu menu = CreateMenu(SBChoice);
		Format(buffer, sizeof(buffer), "---=| %t |=---\n ", "Top Hundred");
		menu.SetTitle(buffer);
		
		char name[MAX_NAME_LENGTH], steamid[32];
		while(result.FetchRow())
		{
			result.FetchString(0, name, sizeof(name));
			result.FetchString(1, steamid, sizeof(steamid));
			menu.AddItem(steamid, name);
		}
		
		menu.ExitButton = true;
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
		CPrintToChat(client, "%s %t", gShadow_LR_E_ChatPrefix, "No Data");
}

public int SBChoice(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char info[64];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		int len = strlen(info) * 2 + 1;
		char[] escapedSteamId = new char[len];
		DB.Escape(info, escapedSteamId, len);
		
		char query[512];
		DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` WHERE auth = '%s'", escapedSteamId);
		DB.Query(GetUserStat_Callback, query, client);
	}
	else if (action == MenuAction_Cancel)
	{
		Command_ShowScoreboard(client, 0);
	}
}

public Action Command_ShowStatsMe(int client, int args)
{
	if (!gH_Cvar_LR_E_Enabled.BoolValue || !IsValidClient(client)) return Plugin_Handled;
	
	char buffer[64];
	Menu menu = CreateMenu(StatsMe);
	Format(buffer, sizeof(buffer), "---=| %t |=---\n ", "Your Stat");
	menu.SetTitle(buffer);
	
	Format(buffer, sizeof(buffer), "%t", "Summary");
	menu.AddItem("summary", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_KnifeFight");
	menu.AddItem("LR_KnifeFight", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Shot4Shot");
	menu.AddItem("LR_Shot4Shot", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_GunToss");
	menu.AddItem("LR_GunToss", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_ChickenFight");
	menu.AddItem("LR_ChickenFight", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_HotPotato");
	menu.AddItem("LR_HotPotato", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Dodgeball");
	menu.AddItem("LR_Dodgeball", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_NoScope");
	menu.AddItem("LR_NoScope", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_RockPaperScissors");
	menu.AddItem("LR_RockPaperScissors", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Rebel");
	menu.AddItem("LR_Rebel", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Mag4Mag");
	menu.AddItem("LR_Mag4Mag", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_Race");
	menu.AddItem("LR_Race", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_RussianRoulette");
	menu.AddItem("LR_RussianRoulette", buffer);
	Format(buffer, sizeof(buffer), "%t", "LR_JumpContest");
	menu.AddItem("LR_JumpContest", buffer);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	gH_Cvar_LR_E_ClientCameFrom[client] = 1;
	return Plugin_Handled;
}

public int StatsMe(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char info[64];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		int len = strlen(gShadow_LR_E_ClientID[client]) * 2 + 1;
		char[] escapedSteamId = new char[len];
		DB.Escape(gShadow_LR_E_ClientID[client], escapedSteamId, len);
		
		Format(gShadow_LR_E_ClientSub[client], sizeof(gShadow_LR_E_ClientSub), info);
		
		char query[512];
		DB.Format(query, sizeof(query), "SELECT * FROM `lr_stats` WHERE auth = '%s'", escapedSteamId);
		DB.Query(GetUserStat_Callback, query, client);
	}
}

public void GetUserStat_Callback(Database db, DBResultSet result, char[] error, int client)
{
	if(result == null)
		LogError("%t: %s", "Error", error);
		
	if(result.RowCount > 0)
	{
		while(result.FetchRow())
		{
			char buffer[128], name[MAX_NAME_LENGTH];
			Panel panel = new Panel();
			result.FetchString(0, name, sizeof(name));
			Format(buffer, sizeof(buffer), "---=| %t |=---\n ", "Player Stat", name);
			panel.SetTitle(buffer);
			
			int total, win, lose, wr;
			if (StrEqual(gShadow_LR_E_ClientSub[client], "summary"))
			{
				total = result.FetchInt(2);
				win =  result.FetchInt(3);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_KnifeFight"))
			{
				total = result.FetchInt(4);
				win =  result.FetchInt(5);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_Shot4Shot"))
			{
				total = result.FetchInt(24);
				win =  result.FetchInt(25);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_GunToss"))
			{
				total = result.FetchInt(28);
				win =  result.FetchInt(29);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_ChickenFight"))
			{
				total = result.FetchInt(22);
				win =  result.FetchInt(23);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_HotPotato"))
			{
				total = result.FetchInt(18);
				win =  result.FetchInt(19);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_Dodgeball"))
			{
				total = result.FetchInt(20);
				win =  result.FetchInt(21);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_NoScope"))
			{
				total = result.FetchInt(16);
				win =  result.FetchInt(17);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_RockPaperScissors"))
			{
				total = result.FetchInt(14);
				win =  result.FetchInt(15);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_Rebel"))
			{
				total = result.FetchInt(12);
				win =  result.FetchInt(13);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_Mag4Mag"))
			{
				total = result.FetchInt(26);
				win =  result.FetchInt(27);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_Race"))
			{
				total = result.FetchInt(10);
				win =  result.FetchInt(11);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_RussianRoulette"))
			{
				total = result.FetchInt(8);
				win =  result.FetchInt(9);
			}
			else if (StrEqual(gShadow_LR_E_ClientSub[client], "LR_JumpContest"))
			{
				total = result.FetchInt(6);
				win =  result.FetchInt(7);
			}
			
			lose = total - win;
			if (total != 0)
				wr = ((win / total) * 100);
			else 
				wr = 0;
				
			Format(buffer, sizeof(buffer), "%t", "Played LR");
			panel.DrawItem(buffer);
			Format(buffer, sizeof(buffer), "   > %i", total);
			panel.DrawText(buffer);
			Format(buffer, sizeof(buffer), "%t", "Won LR");
			panel.DrawItem(buffer);
			Format(buffer, sizeof(buffer), "   > %i", win);
			panel.DrawText(buffer);
			Format(buffer, sizeof(buffer), "%t", "Lost LR");
			panel.DrawItem(buffer);
			Format(buffer, sizeof(buffer), "   > %i", lose);
			panel.DrawText(buffer);
			Format(buffer, sizeof(buffer), "%t", "WinRate");
			panel.DrawItem(buffer);
			Format(buffer, sizeof(buffer), "   > %i%%", wr);
			panel.DrawText(buffer);
			
			panel.DrawText(" ");
			Format(buffer, sizeof(buffer), "%t", "Back");
			panel.DrawItem(buffer);
			Format(buffer, sizeof(buffer), "%t", "Exit");
			panel.DrawItem(buffer);
		 
			panel.Send(client, SubCateg, MENU_TIME_FOREVER);
		 
			delete panel;
		}
	}
	else
	{
		CPrintToChat(client, "%s %t", gShadow_LR_E_ChatPrefix, "No Stats Yet");
	}
}

public int SubCateg(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		if (param == 5)
		{
			switch (gH_Cvar_LR_E_ClientCameFrom[client])
			{
				case 0:
					Command_ShowTopList(client, 0);
				case 1:
					Command_ShowStatsMe(client, 0);
				case 2:
					Command_ShowScoreboard(client, 0);
			}
		}
	}
}

void SQL_DBConnect()
{
	if(DB != null)
		delete DB;
		
	if(SQL_CheckConfig("lr_stats"))
		Database.Connect(SQLConnection_Callback, "lr_stats");
	else
		SetFailState("%t", "No Database");
}

public void SQLConnection_Callback(Database db, char[] error, any data)
{
	if(db == null)
	{
		LogError("%t. %t: %s", "Cant Connect", "Error",error);
		return;
	}
	
	DB = db;
	DB.Query(Nothing_Callback,"CREATE TABLE IF NOT EXISTS `lr_stats`(`name` varchar(64) NOT NULL,`auth` varchar(32) PRIMARY KEY NOT NULL,`played_lr` INT DEFAULT 0,`lr_won` INT DEFAULT 0,`lr_kf_p` INT DEFAULT 0,`lr_kf_w` INT DEFAULT 0,`lr_jg_p` INT DEFAULT 0,`lr_jg_w` INT DEFAULT 0,`lr_rr_p` INT DEFAULT 0,`lr_rr_w` INT DEFAULT 0,`lr_r_p` INT DEFAULT 0,`lr_r_w` INT DEFAULT 0,`lr_rebel_p` INT DEFAULT 0,`lr_rebel_w` INT DEFAULT 0,`lr_rps_p` INT DEFAULT 0,`lr_rps_w` INT DEFAULT 0,`lr_ns_p` INT DEFAULT 0,`lr_ns_w` INT DEFAULT 0,`lr_hp_p` INT DEFAULT 0,`lr_hp_w` INT DEFAULT 0,`lr_db_p` INT DEFAULT 0,`lr_db_w` INT DEFAULT 0,`lr_cf_p` INT DEFAULT 0,`lr_cf_w` INT DEFAULT 0,`lr_s4s_p` INT DEFAULT 0,`lr_s4s_w` INT DEFAULT 0,`lr_m4m_p` INT DEFAULT 0,`lr_m4m_w` INT DEFAULT 0,`lr_gt_p` INT DEFAULT 0,`lr_gt_w` INT DEFAULT 0) ENGINE = MyISAM DEFAULT CHARSET = utf8;", DBPrio_High);
}

public void Nothing_Callback(Database db, DBResultSet result, char[] error, any data)
{
	if(result == null)
		LogError("%t: %s", "Error", error);
}

public void OnCvarChange(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	if (cvar == gH_Cvar_LR_E_ChatPrefix)
	{
		char buffer[128];
		GetConVarString(gH_Cvar_LR_E_ChatPrefix, buffer, sizeof(buffer));
		Format(gShadow_LR_E_ChatPrefix, sizeof(gShadow_LR_E_ChatPrefix), "%s{lightblue} ", buffer);
		
		//Needed against chat-processor bugs
		ReplaceString(gShadow_LR_E_ChatPrefix, sizeof(gShadow_LR_E_ChatPrefix), "{blue}", "\x0C");
		ReplaceString(gShadow_LR_E_ChatPrefix, sizeof(gShadow_LR_E_ChatPrefix), "{red}", "\x02");
	}
}