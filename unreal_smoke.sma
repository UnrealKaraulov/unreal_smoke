#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <reapi>
#include <xs>

#define VERSION "1.0.0"

new const g_szClassname[] = "real_classsmoke";

new const g_szSmokeSprite_SpriteName[] = "sprites/unrealchmoke_1.spr";
new const g_szSmokeSprite_SmokeName[] = "sprites/unrealchmoke_2.spr";


new const SMOKE_LIFE_TIME = 25;


new g_smokesprite_smoke;
new g_smokesprite_sprite;



new g_Cvar_Enabled;

new g_remove_real_smoke;

new max_light;
new min_light;

new max_scale;
new min_scale;

new smoke_fps;

new smoke_as_sprite;

new sprites_per_sec;


new Float:SMOKE_MAX_RADIUS;

new Float:z_offset_rndmax;
new Float:z_offset_rndmin;


public plugin_init( ) 
{
	register_plugin( "Unreal Smoke", VERSION, "karaulov" );
	
	register_cvar( "unreal_smoke", VERSION, FCVAR_SERVER | FCVAR_SPONLY );
	
	set_cvar_string( "unreal_smoke", VERSION );
	
	
	bind_pcvar_num(create_cvar("unrealsmoke", "1", _, _, true, 0.0, true, 1.0), g_Cvar_Enabled)
	
	// удалить эффект дыма
	// remove real smoke effect
	bind_pcvar_num(create_cvar("unrealsmoke_removerealsmoke", "1", _, _, true, 0.0, true, 1.0), g_remove_real_smoke)
	
	// FPS TE_SMOKE
	bind_pcvar_num(create_cvar("unrealsmoke_fps", "4", _, _, true, 0.0, true, 256.0), smoke_fps)
		
	// использовать TE_FIREFIELD ( unrealchmoke_1.spr ) вместо TE_SMOKE ( unrealchmoke_2.spr )
	// use TE_FIREFIELD instead of TE_SMOKE
	bind_pcvar_num(create_cvar("unrealsmoke_fire", "0", _, _, true, 0.0, true, 1.0), smoke_as_sprite)
	
	// максимальный размер TE_SMOKE
	// max scale TE_SMOKE
	bind_pcvar_num(create_cvar("unrealsmoke_maxscale", "130", _, _, true, 2.0, true, 400.0), max_scale)
	
	// минимальный размер TE_SMOKE
	// min scale TE_SMOKE
	bind_pcvar_num(create_cvar("unrealsmoke_minscale", "90", _, _, true, 2.0, true, 400.0), min_scale)
	
	// количество спрайтов в секунду
	// sprites per second
	bind_pcvar_num(create_cvar("unrealsmoke_sprites_per_sec", "20", _, _, true, 10.0, true, 200.0), sprites_per_sec)
	
	// радиус дыма
	// smoke distance
	bind_pcvar_float(create_cvar("unrealsmoke_radius", "150.0", _, _, true, 0.0, true, 600.0), SMOKE_MAX_RADIUS);
	
	// максимальное смещение дыма по Z
	// max Z smoke offset 
	bind_pcvar_float(create_cvar("unrealsmoke_zoff_rnd_max", "20.0", _, _, true, -500.0, true, 500.0), z_offset_rndmax);
	
	// минимальное смещение дыма по Z
	// min Z smoke offset 
	bind_pcvar_float(create_cvar("unrealsmoke_zoff_rnd_min", "5.0", _, _, true, -500.0, true, 500.0), z_offset_rndmin);
	
	RegisterHookChain( RG_CGrenade_ExplodeSmokeGrenade, "ExplodeSmokeGrenade" );
	RegisterHookChain( RG_CSGameRules_RestartRound, "RestartRound" );
	
	AutoExecConfig();
}

public RestartRound()
{
	new pEntity = NULLENT;
	while((pEntity = rg_find_ent_by_class(pEntity, g_szClassname)))
	{
		engfunc(EngFunc_RemoveEntity, pEntity);
	}
}

public plugin_precache( ) 
{
	precache_sound( "weapons/grenade_hit1.wav" );
	precache_sound( "weapons/sg_explode.wav" );
	
	g_smokesprite_sprite = precache_model(g_szSmokeSprite_SpriteName);
	g_smokesprite_smoke = precache_model(g_szSmokeSprite_SmokeName);
	
	force_unmodified(force_exactfile, {0,0,0}, {0,0,0}, g_szSmokeSprite_SpriteName);
	force_unmodified(force_exactfile, {0,0,0}, {0,0,0}, g_szSmokeSprite_SmokeName);
}

public ExplodeSmokeGrenade(const iOrigEnt)
{
	if( g_Cvar_Enabled > 0 )
	{
		// cache origin, angles and model
		new Float:vOrigin[ 3 ], szModel[ 64 ];
		
		get_entvar( iOrigEnt, var_origin, vOrigin );
		get_entvar( iOrigEnt, var_model, szModel, charsmax( szModel ) );
		
		// move entity from world
		if (g_remove_real_smoke == 1)
		{
			set_entvar( iOrigEnt, var_origin, Float:{-8190.0,-8190.0,-8190.0} );
		}
	
		// create new entity
		new iEntity = rg_create_entity( "info_target" );
		if( iEntity ) 
		{
			set_entvar( iEntity, var_classname, g_szClassname );
			set_entvar( iEntity, var_origin, vOrigin );
			set_entvar( iEntity, var_nextthink, get_gametime( ) );
			set_entvar( iEntity, var_solid, SOLID_NOT );
			set_entvar( iEntity, var_movetype, MOVETYPE_NONE );
			set_entvar( iEntity, var_fuser4, get_gametime()+SMOKE_LIFE_TIME);
			entity_set_model( iEntity, szModel );
			
			emit_sound(iEntity, CHAN_AUTO, "weapons/sg_explode.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			SetThink(iEntity,"Think_FakeSmoke");
		}
	}
	return HC_CONTINUE;
}


public Think_FakeSmoke(iEnt)
{
	if( is_nullent( iEnt ) )
		return;
		
	set_entvar( iEnt, var_nextthink, get_gametime( ) + 0.1 );

	
	if( get_gametime () >= get_entvar(iEnt,var_fuser4) )
	{
		set_entvar(iEnt, var_flags, FL_KILLME);
	}
	

	new Float:s_fDistance;
		
	new s_iLoopId = get_entvar(iEnt,var_iuser4);
	
	new cursprite = sprites_per_sec / 10;
	
	if (cursprite <= 0)
		cursprite = 1;
	
	new Float:vOrigin[3], Float:vEndOrigin[3];
	get_entvar(iEnt, var_origin, vOrigin);
	get_entvar(iEnt, var_origin, vEndOrigin);

	

	new Float:s_fFraction;
	engfunc(EngFunc_TraceLine, vOrigin, vEndOrigin, IGNORE_MONSTERS, iEnt, 0);
	get_tr2(0, TR_flFraction, s_fFraction);
	
	if( s_fFraction!=1.0 )
		get_tr2(0, TR_pHit, vOrigin);
	else
		vOrigin = vEndOrigin;

	while(cursprite > 0)
	{
		s_iLoopId++;
		if (s_iLoopId >= sprites_per_sec)
			s_iLoopId = 0;
	
		cursprite--;
		
		vEndOrigin[0] = random_float((random(2)?-50.0:-80.0), 0.0);
		vEndOrigin[1] = random_float((s_iLoopId*(360.0/sprites_per_sec)), ((s_iLoopId+1)*(360.0/sprites_per_sec)));
		vEndOrigin[2] = 0.0;
		
		while( vEndOrigin[1]>180.0 )
			vEndOrigin[1] -= 360.0;
		
		engfunc(EngFunc_MakeVectors, vEndOrigin);
		global_get(glb_v_forward, vEndOrigin);
		
		xs_vec_mul_scalar(vEndOrigin, 9999.0, vEndOrigin)
		xs_vec_add(vEndOrigin, vOrigin, vEndOrigin)
		
		engfunc(EngFunc_TraceLine, vOrigin, vEndOrigin, IGNORE_MONSTERS, iEnt, 0);
		get_tr2(0, TR_vecEndPos, vEndOrigin);
		
		if( (s_fDistance=get_distance_f(vOrigin, vEndOrigin))>(s_fFraction=(random(3)?random_float((SMOKE_MAX_RADIUS*0.5), SMOKE_MAX_RADIUS):random_float(16.0, SMOKE_MAX_RADIUS))) )
		{
			s_fFraction /= s_fDistance;
			
			if( vEndOrigin[0]!=vOrigin[0] )
			{
				s_fDistance = (vEndOrigin[0]-vOrigin[0])*s_fFraction;
				vEndOrigin[0] = (vOrigin[0]+s_fDistance);
			}
			if( vEndOrigin[1]!=vOrigin[1] )
			{
				s_fDistance = (vEndOrigin[1]-vOrigin[1])*s_fFraction;
				vEndOrigin[1] = (vOrigin[1]+s_fDistance);
			}
			if( vEndOrigin[2]!=vOrigin[2] )
			{
				s_fDistance = (vEndOrigin[2]-vOrigin[2])*s_fFraction ;
				vEndOrigin[2] = (vOrigin[2]+s_fDistance) ;
			}
		}
		
		new smokescale = random_num(min_scale, max_scale);
		if (smokescale < 2)
			smokescale = 2;
		new smokelight = random_num(min_light, max_light );
		if (smokelight < 1)
			smokelight = 1;
		new smokefps = smoke_fps;

			
		if (smoke_as_sprite)
		{
			set_entvar( iEnt, var_nextthink, get_gametime( ) + 0.3 );
			te_create_fire_field(vOrigin,g_smokesprite_sprite, floatround(SMOKE_MAX_RADIUS),floatround(float(sprites_per_sec) / 1.5));
			break;
		}

		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_SMOKE);
		engfunc(EngFunc_WriteCoord, vEndOrigin[0]);
		engfunc(EngFunc_WriteCoord, vEndOrigin[1]);
		engfunc(EngFunc_WriteCoord, (vEndOrigin[2] - random_float(z_offset_rndmin,z_offset_rndmax)));
		write_short(g_smokesprite_smoke);
		write_byte(smokescale / 2);
		write_byte(smokefps);
		message_end();
	}
	
	set_entvar(iEnt,var_iuser4,s_iLoopId);
}

stock get_msg_destination(id, bool:reliable)
{
    if(id)
        return reliable ? MSG_ONE : MSG_ONE_UNRELIABLE;

    return reliable ? MSG_ALL : MSG_BROADCAST;
}

stock te_create_fire_field(Float:position[3], sprite, radius = 5, count = 1, duration = 20, flags = TEFIRE_FLAG_ALPHA, receiver = 0, bool:reliable = true)
{
	if(receiver && !is_user_connected(receiver))
		return 0;
	message_begin(get_msg_destination(receiver, reliable), SVC_TEMPENTITY, .player = receiver);
	write_byte(TE_FIREFIELD);
	write_coord_f(position[0]);
	write_coord_f(position[1]);
	write_coord_f(position[2]);
	write_short(radius);
	write_short(sprite);
	write_byte(count);
	write_byte(flags);
	if (duration > 255)
		duration = 255;
	write_byte(duration);
	message_end();
	return 1;
}