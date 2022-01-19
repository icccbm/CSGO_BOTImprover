#pragma semicolon 1
#2022-1-19-16：40

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <eItems>
#include <smlib>
#include <navmesh>
#include <dhooks>
#include <botmimic>

char g_szMap[128];
char g_szCrosshairCode[MAXPLAYERS+1][35];
bool g_bFreezetimeEnd, g_bBombPlanted, g_bTerroristEco, g_bAbortExecute, g_bEveryoneDead;
bool g_bIsProBot[MAXPLAYERS+1], g_bZoomed[MAXPLAYERS + 1], g_bDontSwitch[MAXPLAYERS+1];
int g_bCountAdvance;
int g_iProfileRank[MAXPLAYERS+1], g_iUncrouchChance[MAXPLAYERS+1], g_iUSPChance[MAXPLAYERS+1], g_iM4A1SChance[MAXPLAYERS+1], g_iTarget[MAXPLAYERS+1], g_iNewTargetTime[MAXPLAYERS+1];
int g_iRndExecute, g_iCurrentRound, g_iProfileRankOffset, g_iBotTargetSpotOffset, g_iBotNearbyEnemiesOffset, g_iBotTaskOffset, g_iFireWeaponOffset, g_iEnemyVisibleOffset, g_iBotProfileOffset, g_iBotSafeTimeOffset, g_iBotAttackingOffset, g_iBotEnemyOffset;
float g_fTargetPos[MAXPLAYERS+1][3], g_fNadeTarget[MAXPLAYERS+1][3], g_fReactionTime[MAXPLAYERS+1], g_fAggression[MAXPLAYERS+1], g_fRoundStartTimeStamp;
bool g_bFoundC4;
ConVar g_cvBotEcoLimit;
Handle g_hBotMoveTo;
Handle g_hLookupBone;
Handle g_hGetBonePosition;
Handle g_hBotIsVisible;
Handle g_hBotIsHiding;
Handle g_hBotEquipBestWeapon;
Handle g_hBotSetLookAt;
Handle g_hSetCrosshairCode;
Handle g_hSwitchWeaponCall;
Handle g_hIsLineBlockedBySmoke;
Handle g_hBotSetEnemy;
Handle g_hBotBendLineOfSight;
Address g_pTheBots;
CNavArea g_pCurrArea[MAXPLAYERS+1];

static char g_szBoneNames[][] =  {
	"neck_0", 
	"pelvis", 
	"spine_0", 
	"spine_1", 
	"spine_2", 
	"spine_3", 
	"clavicle_l",
	"clavicle_r",
	"arm_upper_L", 
	"arm_lower_L", 
	"hand_L", 
	"arm_upper_R", 
	"arm_lower_R", 
	"hand_R", 
	"leg_upper_L",  
	"leg_lower_L", 
	"ankle_L",
	"leg_upper_R", 
	"leg_lower_R",
	"ankle_R"
};

enum RouteType
{
	DEFAULT_ROUTE = 0, 
	FASTEST_ROUTE, 
	SAFEST_ROUTE, 
	RETREAT_ROUTE
}

enum PriorityType
{
	PRIORITY_LOWEST = -1,
	PRIORITY_LOW, 
	PRIORITY_MEDIUM, 
	PRIORITY_HIGH, 
	PRIORITY_UNINTERRUPTABLE
}

enum TaskType
{
	SEEK_AND_DESTROY = 0,            //dont know
	PLANT_BOMB,						//team t,plant bomb
	FIND_TICKING_BOMB,				//Useless,should be changed,too much shifting if time waste
	DEFUSE_BOMB,					//team ct,defuse,try to fake
	GUARD_TICKING_BOMB,				//for t 
	GUARD_BOMB_DEFUSER,				//useless
	GUARD_LOOSE_BOMB,				//useless 
	GUARD_BOMB_ZONE,			
	GUARD_INITIAL_ENCOUNTER,		
	ESCAPE_FROM_BOMB,				
	HOLD_POSITION,					//can be modified
	FOLLOW,							//modified?	
//following are useless	
	VIP_ESCAPE,						
	GUARD_VIP_ESCAPE_ZONE,
	COLLECT_HOSTAGES,
	RESCUE_HOSTAGES,
	GUARD_HOSTAGES,           
	GUARD_HOSTAGE_RESCUE_ZONE,
//
	MOVE_TO_LAST_KNOWN_ENEMY_POSITION,
	MOVE_TO_SNIPER_SPOT,
	SNIPING,
	ESCAPE_FROM_FLAMES,
	
}

#include "bot_stuff/de_mirage.sp"
#include "bot_stuff/de_dust2.sp"
#include "bot_stuff/de_inferno.sp"
#include "bot_stuff/de_overpass.sp"
#include "bot_stuff/de_train.sp"
#include "bot_stuff/de_nuke.sp"
#include "bot_stuff/de_vertigo.sp"
#include "bot_stuff/de_cache.sp"
#include "bot_stuff/de_ancient.sp"

public Plugin myinfo = 
{
	name = "BOT Stuff", 
	author = "manico", 
	description = "Improves bots and does other things.", 
	version = "1.0", 
	url = "http://steamcommunity.com/id/manico001"
};

public void OnPluginStart()
{
	HookEventEx("player_spawn", OnPlayerSpawn);
	HookEventEx("player_death", OnPlayerDeath);
	HookEventEx("round_start", OnRoundStart);
	HookEventEx("round_freeze_end", OnFreezetimeEnd);
	HookEventEx("round_end", OnRoundEnd);
	HookEventEx("weapon_zoom", OnWeaponZoom);
	HookEventEx("weapon_fire", OnWeaponFire);
	
	LoadSDK();
	LoadDetours();
	
	g_cvBotEcoLimit = FindConVar("bot_eco_limit");
	
	RegConsoleCmd("team_nip", Team_NiP);
	RegConsoleCmd("team_mibr", Team_MIBR);
	RegConsoleCmd("team_faze", Team_FaZe);
	RegConsoleCmd("team_astralis", Team_Astralis);
	RegConsoleCmd("team_1win", Team_1win);
	RegConsoleCmd("team_g2", Team_G2);
	RegConsoleCmd("team_fnatic", Team_fnatic);
	RegConsoleCmd("team_dynamo", Team_Dynamo);
	RegConsoleCmd("team_mouz", Team_mouz);
	RegConsoleCmd("team_tyloo", Team_TYLOO);
	RegConsoleCmd("team_eg", Team_EG);
	RegConsoleCmd("team_navi", Team_NaVi);
	RegConsoleCmd("team_liquid", Team_Liquid);
	RegConsoleCmd("team_ago", Team_AGO);
	RegConsoleCmd("team_ence", Team_ENCE);
	RegConsoleCmd("team_vitality", Team_Vitality);
	RegConsoleCmd("team_big", Team_BIG);
	RegConsoleCmd("team_furia", Team_FURIA);
	RegConsoleCmd("team_santos", Team_Santos);
	RegConsoleCmd("team_col", Team_coL);
	RegConsoleCmd("team_vici", Team_ViCi);
	RegConsoleCmd("team_forze", Team_forZe);
	RegConsoleCmd("team_sprout", Team_Sprout);
	RegConsoleCmd("team_heroic", Team_Heroic);
	RegConsoleCmd("team_intz", Team_INTZ);
	RegConsoleCmd("team_vp", Team_VP);
	RegConsoleCmd("team_apeks", Team_Apeks);
	RegConsoleCmd("team_rng", Team_Renegades);
	RegConsoleCmd("team_spirit", Team_Spirit);
	RegConsoleCmd("team_ldlc", Team_LDLC);
	RegConsoleCmd("team_gamerlegion", Team_GamerLegion);
	RegConsoleCmd("team_pd", Team_PD);
	RegConsoleCmd("team_havu", Team_HAVU);
	RegConsoleCmd("team_ecstatic", Team_ECSTATIC);
	RegConsoleCmd("team_godsent", Team_GODSENT);
	RegConsoleCmd("team_sj", Team_SJ);
	RegConsoleCmd("team_lions", Team_Lions);
	RegConsoleCmd("team_riders", Team_Riders);
	RegConsoleCmd("team_esuba", Team_eSuba);
	RegConsoleCmd("team_nexus", Team_Nexus);
	RegConsoleCmd("team_pact", Team_PACT);
	RegConsoleCmd("team_nemiga", Team_Nemiga);
	RegConsoleCmd("team_9ine", Team_9INE);
	RegConsoleCmd("team_gzg", Team_GZG);
	RegConsoleCmd("team_detona", Team_DETONA);
	RegConsoleCmd("team_infinity", Team_Infinity);
	RegConsoleCmd("team_isurus", Team_Isurus);
	RegConsoleCmd("team_pain", Team_paiN);
	RegConsoleCmd("team_sharks", Team_Sharks);
	RegConsoleCmd("team_one", Team_One);
	RegConsoleCmd("team_order", Team_ORDER);
	RegConsoleCmd("team_skade", Team_SKADE);
	RegConsoleCmd("team_singularity", Team_Singularity);
	RegConsoleCmd("team_offset", Team_OFFSET);
	RegConsoleCmd("team_nasr", Team_NASR);
	RegConsoleCmd("team_ecb", Team_ECB);
	RegConsoleCmd("team_bravado", Team_Bravado);
	RegConsoleCmd("team_furious", Team_Furious);
	RegConsoleCmd("team_rhyno", Team_Rhyno);
	RegConsoleCmd("team_gtz", Team_GTZ);
	RegConsoleCmd("team_eternal", Team_Eternal);
	RegConsoleCmd("team_k23", Team_K23);
	RegConsoleCmd("team_goliath", Team_Goliath);
	RegConsoleCmd("team_uol", Team_UOL);
	RegConsoleCmd("team_vertex", Team_VERTEX);
	RegConsoleCmd("team_ig", Team_IG);
	RegConsoleCmd("team_finest", Team_Finest);
	RegConsoleCmd("team_gambit", Team_Gambit);
	RegConsoleCmd("team_wisla", Team_Wisla);
	RegConsoleCmd("team_imperial", Team_Imperial);
	RegConsoleCmd("team_Unique", Team_Unique);
	RegConsoleCmd("team_izako", Team_Izako);
	RegConsoleCmd("team_atk", Team_ATK);
	RegConsoleCmd("team_fiend", Team_Fiend);
	RegConsoleCmd("team_wings", Team_Wings);
	RegConsoleCmd("team_lynn", Team_Lynn);
	RegConsoleCmd("team_triumph", Team_Triumph);
	RegConsoleCmd("team_fate", Team_FATE);
	RegConsoleCmd("team_og", Team_OG);
	RegConsoleCmd("team_blink", Team_BLINK);
	RegConsoleCmd("team_tricked", Team_Tricked);
	RegConsoleCmd("team_brute", Team_BRUTE);
	RegConsoleCmd("team_endpoint", Team_Endpoint);
	RegConsoleCmd("team_saw", Team_sAw);
	RegConsoleCmd("team_dig", Team_DIG);
	RegConsoleCmd("team_d13", Team_D13);
	RegConsoleCmd("team_divizon", Team_DIVIZON);
	RegConsoleCmd("team_lll", Team_LLL);
	RegConsoleCmd("team_kova", Team_KOVA);
	RegConsoleCmd("team_agf", Team_AGF);
	RegConsoleCmd("team_nlg", Team_NLG);
	RegConsoleCmd("team_lilmix", Team_Lilmix);
	RegConsoleCmd("team_ftw", Team_FTW);
	RegConsoleCmd("team_tigers", Team_Tigers);
	RegConsoleCmd("team_9z", Team_9z);
	RegConsoleCmd("team_sinners", Team_SINNERS);
	RegConsoleCmd("team_impact", Team_Impact);
	RegConsoleCmd("team_ern", Team_ERN);
	RegConsoleCmd("team_paradox", Team_Paradox);
	RegConsoleCmd("team_flames", Team_Flames);
	RegConsoleCmd("team_exploit", Team_eXploit);
	RegConsoleCmd("team_ep", Team_EP);
	RegConsoleCmd("team_hreds", Team_hREDS);
	RegConsoleCmd("team_lemondogs", Team_Lemondogs);
	RegConsoleCmd("team_havan", Team_Havan);
	RegConsoleCmd("team_sangal", Team_Sangal);
	RegConsoleCmd("team_ambush", Team_Ambush);
	RegConsoleCmd("team_dragons", Team_Dragons);
	RegConsoleCmd("team_keyd", Team_Keyd);
	RegConsoleCmd("team_supremacy", Team_Supremacy);
	RegConsoleCmd("team_x6tence", Team_x6tence);
	RegConsoleCmd("team_avez", Team_AVEZ);
	RegConsoleCmd("team_bp", Team_BP);
	RegConsoleCmd("team_anonymo", Team_Anonymo);
	RegConsoleCmd("team_honoris", Team_HONORIS);
	RegConsoleCmd("team_es", Team_ES);
	RegConsoleCmd("team_rbg", Team_RBG);
	RegConsoleCmd("team_dmnk", Team_DNMK);
	RegConsoleCmd("team_ination", Team_iNation);
	RegConsoleCmd("team_leisure", Team_LEISURE);
	RegConsoleCmd("team_bnb", Team_BNB);
	RegConsoleCmd("team_nation", Team_Nation);
	RegConsoleCmd("team_eriness", Team_Eriness);
	RegConsoleCmd("team_entropiq", Team_Entropiq);
	RegConsoleCmd("team_checkmate", Team_Checkmate);
	RegConsoleCmd("team_renewal", Team_Renewal);
	RegConsoleCmd("team_party", Team_Party);
	RegConsoleCmd("team_777", Team_777);
	RegConsoleCmd("team_CG", Team_CG);
	RegConsoleCmd("team_illuminar", Team_Illuminar);
	RegConsoleCmd("team_bluejays", Team_BLUEJAYS);
	RegConsoleCmd("team_eck", Team_ECK);
	RegConsoleCmd("team_conquer", Team_Conquer);
	RegConsoleCmd("team_avangar", Team_AVANGAR);
	RegConsoleCmd("team_sws", Team_SWS);
	RegConsoleCmd("team_leviatan", Team_Leviatan);
	RegConsoleCmd("team_hr", Team_HR);
	
}






public Action Team_NiP(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "LNZ");
		ServerCommand("bot_add_ct %s", "device");
		ServerCommand("bot_add_ct %s", "hampus");
		ServerCommand("bot_add_ct %s", "Plopski");
		ServerCommand("bot_add_ct %s", "REZ");
		ServerCommand("mp_teamlogo_1 nip");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "LNZ");
		ServerCommand("bot_add_t %s", "device");
		ServerCommand("bot_add_t %s", "hampus");
		ServerCommand("bot_add_t %s", "Plopski");
		ServerCommand("bot_add_t %s", "REZ");
		ServerCommand("mp_teamlogo_2 nip");
	}
	
	return Plugin_Handled;
}

public Action Team_MIBR(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "chelo");
		ServerCommand("bot_add_ct %s", "yel");
		ServerCommand("bot_add_ct %s", "shz");
		ServerCommand("bot_add_ct %s", "boltz");
		ServerCommand("bot_add_ct %s", "exit");
		ServerCommand("mp_teamlogo_1 mibr");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "chelo");
		ServerCommand("bot_add_t %s", "yel");
		ServerCommand("bot_add_t %s", "shz");
		ServerCommand("bot_add_t %s", "boltz");
		ServerCommand("bot_add_t %s", "exit");
		ServerCommand("mp_teamlogo_2 mibr");
	}
	
	return Plugin_Handled;
}

public Action Team_FaZe(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Twistzz");
		ServerCommand("bot_add_ct %s", "broky");
		ServerCommand("bot_add_ct %s", "karrigan");
		ServerCommand("bot_add_ct %s", "rain");
		ServerCommand("bot_add_ct %s", "olofmeister");
		ServerCommand("mp_teamlogo_1 faze");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Twistzz");
		ServerCommand("bot_add_t %s", "broky");
		ServerCommand("bot_add_t %s", "karrigan");
		ServerCommand("bot_add_t %s", "rain");
		ServerCommand("bot_add_t %s", "olofmeister");
		ServerCommand("mp_teamlogo_2 faze");
	}
	
	return Plugin_Handled;
}

public Action Team_Astralis(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "gla1ve");
		ServerCommand("bot_add_ct %s", "Lucky");
		ServerCommand("bot_add_ct %s", "Xyp9x");
		ServerCommand("bot_add_ct %s", "k0nfig");
		ServerCommand("bot_add_ct %s", "blameF");
		ServerCommand("mp_teamlogo_1 astr");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "gla1ve");
		ServerCommand("bot_add_t %s", "Lucky");
		ServerCommand("bot_add_t %s", "Xyp9x");
		ServerCommand("bot_add_t %s", "k0nfig");
		ServerCommand("bot_add_t %s", "blameF");
		ServerCommand("mp_teamlogo_2 astr");
	}
	
	return Plugin_Handled;
}

public Action Team_1win(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "glowiing");
		ServerCommand("bot_add_ct %s", "Ravenlot");
		ServerCommand("bot_add_ct %s", "TRAVIS");
		ServerCommand("bot_add_ct %s", "Polt");
		ServerCommand("bot_add_ct %s", "deko");
		ServerCommand("mp_teamlogo_1 1win");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "glowiing");
		ServerCommand("bot_add_t %s", "Ravenlot");
		ServerCommand("bot_add_t %s", "TRAVIS");
		ServerCommand("bot_add_t %s", "Polt");
		ServerCommand("bot_add_t %s", "deko");
		ServerCommand("mp_teamlogo_2 1win");
	}
	
	return Plugin_Handled;
}

public Action Team_G2(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "huNter-");
		ServerCommand("bot_add_ct %s", "AmaNEk");
		ServerCommand("bot_add_ct %s", "nexa");
		ServerCommand("bot_add_ct %s", "JaCkz");
		ServerCommand("bot_add_ct %s", "NiKo");
		ServerCommand("mp_teamlogo_1 g2");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "huNter-");
		ServerCommand("bot_add_t %s", "AmaNEk");
		ServerCommand("bot_add_t %s", "nexa");
		ServerCommand("bot_add_t %s", "JaCkz");
		ServerCommand("bot_add_t %s", "NiKo");
		ServerCommand("mp_teamlogo_2 g2");
	}
	
	return Plugin_Handled;
}

public Action Team_fnatic(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ALEX");
		ServerCommand("bot_add_ct %s", "smooya");
		ServerCommand("bot_add_ct %s", "KRIMZ");
		ServerCommand("bot_add_ct %s", "Brollan");
		ServerCommand("bot_add_ct %s", "mezii");
		ServerCommand("mp_teamlogo_1 fntc");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ALEX");
		ServerCommand("bot_add_t %s", "smooya");
		ServerCommand("bot_add_t %s", "KRIMZ");
		ServerCommand("bot_add_t %s", "Brollan");
		ServerCommand("bot_add_t %s", "mezii");
		ServerCommand("mp_teamlogo_2 fntc");
	}
	
	return Plugin_Handled;
}

public Action Team_Dynamo(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ZEDc");
		ServerCommand("bot_add_ct %s", "capseN");
		ServerCommand("bot_add_ct %s", "K1-FiDa");
		ServerCommand("bot_add_ct %s", "Valencio");
		ServerCommand("bot_add_ct %s", "nbqq");
		ServerCommand("mp_teamlogo_1 dyna");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ZEDc");
		ServerCommand("bot_add_t %s", "capseN");
		ServerCommand("bot_add_t %s", "K1-FiDa");
		ServerCommand("bot_add_t %s", "Valencio");
		ServerCommand("bot_add_t %s", "nbqq");
		ServerCommand("mp_teamlogo_2 dyna");
	}
	
	return Plugin_Handled;
}

public Action Team_mouz(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "dexter");
		ServerCommand("bot_add_ct %s", "acoR");
		ServerCommand("bot_add_ct %s", "Bymas");
		ServerCommand("bot_add_ct %s", "frozen");
		ServerCommand("bot_add_ct %s", "ropz");
		ServerCommand("mp_teamlogo_1 mouz");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "dexter");
		ServerCommand("bot_add_t %s", "acoR");
		ServerCommand("bot_add_t %s", "Bymas");
		ServerCommand("bot_add_t %s", "frozen");
		ServerCommand("bot_add_t %s", "ropz");
		ServerCommand("mp_teamlogo_2 mouz");
	}
	
	return Plugin_Handled;
}

public Action Team_TYLOO(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Summer");
		ServerCommand("bot_add_ct %s", "Attacker");
		ServerCommand("bot_add_ct %s", "SLOWLY");
		ServerCommand("bot_add_ct %s", "somebody");
		ServerCommand("bot_add_ct %s", "DANK1NG");
		ServerCommand("mp_teamlogo_1 tyl");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Summer");
		ServerCommand("bot_add_t %s", "Attacker");
		ServerCommand("bot_add_t %s", "SLOWLY");
		ServerCommand("bot_add_t %s", "somebody");
		ServerCommand("bot_add_t %s", "DANK1NG");
		ServerCommand("mp_teamlogo_2 tyl");
	}
	
	return Plugin_Handled;
}

public Action Team_EG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "stanislaw");
		ServerCommand("bot_add_ct %s", "CeRq");
		ServerCommand("bot_add_ct %s", "Brehze");
		ServerCommand("bot_add_ct %s", "oBo");
		ServerCommand("bot_add_ct %s", "MICHU");
		ServerCommand("mp_teamlogo_1 evl");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "stanislaw");
		ServerCommand("bot_add_t %s", "CeRq");
		ServerCommand("bot_add_t %s", "Brehze");
		ServerCommand("bot_add_t %s", "oBo");
		ServerCommand("bot_add_t %s", "MICHU");
		ServerCommand("mp_teamlogo_2 evl");
	}
	
	return Plugin_Handled;
}

public Action Team_NaVi(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "electronic");
		ServerCommand("bot_add_ct %s", "s1mple");
		ServerCommand("bot_add_ct %s", "B1T");
		ServerCommand("bot_add_ct %s", "Boombl4");
		ServerCommand("bot_add_ct %s", "Perfecto");
		ServerCommand("mp_teamlogo_1 navi");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "electronic");
		ServerCommand("bot_add_t %s", "s1mple");
		ServerCommand("bot_add_t %s", "B1T");
		ServerCommand("bot_add_t %s", "Boombl4");
		ServerCommand("bot_add_t %s", "Perfecto");
		ServerCommand("mp_teamlogo_2 navi");
	}
	
	return Plugin_Handled;
}

public Action Team_Liquid(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Stewie2K");
		ServerCommand("bot_add_ct %s", "FalleN");
		ServerCommand("bot_add_ct %s", "Grim");
		ServerCommand("bot_add_ct %s", "ELiGE");
		ServerCommand("bot_add_ct %s", "NAF");
		ServerCommand("mp_teamlogo_1 liq");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Stewie2K");
		ServerCommand("bot_add_t %s", "FalleN");
		ServerCommand("bot_add_t %s", "Grim");
		ServerCommand("bot_add_t %s", "ELiGE");
		ServerCommand("bot_add_t %s", "NAF");
		ServerCommand("mp_teamlogo_2 liq");
	}
	
	return Plugin_Handled;
}

public Action Team_AGO(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Furlan");
		ServerCommand("bot_add_ct %s", "mhL");
		ServerCommand("bot_add_ct %s", "kRaSnaL");
		ServerCommand("bot_add_ct %s", "F1KU");
		ServerCommand("bot_add_ct %s", "leman");
		ServerCommand("mp_teamlogo_1 ago");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Furlan");
		ServerCommand("bot_add_t %s", "mhL");
		ServerCommand("bot_add_t %s", "kRaSnaL");
		ServerCommand("bot_add_t %s", "F1KU");
		ServerCommand("bot_add_t %s", "leman");
		ServerCommand("mp_teamlogo_2 ago");
	}
	
	return Plugin_Handled;
}

public Action Team_ENCE(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Snappi");
		ServerCommand("bot_add_ct %s", "hades");
		ServerCommand("bot_add_ct %s", "Spinx");
		ServerCommand("bot_add_ct %s", "doto");
		ServerCommand("bot_add_ct %s", "dycha");
		ServerCommand("mp_teamlogo_1 ence");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Snappi");
		ServerCommand("bot_add_t %s", "hades");
		ServerCommand("bot_add_t %s", "Spinx");
		ServerCommand("bot_add_t %s", "doto");
		ServerCommand("bot_add_t %s", "dycha");
		ServerCommand("mp_teamlogo_2 ence");
	}
	
	return Plugin_Handled;
}

public Action Team_Vitality(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "shox");
		ServerCommand("bot_add_ct %s", "ZywOo");
		ServerCommand("bot_add_ct %s", "apEX");
		ServerCommand("bot_add_ct %s", "Kyojin");
		ServerCommand("bot_add_ct %s", "Misutaaa");
		ServerCommand("mp_teamlogo_1 vita");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "shox");
		ServerCommand("bot_add_t %s", "ZywOo");
		ServerCommand("bot_add_t %s", "apEX");
		ServerCommand("bot_add_t %s", "Kyojin");
		ServerCommand("bot_add_t %s", "Misutaaa");
		ServerCommand("mp_teamlogo_2 vita");
	}
	
	return Plugin_Handled;
}

public Action Team_BIG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "tiziaN");
		ServerCommand("bot_add_ct %s", "syrsoN");
		ServerCommand("bot_add_ct %s", "gade");
		ServerCommand("bot_add_ct %s", "tabseN");
		ServerCommand("bot_add_ct %s", "k1to");
		ServerCommand("mp_teamlogo_1 big");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "tiziaN");
		ServerCommand("bot_add_t %s", "syrsoN");
		ServerCommand("bot_add_t %s", "gade");
		ServerCommand("bot_add_t %s", "tabseN");
		ServerCommand("bot_add_t %s", "k1to");
		ServerCommand("mp_teamlogo_2 big");
	}
	
	return Plugin_Handled;
}

public Action Team_FURIA(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "yuurih");
		ServerCommand("bot_add_ct %s", "drop");
		ServerCommand("bot_add_ct %s", "VINI");
		ServerCommand("bot_add_ct %s", "KSCERATO");
		ServerCommand("bot_add_ct %s", "arT");
		ServerCommand("mp_teamlogo_1 furi");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "yuurih");
		ServerCommand("bot_add_t %s", "drop");
		ServerCommand("bot_add_t %s", "VINI");
		ServerCommand("bot_add_t %s", "KSCERATO");
		ServerCommand("bot_add_t %s", "arT");
		ServerCommand("mp_teamlogo_2 furi");
	}
	
	return Plugin_Handled;
}

public Action Team_Santos(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "jAPA");
		ServerCommand("bot_add_ct %s", "bsd");
		ServerCommand("bot_add_ct %s", "STRIKER");
		ServerCommand("bot_add_ct %s", "begod");
		ServerCommand("bot_add_ct %s", "DebornY");
		ServerCommand("mp_teamlogo_1 sant");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "jAPA");
		ServerCommand("bot_add_t %s", "bsd");
		ServerCommand("bot_add_t %s", "STRIKER");
		ServerCommand("bot_add_t %s", "begod");
		ServerCommand("bot_add_t %s", "DebornY");
		ServerCommand("mp_teamlogo_2 sant");
	}
	
	return Plugin_Handled;
}

public Action Team_coL(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "coldzera");
		ServerCommand("bot_add_ct %s", "poizon");
		ServerCommand("bot_add_ct %s", "jks");
		ServerCommand("bot_add_ct %s", "es3tag");
		ServerCommand("bot_add_ct %s", "blameF");
		ServerCommand("mp_teamlogo_1 col");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "coldzera");
		ServerCommand("bot_add_t %s", "poizon");
		ServerCommand("bot_add_t %s", "jks");
		ServerCommand("bot_add_t %s", "es3tag");
		ServerCommand("bot_add_t %s", "blameF");
		ServerCommand("mp_teamlogo_2 col");
	}
	
	return Plugin_Handled;
}

public Action Team_ViCi(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "zhokiNg");
		ServerCommand("bot_add_ct %s", "kaze");
		ServerCommand("bot_add_ct %s", "aumaN");
		ServerCommand("bot_add_ct %s", "JamYoung");
		ServerCommand("bot_add_ct %s", "advent");
		ServerCommand("mp_teamlogo_1 vici");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "zhokiNg");
		ServerCommand("bot_add_t %s", "kaze");
		ServerCommand("bot_add_t %s", "aumaN");
		ServerCommand("bot_add_t %s", "JamYoung");
		ServerCommand("bot_add_t %s", "advent");
		ServerCommand("mp_teamlogo_2 vici");
	}
	
	return Plugin_Handled;
}

public Action Team_forZe(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "KENSI");
		ServerCommand("bot_add_ct %s", "zorte");
		ServerCommand("bot_add_ct %s", "FL1T");
		ServerCommand("bot_add_ct %s", "shalfey");
		ServerCommand("bot_add_ct %s", "Jerry");
		ServerCommand("mp_teamlogo_1 forz");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "KENSI");
		ServerCommand("bot_add_t %s", "zorte");
		ServerCommand("bot_add_t %s", "FL1T");
		ServerCommand("bot_add_t %s", "shalfey");
		ServerCommand("bot_add_t %s", "Jerry");
		ServerCommand("mp_teamlogo_2 forz");
	}
	
	return Plugin_Handled;
}

public Action Team_Sprout(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "KEi");
		ServerCommand("bot_add_ct %s", "slaxz");
		ServerCommand("bot_add_ct %s", "Spiidi");
		ServerCommand("bot_add_ct %s", "faveN");
		ServerCommand("bot_add_ct %s", "raalz");
		ServerCommand("mp_teamlogo_1 spr");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "KEi");
		ServerCommand("bot_add_t %s", "slaxz");
		ServerCommand("bot_add_t %s", "Spiidi");
		ServerCommand("bot_add_t %s", "faveN");
		ServerCommand("bot_add_t %s", "raalz");
		ServerCommand("mp_teamlogo_2 spr");
	}
	
	return Plugin_Handled;
}

public Action Team_Heroic(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "TeSeS");
		ServerCommand("bot_add_ct %s", "cadiaN");
		ServerCommand("bot_add_ct %s", "sjuush");
		ServerCommand("bot_add_ct %s", "refrezh");
		ServerCommand("bot_add_ct %s", "stavn");
		ServerCommand("mp_teamlogo_1 hero");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "TeSeS");
		ServerCommand("bot_add_t %s", "cadiaN");
		ServerCommand("bot_add_t %s", "sjuush");
		ServerCommand("bot_add_t %s", "refrezh");
		ServerCommand("bot_add_t %s", "stavn");
		ServerCommand("mp_teamlogo_2 hero");
	}
	
	return Plugin_Handled;
}

public Action Team_INTZ(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "guZERA");
		ServerCommand("bot_add_ct %s", "paiva");
		ServerCommand("bot_add_ct %s", "dukka");
		ServerCommand("bot_add_ct %s", "paredao");
		ServerCommand("bot_add_ct %s", "DANVIET");
		ServerCommand("mp_teamlogo_1 intz");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "guZERA");
		ServerCommand("bot_add_t %s", "paiva");
		ServerCommand("bot_add_t %s", "dukka");
		ServerCommand("bot_add_t %s", "paredao");
		ServerCommand("bot_add_t %s", "DANVIET");
		ServerCommand("mp_teamlogo_2 intz");
	}
	
	return Plugin_Handled;
}

public Action Team_VP(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "YEKINDAR");
		ServerCommand("bot_add_ct %s", "Jame");
		ServerCommand("bot_add_ct %s", "qikert");
		ServerCommand("bot_add_ct %s", "SANJI");
		ServerCommand("bot_add_ct %s", "buster");
		ServerCommand("mp_teamlogo_1 vp");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "YEKINDAR");
		ServerCommand("bot_add_t %s", "Jame");
		ServerCommand("bot_add_t %s", "qikert");
		ServerCommand("bot_add_t %s", "SANJI");
		ServerCommand("bot_add_t %s", "buster");
		ServerCommand("mp_teamlogo_2 vp");
	}
	
	return Plugin_Handled;
}

public Action Team_Apeks(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "FREDDyFROG");
		ServerCommand("bot_add_ct %s", "dennis");
		ServerCommand("bot_add_ct %s", "Grus");
		ServerCommand("bot_add_ct %s", "Relaxa");
		ServerCommand("bot_add_ct %s", "AcilioN");
		ServerCommand("mp_teamlogo_1 ape");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "FREDDyFROG");
		ServerCommand("bot_add_t %s", "dennis");
		ServerCommand("bot_add_t %s", "Grus");
		ServerCommand("bot_add_t %s", "Relaxa");
		ServerCommand("bot_add_t %s", "AcilioN");
		ServerCommand("mp_teamlogo_2 ape");
	}
	
	return Plugin_Handled;
}

public Action Team_Renegades(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "INS");
		ServerCommand("bot_add_ct %s", "sico");
		ServerCommand("bot_add_ct %s", "aliStair");
		ServerCommand("bot_add_ct %s", "Hatz");
		ServerCommand("bot_add_ct %s", "malta");
		ServerCommand("mp_teamlogo_1 ren");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "INS");
		ServerCommand("bot_add_t %s", "sico");
		ServerCommand("bot_add_t %s", "aliStair");
		ServerCommand("bot_add_t %s", "Hatz");
		ServerCommand("bot_add_t %s", "malta");
		ServerCommand("mp_teamlogo_2 ren");
	}
	
	return Plugin_Handled;
}

public Action Team_Spirit(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "mir");
		ServerCommand("bot_add_ct %s", "degster");
		ServerCommand("bot_add_ct %s", "somedieyoung");
		ServerCommand("bot_add_ct %s", "chopper");
		ServerCommand("bot_add_ct %s", "magixx");
		ServerCommand("mp_teamlogo_1 spir");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "mir");
		ServerCommand("bot_add_t %s", "degster");
		ServerCommand("bot_add_t %s", "somedieyoung");
		ServerCommand("bot_add_t %s", "chopper");
		ServerCommand("bot_add_t %s", "magixx");
		ServerCommand("mp_teamlogo_2 spir");
	}
	
	return Plugin_Handled;
}

public Action Team_LDLC(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Maka");
		ServerCommand("bot_add_ct %s", "Lambert");
		ServerCommand("bot_add_ct %s", "hAdji");
		ServerCommand("bot_add_ct %s", "Keoz");
		ServerCommand("bot_add_ct %s", "SIXER");
		ServerCommand("mp_teamlogo_1 ldlc");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Maka");
		ServerCommand("bot_add_t %s", "Lambert");
		ServerCommand("bot_add_t %s", "hAdji");
		ServerCommand("bot_add_t %s", "Keoz");
		ServerCommand("bot_add_t %s", "SIXER");
		ServerCommand("mp_teamlogo_2 ldlc");
	}
	
	return Plugin_Handled;
}

public Action Team_GamerLegion(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "iM");
		ServerCommand("bot_add_ct %s", "eraa");
		ServerCommand("bot_add_ct %s", "Zero");
		ServerCommand("bot_add_ct %s", "RuStY");
		ServerCommand("bot_add_ct %s", "isak");
		ServerCommand("mp_teamlogo_1 glegion");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "iM");
		ServerCommand("bot_add_t %s", "eraa");
		ServerCommand("bot_add_t %s", "Zero");
		ServerCommand("bot_add_t %s", "RuStY");
		ServerCommand("bot_add_t %s", "isak");
		ServerCommand("mp_teamlogo_2 glegion");
	}
	
	return Plugin_Handled;
}

public Action Team_PD(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Patrick");
		ServerCommand("bot_add_ct %s", "striNg");
		ServerCommand("bot_add_ct %s", "polzerm");
		ServerCommand("bot_add_ct %s", "AHEAD-");
		ServerCommand("bot_add_ct %s", "nipam");
		ServerCommand("mp_teamlogo_1 playin");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Patrick");
		ServerCommand("bot_add_t %s", "striNg");
		ServerCommand("bot_add_t %s", "polzerm");
		ServerCommand("bot_add_t %s", "AHEAD-");
		ServerCommand("bot_add_t %s", "nipam");
		ServerCommand("mp_teamlogo_2 playin");
	}
	
	return Plugin_Handled;
}

public Action Team_HAVU(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ZOREE");
		ServerCommand("bot_add_ct %s", "sLowi");
		ServerCommand("bot_add_ct %s", "Aerial");
		ServerCommand("bot_add_ct %s", "xseveN");
		ServerCommand("bot_add_ct %s", "jemi");
		ServerCommand("mp_teamlogo_1 havu");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ZOREE");
		ServerCommand("bot_add_t %s", "sLowi");
		ServerCommand("bot_add_t %s", "Aerial");
		ServerCommand("bot_add_t %s", "xseveN");
		ServerCommand("bot_add_t %s", "jemi");
		ServerCommand("mp_teamlogo_2 havu");
	}
	
	return Plugin_Handled;
}

public Action Team_ECSTATIC(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "birdfromsky");
		ServerCommand("bot_add_ct %s", "WolfY");
		ServerCommand("bot_add_ct %s", "maNkz");
		ServerCommand("bot_add_ct %s", "FASHR");
		ServerCommand("bot_add_ct %s", "Daffu");
		ServerCommand("mp_teamlogo_1 ecs");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "birdfromsky");
		ServerCommand("bot_add_t %s", "WolfY");
		ServerCommand("bot_add_t %s", "maNkz");
		ServerCommand("bot_add_t %s", "FASHR");
		ServerCommand("bot_add_t %s", "Daffu");
		ServerCommand("mp_teamlogo_2 ecs");
	}
	
	return Plugin_Handled;
}

public Action Team_GODSENT(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "TACO");
		ServerCommand("bot_add_ct %s", "b4rtiN");
		ServerCommand("bot_add_ct %s", "felps");
		ServerCommand("bot_add_ct %s", "latto");
		ServerCommand("bot_add_ct %s", "dumau");
		ServerCommand("mp_teamlogo_1 god");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "TACO");
		ServerCommand("bot_add_t %s", "b4rtiN");
		ServerCommand("bot_add_t %s", "felps");
		ServerCommand("bot_add_t %s", "latto");
		ServerCommand("bot_add_t %s", "dumau");
		ServerCommand("mp_teamlogo_2 god");
	}
	
	return Plugin_Handled;
}

public Action Team_SJ(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "arvid");
		ServerCommand("bot_add_ct %s", "jelo");
		ServerCommand("bot_add_ct %s", "BONA");
		ServerCommand("bot_add_ct %s", "SADDYX");
		ServerCommand("bot_add_ct %s", "HENU");
		ServerCommand("mp_teamlogo_1 sjg");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "arvid");
		ServerCommand("bot_add_t %s", "jelo");
		ServerCommand("bot_add_t %s", "BONA");
		ServerCommand("bot_add_t %s", "SADDYX");
		ServerCommand("bot_add_t %s", "HENU");
		ServerCommand("mp_teamlogo_2 sjg");
	}
	
	return Plugin_Handled;
}

public Action Team_Lions(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "b0RUP");
		ServerCommand("bot_add_ct %s", "TMB");
		ServerCommand("bot_add_ct %s", "Woro2k");
		ServerCommand("bot_add_ct %s", "sausol");
		ServerCommand("bot_add_ct %s", "jL");
		ServerCommand("mp_teamlogo_1 lion");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "b0RUP");
		ServerCommand("bot_add_t %s", "TMB");
		ServerCommand("bot_add_t %s", "Woro2k");
		ServerCommand("bot_add_t %s", "sausol");
		ServerCommand("bot_add_t %s", "jL");
		ServerCommand("mp_teamlogo_2 lion");
	}
	
	return Plugin_Handled;
}

public Action Team_Riders(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "mopoz");
		ServerCommand("bot_add_ct %s", "SunPayus");
		ServerCommand("bot_add_ct %s", "DeathZz");
		ServerCommand("bot_add_ct %s", "\"alex*\"");
		ServerCommand("bot_add_ct %s", "dav1g");
		ServerCommand("mp_teamlogo_1 ride");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "mopoz");
		ServerCommand("bot_add_t %s", "SunPayus");
		ServerCommand("bot_add_t %s", "DeathZz");
		ServerCommand("bot_add_t %s", "\"alex*\"");
		ServerCommand("bot_add_t %s", "dav1g");
		ServerCommand("mp_teamlogo_2 ride");
	}
	
	return Plugin_Handled;
}

public Action Team_eSuba(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Pechyn");
		ServerCommand("bot_add_ct %s", "twistqt");
		ServerCommand("bot_add_ct %s", "sAvana1");
		ServerCommand("bot_add_ct %s", "blogg1s");
		ServerCommand("bot_add_ct %s", "luko");
		ServerCommand("mp_teamlogo_1 esu");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Pechyn");
		ServerCommand("bot_add_t %s", "twistqt");
		ServerCommand("bot_add_t %s", "sAvana1");
		ServerCommand("bot_add_t %s", "blogg1s");
		ServerCommand("bot_add_t %s", "luko");
		ServerCommand("mp_teamlogo_2 esu");
	}
	
	return Plugin_Handled;
}

public Action Team_Nexus(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "BTN");
		ServerCommand("bot_add_ct %s", "XELLOW");
		ServerCommand("bot_add_ct %s", "ragga");
		ServerCommand("bot_add_ct %s", "lauNX");
		ServerCommand("bot_add_ct %s", "renne");
		ServerCommand("mp_teamlogo_1 nex");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "BTN");
		ServerCommand("bot_add_t %s", "XELLOW");
		ServerCommand("bot_add_t %s", "ragga");
		ServerCommand("bot_add_t %s", "lauNX");
		ServerCommand("bot_add_t %s", "renne");
		ServerCommand("mp_teamlogo_2 nex");
	}
	
	return Plugin_Handled;
}

public Action Team_PACT(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Sobol");
		ServerCommand("bot_add_ct %s", "lunAtic");
		ServerCommand("bot_add_ct %s", "bnox");
		ServerCommand("bot_add_ct %s", "MINISE");
		ServerCommand("bot_add_ct %s", "reatz");
		ServerCommand("mp_teamlogo_1 pact");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Sobol");
		ServerCommand("bot_add_t %s", "lunAtic");
		ServerCommand("bot_add_t %s", "bnox");
		ServerCommand("bot_add_t %s", "MINISE");
		ServerCommand("bot_add_t %s", "reatz");
		ServerCommand("mp_teamlogo_2 pact");
	}
	
	return Plugin_Handled;
}

public Action Team_Nemiga(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "iDISBALANCE");
		ServerCommand("bot_add_ct %s", "mds");
		ServerCommand("bot_add_ct %s", "lollipop21k");
		ServerCommand("bot_add_ct %s", "Jyo");
		ServerCommand("bot_add_ct %s", "boX");
		ServerCommand("mp_teamlogo_1 nem");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "iDISBALANCE");
		ServerCommand("bot_add_t %s", "mds");
		ServerCommand("bot_add_t %s", "lollipop21k");
		ServerCommand("bot_add_t %s", "Jyo");
		ServerCommand("bot_add_t %s", "boX");
		ServerCommand("mp_teamlogo_2 nem");
	}
	
	return Plugin_Handled;
}

public Action Team_9INE(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "veniuz");
		ServerCommand("bot_add_ct %s", "heavy");
		ServerCommand("bot_add_ct %s", "LBNS");
		ServerCommand("bot_add_ct %s", "debo");
		ServerCommand("bot_add_ct %s", "bobeksde");
		ServerCommand("mp_teamlogo_1 9ine");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "veniuz");
		ServerCommand("bot_add_t %s", "heavy");
		ServerCommand("bot_add_t %s", "LBNS");
		ServerCommand("bot_add_t %s", "debo");
		ServerCommand("bot_add_t %s", "bobeksde");
		ServerCommand("mp_teamlogo_2 9ine");
	}
	
	return Plugin_Handled;
}

public Action Team_GZG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "guag");
		ServerCommand("bot_add_ct %s", "mizzy");
		ServerCommand("bot_add_ct %s", "2D");
		ServerCommand("bot_add_ct %s", "rekonz");
		ServerCommand("bot_add_ct %s", "nexar");
		ServerCommand("mp_teamlogo_1 gzg");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "guag");
		ServerCommand("bot_add_t %s", "mizzy");
		ServerCommand("bot_add_t %s", "2D");
		ServerCommand("bot_add_t %s", "rekonz");
		ServerCommand("bot_add_t %s", "nexar");
		ServerCommand("mp_teamlogo_2 gzg");
	}
	
	return Plugin_Handled;
}

public Action Team_DETONA(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "lux");
		ServerCommand("bot_add_ct %s", "phx");
		ServerCommand("bot_add_ct %s", "BobZ");
		ServerCommand("bot_add_ct %s", "keiz");
		ServerCommand("bot_add_ct %s", "NikoM");
		ServerCommand("mp_teamlogo_1 deto");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "lux");
		ServerCommand("bot_add_t %s", "phx");
		ServerCommand("bot_add_t %s", "BobZ");
		ServerCommand("bot_add_t %s", "keiz");
		ServerCommand("bot_add_t %s", "NikoM");
		ServerCommand("mp_teamlogo_2 deto");
	}
	
	return Plugin_Handled;
}

public Action Team_Infinity(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "k1Nky");
		ServerCommand("bot_add_ct %s", "pacman^v^");
		ServerCommand("bot_add_ct %s", "spamzzy");
		ServerCommand("bot_add_ct %s", "tor1towOw");
		ServerCommand("bot_add_ct %s", "points");
		ServerCommand("mp_teamlogo_1 infi");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "k1Nky");
		ServerCommand("bot_add_t %s", "pacman^v^");
		ServerCommand("bot_add_t %s", "spamzzy");
		ServerCommand("bot_add_t %s", "tor1towOw");
		ServerCommand("bot_add_t %s", "points");
		ServerCommand("mp_teamlogo_2 infi");
	}
	
	return Plugin_Handled;
}

public Action Team_Isurus(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "DeStiNy");
		ServerCommand("bot_add_ct %s", "Noktse");
		ServerCommand("bot_add_ct %s", "nython");
		ServerCommand("bot_add_ct %s", "decov9jse");
		ServerCommand("bot_add_ct %s", "ALLE");
		ServerCommand("mp_teamlogo_1 isu");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "DeStiNy");
		ServerCommand("bot_add_t %s", "Noktse");
		ServerCommand("bot_add_t %s", "nython");
		ServerCommand("bot_add_t %s", "decov9jse");
		ServerCommand("bot_add_t %s", "ALLE");
		ServerCommand("mp_teamlogo_2 isu");
	}
	
	return Plugin_Handled;
}

public Action Team_paiN(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "PKL");
		ServerCommand("bot_add_ct %s", "saffee");
		ServerCommand("bot_add_ct %s", "NEKIZ");
		ServerCommand("bot_add_ct %s", "biguzera");
		ServerCommand("bot_add_ct %s", "hardzao");
		ServerCommand("mp_teamlogo_1 pain");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "PKL");
		ServerCommand("bot_add_t %s", "saffee");
		ServerCommand("bot_add_t %s", "NEKIZ");
		ServerCommand("bot_add_t %s", "biguzera");
		ServerCommand("bot_add_t %s", "hardzao");
		ServerCommand("mp_teamlogo_2 pain");
	}
	
	return Plugin_Handled;
}

public Action Team_Sharks(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "realziN");
		ServerCommand("bot_add_ct %s", "jnt");
		ServerCommand("bot_add_ct %s", "Lucaozy");
		ServerCommand("bot_add_ct %s", "pancc");
		ServerCommand("bot_add_ct %s", "zevy");
		ServerCommand("mp_teamlogo_1 shrk");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "realziN");
		ServerCommand("bot_add_t %s", "jnt");
		ServerCommand("bot_add_t %s", "Lucaozy");
		ServerCommand("bot_add_t %s", "pancc");
		ServerCommand("bot_add_t %s", "zevy");
		ServerCommand("mp_teamlogo_2 shrk");
	}
	
	return Plugin_Handled;
}

public Action Team_One(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "prt");
		ServerCommand("bot_add_ct %s", "Maluk3");
		ServerCommand("bot_add_ct %s", "malbsMd");
		ServerCommand("bot_add_ct %s", "xns");
		ServerCommand("bot_add_ct %s", "pesadelo");
		ServerCommand("mp_teamlogo_1 tone");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "prt");
		ServerCommand("bot_add_t %s", "Maluk3");
		ServerCommand("bot_add_t %s", "malbsMd");
		ServerCommand("bot_add_t %s", "xns");
		ServerCommand("bot_add_t %s", "pesadelo");
		ServerCommand("mp_teamlogo_2 tone");
	}
	
	return Plugin_Handled;
}

public Action Team_ORDER(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "J1rah");
		ServerCommand("bot_add_ct %s", "Vexite");
		ServerCommand("bot_add_ct %s", "Rickeh");
		ServerCommand("bot_add_ct %s", "USTILO");
		ServerCommand("bot_add_ct %s", "Valiance");
		ServerCommand("mp_teamlogo_1 order");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "J1rah");
		ServerCommand("bot_add_t %s", "Vexite");
		ServerCommand("bot_add_t %s", "Rickeh");
		ServerCommand("bot_add_t %s", "USTILO");
		ServerCommand("bot_add_t %s", "Valiance");
		ServerCommand("mp_teamlogo_2 order");
	}
	
	return Plugin_Handled;
}

public Action Team_SKADE(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Duplicate");
		ServerCommand("bot_add_ct %s", "dennyslaw");
		ServerCommand("bot_add_ct %s", "KalubeR");
		ServerCommand("bot_add_ct %s", "Rainwaker");
		ServerCommand("bot_add_ct %s", "SHiPZ");
		ServerCommand("mp_teamlogo_1 ska");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Duplicate");
		ServerCommand("bot_add_t %s", "dennyslaw");
		ServerCommand("bot_add_t %s", "KalubeR");
		ServerCommand("bot_add_t %s", "Rainwaker");
		ServerCommand("bot_add_t %s", "SHiPZ");
		ServerCommand("mp_teamlogo_2 ska");
	}
	
	return Plugin_Handled;
}

public Action Team_Singularity(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "seized");
		ServerCommand("bot_add_ct %s", "GuardiaN");
		ServerCommand("bot_add_ct %s", "clax");
		ServerCommand("bot_add_ct %s", "Norwi");
		ServerCommand("bot_add_ct %s", "d1Ledez");
		ServerCommand("mp_teamlogo_1 sing");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "seized");
		ServerCommand("bot_add_t %s", "GuardiaN");
		ServerCommand("bot_add_t %s", "clax");
		ServerCommand("bot_add_t %s", "Norwi");
		ServerCommand("bot_add_t %s", "d1Ledez");
		ServerCommand("mp_teamlogo_2 sing");
	}
	
	return Plugin_Handled;
}

public Action Team_OFFSET(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "NOPEEj");
		ServerCommand("bot_add_ct %s", "EasTor");
		ServerCommand("bot_add_ct %s", "snapy");
		ServerCommand("bot_add_ct %s", "RIZZ");
		ServerCommand("bot_add_ct %s", "shellzi");
		ServerCommand("mp_teamlogo_1 offs");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "NOPEEj");
		ServerCommand("bot_add_t %s", "EasTor");
		ServerCommand("bot_add_t %s", "snapy");
		ServerCommand("bot_add_t %s", "RIZZ");
		ServerCommand("bot_add_t %s", "shellzi");
		ServerCommand("mp_teamlogo_2 offs");
	}
	
	return Plugin_Handled;
}

public Action Team_NASR(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Remind");
		ServerCommand("bot_add_ct %s", "REAL1ZE");
		ServerCommand("bot_add_ct %s", "keen");
		ServerCommand("bot_add_ct %s", "EiZAA");
		ServerCommand("bot_add_ct %s", "bibu");
		ServerCommand("mp_teamlogo_1 nasr");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Remind");
		ServerCommand("bot_add_t %s", "REAL1ZE");
		ServerCommand("bot_add_t %s", "keen");
		ServerCommand("bot_add_t %s", "EiZAA");
		ServerCommand("bot_add_t %s", "bibu");
		ServerCommand("mp_teamlogo_2 nasr");
	}
	
	return Plugin_Handled;
}

public Action Team_ECB(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "KaiR0N-");
		ServerCommand("bot_add_ct %s", "Stev0se");
		ServerCommand("bot_add_ct %s", "xicoz");
		ServerCommand("bot_add_ct %s", "Matty");
		ServerCommand("bot_add_ct %s", "n0tice");
		ServerCommand("mp_teamlogo_1 ecb");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "KaiR0N-");
		ServerCommand("bot_add_t %s", "Stev0se");
		ServerCommand("bot_add_t %s", "xicoz");
		ServerCommand("bot_add_t %s", "Matty");
		ServerCommand("bot_add_t %s", "n0tice");
		ServerCommand("mp_teamlogo_2 ecb");
	}
	
	return Plugin_Handled;
}

public Action Team_Bravado(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "TheM4N");
		ServerCommand("bot_add_ct %s", "SloWye");
		ServerCommand("bot_add_ct %s", "Wip3ouT");
		ServerCommand("bot_add_ct %s", "flexeeee");
		ServerCommand("bot_add_ct %s", ".exe");
		ServerCommand("mp_teamlogo_1 bravg");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "TheM4N");
		ServerCommand("bot_add_t %s", "SloWye");
		ServerCommand("bot_add_t %s", "Wip3ouT");
		ServerCommand("bot_add_t %s", "flexeeee");
		ServerCommand("bot_add_t %s", ".exe");
		ServerCommand("mp_teamlogo_2 bravg");
	}
	
	return Plugin_Handled;
}

public Action Team_Furious(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "abizz");
		ServerCommand("bot_add_ct %s", "Owen$inhoM");
		ServerCommand("bot_add_ct %s", "\"JonY BoY\"");
		ServerCommand("bot_add_ct %s", "nacho");
		ServerCommand("bot_add_ct %s", "meyern");
		ServerCommand("mp_teamlogo_1 furio");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "abizz");
		ServerCommand("bot_add_t %s", "Owen$inhoM");
		ServerCommand("bot_add_t %s", "\"JonY BoY\"");
		ServerCommand("bot_add_t %s", "nacho");
		ServerCommand("bot_add_t %s", "meyern");
		ServerCommand("mp_teamlogo_2 furio");
	}
	
	return Plugin_Handled;
}

public Action Team_Rhyno(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "DiTrip");
		ServerCommand("bot_add_ct %s", "psh");
		ServerCommand("bot_add_ct %s", "Icarus");
		ServerCommand("bot_add_ct %s", "sark");
		ServerCommand("bot_add_ct %s", "Jaepe");
		ServerCommand("mp_teamlogo_1 rhy");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "DiTrip");
		ServerCommand("bot_add_t %s", "psh");
		ServerCommand("bot_add_t %s", "Icarus");
		ServerCommand("bot_add_t %s", "sark");
		ServerCommand("bot_add_t %s", "Jaepe");
		ServerCommand("mp_teamlogo_2 rhy");
	}
	
	return Plugin_Handled;
}

public Action Team_GTZ(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "slaxx");
		ServerCommand("bot_add_ct %s", "Blastinho");
		ServerCommand("bot_add_ct %s", "StepA");
		ServerCommand("bot_add_ct %s", "adamS");
		ServerCommand("bot_add_ct %s", "mik");
		ServerCommand("mp_teamlogo_1 gtz");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "slaxx");
		ServerCommand("bot_add_t %s", "Blastinho");
		ServerCommand("bot_add_t %s", "StepA");
		ServerCommand("bot_add_t %s", "adamS");
		ServerCommand("bot_add_t %s", "mik");
		ServerCommand("mp_teamlogo_2 gtz");
	}
	
	return Plugin_Handled;
}

public Action Team_Eternal(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "XANTARES");
		ServerCommand("bot_add_ct %s", "woxic");
		ServerCommand("bot_add_ct %s", "Calyx");
		ServerCommand("bot_add_ct %s", "imoRR");
		ServerCommand("bot_add_ct %s", "xfl0ud");
		ServerCommand("mp_teamlogo_1 eter");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "XANTARES");
		ServerCommand("bot_add_t %s", "woxic");
		ServerCommand("bot_add_t %s", "Calyx");
		ServerCommand("bot_add_t %s", "imoRR");
		ServerCommand("bot_add_t %s", "xfl0ud");
		ServerCommand("mp_teamlogo_2 eter");
	}
	
	return Plugin_Handled;
}

public Action Team_K23(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "neaLaN");
		ServerCommand("bot_add_ct %s", "mou");
		ServerCommand("bot_add_ct %s", "n0rb3r7");
		ServerCommand("bot_add_ct %s", "fame");
		ServerCommand("bot_add_ct %s", "AdreN");
		ServerCommand("mp_teamlogo_1 k23");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "neaLaN");
		ServerCommand("bot_add_t %s", "mou");
		ServerCommand("bot_add_t %s", "n0rb3r7");
		ServerCommand("bot_add_t %s", "fame");
		ServerCommand("bot_add_t %s", "AdreN");
		ServerCommand("mp_teamlogo_2 k23");
	}
	
	return Plugin_Handled;
}

public Action Team_Goliath(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "massacRe");
		ServerCommand("bot_add_ct %s", "Dweezil");
		ServerCommand("bot_add_ct %s", "Triton");
		ServerCommand("bot_add_ct %s", "ELUSIVE");
		ServerCommand("bot_add_ct %s", "zox");
		ServerCommand("mp_teamlogo_1 gol");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "massacRe");
		ServerCommand("bot_add_t %s", "Dweezil");
		ServerCommand("bot_add_t %s", "Triton");
		ServerCommand("bot_add_t %s", "ELUSIVE");
		ServerCommand("bot_add_t %s", "zox");
		ServerCommand("mp_teamlogo_2 gol");
	}
	
	return Plugin_Handled;
}

public Action Team_UOL(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "crisby");
		ServerCommand("bot_add_ct %s", "Anhuin");
		ServerCommand("bot_add_ct %s", "HadeZ");
		ServerCommand("bot_add_ct %s", "Python");
		ServerCommand("bot_add_ct %s", "P4TriCK");
		ServerCommand("mp_teamlogo_1 uni");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "crisby");
		ServerCommand("bot_add_t %s", "Anhuin");
		ServerCommand("bot_add_t %s", "HadeZ");
		ServerCommand("bot_add_t %s", "Python");
		ServerCommand("bot_add_t %s", "P4TriCK");
		ServerCommand("mp_teamlogo_2 uni");
	}
	
	return Plugin_Handled;
}

public Action Team_VERTEX(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "pz");
		ServerCommand("bot_add_ct %s", "BRACE");
		ServerCommand("bot_add_ct %s", "apocdud");
		ServerCommand("bot_add_ct %s", "ADDICT");
		ServerCommand("bot_add_ct %s", "Roflko");
		ServerCommand("mp_teamlogo_1 vert");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "pz");
		ServerCommand("bot_add_t %s", "BRACE");
		ServerCommand("bot_add_t %s", "apocdud");
		ServerCommand("bot_add_t %s", "ADDICT");
		ServerCommand("bot_add_t %s", "Roflko");
		ServerCommand("mp_teamlogo_2 vert");
	}
	
	return Plugin_Handled;
}

public Action Team_IG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "bottle");
		ServerCommand("bot_add_ct %s", "DeStRoYeR");
		ServerCommand("bot_add_ct %s", "flying");
		ServerCommand("bot_add_ct %s", "Viva");
		ServerCommand("bot_add_ct %s", "rage");
		ServerCommand("mp_teamlogo_1 ig");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "bottle");
		ServerCommand("bot_add_t %s", "DeStRoYeR");
		ServerCommand("bot_add_t %s", "flying");
		ServerCommand("bot_add_t %s", "Viva");
		ServerCommand("bot_add_t %s", "rage");
		ServerCommand("mp_teamlogo_2 ig");
	}
	
	return Plugin_Handled;
}

public Action Team_Finest(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "mar");
		ServerCommand("bot_add_ct %s", "anarkez");
		ServerCommand("bot_add_ct %s", "kreaz");
		ServerCommand("bot_add_ct %s", "robiin");
		ServerCommand("bot_add_ct %s", "shokz");
		ServerCommand("mp_teamlogo_1 fine");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "mar");
		ServerCommand("bot_add_t %s", "anarkez");
		ServerCommand("bot_add_t %s", "kreaz");
		ServerCommand("bot_add_t %s", "robiin");
		ServerCommand("bot_add_t %s", "shokz");
		ServerCommand("mp_teamlogo_2 fine");
	}
	
	return Plugin_Handled;
}

public Action Team_Gambit(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "nafany");
		ServerCommand("bot_add_ct %s", "sh1ro");
		ServerCommand("bot_add_ct %s", "interz");
		ServerCommand("bot_add_ct %s", "Ax1Le");
		ServerCommand("bot_add_ct %s", "Hobbit");
		ServerCommand("mp_teamlogo_1 gamb");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "nafany");
		ServerCommand("bot_add_t %s", "sh1ro");
		ServerCommand("bot_add_t %s", "interz");
		ServerCommand("bot_add_t %s", "Ax1Le");
		ServerCommand("bot_add_t %s", "Hobbit");
		ServerCommand("mp_teamlogo_2 gamb");
	}
	
	return Plugin_Handled;
}

public Action Team_Wisla(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "mynio");
		ServerCommand("bot_add_ct %s", "SZPERO");
		ServerCommand("bot_add_ct %s", "Goofy");
		ServerCommand("bot_add_ct %s", "phr");
		ServerCommand("bot_add_ct %s", "jedqr");
		ServerCommand("mp_teamlogo_1 wisla");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "mynio");
		ServerCommand("bot_add_t %s", "SZPERO");
		ServerCommand("bot_add_t %s", "Goofy");
		ServerCommand("bot_add_t %s", "phr");
		ServerCommand("bot_add_t %s", "jedqr");
		ServerCommand("mp_teamlogo_2 wisla");
	}
	
	return Plugin_Handled;
}

public Action Team_Imperial(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "zqk");
		ServerCommand("bot_add_ct %s", "horvy");
		ServerCommand("bot_add_ct %s", "ckzao");
		ServerCommand("bot_add_ct %s", "f4stzin");
		ServerCommand("bot_add_ct %s", "SHOOWTiME");
		ServerCommand("mp_teamlogo_1 imp");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "zqk");
		ServerCommand("bot_add_t %s", "horvy");
		ServerCommand("bot_add_t %s", "ckzao");
		ServerCommand("bot_add_t %s", "f4stzin");
		ServerCommand("bot_add_t %s", "SHOOWTiME");
		ServerCommand("mp_teamlogo_2 imp");
	}
	
	return Plugin_Handled;
}

public Action Team_Unique(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "sorrow");
		ServerCommand("bot_add_ct %s", "smiley");
		ServerCommand("bot_add_ct %s", "w1nt3r");
		ServerCommand("bot_add_ct %s", "icem4N");
		ServerCommand("bot_add_ct %s", "dukefissura");
		ServerCommand("mp_teamlogo_1 uniq");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "sorrow");
		ServerCommand("bot_add_t %s", "smiley");
		ServerCommand("bot_add_t %s", "w1nt3r");
		ServerCommand("bot_add_t %s", "icem4N");
		ServerCommand("bot_add_t %s", "dukefissura");
		ServerCommand("mp_teamlogo_2 uniq");
	}
	
	return Plugin_Handled;
}

public Action Team_Izako(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "byali");
		ServerCommand("bot_add_ct %s", "STOMP");
		ServerCommand("bot_add_ct %s", "Vegi");
		ServerCommand("bot_add_ct %s", "TOAO");
		ServerCommand("bot_add_ct %s", "Enzo");
		ServerCommand("mp_teamlogo_1 izak");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "byali");
		ServerCommand("bot_add_t %s", "STOMP");
		ServerCommand("bot_add_t %s", "Vegi");
		ServerCommand("bot_add_t %s", "TOAO");
		ServerCommand("bot_add_t %s", "Enzo");
		ServerCommand("mp_teamlogo_2 izak");
	}
	
	return Plugin_Handled;
}

public Action Team_ATK(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Minus");
		ServerCommand("bot_add_ct %s", "MisteM");
		ServerCommand("bot_add_ct %s", "motm");
		ServerCommand("bot_add_ct %s", "Fadey");
		ServerCommand("bot_add_ct %s", "mango");
		ServerCommand("mp_teamlogo_1 atk");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Minus");
		ServerCommand("bot_add_t %s", "MisteM");
		ServerCommand("bot_add_t %s", "motm");
		ServerCommand("bot_add_t %s", "Fadey");
		ServerCommand("bot_add_t %s", "mango");
		ServerCommand("mp_teamlogo_2 atk");
	}
	
	return Plugin_Handled;
}

public Action Team_Fiend(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "dream3r");
		ServerCommand("bot_add_ct %s", "bubble");
		ServerCommand("bot_add_ct %s", "v1c7oR");
		ServerCommand("bot_add_ct %s", "h4rn");
		ServerCommand("bot_add_ct %s", "REDSTAR");
		ServerCommand("mp_teamlogo_1 fiend");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "dream3r");
		ServerCommand("bot_add_t %s", "bubble");
		ServerCommand("bot_add_t %s", "v1c7oR");
		ServerCommand("bot_add_t %s", "h4rn");
		ServerCommand("bot_add_t %s", "REDSTAR");
		ServerCommand("mp_teamlogo_2 fiend");
	}
	
	return Plugin_Handled;
}

public Action Team_Wings(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ChildKing");
		ServerCommand("bot_add_ct %s", "lan");
		ServerCommand("bot_add_ct %s", "MarT1n");
		ServerCommand("bot_add_ct %s", "DD");
		ServerCommand("bot_add_ct %s", "gas");
		ServerCommand("mp_teamlogo_1 wings");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ChildKing");
		ServerCommand("bot_add_t %s", "lan");
		ServerCommand("bot_add_t %s", "MarT1n");
		ServerCommand("bot_add_t %s", "DD");
		ServerCommand("bot_add_t %s", "gas");
		ServerCommand("mp_teamlogo_2 wings");
	}
	
	return Plugin_Handled;
}

public Action Team_Lynn(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "westmelon");
		ServerCommand("bot_add_ct %s", "z4kr");
		ServerCommand("bot_add_ct %s", "Kayo");
		ServerCommand("bot_add_ct %s", "EXPRO");
		ServerCommand("bot_add_ct %s", "B1NGO");
		ServerCommand("mp_teamlogo_1 lynn");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "westmelon");
		ServerCommand("bot_add_t %s", "z4kr");
		ServerCommand("bot_add_t %s", "Kayo");
		ServerCommand("bot_add_t %s", "EXPRO");
		ServerCommand("bot_add_t %s", "B1NGO");
		ServerCommand("mp_teamlogo_2 lynn");
	}
	
	return Plugin_Handled;
}

public Action Team_Triumph(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "RZU");
		ServerCommand("bot_add_ct %s", "grape");
		ServerCommand("bot_add_ct %s", "cxzi");
		ServerCommand("bot_add_ct %s", "viz");
		ServerCommand("bot_add_ct %s", "xCeeD");
		ServerCommand("mp_teamlogo_1 tri");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "RZU");
		ServerCommand("bot_add_t %s", "grape");
		ServerCommand("bot_add_t %s", "cxzi");
		ServerCommand("bot_add_t %s", "viz");
		ServerCommand("bot_add_t %s", "xCeeD");
		ServerCommand("mp_teamlogo_2 tri");
	}
	
	return Plugin_Handled;
}

public Action Team_FATE(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "rafftu");
		ServerCommand("bot_add_ct %s", "Patrick--");
		ServerCommand("bot_add_ct %s", "hybrid");
		ServerCommand("bot_add_ct %s", "shaiK");
		ServerCommand("bot_add_ct %s", "niki1");
		ServerCommand("mp_teamlogo_1 fate");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "rafftu");
		ServerCommand("bot_add_t %s", "Patrick--");
		ServerCommand("bot_add_t %s", "hybrid");
		ServerCommand("bot_add_t %s", "shaiK");
		ServerCommand("bot_add_t %s", "niki1");
		ServerCommand("mp_teamlogo_2 fate");
	}
	
	return Plugin_Handled;
}

public Action Team_OG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "nikozan");
		ServerCommand("bot_add_ct %s", "mantuu");
		ServerCommand("bot_add_ct %s", "Aleksib");
		ServerCommand("bot_add_ct %s", "valde");
		ServerCommand("bot_add_ct %s", "flameZ");
		ServerCommand("mp_teamlogo_1 og");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "nikozan");
		ServerCommand("bot_add_t %s", "mantuu");
		ServerCommand("bot_add_t %s", "Aleksib");
		ServerCommand("bot_add_t %s", "valde");
		ServerCommand("bot_add_t %s", "flameZ");
		ServerCommand("mp_teamlogo_2 og");
	}
	
	return Plugin_Handled;
}

public Action Team_BLINK(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "juanflatroo");
		ServerCommand("bot_add_ct %s", "SENER1");
		ServerCommand("bot_add_ct %s", "sinnopsyy");
		ServerCommand("bot_add_ct %s", "gxx-");
		ServerCommand("bot_add_ct %s", "rigoN");
		ServerCommand("mp_teamlogo_1 blink");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "juanflatroo");
		ServerCommand("bot_add_t %s", "SENER1");
		ServerCommand("bot_add_t %s", "sinnopsyy");
		ServerCommand("bot_add_t %s", "gxx-");
		ServerCommand("bot_add_t %s", "rigoN");
		ServerCommand("mp_teamlogo_2 blink");
	}
	
	return Plugin_Handled;
}

public Action Team_Tricked(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "kiR");
		ServerCommand("bot_add_ct %s", "kwezz");
		ServerCommand("bot_add_ct %s", "larsen");
		ServerCommand("bot_add_ct %s", "jekuzih");
		ServerCommand("bot_add_ct %s", "PR1mE");
		ServerCommand("mp_teamlogo_1 trick");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "kiR");
		ServerCommand("bot_add_t %s", "kwezz");
		ServerCommand("bot_add_t %s", "larsen");
		ServerCommand("bot_add_t %s", "jekuzih");
		ServerCommand("bot_add_t %s", "PR1mE");
		ServerCommand("mp_teamlogo_2 trick");
	}
	
	return Plugin_Handled;
}

public Action Team_BRUTE(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Crazyy");
		ServerCommand("bot_add_ct %s", "KWERTZZ");
		ServerCommand("bot_add_ct %s", "Adejis");
		ServerCommand("bot_add_ct %s", "MATYS");
		ServerCommand("bot_add_ct %s", "EYO");
		ServerCommand("mp_teamlogo_1 brut");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Crazyy");
		ServerCommand("bot_add_t %s", "KWERTZZ");
		ServerCommand("bot_add_t %s", "Adejis");
		ServerCommand("bot_add_t %s", "MATYS");
		ServerCommand("bot_add_t %s", "EYO");
		ServerCommand("mp_teamlogo_2 brut");
	}
	
	return Plugin_Handled;
}

public Action Team_Endpoint(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Surreal");
		ServerCommand("bot_add_ct %s", "CRUC1AL");
		ServerCommand("bot_add_ct %s", "MiGHTYMAX");
		ServerCommand("bot_add_ct %s", "BOROS");
		ServerCommand("bot_add_ct %s", "Nertz");
		ServerCommand("mp_teamlogo_1 endp");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Surreal");
		ServerCommand("bot_add_t %s", "CRUC1AL");
		ServerCommand("bot_add_t %s", "MiGHTYMAX");
		ServerCommand("bot_add_t %s", "BOROS");
		ServerCommand("bot_add_t %s", "Nertz");
		ServerCommand("mp_teamlogo_2 endp");
	}
	
	return Plugin_Handled;
}

public Action Team_sAw(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "arki");
		ServerCommand("bot_add_ct %s", "stadodo");
		ServerCommand("bot_add_ct %s", "JUST");
		ServerCommand("bot_add_ct %s", "MUTiRiS");
		ServerCommand("bot_add_ct %s", "rmn");
		ServerCommand("mp_teamlogo_1 saw");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "arki");
		ServerCommand("bot_add_t %s", "stadodo");
		ServerCommand("bot_add_t %s", "JUST");
		ServerCommand("bot_add_t %s", "MUTiRiS");
		ServerCommand("bot_add_t %s", "rmn");
		ServerCommand("mp_teamlogo_2 saw");
	}
	
	return Plugin_Handled;
}

public Action Team_DIG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Lekr0");
		ServerCommand("bot_add_ct %s", "hallzerk");
		ServerCommand("bot_add_ct %s", "f0rest");
		ServerCommand("bot_add_ct %s", "friberg");
		ServerCommand("bot_add_ct %s", "HEAP");
		ServerCommand("mp_teamlogo_1 dign");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Lekr0");
		ServerCommand("bot_add_t %s", "hallzerk");
		ServerCommand("bot_add_t %s", "f0rest");
		ServerCommand("bot_add_t %s", "friberg");
		ServerCommand("bot_add_t %s", "HEAP");
		ServerCommand("mp_teamlogo_2 dign");
	}
	
	return Plugin_Handled;
}

public Action Team_D13(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "tamir");
		ServerCommand("bot_add_ct %s", "xerolte");
		ServerCommand("bot_add_ct %s", "shinobi");
		ServerCommand("bot_add_ct %s", "yAmi");
		ServerCommand("bot_add_ct %s", "Annihilation");
		ServerCommand("mp_teamlogo_1 d13");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "tamir");
		ServerCommand("bot_add_t %s", "xerolte");
		ServerCommand("bot_add_t %s", "shinobi");
		ServerCommand("bot_add_t %s", "yAmi");
		ServerCommand("bot_add_t %s", "Annihilation");
		ServerCommand("mp_teamlogo_2 d13");
	}
	
	return Plugin_Handled;
}

public Action Team_DIVIZON(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "farmaG");
		ServerCommand("bot_add_ct %s", "Sw1ft");
		ServerCommand("bot_add_ct %s", "Cl34v3rs");
		ServerCommand("bot_add_ct %s", "ChLo");
		ServerCommand("bot_add_ct %s", "Spexy");
		ServerCommand("mp_teamlogo_1 divi");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "farmaG");
		ServerCommand("bot_add_t %s", "Sw1ft");
		ServerCommand("bot_add_t %s", "Cl34v3rs");
		ServerCommand("bot_add_t %s", "ChLo");
		ServerCommand("bot_add_t %s", "Spexy");
		ServerCommand("mp_teamlogo_2 divi");
	}
	
	return Plugin_Handled;
}

public Action Team_LLL(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Q-Q");
		ServerCommand("bot_add_ct %s", "shield");
		ServerCommand("bot_add_ct %s", "Rezst");
		ServerCommand("bot_add_ct %s", "Nexius");
		ServerCommand("bot_add_ct %s", "MaximN");
		ServerCommand("mp_teamlogo_1 lll");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Q-Q");
		ServerCommand("bot_add_t %s", "shield");
		ServerCommand("bot_add_t %s", "Rezst");
		ServerCommand("bot_add_t %s", "Nexius");
		ServerCommand("bot_add_t %s", "MaximN");
		ServerCommand("mp_teamlogo_2 lll");
	}
	
	return Plugin_Handled;
}

public Action Team_KOVA(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "zks");
		ServerCommand("bot_add_ct %s", "spargo");
		ServerCommand("bot_add_ct %s", "uli");
		ServerCommand("bot_add_ct %s", "airax");
		ServerCommand("bot_add_ct %s", "Twixie");
		ServerCommand("mp_teamlogo_1 kova");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "zks");
		ServerCommand("bot_add_t %s", "spargo");
		ServerCommand("bot_add_t %s", "uli");
		ServerCommand("bot_add_t %s", "airax");
		ServerCommand("bot_add_t %s", "Twixie");
		ServerCommand("mp_teamlogo_2 kova");
	}
	
	return Plugin_Handled;
}

public Action Team_AGF(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Buzz");
		ServerCommand("bot_add_ct %s", "kristou");
		ServerCommand("bot_add_ct %s", "cajunb");
		ServerCommand("bot_add_ct %s", "Cabbi");
		ServerCommand("bot_add_ct %s", "Nodios");
		ServerCommand("mp_teamlogo_1 agf");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Buzz");
		ServerCommand("bot_add_t %s", "kristou");
		ServerCommand("bot_add_t %s", "cajunb");
		ServerCommand("bot_add_t %s", "Cabbi");
		ServerCommand("bot_add_t %s", "Nodios");
		ServerCommand("mp_teamlogo_2 agf");
	}
	
	return Plugin_Handled;
}

public Action Team_NLG(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "pdy");
		ServerCommand("bot_add_ct %s", "red");
		ServerCommand("bot_add_ct %s", "xenn");
		ServerCommand("bot_add_ct %s", "s1n");
		ServerCommand("bot_add_ct %s", "kyuubii");
		ServerCommand("mp_teamlogo_1 nlg");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "pdy");
		ServerCommand("bot_add_t %s", "red");
		ServerCommand("bot_add_t %s", "xenn");
		ServerCommand("bot_add_t %s", "s1n");
		ServerCommand("bot_add_t %s", "kyuubii");
		ServerCommand("mp_teamlogo_2 nlg");
	}
	
	return Plugin_Handled;
}

public Action Team_Lilmix(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "quix");
		ServerCommand("bot_add_ct %s", "b0denmaster");
		ServerCommand("bot_add_ct %s", "bq");
		ServerCommand("bot_add_ct %s", "hns");
		ServerCommand("bot_add_ct %s", "freddyyyw");
		ServerCommand("mp_teamlogo_1 lil");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "quix");
		ServerCommand("bot_add_t %s", "b0denmaster");
		ServerCommand("bot_add_t %s", "bq");
		ServerCommand("bot_add_t %s", "hns");
		ServerCommand("bot_add_t %s", "freddyyyw");
		ServerCommand("mp_teamlogo_2 lil");
	}
	
	return Plugin_Handled;
}

public Action Team_FTW(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "NABOWOW");
		ServerCommand("bot_add_ct %s", "ewjerkz");
		ServerCommand("bot_add_ct %s", "DDias");
		ServerCommand("bot_add_ct %s", "Lr0z1n");
		ServerCommand("bot_add_ct %s", "arrozdoce");
		ServerCommand("mp_teamlogo_1 ftw");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "NABOWOW");
		ServerCommand("bot_add_t %s", "ewjerkz");
		ServerCommand("bot_add_t %s", "DDias");
		ServerCommand("bot_add_t %s", "Lr0z1n");
		ServerCommand("bot_add_t %s", "arrozdoce");
		ServerCommand("mp_teamlogo_2 ftw");
	}
	
	return Plugin_Handled;
}

public Action Team_Tigers(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Aralio");
		ServerCommand("bot_add_ct %s", "Feki");
		ServerCommand("bot_add_ct %s", "outex");
		ServerCommand("bot_add_ct %s", "heikkoL");
		ServerCommand("bot_add_ct %s", "creZe");
		ServerCommand("mp_teamlogo_1 tigers");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Aralio");
		ServerCommand("bot_add_t %s", "Feki");
		ServerCommand("bot_add_t %s", "outex");
		ServerCommand("bot_add_t %s", "heikkoL");
		ServerCommand("bot_add_t %s", "creZe");
		ServerCommand("mp_teamlogo_2 tigers");
	}
	
	return Plugin_Handled;
}

public Action Team_9z(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "dgt");
		ServerCommand("bot_add_ct %s", "try");
		ServerCommand("bot_add_ct %s", "maxujas");
		ServerCommand("bot_add_ct %s", "bit");
		ServerCommand("bot_add_ct %s", "rox");
		ServerCommand("mp_teamlogo_1 9z");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "dgt");
		ServerCommand("bot_add_t %s", "try");
		ServerCommand("bot_add_t %s", "maxujas");
		ServerCommand("bot_add_t %s", "bit");
		ServerCommand("bot_add_t %s", "rox");
		ServerCommand("mp_teamlogo_2 9z");
	}
	
	return Plugin_Handled;
}

public Action Team_SINNERS(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ZEDKO");
		ServerCommand("bot_add_ct %s", "oskar");
		ServerCommand("bot_add_ct %s", "SHOCK");
		ServerCommand("bot_add_ct %s", "beastik");
		ServerCommand("bot_add_ct %s", "NEOFRAG");
		ServerCommand("mp_teamlogo_1 sinn");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ZEDKO");
		ServerCommand("bot_add_t %s", "oskar");
		ServerCommand("bot_add_t %s", "SHOCK");
		ServerCommand("bot_add_t %s", "beastik");
		ServerCommand("bot_add_t %s", "NEOFRAG");
		ServerCommand("mp_teamlogo_2 sinn");
	}
	
	return Plugin_Handled;
}

public Action Team_Impact(int client, int iArgs)
{
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "DaneJoris");
		ServerCommand("bot_add_ct %s", "JoJo");
		ServerCommand("bot_add_ct %s", "hate");
		ServerCommand("bot_add_ct %s", "AJaxz");
		ServerCommand("bot_add_ct %s", "insane");
		ServerCommand("mp_teamlogo_1 impa");
	}
	
	if (strcmp(arg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "DaneJoris");
		ServerCommand("bot_add_t %s", "JoJo");
		ServerCommand("bot_add_t %s", "hate");
		ServerCommand("bot_add_t %s", "AJaxz");
		ServerCommand("bot_add_t %s", "insane");
		ServerCommand("mp_teamlogo_2 impa");
	}
	
	return Plugin_Handled;
}

public Action Team_ERN(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "j1NZO");
		ServerCommand("bot_add_ct %s", "sesL");
		ServerCommand("bot_add_ct %s", "ADR1AN");
		ServerCommand("bot_add_ct %s", "mvN");
		ServerCommand("bot_add_ct %s", "sehza");
		ServerCommand("mp_teamlogo_1 ern");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "j1NZO");
		ServerCommand("bot_add_t %s", "sesL");
		ServerCommand("bot_add_t %s", "ADR1AN");
		ServerCommand("bot_add_t %s", "mvN");
		ServerCommand("bot_add_t %s", "sehza");
		ServerCommand("mp_teamlogo_2 ern");
	}
	
	return Plugin_Handled;
}

public Action Team_Paradox(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "DannyG");
		ServerCommand("bot_add_ct %s", "nettik");
		ServerCommand("bot_add_ct %s", "chelleos");
		ServerCommand("bot_add_ct %s", "asap");
		ServerCommand("bot_add_ct %s", "dangeR");
		ServerCommand("mp_teamlogo_1 para");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "DannyG");
		ServerCommand("bot_add_t %s", "nettik");
		ServerCommand("bot_add_t %s", "chelleos");
		ServerCommand("bot_add_t %s", "asap");
		ServerCommand("bot_add_t %s", "dangeR");
		ServerCommand("mp_teamlogo_2 para");
	}
	
	return Plugin_Handled;
}

public Action Team_Flames(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "roeJ");
		ServerCommand("bot_add_ct %s", "nicoodoz");
		ServerCommand("bot_add_ct %s", "HooXi");
		ServerCommand("bot_add_ct %s", "Jabbi");
		ServerCommand("bot_add_ct %s", "Zyphon");
		ServerCommand("mp_teamlogo_1 cope");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "roeJ");
		ServerCommand("bot_add_t %s", "nicoodoz");
		ServerCommand("bot_add_t %s", "HooXi");
		ServerCommand("bot_add_t %s", "Jabbi");
		ServerCommand("bot_add_t %s", "Zyphon");
		ServerCommand("mp_teamlogo_2 cope");
	}
	
	return Plugin_Handled;
}

public Action Team_eXploit(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "BLOODZ");
		ServerCommand("bot_add_ct %s", "obj");
		ServerCommand("bot_add_ct %s", "Ag1l");
		ServerCommand("bot_add_ct %s", "pr");
		ServerCommand("bot_add_ct %s", "renatoohaxx");
		ServerCommand("mp_teamlogo_1 exp");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "BLOODZ");
		ServerCommand("bot_add_t %s", "obj");
		ServerCommand("bot_add_t %s", "Ag1l");
		ServerCommand("bot_add_t %s", "pr");
		ServerCommand("bot_add_t %s", "renatoohaxx");
		ServerCommand("mp_teamlogo_2 exp");
	}
	
	return Plugin_Handled;
}

public Action Team_EP(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "\"The eLiVe\"");
		ServerCommand("bot_add_ct %s", "forsyy");
		ServerCommand("bot_add_ct %s", "manguss");
		ServerCommand("bot_add_ct %s", "Levi");
		ServerCommand("bot_add_ct %s", "lucasp");
		ServerCommand("mp_teamlogo_1 ente");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "\"The eLiVe\"");
		ServerCommand("bot_add_t %s", "forsyy");
		ServerCommand("bot_add_t %s", "manguss");
		ServerCommand("bot_add_t %s", "Levi");
		ServerCommand("bot_add_t %s", "lucasp");
		ServerCommand("mp_teamlogo_2 ente");
	}
	
	return Plugin_Handled;
}

public Action Team_hREDS(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "eDi");
		ServerCommand("bot_add_ct %s", "oopee");
		ServerCommand("bot_add_ct %s", "Sm1llee");
		ServerCommand("bot_add_ct %s", "LYNXi");
		ServerCommand("bot_add_ct %s", "xartE");
		ServerCommand("mp_teamlogo_1 hreds");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "eDi");
		ServerCommand("bot_add_t %s", "oopee");
		ServerCommand("bot_add_t %s", "Sm1llee");
		ServerCommand("bot_add_t %s", "LYNXi");
		ServerCommand("bot_add_t %s", "xartE");
		ServerCommand("mp_teamlogo_2 hreds");
	}
	
	return Plugin_Handled;
}

public Action Team_Lemondogs(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "xelos");
		ServerCommand("bot_add_ct %s", "twist");
		ServerCommand("bot_add_ct %s", "hemzk9");
		ServerCommand("bot_add_ct %s", "ZER");
		ServerCommand("bot_add_ct %s", "Svedjehed");
		ServerCommand("mp_teamlogo_1 lemon");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "xelos");
		ServerCommand("bot_add_t %s", "twist");
		ServerCommand("bot_add_t %s", "hemzk9");
		ServerCommand("bot_add_t %s", "ZER");
		ServerCommand("bot_add_t %s", "Svedjehed");
		ServerCommand("mp_teamlogo_2 lemon");
	}
	
	return Plugin_Handled;
}

public Action Team_Havan(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "cidz");
		ServerCommand("bot_add_ct %s", "kye");
		ServerCommand("bot_add_ct %s", "remix");
		ServerCommand("bot_add_ct %s", "dok");
		ServerCommand("bot_add_ct %s", "skullz");
		ServerCommand("mp_teamlogo_1 havan");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "cidz");
		ServerCommand("bot_add_t %s", "kye");
		ServerCommand("bot_add_t %s", "remix");
		ServerCommand("bot_add_t %s", "dok");
		ServerCommand("bot_add_t %s", "skullz");
		ServerCommand("mp_teamlogo_2 havan");
	}
	
	return Plugin_Handled;
}

public Action Team_Sangal(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "MAJ3R");
		ServerCommand("bot_add_ct %s", "ngiN");
		ServerCommand("bot_add_ct %s", "paz");
		ServerCommand("bot_add_ct %s", "Soulfly");
		ServerCommand("bot_add_ct %s", "S3NSEY");
		ServerCommand("mp_teamlogo_1 sang");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "MAJ3R");
		ServerCommand("bot_add_t %s", "ngiN");
		ServerCommand("bot_add_t %s", "paz");
		ServerCommand("bot_add_t %s", "Soulfly");
		ServerCommand("bot_add_t %s", "S3NSEY");
		ServerCommand("mp_teamlogo_2 sang");
	}
	
	return Plugin_Handled;
}

public Action Team_Ambush(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Maze");
		ServerCommand("bot_add_ct %s", "Gnoffe");
		ServerCommand("bot_add_ct %s", "milky");
		ServerCommand("bot_add_ct %s", "Rock1nG");
		ServerCommand("bot_add_ct %s", "k0lty");
		ServerCommand("mp_teamlogo_1 amb");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Maze");
		ServerCommand("bot_add_t %s", "Gnoffe");
		ServerCommand("bot_add_t %s", "milky");
		ServerCommand("bot_add_t %s", "Rock1nG");
		ServerCommand("bot_add_t %s", "k0lty");
		ServerCommand("mp_teamlogo_2 amb");
	}
	
	return Plugin_Handled;
}

public Action Team_Dragons(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "GYZER");
		ServerCommand("bot_add_ct %s", "fREQ");
		ServerCommand("bot_add_ct %s", "KNCERATO");
		ServerCommand("bot_add_ct %s", "detr0it");
		ServerCommand("bot_add_ct %s", "r4ul");
		ServerCommand("mp_teamlogo_1 drag");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "GYZER");
		ServerCommand("bot_add_t %s", "fREQ");
		ServerCommand("bot_add_t %s", "KNCERATO");
		ServerCommand("bot_add_t %s", "detr0it");
		ServerCommand("bot_add_t %s", "r4ul");
		ServerCommand("mp_teamlogo_2 drag");
	}
	
	return Plugin_Handled;
}

public Action Team_Keyd(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "YJ");
		ServerCommand("bot_add_ct %s", "abr");
		ServerCommand("bot_add_ct %s", "ponter");
		ServerCommand("bot_add_ct %s", "raafa");
		ServerCommand("bot_add_ct %s", "ph1");
		ServerCommand("mp_teamlogo_1 keyds");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "YJ");
		ServerCommand("bot_add_t %s", "abr");
		ServerCommand("bot_add_t %s", "ponter");
		ServerCommand("bot_add_t %s", "raafa");
		ServerCommand("bot_add_t %s", "ph1");
		ServerCommand("mp_teamlogo_2 keyds");
	}
	
	return Plugin_Handled;
}

public Action Team_Supremacy(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "kevz");
		ServerCommand("bot_add_ct %s", "GuepaRd");
		ServerCommand("bot_add_ct %s", "zockie");
		ServerCommand("bot_add_ct %s", "LKN");
		ServerCommand("bot_add_ct %s", "ALONZO");
		ServerCommand("mp_teamlogo_1 sup");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "kevz");
		ServerCommand("bot_add_t %s", "GuepaRd");
		ServerCommand("bot_add_t %s", "zockie");
		ServerCommand("bot_add_t %s", "LKN");
		ServerCommand("bot_add_t %s", "ALONZO");
		ServerCommand("mp_teamlogo_2 sup");
	}
	
	return Plugin_Handled;
}

public Action Team_x6tence(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "flowX");
		ServerCommand("bot_add_ct %s", "Ezetapsss");
		ServerCommand("bot_add_ct %s", "SOKER");
		ServerCommand("bot_add_ct %s", "GOYO007");
		ServerCommand("bot_add_ct %s", "roGerzz");
		ServerCommand("mp_teamlogo_1 x6t");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "flowX");
		ServerCommand("bot_add_t %s", "Ezetapsss");
		ServerCommand("bot_add_t %s", "SOKER");
		ServerCommand("bot_add_t %s", "GOYO007");
		ServerCommand("bot_add_t %s", "roGerzz");
		ServerCommand("mp_teamlogo_2 x6t");
	}
	
	return Plugin_Handled;
}

public Action Team_AVEZ(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "LeS");
		ServerCommand("bot_add_ct %s", "fanatyk");
		ServerCommand("bot_add_ct %s", "gRuChA");
		ServerCommand("bot_add_ct %s", "SaMey");
		ServerCommand("bot_add_ct %s", "pendzel");
		ServerCommand("mp_teamlogo_1 avez");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "LeS");
		ServerCommand("bot_add_t %s", "fanatyk");
		ServerCommand("bot_add_t %s", "gRuChA");
		ServerCommand("bot_add_t %s", "SaMey");
		ServerCommand("bot_add_t %s", "pendzel");
		ServerCommand("mp_teamlogo_2 avez");
	}
	
	return Plugin_Handled;
}

public Action Team_BP(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "coolio");
		ServerCommand("bot_add_ct %s", "torzsi");
		ServerCommand("bot_add_ct %s", "kory");
		ServerCommand("bot_add_ct %s", "fleav");
		ServerCommand("bot_add_ct %s", "Cr0n0s");
		ServerCommand("mp_teamlogo_1 bp");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "coolio");
		ServerCommand("bot_add_t %s", "torzsi");
		ServerCommand("bot_add_t %s", "kory");
		ServerCommand("bot_add_t %s", "fleav");
		ServerCommand("bot_add_t %s", "Cr0n0s");
		ServerCommand("mp_teamlogo_2 bp");
	}
	
	return Plugin_Handled;
}

public Action Team_Anonymo(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "snatchie");
		ServerCommand("bot_add_ct %s", "Snax");
		ServerCommand("bot_add_ct %s", "Demho");
		ServerCommand("bot_add_ct %s", "rallen");
		ServerCommand("bot_add_ct %s", "innocent");
		ServerCommand("mp_teamlogo_1 anon");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "snatchie");
		ServerCommand("bot_add_t %s", "Snax");
		ServerCommand("bot_add_t %s", "Demho");
		ServerCommand("bot_add_t %s", "rallen");
		ServerCommand("bot_add_t %s", "innocent");
		ServerCommand("mp_teamlogo_2 anon");
	}
	
	return Plugin_Handled;
}

public Action Team_HONORIS(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "TaZ");
		ServerCommand("bot_add_ct %s", "fr3nd");
		ServerCommand("bot_add_ct %s", "reiko");
		ServerCommand("bot_add_ct %s", "mouz");
		ServerCommand("bot_add_ct %s", "NEO");
		ServerCommand("mp_teamlogo_1 hono");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "TaZ");
		ServerCommand("bot_add_t %s", "fr3nd");
		ServerCommand("bot_add_t %s", "reiko");
		ServerCommand("bot_add_t %s", "mouz");
		ServerCommand("bot_add_t %s", "NEO");
		ServerCommand("mp_teamlogo_2 hono");
	}
	
	return Plugin_Handled;
}

public Action Team_ES(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "JT");
		ServerCommand("bot_add_ct %s", "oSee");
		ServerCommand("bot_add_ct %s", "MarKE");
		ServerCommand("bot_add_ct %s", "floppy");
		ServerCommand("bot_add_ct %s", "FaNg");
		ServerCommand("mp_teamlogo_1 es");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "JT");
		ServerCommand("bot_add_t %s", "oSee");
		ServerCommand("bot_add_t %s", "MarKE");
		ServerCommand("bot_add_t %s", "floppy");
		ServerCommand("bot_add_t %s", "FaNg");
		ServerCommand("mp_teamlogo_2 es");
	}
	
	return Plugin_Handled;
}

public Action Team_RBG(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Walco");
		ServerCommand("bot_add_ct %s", "HexT");
		ServerCommand("bot_add_ct %s", "wiz");
		ServerCommand("bot_add_ct %s", "chop");
		ServerCommand("bot_add_ct %s", "jitter");
		ServerCommand("mp_teamlogo_1 rbg");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Walco");
		ServerCommand("bot_add_t %s", "HexT");
		ServerCommand("bot_add_t %s", "wiz");
		ServerCommand("bot_add_t %s", "chop");
		ServerCommand("bot_add_t %s", "jitter");
		ServerCommand("mp_teamlogo_2 rbg");
	}
	
	return Plugin_Handled;
}

public Action Team_DNMK(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Heartbreak");
		ServerCommand("bot_add_ct %s", "kaNibalistic");
		ServerCommand("bot_add_ct %s", "dyvo");
		ServerCommand("bot_add_ct %s", "Doru");
		ServerCommand("bot_add_ct %s", "Dubee");
		ServerCommand("mp_teamlogo_1 dnmk");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Heartbreak");
		ServerCommand("bot_add_t %s", "kaNibalistic");
		ServerCommand("bot_add_t %s", "dyvo");
		ServerCommand("bot_add_t %s", "Doru");
		ServerCommand("bot_add_t %s", "Dubee");
		ServerCommand("mp_teamlogo_2 dnkm");
	}
	
	return Plugin_Handled;
}

public Action Team_iNation(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Dragon");
		ServerCommand("bot_add_ct %s", "VLDN");
		ServerCommand("bot_add_ct %s", "choiv7");
		ServerCommand("bot_add_ct %s", "pTKKK");
		ServerCommand("bot_add_ct %s", "SkippeR");
		ServerCommand("mp_teamlogo_1 inat");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Dragon");
		ServerCommand("bot_add_t %s", "VLDN");
		ServerCommand("bot_add_t %s", "choiv7");
		ServerCommand("bot_add_t %s", "pTKKK");
		ServerCommand("bot_add_t %s", "SkippeR");
		ServerCommand("mp_teamlogo_2 inat");
	}
	
	return Plugin_Handled;
}

public Action Team_LEISURE(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "get");
		ServerCommand("bot_add_ct %s", "rome");
		ServerCommand("bot_add_ct %s", "raveN");
		ServerCommand("bot_add_ct %s", "d1cer");
		ServerCommand("bot_add_ct %s", "oddo");
		ServerCommand("mp_teamlogo_1 leis");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "get");
		ServerCommand("bot_add_t %s", "rome");
		ServerCommand("bot_add_t %s", "raveN");
		ServerCommand("bot_add_t %s", "d1cer");
		ServerCommand("bot_add_t %s", "oddo");
		ServerCommand("mp_teamlogo_2 leis");
	}
	
	return Plugin_Handled;
}

public Action Team_Paqueta(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "DeStiNy");
		ServerCommand("bot_add_ct %s", "nython");
		ServerCommand("bot_add_ct %s", "dav1d");
		ServerCommand("bot_add_ct %s", "KHTEX");
		ServerCommand("bot_add_ct %s", "iDk");
		ServerCommand("mp_teamlogo_1 paq");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "DeStiNy");
		ServerCommand("bot_add_t %s", "nython");
		ServerCommand("bot_add_t %s", "dav1d");
		ServerCommand("bot_add_t %s", "KHTEX");
		ServerCommand("bot_add_t %s", "iDk");
		ServerCommand("mp_teamlogo_2 paq");
	}
	
	return Plugin_Handled;
}

public Action Team_BNB(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Bwills");
		ServerCommand("bot_add_ct %s", "Junior");
		ServerCommand("bot_add_ct %s", "Swisher");
		ServerCommand("bot_add_ct %s", "Spongey");
		ServerCommand("bot_add_ct %s", "Shakezullah");
		ServerCommand("mp_teamlogo_1 bnb");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Bwills");
		ServerCommand("bot_add_t %s", "Junior");
		ServerCommand("bot_add_t %s", "Swisher");
		ServerCommand("bot_add_t %s", "Spongey");
		ServerCommand("bot_add_t %s", "Shakezullah");
		ServerCommand("mp_teamlogo_2 bnb");
	}
	
	return Plugin_Handled;
}

public Action Team_Nation(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "fer");
		ServerCommand("bot_add_ct %s", "kNgV-");
		ServerCommand("bot_add_ct %s", "leo_drk");
		ServerCommand("bot_add_ct %s", "trk");
		ServerCommand("bot_add_ct %s", "v$m");
		ServerCommand("mp_teamlogo_1 nat");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "fer");
		ServerCommand("bot_add_t %s", "kNgV-");
		ServerCommand("bot_add_t %s", "leo_drk");
		ServerCommand("bot_add_t %s", "trk");
		ServerCommand("bot_add_t %s", "v$m");
		ServerCommand("mp_teamlogo_2 nat");
	}
	
	return Plugin_Handled;
}

public Action Team_Eriness(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "replay");
		ServerCommand("bot_add_ct %s", "desty");
		ServerCommand("bot_add_ct %s", "Lueg");
		ServerCommand("bot_add_ct %s", "DOCKSTAR");
		ServerCommand("bot_add_ct %s", "Lastiik");
		ServerCommand("mp_teamlogo_1 eri");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "replay");
		ServerCommand("bot_add_t %s", "desty");
		ServerCommand("bot_add_t %s", "Lueg");
		ServerCommand("bot_add_t %s", "DOCKSTAR");
		ServerCommand("bot_add_t %s", "Lastiik");
		ServerCommand("mp_teamlogo_2 eri");
	}
	
	return Plugin_Handled;
}

public Action Team_Entropiq(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Lack1");
		ServerCommand("bot_add_ct %s", "El1an");
		ServerCommand("bot_add_ct %s", "NickelBack");
		ServerCommand("bot_add_ct %s", "Krad");
		ServerCommand("bot_add_ct %s", "Forester");
		ServerCommand("mp_teamlogo_1 ent");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Lack1");
		ServerCommand("bot_add_t %s", "El1an");
		ServerCommand("bot_add_t %s", "NickelBack");
		ServerCommand("bot_add_t %s", "Krad");
		ServerCommand("bot_add_t %s", "Forester");
		ServerCommand("mp_teamlogo_2 ent");
	}
	
	return Plugin_Handled;
}

public Action Team_Checkmate(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "bLitz");
		ServerCommand("bot_add_ct %s", "cool4st");
		ServerCommand("bot_add_ct %s", "hasteka");
		ServerCommand("bot_add_ct %s", "Techno4K");
		ServerCommand("bot_add_ct %s", "Bart4k");
		ServerCommand("mp_teamlogo_1 check");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "bLitz");
		ServerCommand("bot_add_t %s", "cool4st");
		ServerCommand("bot_add_t %s", "hasteka");
		ServerCommand("bot_add_t %s", "Techno4K");
		ServerCommand("bot_add_t %s", "Bart4k");
		ServerCommand("mp_teamlogo_2 check");
	}
	
	return Plugin_Handled;
}

public Action Team_Renewal(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "dobu");
		ServerCommand("bot_add_ct %s", "nin9");
		ServerCommand("bot_add_ct %s", "kabal");
		ServerCommand("bot_add_ct %s", "rate");
		ServerCommand("bot_add_ct %s", "NEUZ");
		ServerCommand("mp_teamlogo_1 rene");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "dobu");
		ServerCommand("bot_add_t %s", "nin9");
		ServerCommand("bot_add_t %s", "kabal");
		ServerCommand("bot_add_t %s", "rate");
		ServerCommand("bot_add_t %s", "NEUZ");
		ServerCommand("mp_teamlogo_2 rene");
	}
	
	return Plugin_Handled;
}

public Action Team_Party(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ben1337");
		ServerCommand("bot_add_ct %s", "PwnAlone");
		ServerCommand("bot_add_ct %s", "djay");
		ServerCommand("bot_add_ct %s", "Infinite");
		ServerCommand("bot_add_ct %s", "cynic");
		ServerCommand("mp_teamlogo_1 part");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ben1337");
		ServerCommand("bot_add_t %s", "PwnAlone");
		ServerCommand("bot_add_t %s", "djay");
		ServerCommand("bot_add_t %s", "Infinite");
		ServerCommand("bot_add_t %s", "cynic");
		ServerCommand("mp_teamlogo_2 part");
	}
	
	return Plugin_Handled;
}

public Action Team_777(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ruyter");
		ServerCommand("bot_add_ct %s", "Marcelious");
		ServerCommand("bot_add_ct %s", "mikki");
		ServerCommand("bot_add_ct %s", "akEz");
		ServerCommand("bot_add_ct %s", "H4RR3");
		ServerCommand("mp_teamlogo_1 777");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ruyter");
		ServerCommand("bot_add_t %s", "Marcelious");
		ServerCommand("bot_add_t %s", "mikki");
		ServerCommand("bot_add_t %s", "akEz");
		ServerCommand("bot_add_t %s", "H4RR3");
		ServerCommand("mp_teamlogo_2 777");
	}
	
	return Plugin_Handled;
}

public Action Team_CG(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "ScrunK");
		ServerCommand("bot_add_ct %s", "PANIX");
		ServerCommand("bot_add_ct %s", "Krimbo");
		ServerCommand("bot_add_ct %s", "kRYSTAL");
		ServerCommand("bot_add_ct %s", "stfN");
		ServerCommand("mp_teamlogo_1 cg");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "ScrunK");
		ServerCommand("bot_add_t %s", "PANIX");
		ServerCommand("bot_add_t %s", "Krimbo");
		ServerCommand("bot_add_t %s", "kRYSTAL");
		ServerCommand("bot_add_t %s", "stfN");
		ServerCommand("mp_teamlogo_2 cg");
	}
	
	return Plugin_Handled;
}

public Action Team_Illuminar(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "oskarish");
		ServerCommand("bot_add_ct %s", "MWLKY");
		ServerCommand("bot_add_ct %s", "maaryy");
		ServerCommand("bot_add_ct %s", "zaNNN");
		ServerCommand("bot_add_ct %s", "tomiko");
		ServerCommand("mp_teamlogo_1 illu");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "oskarish");
		ServerCommand("bot_add_t %s", "MWLKY");
		ServerCommand("bot_add_t %s", "maaryy");
		ServerCommand("bot_add_t %s", "zaNNN");
		ServerCommand("bot_add_t %s", "tomiko");
		ServerCommand("mp_teamlogo_2 illu");
	}
	
	return Plugin_Handled;
}

public Action Team_BLUEJAYS(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "aidKiT");
		ServerCommand("bot_add_ct %s", "kyxsan");
		ServerCommand("bot_add_ct %s", "stYleEeZ");
		ServerCommand("bot_add_ct %s", "dan1");
		ServerCommand("bot_add_ct %s", "Cryveng");
		ServerCommand("mp_teamlogo_1 bluej");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "aidKiT");
		ServerCommand("bot_add_t %s", "kyxsan");
		ServerCommand("bot_add_t %s", "stYleEeZ");
		ServerCommand("bot_add_t %s", "dan1");
		ServerCommand("bot_add_t %s", "Cryveng");
		ServerCommand("mp_teamlogo_2 bluej");
	}
	
	return Plugin_Handled;
}

public Action Team_ECK(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "byr9");
		ServerCommand("bot_add_ct %s", "uQlutzavr");
		ServerCommand("bot_add_ct %s", "Smash");
		ServerCommand("bot_add_ct %s", "s4");
		ServerCommand("bot_add_ct %s", "amster");
		ServerCommand("mp_teamlogo_1 eck");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "byr9");
		ServerCommand("bot_add_t %s", "uQlutzavr");
		ServerCommand("bot_add_t %s", "Smash");
		ServerCommand("bot_add_t %s", "s4");
		ServerCommand("bot_add_t %s", "amster");
		ServerCommand("mp_teamlogo_2 eck");
	}
	
	return Plugin_Handled;
}

public Action Team_Conquer(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "choco");
		ServerCommand("bot_add_ct %s", "Elfern");
		ServerCommand("bot_add_ct %s", "myltsi");
		ServerCommand("bot_add_ct %s", "Jerppa");
		ServerCommand("bot_add_ct %s", "Jimpphat");
		ServerCommand("mp_teamlogo_1 conq");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "choco");
		ServerCommand("bot_add_t %s", "Elfern");
		ServerCommand("bot_add_t %s", "myltsi");
		ServerCommand("bot_add_t %s", "Jerppa");
		ServerCommand("bot_add_t %s", "Jimpphat");
		ServerCommand("mp_teamlogo_2 conq");
	}
	
	return Plugin_Handled;
}

public Action Team_AVANGAR(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "FinigaN");
		ServerCommand("bot_add_ct %s", "znx");
		ServerCommand("bot_add_ct %s", "kade0");
		ServerCommand("bot_add_ct %s", "s1natoRRR");
		ServerCommand("bot_add_ct %s", "ICY");
		ServerCommand("mp_teamlogo_1 avg");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "FinigaN");
		ServerCommand("bot_add_t %s", "znx");
		ServerCommand("bot_add_t %s", "kade0");
		ServerCommand("bot_add_t %s", "s1natoRRR");
		ServerCommand("bot_add_t %s", "ICY");
		ServerCommand("mp_teamlogo_2 avg");
	}
	
	return Plugin_Handled;
}

public Action Team_SWS(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "RICIOLI");
		ServerCommand("bot_add_ct %s", "Gafolo");
		ServerCommand("bot_add_ct %s", "matios");
		ServerCommand("bot_add_ct %s", "chay");
		ServerCommand("bot_add_ct %s", "w1");
		ServerCommand("mp_teamlogo_1 sws");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "RICIOLI");
		ServerCommand("bot_add_t %s", "Gafolo");
		ServerCommand("bot_add_t %s", "matios");
		ServerCommand("bot_add_t %s", "chay");
		ServerCommand("bot_add_t %s", "w1");
		ServerCommand("mp_teamlogo_2 sws");
	}
	
	return Plugin_Handled;
}

public Action Team_Leviatan(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "1962");
		ServerCommand("bot_add_ct %s", "DILLION1");
		ServerCommand("bot_add_ct %s", "Reversive");
		ServerCommand("bot_add_ct %s", "tom1");
		ServerCommand("bot_add_ct %s", "Yokowow");
		ServerCommand("mp_teamlogo_1 levi");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "1962");
		ServerCommand("bot_add_t %s", "DILLION1");
		ServerCommand("bot_add_t %s", "Reversive");
		ServerCommand("bot_add_t %s", "tom1");
		ServerCommand("bot_add_t %s", "Yokowow");
		ServerCommand("mp_teamlogo_2 levi");
	}
	
	return Plugin_Handled;
}

public Action Team_HR(int client, int iArgs)
{
	char szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	if (strcmp(szArg, "ct") == 0)
	{
		ServerCommand("bot_kick ct all");
		ServerCommand("bot_add_ct %s", "Templ");
		ServerCommand("bot_add_ct %s", "alex666");
		ServerCommand("bot_add_ct %s", "7oX1C");
		ServerCommand("bot_add_ct %s", "w0nderful");
		ServerCommand("bot_add_ct %s", "OWNER");
		ServerCommand("mp_teamlogo_1 hr");
	}
	
	if (strcmp(szArg, "t") == 0)
	{
		ServerCommand("bot_kick t all");
		ServerCommand("bot_add_t %s", "Templ");
		ServerCommand("bot_add_t %s", "alex666");
		ServerCommand("bot_add_t %s", "7oX1C");
		ServerCommand("bot_add_t %s", "w0nderful");
		ServerCommand("bot_add_t %s", "OWNER");
		ServerCommand("mp_teamlogo_2 hr");
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	g_iProfileRankOffset = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");
	
	GetCurrentMap(g_szMap, sizeof(g_szMap));
	
	CreateTimer(1.0, Timer_CheckPlayer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, Timer_CheckPlayerFast, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	SDKHook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public Action Timer_CheckPlayer(Handle hTimer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsFakeClient(i) && IsPlayerAlive(i))
		{
			int iAccount = GetEntProp(i, Prop_Send, "m_iAccount");
			bool bInBuyZone = !!GetEntProp(i, Prop_Send, "m_bInBuyZone");
			int iTeam = GetClientTeam(i);
			//bool bHasHumanTeam = !!HumansOnTeam(GetClientTeam(i));//
			bool bHasDefuser = !!GetEntProp(i, Prop_Send, "m_bHasDefuser");
			
			
			
			if (Math_GetRandomInt(1, 100) <= 5)
			{
				FakeClientCommand(i, "+lookatweapon");
				FakeClientCommand(i, "-lookatweapon");
			}
			
			if ((g_iCurrentRound == 0 || g_iCurrentRound == 15) && bInBuyZone)
			{
				switch (Math_GetRandomInt(1,3))
				{
					case 1: FakeClientCommand(i, "buy vest");
					case 3:	FakeClientCommand(i, "buy %s", (iTeam == CS_TEAM_CT) ? "defuser" : "p250");
				}
			}
			else if ((iAccount > g_cvBotEcoLimit.IntValue || GetPlayerWeaponSlot(i, CS_SLOT_PRIMARY) != -1) && bInBuyZone)
			{
				if (GetEntProp(i, Prop_Data, "m_ArmorValue") < 50 || GetEntProp(i, Prop_Send, "m_bHasHelmet") == 0)
					FakeClientCommand(i, "buy vesthelm");
				
				if (iTeam == CS_TEAM_CT && !bHasDefuser)
					FakeClientCommand(i, "buy defuser");
			}
			else if (iAccount < g_cvBotEcoLimit.IntValue && iAccount > 2000 && !bHasDefuser && bInBuyZone)
			{
				switch (Math_GetRandomInt(1,10))
				{
					case 1: FakeClientCommand(i, "buy vest");
					case 5:	FakeClientCommand(i, "buy %s", (iTeam == CS_TEAM_CT) ? "defuser" : "vest");
				}
			}
			
		}
	}
}

public Action Timer_CheckPlayerFast(Handle hTimer, any data)
{
	g_bBombPlanted = !!GameRules_GetProp("m_bBombPlanted");
	g_bCountAdvance = GetAliveTeamCount(CS_TEAM_T)- GetAliveTeamCount(CS_TEAM_CT);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client))
		{
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (iActiveWeapon == -1) return Plugin_Continue;
			
			float fClientLoc[3], fClientEyes[3];
			GetClientAbsOrigin(client, fClientLoc);
			GetClientEyePosition(client, fClientEyes);
			g_pCurrArea[client] = NavMesh_GetNearestArea(fClientLoc);
			
			if ((GetAliveTeamCount(CS_TEAM_T) == 0 || GetAliveTeamCount(CS_TEAM_CT) == 0) && !g_bDontSwitch[client])
			{
				SDKCall(g_hSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE), 0);
				g_bEveryoneDead = true;
			}
			
			if (BotMimic_IsPlayerMimicing(client) && ((GetClientTeam(client) == CS_TEAM_T && GetAliveTeamCount(CS_TEAM_T) < 3 && GetAliveTeamCount(CS_TEAM_CT) > 0) || g_bAbortExecute))
				BotMimic_StopPlayerMimic(client);
			
			if (g_bIsProBot[client])
			{
			
				TaskType iBotTask = view_as<TaskType>(GetEntData(client, g_iBotTaskOffset));   //Bot state
			
				if(!g_bBombPlanted && !g_bEveryoneDead)
				{
						int iWeaponC4 = GetNearestEntity(client, "weapon_c4");
						float fWeaponC4Location[3];
						GetEntPropVector(iWeaponC4, Prop_Send, "m_vecOrigin", fWeaponC4Location);	
						float fWeaponC4Distance;
						fWeaponC4Distance = GetVectorDistance(fClientLoc, fWeaponC4Location);
						
						if (IsValidEntity(iWeaponC4))
						{
							if(GetClientTeam(client) == CS_TEAM_CT)
							{
								if(IsPointVisible(fClientEyes, fWeaponC4Location) && !g_bFoundC4)
								{
									g_bFoundC4 = true;
								}
								if(g_bFoundC4 && fWeaponC4Distance > 1000 )
								{
									BotMoveTo(client,fWeaponC4Location,FASTEST_ROUTE);	
								}
							}	
							
							if(GetClientTeam(client) == CS_TEAM_T)
							{
								if(iBotTask == PLANT_BOMB &&  GetEntData(client, g_iBotNearbyEnemiesOffset) == 1 && GetAliveTeamCount(CS_TEAM_CT) )
								{
									BotMoveTo(client,g_fTargetPos[client],FASTEST_ROUTE);
								}							
							}
						}
						
				}	
				
				if(g_bBombPlanted)
				{
					int iPlantedC4 = GetNearestEntity(client, "planted_c4");
					float fPlantedC4Location[3];
					GetEntPropVector(iPlantedC4, Prop_Send, "m_vecOrigin", fPlantedC4Location);	
					float fPlantedC4Distance;
					fPlantedC4Distance = GetVectorDistance(fClientLoc, fPlantedC4Location);
					
					
					if (IsValidEntity(iPlantedC4) )
					{
						if(GetClientTeam(client) == CS_TEAM_CT)
						{
							if (fPlantedC4Distance > 2000.0 && !BotIsBusy(client) && GetEntData(client, g_iBotNearbyEnemiesOffset) == 0 && !g_bDontSwitch[client])
							{
								SDKCall(g_hSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), 0);
								BotMoveTo(client, fPlantedC4Location, FASTEST_ROUTE);
							}
							if( (fPlantedC4Distance < 800 && GetEntData(client, g_iBotNearbyEnemiesOffset) == 1) || GetAliveTeamCount(CS_TEAM_CT)==1 )						
							{
								if(iBotTask == DEFUSE_BOMB && GetAliveTeamCount(CS_TEAM_T))
								{
									BotMoveTo(client,g_fTargetPos[client],FASTEST_ROUTE);
								}
							/*	
								if(GetAliveTeamCount(CS_TEAM_T)==0)
								{
									BotMoveTo(client, fPlantedC4Location, FASTEST_ROUTE);
								}
							*/	
							}
						}
						
						if(GetClientTeam(client) == CS_TEAM_T)
						{
							
							if (fPlantedC4Distance > 1000.0 && !BotIsBusy(client)&& !g_bDontSwitch[client] && g_bCountAdvance < 3 && GetAliveTeamCount(CS_TEAM_T) >2)
							{
								SDKCall(g_hSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), 0);
								BotMoveTo(client, fPlantedC4Location, FASTEST_ROUTE);
							}
							if(GetAliveTeamCount(CS_TEAM_T) <= 2 && !g_bEveryoneDead && GetEntData(client, g_iBotNearbyEnemiesOffset) == 1 )
							{
								if (fPlantedC4Distance > 500.0) 
								BotMoveTo(client, fPlantedC4Location, FASTEST_ROUTE);
							}
						}
					}
				}
				
				if (g_bFreezetimeEnd && !g_bBombPlanted && !BotIsBusy(client) && !BotIsHiding(client) && !BotMimic_IsPlayerMimicing(client))
				{
					//Rifles
					int iAK47 = GetNearestEntity(client, "weapon_ak47");
					int iM4A1 = GetNearestEntity(client, "weapon_m4a1");
					int iM4A1S = GetNearestEntity(client, "weapon_m4a1_silencer");
					int iPrimary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
					int iPrimaryDefIndex;

					if (IsValidEntity(iAK47))
					{
						float fAK47Location[3];

						iPrimaryDefIndex = IsValidEntity(iPrimary) ? GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") : 0;

						if ((iPrimaryDefIndex != 7 && iPrimaryDefIndex != 9) || iPrimary == -1)
						{
							GetEntPropVector(iAK47, Prop_Send, "m_vecOrigin", fAK47Location);

							if (GetVectorLength(fAK47Location) > 0.0 && IsPointVisible(fClientEyes, fAK47Location))
								BotMoveTo(client, fAK47Location, FASTEST_ROUTE);
						}
					}
					else if (IsValidEntity(iM4A1))
					{
						float fM4A1Location[3];

						iPrimaryDefIndex = IsValidEntity(iPrimary) ? GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") : 0;

						if (iPrimaryDefIndex != 7 && iPrimaryDefIndex != 9 && iPrimaryDefIndex != 16 && iPrimaryDefIndex != 60)
						{
							GetEntPropVector(iM4A1, Prop_Send, "m_vecOrigin", fM4A1Location);

							if (GetVectorLength(fM4A1Location) > 0.0 && IsPointVisible(fClientEyes, fM4A1Location))
							{
								BotMoveTo(client, fM4A1Location, FASTEST_ROUTE);

								if (GetVectorDistance(fClientLoc, fM4A1Location) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), false);
							}
						}
						else if (iPrimary == -1)
						{
							GetEntPropVector(iM4A1, Prop_Send, "m_vecOrigin", fM4A1Location);

							if (GetVectorLength(fM4A1Location) > 0.0 && IsPointVisible(fClientEyes, fM4A1Location))
								BotMoveTo(client, fM4A1Location, FASTEST_ROUTE);
						}
					}
					
					else if (IsValidEntity(iM4A1S))
					{
						float fM4A1SLocation[3];

						iPrimaryDefIndex = IsValidEntity(iPrimary) ? GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") : 0;

						if (iPrimaryDefIndex != 7 && iPrimaryDefIndex != 9 && iPrimaryDefIndex != 16)
						{
							GetEntPropVector(iM4A1S, Prop_Send, "m_vecOrigin", fM4A1SLocation);

							if (GetVectorLength(fM4A1SLocation) > 0.0 && IsPointVisible(fClientEyes, fM4A1SLocation))
							{
								BotMoveTo(client, fM4A1SLocation, FASTEST_ROUTE);

								if (GetVectorDistance(fClientLoc, fM4A1SLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), false);
							}
						}
						else if (iPrimary == -1)
						{
							GetEntPropVector(iM4A1S, Prop_Send, "m_vecOrigin", fM4A1SLocation);

							if (GetVectorLength(fM4A1SLocation) > 0.0 && IsPointVisible(fClientEyes, fM4A1SLocation))
								BotMoveTo(client, fM4A1SLocation, FASTEST_ROUTE);
						}
					}
					
					//Pistols
					int iUSP = GetNearestEntity(client, "weapon_hkp2000");
					int iP250 = GetNearestEntity(client, "weapon_p250");
					int iFiveSeven = GetNearestEntity(client, "weapon_fiveseven");
					int iTec9 = GetNearestEntity(client, "weapon_tec9");
					int iDeagle = GetNearestEntity(client, "weapon_deagle");
					int iSecondary = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
					int iSecondaryDefIndex;
					
					if (IsValidEntity(iDeagle))
					{
						float fDeagleLocation[3];
						
						iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
						
						if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61 || iSecondaryDefIndex == 36 || iSecondaryDefIndex == 30 || iSecondaryDefIndex == 3 || iSecondaryDefIndex == 63)
						{
							GetEntPropVector(iDeagle, Prop_Send, "m_vecOrigin", fDeagleLocation);
							
							if (GetVectorLength(fDeagleLocation) > 0.0 && IsPointVisible(fClientEyes, fDeagleLocation))
							{
								BotMoveTo(client, fDeagleLocation, FASTEST_ROUTE);
								
								if (GetVectorDistance(fClientLoc, fDeagleLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
							}
						}
					}
					else if (IsValidEntity(iTec9))
					{
						float fTec9Location[3];
						
						iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
						
						if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61 || iSecondaryDefIndex == 36)
						{
							GetEntPropVector(iTec9, Prop_Send, "m_vecOrigin", fTec9Location);
							
							if (GetVectorLength(fTec9Location) > 0.0 && IsPointVisible(fClientEyes, fTec9Location))
							{
								BotMoveTo(client, fTec9Location, FASTEST_ROUTE);
								
								if (GetVectorDistance(fClientLoc, fTec9Location) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
							}
						}
					}
					else if (IsValidEntity(iFiveSeven))
					{
						float fFiveSevenLocation[3];
						
						iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
						
						if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61 || iSecondaryDefIndex == 36)
						{
							GetEntPropVector(iFiveSeven, Prop_Send, "m_vecOrigin", fFiveSevenLocation);
							
							if (GetVectorLength(fFiveSevenLocation) > 0.0 && IsPointVisible(fClientEyes, fFiveSevenLocation))
							{
								BotMoveTo(client, fFiveSevenLocation, FASTEST_ROUTE);
								
								if (GetVectorDistance(fClientLoc, fFiveSevenLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
							}
						}
					}
					else if (IsValidEntity(iP250))
					{
						float fP250Location[3];
						
						iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
						
						if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61)
						{
							GetEntPropVector(iP250, Prop_Send, "m_vecOrigin", fP250Location);
							
							if (GetVectorLength(fP250Location) > 0.0 && IsPointVisible(fClientEyes, fP250Location))
							{
								BotMoveTo(client, fP250Location, FASTEST_ROUTE);
								
								if (GetVectorDistance(fClientLoc, fP250Location) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
							}
						}
					}
					else if (IsValidEntity(iUSP))
					{
						float fUSPLocation[3];
						
						iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
						
						if (iSecondaryDefIndex == 4)
						{
							GetEntPropVector(iUSP, Prop_Send, "m_vecOrigin", fUSPLocation);
							
							if (GetVectorLength(fUSPLocation) > 0.0 && IsPointVisible(fClientEyes, fUSPLocation))
							{
								BotMoveTo(client, fUSPLocation, FASTEST_ROUTE);
								
								if (GetVectorDistance(fClientLoc, fUSPLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
									CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnMapEnd()
{
	SDKUnhook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public void OnClientPostAdminCheck(int client)
{
	g_iProfileRank[client] = Math_GetRandomInt(1, 40);
	

	if (IsValidClient(client) && IsFakeClient(client))
	{
		char szBotName[MAX_NAME_LENGTH];
		char szClanTag[MAX_NAME_LENGTH];
		
		GetClientName(client, szBotName, sizeof(szBotName));
		g_bIsProBot[client] = false;
		
		if(IsProBot(szBotName, szClanTag))
		{
			g_fReactionTime[client] = 0.02;
			g_fAggression[client] = Math_GetRandomFloat(0.0, 1.0);
			g_bIsProBot[client] = true;
		}
		
		CS_SetClientClanTag(client, szClanTag);
		GetCrosshairCode(szBotName, g_szCrosshairCode[client], 35);
		
		g_iUSPChance[client] = Math_GetRandomInt(1, 100);
		g_iM4A1SChance[client] = Math_GetRandomInt(1, 100);
		g_pCurrArea[client] = INVALID_NAV_AREA;
		
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
}

public void OnRoundStart(Event eEvent, char[] szName, bool bDontBroadcast)
{
	g_iCurrentRound = GameRules_GetProp("m_totalRoundsPlayed");
	g_bFreezetimeEnd = false;
	g_bAbortExecute = false;
	g_bTerroristEco = false;
	g_bEveryoneDead = false;
	g_bFoundC4 = false;
	
	
	int p_flash = Math_GetRandomInt(1,10);
	
	switch(p_flash)	
	{
			case 1,2,3,4,5: 
			{	
				ServerCommand("ammo_grenade_limit_flashbang 0");ServerCommand("sm_csay 0 DAMN!No flash");
			}
		
			case 6,7,8,9: 
			{
				ServerCommand("ammo_grenade_limit_flashbang 1");ServerCommand("sm_csay SR!1 flash");
			}
		
			case 10: 
			{
				ServerCommand("ammo_grenade_limit_flashbang 2");ServerCommand("sm_csay SSR!2 flash");
			}
	}	
	
	
	ServerCommand("bot_max_visible_smoke_length %d",Math_GetRandomInt(100,800));
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsFakeClient(i) && IsPlayerAlive(i))
		{
			g_iUncrouchChance[i] = Math_GetRandomInt(1, 100);
			g_bDontSwitch[i] = false;
			g_iNewTargetTime[i] = 0;
			g_iTarget[i] = -1;
			if(BotMimic_IsPlayerMimicing(i))
				BotMimic_StopPlayerMimic(i);
		}
	}
	
	if(g_iCurrentRound==0) ServerCommand("sm_csay Good Luck&Have Fun ~");
}

public void OnFreezetimeEnd(Event eEvent, char[] szName, bool bDontBroadcast)
{
	g_bFreezetimeEnd = true;
	g_fRoundStartTimeStamp = GetGameTime();
	bool bWarmupPeriod = !!GameRules_GetProp("m_bWarmupPeriod");
	
	if(bWarmupPeriod || g_bTerroristEco || HumansOnTeam(CS_TEAM_T) > 0)
		return;
	
	if(Math_GetRandomInt(1,100) <= 80)
	{
		if (strcmp(g_szMap, "de_mirage") == 0)
		{
			g_iRndExecute = (g_iCurrentRound == 0 || g_iCurrentRound == 15) ? Math_GetRandomInt(1, 3) : Math_GetRandomInt(1, 19);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareMirageExecutes();
		}
		else if (strcmp(g_szMap, "de_dust2") == 0)
		{
			g_iRndExecute = (g_iCurrentRound == 0 || g_iCurrentRound == 15) ? Math_GetRandomInt(1, 1) : Math_GetRandomInt(1, 11);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareDust2Executes();
		}
		else if (strcmp(g_szMap, "de_inferno") == 0 || strcmp(g_szMap, "de_inferno_night") == 0 || strcmp(g_szMap, "de_infernohr_night") == 0)
		{
			g_iRndExecute = (g_iCurrentRound == 0 || g_iCurrentRound == 15) ? Math_GetRandomInt(1, 2) : Math_GetRandomInt(1, 16);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareInfernoExecutes();
		}
		else if (strcmp(g_szMap, "de_overpass") == 0)
		{
			g_iRndExecute = Math_GetRandomInt(1, 2);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareOverpassExecutes();
		}
		else if (strcmp(g_szMap, "de_train") == 0)
		{
			g_iRndExecute = Math_GetRandomInt(1, 2);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareTrainExecutes();
		}
		else if (strcmp(g_szMap, "de_nuke") == 0)
		{
			g_iRndExecute = Math_GetRandomInt(1, 2);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareNukeExecutes();
		}
		else if (strcmp(g_szMap, "de_vertigo") == 0)
		{
			g_iRndExecute = Math_GetRandomInt(1, 2);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareVertigoExecutes();
		}
		else if (strcmp(g_szMap, "de_cache") == 0)
		{
			g_iRndExecute = Math_GetRandomInt(1, 3);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareCacheExecutes();
		}
		else if (strcmp(g_szMap, "de_ancient") == 0)
		{
			g_iRndExecute = Math_GetRandomInt(1, 3);
			LogMessage("BOT STUFF: %s selected execute for Round %i: %i", g_szMap, g_iCurrentRound, g_iRndExecute);
			PrepareAncientExecutes();
		}
	}
}

public void OnRoundEnd(Event eEvent, char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsFakeClient(i) && BotMimic_IsPlayerMimicing(i))
			BotMimic_StopPlayerMimic(i);
	}
}

public void OnWeaponZoom(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client))
		CreateTimer(0.3, Timer_Zoomed, GetClientUserId(client));
}

public void OnWeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(eEvent.GetInt("userid"));
	if(IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client))
	{
		char szWeaponName[64];
		eEvent.GetString("weapon", szWeaponName, sizeof(szWeaponName));
		
		if(IsValidClient(g_iTarget[client]))
		{
			float fClientLoc[3], fTargetLoc[3];
			
			GetClientAbsOrigin(client, fClientLoc);
			GetClientAbsOrigin(g_iTarget[client], fTargetLoc);
			
			float fRangeToEnemy = GetVectorDistance(fClientLoc, fTargetLoc);
			
			if (strcmp(szWeaponName, "weapon_deagle") == 0 && fRangeToEnemy > 100.0)
				//SetEntDataFloat(client, g_iFireWeaponOffset, GetEntDataFloat(client, g_iFireWeaponOffset) + Math_GetRandomFloat(0.35, 0.60));
				SetEntDataFloat(client, g_iFireWeaponOffset, GetEntDataFloat(client, g_iFireWeaponOffset) + Math_GetRandomFloat(0.35, 0.60));
		}
		
		if (strcmp(szWeaponName, "weapon_awp") == 0 || strcmp(szWeaponName, "weapon_ssg08") == 0)
		{
			g_bZoomed[client] = false;
			CreateTimer(0.1, Timer_DelaySwitch, GetClientUserId(client));
		}
	}
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3])
{
	if (float(GetClientHealth(iVictim)) - fDamage < 0.0)
		return Plugin_Continue;
	
	if (!(iDamageType & DMG_SLASH) && !(iDamageType & DMG_BULLET) && !(iDamageType & DMG_BURN))
		return Plugin_Continue;
	
	if (iVictim == iAttacker || !IsValidClient(iAttacker) || !IsPlayerAlive(iAttacker))
		return Plugin_Continue;
	
	if(GetClientTeam(iVictim) == CS_TEAM_T)
	{
		g_bAbortExecute = true;
		BotEquipBestWeapon(iVictim, true);
	}
	
	return Plugin_Continue;
}

public void OnThinkPost(int iEnt)
{
	SetEntDataArray(iEnt, g_iProfileRankOffset, g_iProfileRank, MAXPLAYERS + 1);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsFakeClient(i))
			SetCrosshairCode(GetEntityAddress(iEnt), i, g_szCrosshairCode[i]);
	}
}

public Action CS_OnBuyCommand(int client, const char[] szWeapon)
{
	if (IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client))
	{
		if (strcmp(szWeapon, "molotov") == 0 || strcmp(szWeapon, "incgrenade") == 0 || strcmp(szWeapon, "decoy") == 0 || strcmp(szWeapon, "flashbang") == 0 || strcmp(szWeapon, "hegrenade") == 0
			 || strcmp(szWeapon, "smokegrenade") == 0 || strcmp(szWeapon, "vest") == 0 || strcmp(szWeapon, "vesthelm") == 0 || strcmp(szWeapon, "defuser") == 0)
			return Plugin_Continue;
		else if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1 && (strcmp(szWeapon, "galilar") == 0 || strcmp(szWeapon, "famas") == 0 || strcmp(szWeapon, "ak47") == 0
				 || strcmp(szWeapon, "m4a1") == 0 || strcmp(szWeapon, "ssg08") == 0 || strcmp(szWeapon, "aug") == 0 || strcmp(szWeapon, "sg556") == 0 || strcmp(szWeapon, "awp") == 0
				 || strcmp(szWeapon, "scar20") == 0 || strcmp(szWeapon, "g3sg1") == 0 || strcmp(szWeapon, "nova") == 0 || strcmp(szWeapon, "xm1014") == 0 || strcmp(szWeapon, "mag7") == 0
				 || strcmp(szWeapon, "m249") == 0 || strcmp(szWeapon, "negev") == 0 || strcmp(szWeapon, "mac10") == 0 || strcmp(szWeapon, "mp9") == 0 || strcmp(szWeapon, "mp7") == 0
				 || strcmp(szWeapon, "ump45") == 0 || strcmp(szWeapon, "p90") == 0 || strcmp(szWeapon, "bizon") == 0))
			return Plugin_Handled;
		
		int iAccount = GetEntProp(client, Prop_Send, "m_iAccount");
		
		if (strcmp(szWeapon, "m4a1") == 0)
		{
			if (g_iM4A1SChance[client] <= 80 && iAccount >= CS_GetWeaponPrice(client, CSWeapon_M4A1_SILENCER))
			{
				CSGO_SetMoney(client, iAccount - CS_GetWeaponPrice(client, CSWeapon_M4A1_SILENCER));
				CSGO_ReplaceWeapon(client, CS_SLOT_PRIMARY, "weapon_m4a1_silencer");
				
				return Plugin_Changed;
			}
			
			if (Math_GetRandomInt(1, 100) <= 5 && iAccount >= CS_GetWeaponPrice(client, CSWeapon_AUG))
			{
				CSGO_SetMoney(client, iAccount - CS_GetWeaponPrice(client, CSWeapon_AUG));
				CSGO_ReplaceWeapon(client, CS_SLOT_PRIMARY, "weapon_aug");
				
				return Plugin_Changed;
			}
		}
		else if (strcmp(szWeapon, "mac10") == 0)
		{
			if (Math_GetRandomInt(1, 100) <= 20 && iAccount >= CS_GetWeaponPrice(client, CSWeapon_GALILAR))
			{
				CSGO_SetMoney(client, iAccount - CS_GetWeaponPrice(client, CSWeapon_GALILAR));
				CSGO_ReplaceWeapon(client, CS_SLOT_PRIMARY, "weapon_galilar");
				
				return Plugin_Changed;
			}
		}
		else if (strcmp(szWeapon, "mp9") == 0)
		{
			if (Math_GetRandomInt(1, 100) <= 20 && iAccount >= CS_GetWeaponPrice(client, CSWeapon_FAMAS))
			{
				CSGO_SetMoney(client, iAccount - CS_GetWeaponPrice(client, CSWeapon_FAMAS));
				CSGO_ReplaceWeapon(client, CS_SLOT_PRIMARY, "weapon_famas");
				
				return Plugin_Changed;
			}
			else if (Math_GetRandomInt(1, 100) <= 5 && iAccount >= CS_GetWeaponPrice(client, CSWeapon_UMP45))
			{
				CSGO_SetMoney(client, iAccount - CS_GetWeaponPrice(client, CSWeapon_UMP45));
				CSGO_ReplaceWeapon(client, CS_SLOT_PRIMARY, "weapon_ump45");
				
				return Plugin_Changed;
			}
		}
		/*
		else if (strcmp(szWeapon, "tec9") == 0 || strcmp(szWeapon, "fiveseven") == 0)
		{
			if (Math_GetRandomInt(1, 100) <= 50)
			{
				CSGO_SetMoney(client, iAccount - CS_GetWeaponPrice(client, CSWeapon_CZ75A));
				CSGO_ReplaceWeapon(client, CS_SLOT_PRIMARY, "weapon_cz75a");
				
				return Plugin_Changed;
			}
		}
		*/
		
	}
	return Plugin_Continue;
}

public MRESReturn CCSBot_ThrowGrenade(int client, DHookParam hParams)
{
	if (BotMimic_IsPlayerMimicing(client))
		return MRES_Supercede;
	
	hParams.GetVector(1, g_fNadeTarget[client]);
	
	return MRES_Ignored;
}

public MRESReturn BotCOS(DHookReturn hReturn)
{
	hReturn.Value = 0;
	return MRES_Supercede;
}

public MRESReturn BotSIN(DHookReturn hReturn)
{
	hReturn.Value = 0;
	return MRES_Supercede;
}

public MRESReturn CCSBot_IsVisiblePos(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	hParams.Set(2, 0);

	return MRES_ChangedHandled;
}

public MRESReturn CCSBot_IsVisiblePlayer(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	hParams.Set(2, false);

	return MRES_ChangedHandled;
}


public MRESReturn CCSBot_GetPartPosition(DHookReturn hReturn, DHookParam hParams)
{
	int iPlayer = hParams.Get(1);
	int iPart = hParams.Get(2);
	
	if(iPart == 2)
	{
		int iBone = LookupBone(iPlayer, "head_0");
		if (iBone < 0)
			return MRES_Ignored;
		
		float fHead[3], fBad[3];
		GetBonePosition(iPlayer, iBone, fHead, fBad);
		
		fHead[2] += 4.0;
		
		hReturn.SetVector(fHead);
		
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn CCSBot_SetLookAt(int client, DHookParam hParams)
{
	char szDesc[64];
	
	DHookGetParamString(hParams, 1, szDesc, sizeof(szDesc));
	
	if ( strcmp(szDesc, "Use entity") == 0 || strcmp(szDesc, "Open door") == 0 || strcmp(szDesc, "Hostage") == 0 || strcmp(szDesc, "Face outward") == 0)
		return MRES_Ignored;
	else if (strcmp(szDesc, "Avoid Flashbang") == 0)
	{
		DHookSetParam(hParams, 3, PRIORITY_HIGH);
		
		return MRES_ChangedHandled;
	}
	else if (strcmp(szDesc, "Blind") == 0)
	{
		DHookSetParamString(hParams, 1, "Face outward");
		
		return MRES_ChangedHandled;
	}
	else if (strcmp(szDesc, "Breakable") == 0 || strcmp(szDesc, "Plant bomb on floor") == 0 || strcmp(szDesc, "Defuse Bomb") == 0)
	{
		g_bDontSwitch[client] = true;
		CreateTimer(5.0, Timer_Breakable, GetClientUserId(client));
		
		return MRES_Ignored;
	}
	else if(strcmp(szDesc, "GrenadeThrowBend") == 0)
	{
		float fEyePos[3];
		GetClientEyePosition(client, fEyePos);
		BotBendLineOfSight(client, fEyePos, g_fNadeTarget[client], g_fNadeTarget[client], 180.0);
		hParams.SetVector(2, g_fNadeTarget[client]);
		
		return MRES_ChangedHandled;
	}
	else if(strcmp(szDesc, "Noise") == 0)
	{
		float fNoisePos[3], fClientEyes[3];
		
		DHookGetParamVector(hParams, 2, fNoisePos);
		fNoisePos[2] += 25.0;
		DHookSetParamVector(hParams, 2, fNoisePos);
		
		GetClientEyePosition(client, fClientEyes);
		if(IsPointVisible(fClientEyes, fNoisePos) && LineGoesThroughSmoke(fClientEyes, fNoisePos))
			DHookSetParam(hParams, 7, true);
		
		return MRES_ChangedHandled;
	}
	else
	{
		float fPos[3];
		
		DHookGetParamVector(hParams, 2, fPos);
		fPos[2] += 25.0;
		DHookSetParamVector(hParams, 2, fPos);
		
		return MRES_ChangedHandled;
	}
}

public MRESReturn CCSBot_PickNewAimSpot(int client, DHookParam hParams)
{
	if (g_bIsProBot[client])
	{
		SelectBestTargetPos(client, g_fTargetPos[client]);
		
		if (!IsValidClient(g_iTarget[client]) || !IsPlayerAlive(g_iTarget[client]) || g_fTargetPos[client][2] == 0)
			return MRES_Ignored;
		
		SetEntDataVector(client, g_iBotTargetSpotOffset, g_fTargetPos[client]);
	}
	
	return MRES_Ignored;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapon, int &iSubtype, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2])
{	
	if (g_bFreezetimeEnd && IsValidClient(client) && IsPlayerAlive(client) && IsFakeClient(client))
	{
		int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon == -1) return Plugin_Continue;
		
		int iDefIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		float fClientLoc[3];
		
		GetClientAbsOrigin(client, fClientLoc);
		
		if(g_pCurrArea[client] != INVALID_NAV_AREA)
		{
			//SAME RUN NavMesh LOGIC
	
			if (g_pCurrArea[client].Attributes & NAV_MESH_RUN)
			{
					iButtons &= ~IN_SPEED;           //RUN is & = ~,WALK is |=
			}
		
			if(!g_bBombPlanted)
			{
				if(GetClientTeam(client) == CS_TEAM_CT)
				{
					if (g_pCurrArea[client].Attributes & NAV_MESH_WALK)
					{
						if( Math_GetRandomInt(1,10) < 7)   //CT should be more precise
							{iButtons |= IN_SPEED;}
						else 
							{iButtons &= ~IN_SPEED;}
					}
				}

				if(GetClientTeam(client) == CS_TEAM_T)
				{
					if (g_pCurrArea[client].Attributes & NAV_MESH_WALK)
					{
						if( Math_GetRandomInt(1,10) < 3)   //T can be aggresive
							{iButtons |= IN_SPEED;}
						else 
							{iButtons &= ~IN_SPEED;}
					}			
				}
			}
			
			
			if(g_bBombPlanted)  //After C4 planted, ct be aggresive,t defensive.
			{
				if(GetClientTeam(client) == CS_TEAM_CT)
				{
					if (g_pCurrArea[client].Attributes & NAV_MESH_WALK)
					{
						if( Math_GetRandomInt(1,10) < 2)   //reverse that.
							{iButtons |= IN_SPEED;}
						else 
							{iButtons &= ~IN_SPEED;}
					}
				}

				if(GetClientTeam(client) == CS_TEAM_T)
				{
					if (g_pCurrArea[client].Attributes & NAV_MESH_WALK)
					{
						if( Math_GetRandomInt(1,10) < 7)   //Defensive logic
							{iButtons |= IN_SPEED;}
						else 
							{iButtons &= ~IN_SPEED;}
					}			
				}
			}


			
		}
		
		if(((GetGameTime() - g_fRoundStartTimeStamp) < GetEntDataFloat(client, g_iBotSafeTimeOffset)/3 && !BotMimic_IsPlayerMimicing(client)) || g_bEveryoneDead)
			iButtons &= ~IN_SPEED;
		
		if(GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") == 1.0)
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 260.0);
		
		if (g_bIsProBot[client])
		{		
			g_iTarget[client] = BotGetEnemy(client);
			
			float fTargetDistance;
			int iZoomLevel;
			bool bIsEnemyVisible = !!GetEntData(client, g_iEnemyVisibleOffset);
			bool bIsAttacking = !!GetEntData(client, g_iBotAttackingOffset);
			bool bIsHiding = BotIsHiding(client);
			bool bIsDucking = !!(GetEntityFlags(client) & FL_DUCKING);
			bool bIsReloading = IsPlayerReloading(client);
			
			if(HasEntProp(iActiveWeapon, Prop_Send, "m_zoomLevel"))
				iZoomLevel = GetEntProp(iActiveWeapon, Prop_Send, "m_zoomLevel");
			
			if (!GetEntProp(client, Prop_Send, "m_bIsScoped"))
				g_bZoomed[client] = false;
			
			if(bIsHiding && (iDefIndex == 8 || iDefIndex == 39) && iZoomLevel == 0)           //8 and 39 should be awp and ssg08?
				iButtons |= IN_ATTACK2;
			else if(!bIsHiding && (iDefIndex == 8 || iDefIndex == 39) && iZoomLevel == 1)
				iButtons |= IN_ATTACK2;
			
			if (bIsHiding && g_iUncrouchChance[client] <= 50)  
				iButtons &= ~IN_DUCK;
				
			if (!IsValidClient(g_iTarget[client]) || !IsPlayerAlive(g_iTarget[client]) || g_fTargetPos[client][2] == 0)
				return Plugin_Continue;
			
			if (bIsEnemyVisible && bIsAttacking && GetEntityMoveType(client) != MOVETYPE_LADDER)
			{
				if (eItems_GetWeaponSlotByDefIndex(iDefIndex) == CS_SLOT_KNIFE)
					BotEquipBestWeapon(client, true);
			
				fTargetDistance = GetVectorDistance(fClientLoc, g_fTargetPos[client]);
				
				float fClientEyes[3], fClientAngles[3], fAimPunchAngle[3], fToAimSpot[3], fAimDir[3];
					
				GetClientEyePosition(client, fClientEyes);
				SubtractVectors(g_fTargetPos[client], fClientEyes, fToAimSpot);
				GetClientEyeAngles(client, fClientAngles);
				GetEntPropVector(client, Prop_Send, "m_aimPunchAngle", fAimPunchAngle);
				ScaleVector(fAimPunchAngle, (FindConVar("weapon_recoil_scale").FloatValue));
				AddVectors(fClientAngles, fAimPunchAngle, fClientAngles);
				GetViewVector(fClientAngles, fAimDir);
				
				float fRangeToEnemy = NormalizeVector(fToAimSpot, fToAimSpot);
				float fOnTarget = GetVectorDotProduct(fToAimSpot, fAimDir);
				float fAimTolerance = Cosine(ArcTangent(32.0 / fRangeToEnemy));
				
				switch(iDefIndex)
				{
					case 7, 8, 10, 13, 14, 16, 17, 19, 23, 24, 25, 26, 28, 33, 34, 39, 60:
					{
						//if (fOnTarget > fAimTolerance && fTargetDistance < 3000.0)
						if (fOnTarget > fAimTolerance )
						{
							iButtons &= ~IN_ATTACK;
						
							if(!bIsReloading) 
								iButtons |= IN_ATTACK;
						}
						
						if (fOnTarget > fAimTolerance && !bIsDucking && fTargetDistance < 3000.0 && iDefIndex != 17 && iDefIndex != 19 && iDefIndex != 23 && iDefIndex != 24 && iDefIndex != 25 && iDefIndex != 26 && iDefIndex != 33 && iDefIndex != 34)	
						{
							SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
						}
					}
					case 1:
					{
						if (fOnTarget > fAimTolerance && !bIsDucking && !bIsReloading)
							SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
					}
					case 9, 40:
					{
						if (GetClientAimTarget(client, true) == g_iTarget[client] && g_bZoomed[client] && !bIsReloading)
						{
							iButtons |= IN_ATTACK;
							
							SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
						}
					}
				}
				
				fClientLoc[2] += 35.5;
				
				if (!GetEntProp(iActiveWeapon, Prop_Data, "m_bInReload") && IsPointVisible(fClientLoc, g_fTargetPos[client]) && fOnTarget > fAimTolerance && fTargetDistance < 2000.0)
					iButtons |= IN_DUCK;
				
				if (!(GetEntityFlags(client))) 			//& FL_ONGROUND))//
					iButtons &= ~IN_ATTACK;
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnPlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(eEvent.GetInt("userid"));

	if (IsValidClient(client) && IsFakeClient(client))
	{
		if(g_bIsProBot[client])
		{
			Address pLocalProfile = view_as<Address>(GetEntData(client, g_iBotProfileOffset));
			

			StoreToAddress(pLocalProfile + view_as<Address>(84), view_as<int>(g_fReactionTime[client]), NumberType_Int32);
			StoreToAddress(pLocalProfile + view_as<Address>(4), view_as<int>(g_fAggression[client]), NumberType_Int32);
		}
		
		CreateTimer(1.0, RFrame_CheckBuyZoneValue, GetClientSerial(client));
		
		if (g_iUSPChance[client] >= 25)
		{
			if (GetClientTeam(client) == CS_TEAM_CT)
			{
				char szUSP[32];
				
				GetClientWeapon(client, szUSP, sizeof(szUSP));
				
				if (strcmp(szUSP, "weapon_hkp2000") == 0)
					CSGO_ReplaceWeapon(client, CS_SLOT_SECONDARY, "weapon_usp_silencer");
			}
		}
	}
}

public void OnPlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (IsValidClient(client) && IsFakeClient(client) && g_bIsProBot[client] && BotMimic_IsPlayerMimicing(client))
		BotMimic_StopPlayerMimic(client);
}

public Action RFrame_CheckBuyZoneValue(Handle hTimer, int iSerial)
{
	int client = GetClientFromSerial(iSerial);
	
	if (!IsValidClient(client) || !IsPlayerAlive(client))return Plugin_Stop;
	int iTeam = GetClientTeam(client);
	if (iTeam < 2)return Plugin_Stop;
	
	int iAccount = GetEntProp(client, Prop_Send, "m_iAccount");
	
	bool bInBuyZone = view_as<bool>(GetEntProp(client, Prop_Send, "m_bInBuyZone"));
	
	if (!bInBuyZone)return Plugin_Stop;
	
	int iPrimary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
	
	char szDefaultPrimary[64];
	GetClientWeapon(client, szDefaultPrimary, sizeof(szDefaultPrimary));
	
	if ((iAccount < 2000 || (iAccount > 2000 && iAccount < g_cvBotEcoLimit.IntValue)) && iPrimary == -1)
	{
		if(GetClientTeam(client) == CS_TEAM_T)
			g_bTerroristEco = true;
	}
	
	if ((iAccount > 2000) && (iAccount < g_cvBotEcoLimit.IntValue) && iPrimary == -1 && (strcmp(szDefaultPrimary, "weapon_hkp2000") == 0 || strcmp(szDefaultPrimary, "weapon_usp_silencer") == 0 || strcmp(szDefaultPrimary, "weapon_glock") == 0))
	{
		int iRndPistol = Math_GetRandomInt(1,10);
		
		switch (iRndPistol)
		{
			case 1: 			FakeClientCommand(client, "buy p250");
			case 2,3,4:			{FakeClientCommand(client, "buy %s", (iTeam == CS_TEAM_CT) ? "fiveseven" : "tec9");}
			case 5: 			FakeClientCommand(client, "buy elite");
			case 6,7,8,9,10: 	{FakeClientCommand(client, "buy deagle");}	
		}
	}
	return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client) && IsFakeClient(client))
	{
		g_iProfileRank[client] = 0;
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
}

public void eItems_OnItemsSynced()
{
	ServerCommand("changelevel %s", g_szMap);
}

bool IsProBot(const char[] szName, char[] szClanTag)
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/bot_names.txt");
	
	if (!FileExists(szPath))
	{
		PrintToServer("Configuration file %s is not found.", szPath);
		return false;
	}
	
	KeyValues kv = new KeyValues("Names");
	
	if (!kv.ImportFromFile(szPath))
	{
		delete kv;
		PrintToServer("Unable to parse Key Values file %s.", szPath);
		return false;
	}
	
	if(!kv.GetString(szName, szClanTag, MAX_NAME_LENGTH))
	{
		delete kv;
		return false;
	}
	
	if(strcmp(szClanTag, "") == 0)
	{
		delete kv;
		return false;
	}
	
	delete kv;
	
	return true;
}

bool GetCrosshairCode(const char[] szName, char[] szCrosshairCode, int iSize)
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/bot_crosshaircodes.txt");
	
	if (!FileExists(szPath))
	{
		PrintToServer("Configuration file %s is not found.", szPath);
		return false;
	}
	
	KeyValues kv = new KeyValues("Names");
	
	if (!kv.ImportFromFile(szPath))
	{
		delete kv;
		PrintToServer("Unable to parse Key Values file %s.", szPath);
		return false;
	}
	
	kv.GetString(szName, szCrosshairCode, iSize);
	
	delete kv;
	
	return true;
}

public void LoadSDK()
{
	Handle hGameConfig = LoadGameConfigFile("botstuff.games");
	if (hGameConfig == INVALID_HANDLE)
		SetFailState("Failed to find botstuff.games game config.");
	
	if(!(g_pTheBots = GameConfGetAddress(hGameConfig, "TheBots")))
		SetFailState("Failed to get TheBots address.");
	
	if ((g_iBotTargetSpotOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_targetSpot")) == -1)
		SetFailState("Failed to get CCSBot::m_targetSpot offset.");
	
	if ((g_iBotNearbyEnemiesOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_nearbyEnemyCount")) == -1)
		SetFailState("Failed to get CCSBot::m_nearbyEnemyCount offset.");
	
	if ((g_iBotTaskOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_task")) == -1)
		SetFailState("Failed to get CCSBot::m_task offset.");
	
	if ((g_iFireWeaponOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_fireWeaponTimestamp")) == -1)
		SetFailState("Failed to get CCSBot::m_fireWeaponTimestamp offset.");
	
	if ((g_iEnemyVisibleOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_isEnemyVisible")) == -1)
		SetFailState("Failed to get CCSBot::m_isEnemyVisible offset.");
	
	if ((g_iBotProfileOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_pLocalProfile")) == -1)
		SetFailState("Failed to get CCSBot::m_pLocalProfile offset.");
	
	if ((g_iBotSafeTimeOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_safeTime")) == -1)
		SetFailState("Failed to get CCSBot::m_safeTime offset.");
	
	if ((g_iBotAttackingOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_isAttacking")) == -1)
		SetFailState("Failed to get CCSBot::m_isAttacking offset.");
	
	if ((g_iBotEnemyOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_enemy")) == -1)
		SetFailState("Failed to get CCSBot::m_enemy offset.");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::MoveTo");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); // Move Position As Vector, Pointer
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // Move Type As Integer
	if ((g_hBotMoveTo = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::MoveTo signature!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBaseAnimating::LookupBone");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBaseAnimating::GetBonePosition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::IsVisible");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotIsVisible = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::IsVisible signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::IsAtHidingSpot");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotIsHiding = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::IsAtHidingSpot signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::EquipBestWeapon");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotEquipBestWeapon = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::EquipBestWeapon signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::SetLookAt");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotSetLookAt = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::SetLookAt signature!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "SetCrosshairCode");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((g_hSetCrosshairCode = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for SetCrosshairCode signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "Weapon_Switch");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSwitchWeaponCall = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for Weapon_Switch offset!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBotManager::IsLineBlockedBySmoke");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hIsLineBlockedBySmoke = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CBotManager::IsLineBlockedBySmoke offset!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::SetBotEnemy");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Plain);
	if ((g_hBotSetEnemy = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::SetBotEnemy signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::BendLineOfSight");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	if ((g_hBotBendLineOfSight = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::BendLineOfSight signature!");
	
	delete hGameConfig;
}

public void LoadDetours()
{
	GameData hGameData = new GameData("botstuff.games");   
	if (hGameData == null)
	{
		SetFailState("Failed to load botstuff gamedata.");
		return;
	}
	
	//CCSBot::SetLookAt Detour
	DynamicDetour hBotSetLookAtDetour = DynamicDetour.FromConf(hGameData, "CCSBot::SetLookAt");
	if(!hBotSetLookAtDetour.Enable(Hook_Pre, CCSBot_SetLookAt))
		SetFailState("Failed to setup detour for CCSBot::SetLookAt");
	
	//CCSBot::PickNewAimSpot Detour
	DynamicDetour hBotPickNewAimSpotDetour = DynamicDetour.FromConf(hGameData, "CCSBot::PickNewAimSpot");
	if(!hBotPickNewAimSpotDetour.Enable(Hook_Post, CCSBot_PickNewAimSpot))
		SetFailState("Failed to setup detour for CCSBot::PickNewAimSpot");
	
	//CCSBot::ThrowGrenade Detour
	DynamicDetour hBotThrowGrenadeDetour = DynamicDetour.FromConf(hGameData, "CCSBot::ThrowGrenade");
	if(!hBotThrowGrenadeDetour.Enable(Hook_Pre, CCSBot_ThrowGrenade))
		SetFailState("Failed to setup detour for CCSBot::ThrowGrenade");
	
	//BotCOS Detour
	DynamicDetour hBotCOSDetour = DynamicDetour.FromConf(hGameData, "BotCOS");
	if(!hBotCOSDetour.Enable(Hook_Pre, BotCOS))
		SetFailState("Failed to setup detour for BotCOS");
	
	//BotSIN Detour
	DynamicDetour hBotSINDetour = DynamicDetour.FromConf(hGameData, "BotSIN");
	if(!hBotSINDetour.Enable(Hook_Pre, BotSIN))
		SetFailState("Failed to setup detour for BotSIN");
	
	//CCSBot::IsVisible(pos) Detour
	DynamicDetour hBotVisiblePosDetour = DynamicDetour.FromConf(hGameData, "CCSBot::IsVisible(pos)");
	if(!hBotVisiblePosDetour.Enable(Hook_Pre, CCSBot_IsVisiblePos))
		SetFailState("Failed to setup detour for CCSBot::IsVisible(pos)");

	//CCSBot::IsVisible(player) Detour
	DynamicDetour hBotVisiblePlayerDetour = DynamicDetour.FromConf(hGameData, "CCSBot::IsVisible(player)");
	if(!hBotVisiblePlayerDetour.Enable(Hook_Pre, CCSBot_IsVisiblePlayer))
		SetFailState("Failed to setup detour for CCSBot::IsVisible(player)");
	
	//CCSBot::GetPartPosition Detour
	DynamicDetour hBotGetPartPosDetour = DynamicDetour.FromConf(hGameData, "CCSBot::GetPartPosition");
	if(!hBotGetPartPosDetour.Enable(Hook_Pre, CCSBot_GetPartPosition))
		SetFailState("Failed to setup detour for CCSBot::GetPartPosition");
	
	delete hGameData;
}

public int LookupBone(int iEntity, const char[] szName)
{
	return SDKCall(g_hLookupBone, iEntity, szName);
}

public void GetBonePosition(int iEntity, int iBone, float fOrigin[3], float fAngles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, fOrigin, fAngles);
}

public void BotMoveTo(int client, float fOrigin[3], RouteType routeType)
{
	SDKCall(g_hBotMoveTo, client, fOrigin, routeType);
}

bool BotIsVisible(int client, float fPos[3], bool bTestFOV, int iIgnore = -1)
{
	return SDKCall(g_hBotIsVisible, client, fPos, bTestFOV, iIgnore);
}

public bool BotIsHiding(int client)
{
	return SDKCall(g_hBotIsHiding, client);
}

public void BotEquipBestWeapon(int client, bool bMustEquip)
{
	SDKCall(g_hBotEquipBestWeapon, client, bMustEquip);
}

public void BotSetLookAt(int client, const char[] szDesc, const float fPos[3], PriorityType pri, float fDuration, bool bClearIfClose, float fAngleTolerance, bool bAttack)
{
	SDKCall(g_hBotSetLookAt, client, szDesc, fPos, pri, fDuration, bClearIfClose, fAngleTolerance, bAttack);
}

public void BotSetEnemy(int client, int iEnemy)
{
	SDKCall(g_hBotSetEnemy, client, iEnemy);
}

public int BotBendLineOfSight(int client, const float fEye[3], const float fTarget[3], float fBend[3], float fAngleLimit)
{
	SDKCall(g_hBotBendLineOfSight, client, fEye, fTarget, fBend, fAngleLimit);
}

public void SetCrosshairCode(Address pCCSPlayerResource, int client, const char[] szCode)
{
	SDKCall(g_hSetCrosshairCode, pCCSPlayerResource, client, szCode);
}

public int BotGetEnemy(int client)
{
	return GetEntDataEnt2(client, g_iBotEnemyOffset);
}

public bool BotIsBusy(int client)
{
	TaskType iBotTask = view_as<TaskType>(GetEntData(client, g_iBotTaskOffset));
	
	return iBotTask == PLANT_BOMB || iBotTask == RESCUE_HOSTAGES || iBotTask == COLLECT_HOSTAGES || iBotTask == GUARD_LOOSE_BOMB || iBotTask == GUARD_BOMB_ZONE || iBotTask == GUARD_HOSTAGES || iBotTask == GUARD_HOSTAGE_RESCUE_ZONE || iBotTask == ESCAPE_FROM_FLAMES;
}

public int GetNearestEntity(int client, char[] szClassname)
{
	int iNearestEntity = -1;
	float fClientOrigin[3], fEntityOrigin[3];
	
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", fClientOrigin); // Line 2607
	
	//Get the distance between the first entity and client
	float fDistance, fNearestDistance = -1.0;
	
	//Find all the entity and compare the distances
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, szClassname)) != -1)
	{
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin); // Line 2610
		fDistance = GetVectorDistance(fClientOrigin, fEntityOrigin);
		
		if (fDistance < fNearestDistance || fNearestDistance == -1.0)
		{
			iNearestEntity = iEntity;
			fNearestDistance = fDistance;
		}
	}
	
	return iNearestEntity;
}

stock void CSGO_SetMoney(int client, int iAmount)
{
	if (iAmount < 0)
		iAmount = 0;
	
	int iMax = FindConVar("mp_maxmoney").IntValue;
	
	if (iAmount > iMax)
		iAmount = iMax;
	
	SetEntProp(client, Prop_Send, "m_iAccount", iAmount);
}

stock int CSGO_ReplaceWeapon(int client, int iSlot, const char[] szClass)
{
	int iWeapon = GetPlayerWeaponSlot(client, iSlot);
	
	if (IsValidEntity(iWeapon))
	{
		if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") != client)
			SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", client);
		
		CS_DropWeapon(client, iWeapon, false, true);
		AcceptEntityInput(iWeapon, "Kill");
	}
	
	iWeapon = GivePlayerItem(client, szClass);
	
	if (IsValidEntity(iWeapon))
		EquipPlayerWeapon(client, iWeapon);
	
	return iWeapon;
}

bool IsPlayerReloading(int client)
{
	int iPlayerWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(!IsValidEntity(iPlayerWeapon))
		return false;
	
	//Out of ammo? or Reloading? or Finishing Weapon Switch?
	if(GetEntProp(iPlayerWeapon, Prop_Data, "m_bInReload") || GetEntProp(iPlayerWeapon, Prop_Send, "m_iClip1") <= 0 || GetEntProp(iPlayerWeapon, Prop_Send, "m_iIronSightMode") == 2)
		return true;
	
	if(GetEntPropFloat(client, Prop_Send, "m_flNextAttack") > GetGameTime())
		return true;
	
	return GetEntPropFloat(iPlayerWeapon, Prop_Send, "m_flNextPrimaryAttack") >= GetGameTime();
}

public Action Timer_Zoomed(Handle hTimer, any client)
{
	client = GetClientOfUserId(client);
	
	if(client != 0 && IsClientInGame(client))
		g_bZoomed[client] = true;	
	
	return Plugin_Stop;
}

public Action Timer_DelaySwitch(Handle hTimer, any client)
{
	client = GetClientOfUserId(client);
	
	if(client != 0 && IsClientInGame(client))
	{
		SDKCall(g_hSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE), 0);
		SDKCall(g_hSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), 0);
	}
	
	return Plugin_Stop;
}

public Action Timer_Breakable(Handle hTimer, any client)
{
	client = GetClientOfUserId(client);
	
	if(client != 0 && IsClientInGame(client))
		g_bDontSwitch[client] = false;	
	
	return Plugin_Stop;
}

public void SelectBestTargetPos(int client, float fTargetPos[3])
{
	if(IsValidClient(g_iTarget[client]) && IsPlayerAlive(g_iTarget[client]))
	{
		int iBone = LookupBone(g_iTarget[client], "head_0");
		int iSpineBone = LookupBone(g_iTarget[client], "spine_3");
		if (iBone < 0 || iSpineBone < 0)
			return;
		
		bool bShootSpine;
		float fHead[3], fBody[3], fBad[3];
		GetBonePosition(g_iTarget[client], iBone, fHead, fBad);
		GetBonePosition(g_iTarget[client], iSpineBone, fBody, fBad);
		
		fHead[2] += 4.0;
		
		if (BotIsVisible(client, fHead, false, -1))
		{
			if (BotIsVisible(client, fBody, false, -1))
			{
				int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if (iActiveWeapon == -1) return;
				
				int iDefIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
				
				switch(iDefIndex)
				{
					case 7, 8, 10, 13, 14, 16, 17, 19, 23, 24, 25, 26, 27, 28, 29, 33, 34, 35, 39, 60:
					{	
						if(HumansOnTeam(CS_TEAM_CT) > 0 && !HumansOnTeam(CS_TEAM_T))
						{
							if(	GetClientTeam(client) == CS_TEAM_CT)
							{
								if (Math_GetRandomInt(1, 100) <= 85)
								bShootSpine = true;
							}
							if(	GetClientTeam(client) == CS_TEAM_T)
							{
								if (Math_GetRandomInt(1, 100) <= 5)
								bShootSpine = true;
							}
						}
						
						if(HumansOnTeam(CS_TEAM_T) > 0 && !HumansOnTeam(CS_TEAM_CT))
						{
							if(	GetClientTeam(client) == CS_TEAM_CT)
							{
								if (Math_GetRandomInt(1, 100) <= 5)
								bShootSpine = true;
							}
							if(	GetClientTeam(client) == CS_TEAM_T)
							{
								if (Math_GetRandomInt(1, 100) <= 75)
								bShootSpine = true;
							}
						}
						
						else 
						{
								if (Math_GetRandomInt(1, 100) <= 10)
								bShootSpine = true;
						}	
					}	
					case 2, 3, 4, 30, 32, 36, 61, 63:
					{
						if (Math_GetRandomInt(1, 100) <= 5)
							bShootSpine = true;
					}
					case 9, 11, 38:
					{
						bShootSpine = true;
					}
				}
			}
		}
		else
		{
			//Head wasn't visible, check other bones.
			for (int b = 0; b <= sizeof(g_szBoneNames) - 1; b++)
			{
				iBone = LookupBone(g_iTarget[client], g_szBoneNames[b]);
				if (iBone < 0)
					return;
				
				GetBonePosition(g_iTarget[client], iBone, fHead, fBad);
				
				if (BotIsVisible(client, fHead, false, -1))
					break;
				else
					fHead[2] = 0.0;
			}
		}
		
		if(bShootSpine)
			fTargetPos = fBody;
		else
			fTargetPos = fHead;
	}
}

stock void GetViewVector(float fVecAngle[3], float fOutPut[3])
{
	fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

stock bool IsPointVisible(float fStart[3], float fEnd[3])
{
	TR_TraceRayFilter(fStart, fEnd, MASK_VISIBLE_AND_NPCS, RayType_EndPoint, TraceEntityFilterStuff);
	return TR_GetFraction() >= 0.9;
}

public bool TraceEntityFilterStuff(int iEntity, int iMask)
{
	return iEntity > MaxClients;
}

stock bool LineGoesThroughSmoke(float fFrom[3], float fTo[3])
{	
	return SDKCall(g_hIsLineBlockedBySmoke, g_pTheBots, fFrom, fTo);
} 

stock int GetAliveTeamCount(int iTeam)
{
	int iNumber = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == iTeam)
			iNumber++;
	}
	return iNumber;
}

stock int HumansOnTeam(int iTeam, bool bIsAlive = false)
{
	int iCount = 0;

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsValidClient(i))
			continue;

		if (IsFakeClient(i))
			continue;

		if (GetClientTeam(i) != iTeam)
			continue;

		if (bIsAlive && !IsPlayerAlive(i))
			continue;

		iCount++;
	}

	return iCount;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}
