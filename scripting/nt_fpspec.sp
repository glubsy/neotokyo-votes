#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <neotokyo>
#define DEBUG 0
#define PLUGIN_VERSION "0.2"

#pragma semicolon 1
#pragma newdecls required

// Incremented id for observer
int iObserverCursor;

// Holds player ids for 5 casters and their targets
int iObserver[5], iObserverTarget[5];

// Toggles first person spectating state
bool bFirstPersonSpec[MAXPLAYERS+1];

int iShouldHide[MAXPLAYERS+1][6]; //one extra, just cause'

bool g_bDuck[MAXPLAYERS+1];
bool g_bDuckHeld[MAXPLAYERS+1];
bool g_bVisionHeld[MAXPLAYERS+1];

float g_fLeanIncrement[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "NEOTOKYO: first person spectate",
	author = "glub, Soft as HELL",
	description = "spectates in first person view",
	version = PLUGIN_VERSION,
	url = "https://github.com/glubsy"
};

public void OnPluginStart()
{
	//HookEvent("player_death", OnPlayerDeath);
	AddCommandListener(OnSpecCmd, "spec_next");
	AddCommandListener(OnSpecCmd, "spec_prev");
	
	RegConsoleCmd("sm_spec_pov", SpecPOVCommand, "Spectate a specific client");
}



public Action OnSpecCmd(int client, const char[] command, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	if(target <= 0)
		return Plugin_Continue;
	#if DEBUG >0
	PrintToChatAll("Observing: %i", target);
	#endif
	
	if(bFirstPersonSpec[client])
			return Plugin_Handled;

	// Loop trough observers
	for(int cursor = 0; cursor < 5; cursor++)
	{
		if(iObserver[cursor] == client)
		{
			// Update current target if we're in first person mode
			iObserverTarget[cursor] = target;

			break;
		}
	}
	return Plugin_Continue;
}


public Action SpecPOVCommand(int client, int args)
{
	if(GetClientTeam(client) > 1)
	{
		PrintToChat(client, "You cannot use first person spec unless you are in team spectator.");
		return Plugin_Handled;		
	}
	
	char arg1[3];
	GetCmdArgString(arg1, sizeof(arg1));
	
	int observer_mode = StringToInt(arg1);
	
	if(iObserverCursor > 4)
		iObserverCursor = 0;
	
	iObserver[iObserverCursor] = client;
	iObserverTarget[iObserverCursor] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
	
	if(iObserverTarget[iObserverCursor] <= 0)
	{
		#if DEBUG > 0
		PrintToServer("Observed player no found for observer: %N (%i)", client, client);
		#endif
		return Plugin_Handled;
	}
	
	#if DEBUG > 0
	PrintToChatAll("%N (%i) is currently observing %N (%i)", client, client, iObserverTarget[iObserverCursor], iObserverTarget[iObserverCursor]);
	#endif

	if(observer_mode == 1)
	{
		SDKHookEx(iObserverTarget[iObserverCursor], SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][0] = iObserverTarget[iObserverCursor]; // 0 holds player entity ID to hide
		
		int primaryweapon = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_PRIMARY); 
		int secondaryweapon = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_SECONDARY);
		int knife = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_MELEE);
		int grenade = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_GRENADE);
		
		SDKHookEx(primaryweapon, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][1] = primaryweapon;
		//bShouldHide[primaryweapon] = true;
		
		SDKHookEx(secondaryweapon, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][2] = secondaryweapon;
		//bShouldHide[secondaryweapon] = true;
		
		SDKHookEx(knife, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][3] = knife;
		//bShouldHide[knife] = true;
		
		SDKHookEx(grenade, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][4] = grenade;
		//bShouldHide[grenade] = true;
		
		
		Client_SetObserverMode(client, OBS_MODE_NONE, false); //OBS_MODE_NONE
		//SetEntProp(client, Prop_Send, "m_iObserverMode", 5);

		SetEntityMoveType(client, MOVETYPE_NONE);   // important, otherwise wasd still works: MOVETYPE_NONE

	   
		CreateTimer(0.1, timer_ActivateFPPOV, client);
	}
	else if(observer_mode == 0)
	{
		SDKUnhook(iObserverTarget[iObserverCursor], SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][0] = 0;
		
		//bShouldHide[iObserverTarget[iObserverCursor]] = false;
		
		int primaryweapon = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_PRIMARY);
		int secondaryweapon = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_SECONDARY);
		int knife = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_MELEE);
		int grenade = GetPlayerWeaponSlot(iObserverTarget[iObserverCursor], SLOT_GRENADE);
		
		SDKUnhook(primaryweapon, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][1] = 0;
		//bShouldHide[primaryweapon] = false;
		
		SDKUnhook(secondaryweapon, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][2] = 0;
		//bShouldHide[secondaryweapon] = false;
		
		SDKUnhook(knife, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][3] = 0;
		//bShouldHide[knife] = false;
		
		SDKUnhook(grenade, SDKHook_SetTransmit, Hook_ShouldHide);
		iShouldHide[iObserver[iObserverCursor]][4] = 0;
		//bShouldHide[grenade] = false;
		
		
		Client_SetObserverMode(client, view_as<Obs_Mode>(5)); // 5 = free roaming
		bFirstPersonSpec[client] = false;
		
		//ClientCommand(client, "r_screenoverlay off");
	}		
	iObserverCursor++;	
	
	
	return Plugin_Handled;
}

public Action timer_ActivateFPPOV(Handle timer, int client)
{
	bFirstPersonSpec[client] = true;
	//ClientCommand(client, "r_screenoverlay effects/combine_binocoverlay.vmt");
}

//Blocking transmit from observed player to observer
public Action Hook_ShouldHide(int entity, int client)
{
	if(entity == iShouldHide[client][0] || iShouldHide[client][1] == entity || iShouldHide[client][2] == entity || iShouldHide[client][3] == entity ||
		iShouldHide[client][4] == entity || iShouldHide[client][5] == entity)
	{
		if(bFirstPersonSpec[client])
		{
			return Plugin_Handled;
		}
		return Plugin_Continue;
	}
	else
		return Plugin_Continue;
}


public void UpdateView(int caster) // only up to 5 casters
{
	int client = iObserver[caster];
	int target = iObserverTarget[caster];
	
	if(IsValidClient(client) && bFirstPersonSpec[client] && target > 0)
	{
		float vecAbsOrigin[3], vecEyeAngles[3], vecAbsAngles[3];

		GetClientAbsOrigin(target, vecAbsOrigin);      
		GetClientEyeAngles(target, vecEyeAngles);
		GetClientAbsAngles(target, vecAbsAngles);
		
		float vecVelocity[3];
		GetVelocity(target, vecVelocity);
		//PrintToChat(client, "%f %f %f", vecVelocity[0], vecVelocity[1], vecVelocity[2]);
		
		//vecAbsOrigin[0] += 8.0 * Cosine(DegToRad(vecEyeAngles[1])); //+10
		//vecAbsOrigin[1] += 8.0 * Sine(DegToRad(vecEyeAngles[1])); //+10
		//vecAbsOrigin[2] += 3; //+3


		
		if(GetEntProp(target, Prop_Send, "m_iLean") == 2)
		{
			IncrementLeanDegree(client);
			
			vecEyeAngles[2] += g_fLeanIncrement[client];
			vecAbsOrigin[1] -= 7.0 * Cosine(DegToRad(vecAbsAngles[1]));
			vecAbsOrigin[1] -= 7.0 * Sine(DegToRad(vecAbsAngles[1]));
			
			//SetEntPropEnt(client, Prop_Send, "m_iLean", 2); //doesn't work, reset to 0 every frame!
		}
		else if(GetEntProp(target, Prop_Send, "m_iLean") == 1)
		{
			IncrementLeanDegree(client);
			
			vecEyeAngles[2] -= g_fLeanIncrement[client];
			vecAbsOrigin[1] += 7.0 * Cosine(DegToRad(vecAbsAngles[1]));
			vecAbsOrigin[1] += 7.0 * Sine(DegToRad(vecAbsAngles[1]));

			//SetEntPropEnt(client, Prop_Send, "m_iLean", 1); //doesn't work, reset to 0 every frame!
		}
		else
		{
			g_fLeanIncrement[client] = 0.0;
		}
		
		if(g_bDuck[client]) //doesn't work, reset to 0 every frame?
		{
			if(GetEntProp(target, Prop_Send, "m_bDucking") != 0)
			{
				//artificially move camera down, which causes collision glitches!
				//vecAbsOrigin[0] -= 40.0 * Cosine(DegToRad(vecEyeAngles[1])); //+10
				//vecAbsOrigin[1] -= 40.0 * Sine(DegToRad(vecEyeAngles[1])); //+10
				//vecAbsOrigin[2] -= 12.0;

				SetEntProp(client, Prop_Send, "m_bDucking", 1);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_bDucking", 0);
			}
			
			if(GetEntProp(target, Prop_Send, "m_bDucked") != 0)
			{
				SetEntProp(client, Prop_Send, "m_bDucked", 1);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_bDucked", 0);
			}
			
			SetEntProp(client, Prop_Send, "m_bDucking", GetEntProp(target, Prop_Send, "m_bDucking"));
			SetEntProp(client, Prop_Send, "m_bDucked", 1);
		}
		else if(!g_bDuck[client])
		{
			SetEntProp(client, Prop_Send, "m_bDucking", GetEntProp(target, Prop_Send, "m_bDucking"));
			SetEntProp(client, Prop_Send, "m_bDucked", 0);
		}
		
		TeleportEntity(client, vecAbsOrigin, vecEyeAngles, vecVelocity);
	}
}


public void IncrementLeanDegree(int client){
	if(g_fLeanIncrement[client] >= 28.0)
		return;

	g_fLeanIncrement[client] += 2.0;	
}

public Action OnPlayerRunCmd(int client, int &buttons)
{	
	for(int caster = 0; caster < 5; caster++)
	{
		if(iObserverTarget[caster] != client)
			return;

		if((buttons & IN_VISION) == IN_VISION)
		{
			if(g_bVisionHeld[client])
			{
				SetEntProp(iObserver[caster], Prop_Send, "m_iVision", GetEntProp(client, Prop_Send, "m_iVision")); //works, DONE.
			}
			else
			{
				g_bVisionHeld[client] = true;
			}
		}
		else 
		{
			g_bVisionHeld[client] = false;
		}
		
		
		if((buttons & IN_DUCK) == IN_DUCK)
		{
			if(g_bDuckHeld[client])
			{
				g_bDuck[iObserver[caster]] = true;
			}
			else
			{
				g_bDuckHeld[client] = true;
			}
		}
		else 
		{
			g_bDuck[iObserver[caster]] = false;
			g_bDuckHeld[client] = false;
		}
		
		
	}
}



public void OnGameFrame()
{
	for(int cursor = 0; cursor < 5; cursor++)
	{
		if(!bFirstPersonSpec[iObserver[cursor]])
				continue;
		 
		UpdateView(cursor);
	}
}

stock void GetVelocity(int client, float output[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", output);
}
