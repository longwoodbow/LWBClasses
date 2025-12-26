//added new hitters
#include "Hitters.as";
#include "GameplayEventsCommon.as";

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	f32 dmg = damage;

	switch (customData)
	{
		case Hitters::builder:
		case Hitters::hammer:
		case Hitters::mattock:
		case Hitters::ram:
		case Hitters::axe:
		case Hitters::pike_slash:
		case Hitters::handaxe:
			dmg *= 2.0f;
			break;

		case Hitters::sword:
		case Hitters::bayonet:
		case Hitters::spear:
		case Hitters::stab:
		case Hitters::rapier:
		case Hitters::boomerang:
		case Hitters::stick:
		case Hitters::kitchenknife:
		case Hitters::pike_thrust:
			if (dmg <= 1.0f)
			{
				dmg = 0.25f;
			}
			else
			{
				dmg = 0.5f;
			}
			break;

		case Hitters::bomb:
		case Hitters::handcannon:
			dmg *= 1.40f;
			break;

		case Hitters::cannon:
			dmg *= 2.5f;
			break;

		case Hitters::explosion:
			dmg *= 4.5f;
			break;

		case Hitters::bomb_arrow:
			dmg *= this.exists("bomb resistance") ? this.get_f32("bomb resistance") : 8.0f;
			break;

		case Hitters::acid:
			dmg = this.getMass() > 1000.0f ? 4.0f : 2.0f;
			break;

		case Hitters::arrow:
			dmg = this.getMass() > 1000.0f ? 0.2f : 0.5f;
			break;

		case Hitters::thrownspear:
		case Hitters::thrownaxe:
			dmg = this.getMass() > 1000.0f ? 0.5f : 1.0f;
			break;

		case Hitters::ballista:
			dmg *= 2.0f;
			break;

		case Hitters::thrownrock:
		case Hitters::bullet:
		case Hitters::shovel:
		case Hitters::warhammer:
		case Hitters::flail:
		case Hitters::chakram:
		case Hitters::firelance:
			dmg *= 1.0f;
			break;

	}

	if (dmg > 0 && hitterBlob !is null && hitterBlob !is this)
	{
		CPlayer@ damageowner = hitterBlob.getDamageOwnerPlayer();
		if (damageowner !is null)
		{
			if (damageowner.getTeamNum() != this.getTeamNum() && isServer())
			{
				GE_HitVehicle(damageowner.getNetworkID(), dmg); // gameplay event for coins
			}
		}
	}

	return dmg;
}

void onDie(CBlob@ this)
{
	CPlayer@ p = this.getPlayerOfRecentDamage();
	if (p !is null)
	{
		CBlob@ b = p.getBlob();
		if (b !is null && b.getTeamNum() != this.getTeamNum() && isServer())
		{
			CPlayer@ p = this.getPlayerOfRecentDamage();
			if (p !is null)
			{
				GE_KillVehicle(p.getNetworkID());
			}
		}
	}
}