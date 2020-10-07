/*
 * SourceMod Entity Projects
 * by: Entity
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#if defined _TomoriCore_Included_
	#endinput
#endif
#define _TomoriCore_
#define	FlashbangOffsetForHC	15

public char C_sWeapon[MAXPLAYERS + 1][11][64]; 
public int C_WeaponCount[MAXPLAYERS + 1] = 0;
public int C_FlashCounter[MAXPLAYERS + 1] = 0;

/**
* Checks several parameters to see if the specified client is a valid user.
*
* @param client index
* @param Allow bots?
* @param Allow dead?
* @return true if valid
*/
stock bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
    {
        return false;
    }
    return true;
} 

stock bool DirExistsEx(const char[] path)
{
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);

		if (!DirExists(path))
		{
			LogError("Couldn't create folder! (%s)", path);
			return false;
		}
	}

	return true;
}

stock void GetFlagInt(char buffer[30])
{
	FlagStringToInt(buffer, "a", ADMFLAG_RESERVATION);
	FlagStringToInt(buffer, "b", ADMFLAG_GENERIC);
	FlagStringToInt(buffer, "c", ADMFLAG_KICK);
	FlagStringToInt(buffer, "d", ADMFLAG_BAN);
	FlagStringToInt(buffer, "e", ADMFLAG_UNBAN);
	FlagStringToInt(buffer, "f", ADMFLAG_SLAY);
	FlagStringToInt(buffer, "g", ADMFLAG_CHANGEMAP);
	FlagStringToInt(buffer, "h", 128);
	FlagStringToInt(buffer, "i", ADMFLAG_CONFIG);
	FlagStringToInt(buffer, "j", ADMFLAG_CHAT);
	FlagStringToInt(buffer, "k", ADMFLAG_VOTE);
	FlagStringToInt(buffer, "l", ADMFLAG_PASSWORD);
	FlagStringToInt(buffer, "m", ADMFLAG_RCON);
	FlagStringToInt(buffer, "n", ADMFLAG_CHEATS);
	FlagStringToInt(buffer, "z", ADMFLAG_ROOT);
	FlagStringToInt(buffer, "o", ADMFLAG_CUSTOM1);
	FlagStringToInt(buffer, "p", ADMFLAG_CUSTOM2);
	FlagStringToInt(buffer, "q", ADMFLAG_CUSTOM3);
	FlagStringToInt(buffer, "r", ADMFLAG_CUSTOM4);
	FlagStringToInt(buffer, "s", ADMFLAG_CUSTOM5);
	FlagStringToInt(buffer, "t", ADMFLAG_CUSTOM6);
}

stock void FlagStringToInt(char StrToReplace[30], char flag[10], int ReplaceWith)
{
	char NewFlagValue[10];
	IntToString(ReplaceWith, NewFlagValue, sizeof(NewFlagValue));
	ReplaceString(StrToReplace, sizeof(StrToReplace), flag, NewFlagValue, false);
}

stock void SetLogFile(char path[PLATFORM_MAX_PATH], char[] file, char[] folder)
{
	char sDate[12];
	FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
	Format(path, sizeof(path), "logs/%s/%s-%s.log", folder, file, sDate);

	BuildPath(Path_SM, path, sizeof(path), path);
}

/**
* Strip all weapons from the aimed target and save them
*
* @param aimed client
*/
stock void SaveWeapons(int target)
{
	C_FlashCounter[target] = 0;
	int counter = 0;
	
	C_FlashCounter[target] = GetEntProp(target, Prop_Data, "m_iAmmo", _, FlashbangOffsetForHC);
	C_WeaponCount[target] = Client_GetWeaponCount(target);
	int temp_count = C_WeaponCount[target];
	if (IsValidClient(target))
	{
		for (int g = C_WeaponCount[target]; g != 0; g--)
		{
			int temp_weapon = Client_GetActiveWeapon(target);
			if (Weapon_IsValid(temp_weapon))
			{
				char temp_weapon_name[64];
				SetWeaponClassname(temp_weapon, temp_weapon_name, sizeof(temp_weapon_name));
				
				Client_DetachWeapon(target, temp_weapon);
				C_sWeapon[target][counter] = temp_weapon_name;
				
				counter++; temp_count--;
			}
		}
	}
}

/**
* Restore Saved Weapons of the aimed target
*
* @param aimed client
*/
stock void RestoreWeapons(int aimed)
{
	if (IsValidClient(aimed))
	{
		for (int g = 0; g <= C_WeaponCount[aimed]; g++)
		{
			if (!StrEqual(C_sWeapon[aimed][g], "weapon_flashbang"))
			{
				GivePlayerItem(aimed, C_sWeapon[aimed][g]);
			}
			else
			{
				for (int x = 1; x <= C_FlashCounter[aimed]; x++)
				{

					GivePlayerItem(aimed, C_sWeapon[aimed][g]);
				}
			}
		}
	}
}

/**
* Sets the ClassName of a weapon
*
* @param Weapon entity
* @param buffer
* @param size
*/
stock void SetWeaponClassname(int weapon, char[] buffer, int size) 
{ 
	if (Weapon_IsValid(weapon))
	{
		switch (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex")) 
		{ 
			case 23: Format(buffer, size, "weapon_mp5sd"); 
			case 60: Format(buffer, size, "weapon_m4a1_silencer"); 
			case 61: Format(buffer, size, "weapon_usp_silencer"); 
			case 63: Format(buffer, size, "weapon_cz75a"); 
			case 64: Format(buffer, size, "weapon_revolver"); 
			default: GetEntityClassname(weapon, buffer, size); 
		}
	}
}