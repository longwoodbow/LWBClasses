//added new hitters
//scale the damage:
//      knights cant damage
//      arrows cant damage

#include "Hitters.as";

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	f32 dmg = damage;
	switch (customData)
	{
		case Hitters::builder:
		case Hitters::hammer:
		case Hitters::mattock:
		case Hitters::acid:
		case Hitters::ram:
		case Hitters::handaxe:
			dmg *= 2.0f; //builder is great at smashing stuff
			break;

		case Hitters::sword:
		case Hitters::bayonet:
		case Hitters::spear:
		case Hitters::arrow:
		case Hitters::thrownspear:
		case Hitters::stab:
		case Hitters::shovel:
		case Hitters::axe:
		case Hitters::rapier:
		case Hitters::boomerang:
		case Hitters::stick:
		case Hitters::kitchenknife:
		case Hitters::thrownrock:
		case Hitters::thrownaxe:
		case Hitters::pike_thrust:
			dmg = 0.0f;
			break;

		case Hitters::bomb:
		case Hitters::handcannon:
			dmg *= 0.5f;
			break;

		case Hitters::keg:
		case Hitters::explosion:
			dmg *= 2.5f;
			break;

		case Hitters::bomb_arrow:
			dmg *= 8.0f;
			break;

		case Hitters::cata_stones:
			dmg *= 5.0f;
			break;
		case Hitters::crush:
			dmg *= 4.0f;
			break;

		case Hitters::flying: // boat ram
			dmg *= 7.0f;
			break;
			
		case Hitters::chakram:
		case Hitters::warhammer:
		case Hitters::flail:
		case Hitters::pike_slash:
			dmg *= 0.5f;
			break;

		case Hitters::bullet:
		case Hitters::firelance:
			dmg *= 1.5f;
			break;
	}

	return dmg;
}
